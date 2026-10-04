import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from passlib.context import CryptContext
from sqlalchemy import func
from sqlalchemy.orm import Session

from ...database.session import get_db
from ...models.db_models import (
    CategoryCorrection,
    CashExpense,
    Forecast,
    Statement,
    Transaction,
    User,
)
from ...models.schemas import (
    Token,
    UserCreate,
    UserIdentifyRequest,
    UserIdentifyResponse,
    UserLogin,
    UserResponse,
)
from ..deps import create_access_token, get_current_user, get_current_user_optional

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    if not hashed_password:
        return False
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

@router.post("/identify", response_model=UserIdentifyResponse)
def identify(
    payload: UserIdentifyRequest,
    db: Session = Depends(get_db),
    calling_user: Optional[User] = Depends(get_current_user_optional)
):
    """
    Identifies a user by normalized email address (Phase 5).
    - Validates and normalizes email (trim + lowercase).
    - If user exists, retrieves user and returns stable user_id and access token.
    - If user does not exist, creates a new user or upgrades an existing guest session.
    - Safely migrates financial records if an ephemeral guest user identifies as an existing user.
    """
    normalized_email = payload.email.strip().lower()
    if not normalized_email:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A valid email address is required."
        )

    # Case-insensitive query using func.lower
    existing_user = db.query(User).filter(func.lower(User.email) == normalized_email).first()

    is_ephemeral_guest = (
        calling_user is not None
        and calling_user.is_guest
        and calling_user.email != "demo@expenseinsight.app"
    )

    if existing_user:
        is_new_user = False
        target_user = existing_user

        # If calling from an ephemeral guest session that is distinct from existing user,
        # safely migrate guest-created records into the existing user account (Phase 8)
        if is_ephemeral_guest and calling_user.id != existing_user.id:
            # Reassign statements
            db.query(Statement).filter(Statement.user_id == calling_user.id).update(
                {Statement.user_id: existing_user.id}, synchronize_session=False
            )
            # Reassign transactions
            db.query(Transaction).filter(Transaction.user_id == calling_user.id).update(
                {Transaction.user_id: existing_user.id}, synchronize_session=False
            )
            # Reassign cash expenses
            db.query(CashExpense).filter(CashExpense.user_id == calling_user.id).update(
                {CashExpense.user_id: existing_user.id}, synchronize_session=False
            )
            # Reassign category corrections
            db.query(CategoryCorrection).filter(CategoryCorrection.user_id == calling_user.id).update(
                {CategoryCorrection.user_id: existing_user.id}, synchronize_session=False
            )
            # Remove guest forecast
            db.query(Forecast).filter(Forecast.user_id == calling_user.id).delete(synchronize_session=False)
            # Remove ephemeral guest record
            db.delete(calling_user)
            db.commit()
            db.refresh(existing_user)

            # Trigger safe observable forecast recalculation for existing user
            from ...services.forecasting_service import ForecastingService
            ForecastingService.refresh_user_forecast_safe(
                db=db,
                user_id=existing_user.id,
                trigger="guest_migration"
            )

    else:
        # User does not exist yet
        is_new_user = True
        if is_ephemeral_guest:
            # Upgrade guest in-place, preserving stable user.id and all existing records
            calling_user.email = normalized_email
            calling_user.is_guest = False
            db.commit()
            db.refresh(calling_user)
            target_user = calling_user
        else:
            new_user = User(
                email=normalized_email,
                hashed_password=None,
                is_guest=False
            )
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            target_user = new_user

    token = create_access_token(data={"sub": target_user.id, "email": target_user.email})

    return {
        "user_id": target_user.id,
        "email": target_user.email,
        "is_new_user": is_new_user,
        "access_token": token,
        "token_type": "bearer",
        "user": target_user
    }

@router.post("/register", response_model=Token)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    """Registers a new user account."""
    normalized_email = user_in.email.strip().lower()
    existing = db.query(User).filter(func.lower(User.email) == normalized_email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email address already exists."
        )

    user = User(
        email=normalized_email,
        hashed_password=get_password_hash(user_in.password),
        is_guest=False
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(data={"sub": user.id, "email": user.email})
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": user
    }

@router.post("/login", response_model=Token)
def login(user_in: UserLogin, db: Session = Depends(get_db)):
    """Logs in an existing user."""
    normalized_email = user_in.email.strip().lower()
    user = db.query(User).filter(func.lower(User.email) == normalized_email).first()
    if not user or not verify_password(user_in.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password."
        )

    token = create_access_token(data={"sub": user.id, "email": user.email})
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": user
    }

@router.post("/guest", response_model=Token)
def guest_login(db: Session = Depends(get_db)):
    """Creates or returns an instant guest/demo session."""
    guest_email = f"guest_{uuid.uuid4().hex[:8]}@expenseinsight.app"
    user = User(
        email=guest_email,
        hashed_password="guest_nopassword",
        is_guest=True
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(data={"sub": user.id, "email": user.email})
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": user
    }

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    """Returns profile information for current user."""
    return current_user
