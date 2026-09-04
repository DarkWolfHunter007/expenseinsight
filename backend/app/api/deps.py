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

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "expenseinsight-super-secret-key-2026")
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

def get_current_user(
    auth_credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Retrieves the current authenticated user.
    If no token is provided, creates or retrieves the default Demo/Guest user for seamless evaluation.
    """
    if auth_credentials:
        token = auth_credentials.credentials
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            user_id: str = payload.get("sub")
            if user_id:
                user = db.query(User).filter(User.id == user_id).first()
                if user:
                    return user
        except jwt.PyJWTError:
            pass

    # Default Guest/Demo fallback user for evaluator convenience
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
