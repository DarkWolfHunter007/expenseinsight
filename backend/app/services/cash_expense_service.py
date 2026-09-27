from datetime import datetime
from typing import List, Optional
from sqlalchemy.orm import Session

from ..models.db_models import CashExpense
from ..models.schemas import CashExpenseCreate, CashExpenseUpdate

class CashExpenseService:
    """
    Business logic and database persistence layer for Cash / Liquid Money Expenses.
    Guarantees user isolation, financial precision, and deterministic date handling.
    """

    def __init__(self, db: Session):
        self.db = db

    def create_cash_expense(self, user_id: str, payload: CashExpenseCreate) -> CashExpense:
        """Creates a new cash expense record strictly owned by user_id."""
        clean_category = payload.category.strip()
        clean_desc = payload.description.strip() if payload.description else None
        amt = round(float(payload.amount), 2)

        expense = CashExpense(
            user_id=user_id,
            amount=amt,
            category=clean_category,
            description=clean_desc,
            expense_date=payload.expense_date,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        self.db.add(expense)
        self.db.commit()
        self.db.refresh(expense)
        return expense

    def get_cash_expenses(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        category: Optional[str] = None,
        search: Optional[str] = None,
        sort_by: str = "expense_date",
        order: str = "desc",
        limit: int = 500,
        offset: int = 0
    ) -> List[CashExpense]:
        """Lists user's cash expenses with optional date range, category, and text search."""
        query = self.db.query(CashExpense).filter(CashExpense.user_id == user_id)

        if start_date:
            query = query.filter(CashExpense.expense_date >= start_date)
        if end_date:
            query = query.filter(CashExpense.expense_date <= end_date)
        if category and category.lower() != "all":
            query = query.filter(CashExpense.category.ilike(category))
        if search:
            search_pat = f"%{search}%"
            query = query.filter(
                (CashExpense.description.ilike(search_pat)) |
                (CashExpense.category.ilike(search_pat))
            )

        if sort_by == "amount":
            query = query.order_by(CashExpense.amount.desc() if order == "desc" else CashExpense.amount.asc())
        elif sort_by == "category":
            query = query.order_by(CashExpense.category.desc() if order == "desc" else CashExpense.category.asc())
        else:  # expense_date
            query = query.order_by(CashExpense.expense_date.desc() if order == "desc" else CashExpense.expense_date.asc())

        return query.offset(offset).limit(limit).all()

    def get_cash_expense(self, user_id: str, expense_id: str) -> Optional[CashExpense]:
        """Retrieves a single cash expense ensuring user ownership."""
        return self.db.query(CashExpense).filter(
            CashExpense.id == expense_id,
            CashExpense.user_id == user_id
        ).first()

    def update_cash_expense(
        self,
        user_id: str,
        expense_id: str,
        payload: CashExpenseUpdate
    ) -> Optional[CashExpense]:
        """Updates a cash expense ensuring user ownership and recalculating updated_at."""
        expense = self.get_cash_expense(user_id, expense_id)
        if not expense:
            return None

        if payload.amount is not None:
            expense.amount = round(float(payload.amount), 2)
        if payload.category is not None:
            expense.category = payload.category.strip()
        if payload.expense_date is not None:
            expense.expense_date = payload.expense_date
        if payload.description is not None:
            expense.description = payload.description.strip() if payload.description else None

        expense.updated_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(expense)
        return expense

    def delete_cash_expense(self, user_id: str, expense_id: str) -> bool:
        """Deletes a cash expense record ensuring user ownership."""
        expense = self.get_cash_expense(user_id, expense_id)
        if not expense:
            return False

        self.db.delete(expense)
        self.db.commit()
        return True
