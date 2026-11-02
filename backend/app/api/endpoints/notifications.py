from datetime import datetime
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ...database.session import get_db
from ...models.db_models import Notification, User
from ...services.notification_service import NotificationService, group_of
from ..deps import get_current_user

router = APIRouter()


class NotificationOut(BaseModel):
    id: str
    type: str
    group: str
    severity: str
    title: str
    body: str
    action: Optional[str] = None
    scope_month: Optional[str] = None
    scope_day: Optional[str] = None
    scope_category: Optional[str] = None
    live_count: Optional[int] = None
    read: bool
    dismissed: bool
    resolved: bool
    created_at: datetime


class NotificationList(BaseModel):
    items: List[NotificationOut]
    unread_count: int
    counts: Dict[str, int]


def _out(n: Notification) -> NotificationOut:
    return NotificationOut(
        id=n.id, type=n.type, group=group_of(n.type), severity=n.severity, title=n.title, body=n.body,
        action=n.action, scope_month=n.scope_month, scope_day=n.scope_day, scope_category=n.scope_category,
        live_count=n.live_count, read=n.read_at is not None, dismissed=n.dismissed_at is not None,
        resolved=n.resolved_at is not None, created_at=n.created_at,
    )


@router.get("", response_model=NotificationList)
def list_notifications(
    group: str = Query("all", json_schema_extra={"enum": ["all", "budget", "transactions", "system"]}),
    include_dismissed: bool = False,
    limit: int = Query(100, le=300),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The signed-in user's notifications. Dismissed and resolved ones are included only on request."""
    result = NotificationService(db).list(current_user.id, group, include_dismissed, limit)
    return NotificationList(
        items=[_out(n) for n in result["items"]], unread_count=result["unread_count"], counts=result["counts"]
    )


@router.post("/sync", response_model=NotificationList)
def sync_notifications(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Records whatever is newly due (budget levels, the day's allowance, the review queue). Idempotent."""
    service = NotificationService(db)
    service.sync(current_user.id)
    result = service.list(current_user.id)
    return NotificationList(
        items=[_out(n) for n in result["items"]], unread_count=result["unread_count"], counts=result["counts"]
    )


@router.post("/read-all")
def read_all(
    group: str = "all", db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    return {"marked": NotificationService(db).mark_all_read(current_user.id, group)}


def _change(record: Optional[Notification]) -> NotificationOut:
    if record is None:
        raise HTTPException(status_code=404, detail="Notification not found.")
    return _out(record)


@router.post("/{notification_id}/read", response_model=NotificationOut)
def mark_read(notification_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _change(NotificationService(db).set_read(current_user.id, notification_id, True))


@router.post("/{notification_id}/unread", response_model=NotificationOut)
def mark_unread(notification_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _change(NotificationService(db).set_read(current_user.id, notification_id, False))


@router.post("/{notification_id}/dismiss", response_model=NotificationOut)
def dismiss(notification_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _change(NotificationService(db).set_dismissed(current_user.id, notification_id, True))


@router.post("/{notification_id}/restore", response_model=NotificationOut)
def restore(notification_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _change(NotificationService(db).set_dismissed(current_user.id, notification_id, False))
