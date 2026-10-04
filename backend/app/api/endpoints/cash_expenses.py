from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ...database.session import get_db
from ...models.db_models import User
from ...models.schemas import CashExpenseCreate, CashExpenseResponse, CashExpenseUpdate
from ...services.cash_expense_service import CashExpenseService
from ..deps import get_current_user

router = APIRouter()

def _trigger_forecast_sync(db: Session, user_id: str, trigger: str = "cash_expense_mutation", transaction_id: Optional[str] = None):
    """Triggers observable, safe forecast recalculation and persistence."""
    from ...services.forecasting_service import ForecastingService
    ForecastingService.refresh_user_forecast_safe(
        db=db,
        user_id=user_id,
        trigger=trigger,
        transaction_id=transaction_id
    )


@router.post("", response_model=CashExpenseResponse, status_code=status.HTTP_201_CREATED)
def create_cash_expense(
    payload: CashExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Creates a new manual cash / liquid money expense (PRD Cash Expense Tracking).
    """
    service = CashExpenseService(db=db)
    expense = service.create_cash_expense(user_id=current_user.id, payload=payload)
    _trigger_forecast_sync(db, current_user.id, trigger="create_cash_expense", transaction_id=expense.id)
    return expense


@router.get("", response_model=List[CashExpenseResponse])
def get_cash_expenses(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    sort_by: str = Query("expense_date", enum=["expense_date", "amount", "category"]),
    order: str = Query("desc", enum=["asc", "desc"]),
    limit: int = Query(500, le=1000),
    offset: int = 0,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Retrieves user's cash expenses with optional date range, category, text search, sorting, and pagination.
    """
    service = CashExpenseService(db=db)
    return service.get_cash_expenses(
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
        category=category,
        search=search,
        sort_by=sort_by,
        order=order,
        limit=limit,
        offset=offset
    )


@router.get("/{expense_id}", response_model=CashExpenseResponse)
def get_cash_expense(
    expense_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Retrieves a single cash expense by ID, enforcing user ownership.
    """
    service = CashExpenseService(db=db)
    expense = service.get_cash_expense(user_id=current_user.id, expense_id=expense_id)
    if not expense:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cash expense not found."
        )
    return expense


@router.put("/{expense_id}", response_model=CashExpenseResponse)
def update_cash_expense(
    expense_id: str,
    payload: CashExpenseUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Updates an existing cash expense, recalculating timestamps and enforcing ownership.
    """
    service = CashExpenseService(db=db)
    expense = service.update_cash_expense(
        user_id=current_user.id,
        expense_id=expense_id,
        payload=payload
    )
    if not expense:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cash expense not found."
        )
    _trigger_forecast_sync(db, current_user.id, trigger="update_cash_expense", transaction_id=expense_id)
    return expense


@router.delete("/{expense_id}")
def delete_cash_expense(
    expense_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Deletes a single cash expense by ID, enforcing user ownership.
    """
    service = CashExpenseService(db=db)
    deleted = service.delete_cash_expense(user_id=current_user.id, expense_id=expense_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cash expense not found."
        )
    _trigger_forecast_sync(db, current_user.id, trigger="delete_cash_expense", transaction_id=expense_id)
    return {"status": "success", "message": "Cash expense deleted successfully."}
