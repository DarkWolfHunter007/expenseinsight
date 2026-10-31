import json

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...database.session import get_db
from ...models.db_models import BudgetSettings, User
from ...models.schemas import BudgetSettingsPayload
from ..deps import get_current_user

router = APIRouter()


def _to_payload(row: BudgetSettings | None) -> BudgetSettingsPayload:
    if row is None:
        return BudgetSettingsPayload()
    try:
        limits = json.loads(row.category_limits or "{}")
    except ValueError:
        limits = {}
    return BudgetSettingsPayload(
        auto_limits=bool(row.auto_limits),
        monthly_limit=row.monthly_limit,
        category_limits=limits,
    )


@router.get("/settings", response_model=BudgetSettingsPayload)
def get_budget_settings(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Returns the user's budget preferences (defaults to automatic limits)."""
    row = db.query(BudgetSettings).filter(BudgetSettings.user_id == current_user.id).first()
    return _to_payload(row)


@router.put("/settings", response_model=BudgetSettingsPayload)
def save_budget_settings(
    payload: BudgetSettingsPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Saves automatic/manual limit preferences for the current user only."""
    row = db.query(BudgetSettings).filter(BudgetSettings.user_id == current_user.id).first()
    if row is None:
        row = BudgetSettings(user_id=current_user.id)
        db.add(row)
    row.auto_limits = payload.auto_limits
    row.monthly_limit = payload.monthly_limit if payload.monthly_limit and payload.monthly_limit > 0 else None
    row.category_limits = json.dumps(payload.category_limits)
    db.commit()
    db.refresh(row)
    return _to_payload(row)
