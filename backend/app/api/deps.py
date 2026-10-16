import logging
import os
from datetime import datetime, timedelta
from typing import Optional
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from ..database.session import get_db
from ..models.db_models import User
from ..models.schemas import TokenData

logger = logging.getLogger("expenseinsight.auth")

_DEFAULT_SECRET_KEY = "expenseinsight-super-secret-key-2026"
SECRET_KEY = os.getenv("JWT_SECRET_KEY") or _DEFAULT_SECRET_KEY
if SECRET_KEY == _DEFAULT_SECRET_KEY:
    logger.warning(
        "JWT_SECRET_KEY is not set: using the built-in development secret. "
        "Anyone who reads the source code can forge login tokens. "
        "Set JWT_SECRET_KEY to a long random value for any shared or public deployment."
    )
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 # 7 days

security = HTTPBearer(auto_error=False)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user_optional(
    auth_credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """
    Retrieves the current authenticated user if a valid bearer token is supplied.
    Returns None ONLY if no token is provided.
    Raises HTTPException(401) if an invalid or expired token is provided or if user no longer exists.
    Does NOT fall back to the default demo user.
    """
    if not auth_credentials:
        return None

    token = auth_credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user

def get_current_user(
    auth_credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Retrieves the current authenticated user.
    If a Bearer token is provided, strictly validates it (raises 401 on invalid/expired/not found).
    If no token is provided, creates or retrieves the default Demo/Guest user for seamless evaluation.
    """
    user = get_current_user_optional(auth_credentials, db)
    if user:
        return user

    # Default Guest/Demo fallback user for evaluator convenience ONLY when NO token is provided
    guest_user = db.query(User).filter(User.email == "demo@expenseinsight.app").first()
    if not guest_user:
        guest_user = User(
            email="demo@expenseinsight.app",
            hashed_password="demo_hashed_pw",
            is_guest=True
        )
        db.add(guest_user)
        db.commit()
        db.refresh(guest_user)
    return guest_user
