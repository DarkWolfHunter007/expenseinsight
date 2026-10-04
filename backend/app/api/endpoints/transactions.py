from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ...database.session import get_db
from ...models.db_models import CategoryCorrection, Transaction, User, CashExpense
from ...models.schemas import TransactionResponse, TransactionUpdateCategory, UncertainTransactionReview
from ..deps import get_current_user

router = APIRouter()

def _format_cash_to_transaction_response(c: CashExpense) -> TransactionResponse:
    pm = getattr(c, "effective_payment_method", "cash")
    clean_desc = getattr(c, "clean_description", c.description)
    merchant_name = "Bank Transfer" if pm == "bank" else ("UPI Payment" if pm == "upi" else "Cash Payment")
    return TransactionResponse(
        id=c.id,
        user_id=c.user_id,
        statement_id=None,
        date=c.expense_date,
        raw_description=clean_desc or f"{pm.upper()} Expense ({c.category})",
        clean_description=clean_desc,
        merchant=merchant_name,
        normalized_merchant=f"manual_{pm}",
        amount=c.amount,
        currency="INR",
        transaction_type="cash_expense" if pm == "cash" else f"{pm}_expense",
        cr_dr="DR",
        balance=None,
        reference_number=None,
        category=c.category,
        category_confidence=1.0,
        category_source=f"{pm}_manual",
        needs_review=False,
        is_duplicate=False,
        created_at=c.created_at,
        source_type=pm,
        payment_method=pm
    )

@router.get("", response_model=List[TransactionResponse])
def get_transactions(
    category: Optional[str] = None,
    search: Optional[str] = None,
    statement_id: Optional[str] = None,
    needs_review: Optional[bool] = None,
    transaction_type: Optional[str] = None,
    source: Optional[str] = Query("all", enum=["all", "bank", "cash", "upi"]),
    sort_by: str = Query("date", enum=["date", "amount", "merchant"]),
    order: str = Query("desc", enum=["asc", "desc"]),
    limit: int = Query(500, le=1000),
    offset: int = 0,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Retrieves user transactions with filtering, search, sorting, and pagination (PRD Section 33).
    Reflects bank transactions and manually entered expenses across Bank, UPI, and Cash.
    """
    bank_items: List[TransactionResponse] = []
    # Statement bank transactions are included for 'all' and 'bank'
    if source in ["all", "bank"] and transaction_type != "cash_expense":
        query = db.query(Transaction).filter(Transaction.user_id == current_user.id)

        if category and category.lower() != "all":
            query = query.filter(Transaction.category.ilike(category))

        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                (Transaction.raw_description.ilike(search_pattern)) |
                (Transaction.merchant.ilike(search_pattern)) |
                (Transaction.normalized_merchant.ilike(search_pattern))
            )

        if statement_id:
            query = query.filter(Transaction.statement_id == statement_id)

        if needs_review is not None:
            query = query.filter(Transaction.needs_review == needs_review)

        if transaction_type:
            query = query.filter(Transaction.transaction_type == transaction_type)

        # A bank statement can contain both ordinary bank-rail transactions
        # and UPI transactions. Apply the source filter after classifying each
        # persisted transaction's payment rail.
        for transaction in query.all():
            transaction_source = getattr(transaction, "source_type", "bank")
            if source in ("bank", "upi") and transaction_source != source:
                continue
            bank_items.append(TransactionResponse.model_validate(transaction))

    cash_items: List[TransactionResponse] = []
    if statement_id is None and needs_review is not True:
        cash_query = db.query(CashExpense).filter(CashExpense.user_id == current_user.id)

        if category and category.lower() != "all":
            cash_query = cash_query.filter(CashExpense.category.ilike(category))

        if search:
            search_pattern = f"%{search}%"
            cash_query = cash_query.filter(
                (CashExpense.description.ilike(search_pattern)) |
                (CashExpense.category.ilike(search_pattern))
            )

        for c in cash_query.all():
            pm = c.effective_payment_method
            # Match source filter
            if source == "all" or source == pm:
                if transaction_type is None or transaction_type in ["expense", "cash_expense", f"{pm}_expense"]:
                    cash_items.append(_format_cash_to_transaction_response(c))

    combined = bank_items + cash_items

    # Sorting
    reverse = (order == "desc")
    if sort_by == "amount":
        combined.sort(key=lambda x: x.amount, reverse=reverse)
    elif sort_by == "merchant":
        combined.sort(key=lambda x: (x.merchant or "").lower(), reverse=reverse)
    else:  # date
        combined.sort(key=lambda x: (x.date, x.created_at.isoformat() if x.created_at else ""), reverse=reverse)

    return combined[offset : offset + limit]


@router.get("/uncertain", response_model=List[UncertainTransactionReview])
def get_uncertain_transactions(
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Retrieves low-confidence transactions for the 'Help Me Categorize This' feature (PRD Section 20).
    """
    txns = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.needs_review == True
    ).order_by(Transaction.date.desc()).limit(limit).all()

    suggested = [
        "Food", "Shopping", "Travel", "Bills", "Entertainment",
        "Groceries", "Fuel", "Healthcare", "Rent", "Personal Care",
        "Education", "Investments", "Other", "Uncategorized"
    ]

    results = []
    for t in txns:
        results.append({
            "transaction_id": t.id,
            "merchant": t.merchant or t.raw_description[:25],
            "raw_description": t.raw_description,
            "amount": t.amount,
            "date": t.date,
            "predicted_category": t.category,
            "confidence": t.category_confidence,
            "confidence_percentage": f"{t.category_confidence * 100:.1f}%",
            "suggested_categories": suggested
        })

    return results


@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction(
    transaction_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieves a single transaction by ID (Bank or Cash)."""
    txn = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()
    if txn:
        return txn

    cash = db.query(CashExpense).filter(
        CashExpense.id == transaction_id,
        CashExpense.user_id == current_user.id
    ).first()
    if cash:
        return _format_cash_to_transaction_response(cash)

    raise HTTPException(status_code=404, detail="Transaction not found.")


@router.patch("/{transaction_id}/category", response_model=TransactionResponse)
def update_transaction_category(
    transaction_id: str,
    payload: TransactionUpdateCategory,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Updates category for a transaction and saves user correction feedback (PRD Section 23).
    Supports updating both bank transactions and cash expenses.
    """
    txn = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()
    if not txn:
        cash = db.query(CashExpense).filter(
            CashExpense.id == transaction_id,
            CashExpense.user_id == current_user.id
        ).first()
        if cash:
            cash.category = payload.category.strip()
            db.commit()
            db.refresh(cash)
            return _format_cash_to_transaction_response(cash)
        raise HTTPException(status_code=404, detail="Transaction not found.")

    old_cat = txn.category
    new_cat = payload.category.strip()

    txn.category = new_cat
    txn.category_confidence = 1.0
    txn.category_source = "manual_user"
    txn.needs_review = False

    # Record correction in feedback table
    correction = CategoryCorrection(
        transaction_id=txn.id,
        user_id=current_user.id,
        old_category=old_cat,
        new_category=new_cat
    )
    db.add(correction)

    # If apply_to_future is enabled, update all same-merchant transactions for this user
    if payload.apply_to_future and txn.normalized_merchant:
        similar_txns = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.normalized_merchant == txn.normalized_merchant,
            Transaction.id != txn.id
        ).all()
        for st in similar_txns:
            st.category = new_cat
            st.category_confidence = 0.95
            st.category_source = "learned_feedback"
            st.needs_review = False

    db.commit()
    db.refresh(txn)
    return txn


@router.delete("/{transaction_id}")
def delete_transaction(
    transaction_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Deletes a single transaction and cascades to its corrections and forecast update."""
    from ...models.db_models import CategoryCorrection, Forecast
    from ...services.forecasting_service import ForecastingService

    txn = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found.")

    db.query(CategoryCorrection).filter(CategoryCorrection.transaction_id == transaction_id).delete(synchronize_session=False)
    db.delete(txn)
    db.commit()

    # Re-evaluate forecasts
    remaining_count = db.query(Transaction).filter(Transaction.user_id == current_user.id).count()
    if remaining_count == 0:
        db.query(Forecast).filter(Forecast.user_id == current_user.id).delete(synchronize_session=False)
        db.commit()
    else:
        try:
            ForecastingService(db=db).generate_user_forecast(user_id=current_user.id, persist=True)
        except Exception:
            pass

    return {"status": "success", "message": "Transaction deleted."}


@router.delete("")
def delete_all_transactions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Purges all user transactions, category corrections, and forecasts."""
    from ...models.db_models import CategoryCorrection, Forecast

    db.query(CategoryCorrection).filter(CategoryCorrection.user_id == current_user.id).delete(synchronize_session=False)
    db.query(Transaction).filter(Transaction.user_id == current_user.id).delete(synchronize_session=False)
    db.query(Forecast).filter(Forecast.user_id == current_user.id).delete(synchronize_session=False)
    db.commit()

    return {"status": "success", "message": "All transactions purged."}

