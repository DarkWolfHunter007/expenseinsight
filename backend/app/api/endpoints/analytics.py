from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ...database.session import get_db
from ...models.db_models import User
from ...models.schemas import (
    AnalyticsSummaryResponse,
    CategorySpendingItem,
    MerchantSpendingItem,
    MonthlySpendingItem,
    RecurringExpenseItem,
)
from ...services.analytics_service import AnalyticsService
from ..deps import get_current_user

router = APIRouter()

@router.get("/summary", response_model=AnalyticsSummaryResponse)
def get_analytics_summary(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Calculates overall spending analytics summary combining Bank + Cash (PRD Section 25)."""
    service = AnalyticsService(db=db)
    return service.get_summary(user_id=current_user.id, start_date=start_date, end_date=end_date)


@router.get("/monthly", response_model=List[MonthlySpendingItem])
def get_monthly_spending(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Returns monthly income, expense, and savings trends combining Bank + Cash."""
    service = AnalyticsService(db=db)
    return service.get_monthly_spending(user_id=current_user.id, start_date=start_date, end_date=end_date)


@router.get("/categories", response_model=List[CategorySpendingItem])
def get_category_spending(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Returns category-wise spending distribution with percentages combining Bank + Cash."""
    service = AnalyticsService(db=db)
    return service.get_category_spending(user_id=current_user.id, start_date=start_date, end_date=end_date)


@router.get("/merchants", response_model=List[MerchantSpendingItem])
def get_merchant_spending(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Returns top spending merchants."""
    service = AnalyticsService(db=db)
    return service.get_merchant_spending(user_id=current_user.id)


@router.get("/recurring", response_model=List[RecurringExpenseItem])
def get_recurring_expenses(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Identifies recurring subscription expenses and bill cycles (PRD Section 26)."""
    service = AnalyticsService(db=db)
    return service.get_recurring_expenses(user_id=current_user.id)
