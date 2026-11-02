"""
Financial Activity Centre: persistent, per-user notifications.

Every record is created through `create_once`, keyed by (user_id, dedupe_key), so refreshing analytics,
re-opening the dashboard or retrying an upload can never create a second record for the same event.
Reading and dismissing are separate, and an alert about money (budget level, uncertain transactions)
is never resolved just because it was read.
"""
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..models.db_models import Notification, Transaction

BUDGET_TYPES = {"month_recap", "safe_to_spend", "budget_warning", "budget_critical", "budget_exceeded"}
TRANSACTION_TYPES = {"uncertain_transaction", "transaction_success", "statement_upload"}
SYSTEM_TYPES = {"system"}
ALL_TYPES = BUDGET_TYPES | TRANSACTION_TYPES | SYSTEM_TYPES

GROUPS: Dict[str, set] = {"budget": BUDGET_TYPES, "transactions": TRANSACTION_TYPES, "system": SYSTEM_TYPES}


def group_of(notification_type: str) -> str:
    for name, types in GROUPS.items():
        if notification_type in types:
            return name
    return "system"


def _money(value: float) -> str:
    return f"₹{abs(value):,.0f}"


class NotificationService:
    def __init__(self, db: Session):
        self.db = db

    # ------------------------------------------------------------------ core

    def _find(self, user_id: str, dedupe_key: str) -> Optional[Notification]:
        return (
            self.db.query(Notification)
            .filter(Notification.user_id == user_id, Notification.dedupe_key == dedupe_key)
            .first()
        )

    def create_once(
        self,
        user_id: str,
        *,
        type: str,
        dedupe_key: str,
        title: str,
        body: str,
        severity: str = "info",
        action: Optional[str] = None,
        scope_month: Optional[str] = None,
        scope_day: Optional[str] = None,
        scope_category: Optional[str] = None,
        live_count: Optional[int] = None,
    ) -> Tuple[Notification, bool]:
        """Creates the notification unless one with this key already exists. Returns (record, created)."""
        if type not in ALL_TYPES:
            raise ValueError(f"Unknown notification type: {type}")
        existing = self._find(user_id, dedupe_key)
        if existing is not None:
            return existing, False

        record = Notification(
            user_id=user_id,
            type=type,
            severity=severity,
            title=title,
            body=body,
            dedupe_key=dedupe_key,
            action=action,
            scope_month=scope_month,
            scope_day=scope_day,
            scope_category=scope_category,
            live_count=live_count,
        )
        self.db.add(record)
        try:
            self.db.commit()
        except IntegrityError:
            # Another request created the same record first: use that one
            self.db.rollback()
            return self._find(user_id, dedupe_key), False
        self.db.refresh(record)
        return record, True

    # ------------------------------------------------------------------ budget

    def sync_budget(self, user_id: str, summary: Dict[str, Any], today: Optional[date] = None) -> None:
        """Creates the budget notifications that are due for this summary (idempotent)."""
        today = today or date.today()
        status = summary.get("budget_status", "none")
        if status == "none":
            return
        month = summary.get("budget_month") or today.strftime("%Y-%m")
        budget = float(summary.get("monthly_budget", 0.0))
        spent = float(summary.get("budget_spent", 0.0))
        remaining = float(summary.get("budget_remaining", 0.0))
        days_left = int(summary.get("days_left_in_month", 0))

        overall = {
            "warning": ("budget_warning", "warning", "80% of this month's budget used",
                        f"{_money(spent)} of {_money(budget)} spent, {_money(remaining)} left."),
            "critical": ("budget_critical", "critical", "90% of this month's budget used",
                         f"Only {_money(remaining)} left for the next {days_left} days."),
            "exceeded": ("budget_exceeded", "critical", "You've exceeded this month's budget",
                         f"{_money(spent)} spent of {_money(budget)}, over by {_money(remaining)}."),
        }
        if status in overall:
            n_type, severity, title, body = overall[status]
            self.create_once(
                user_id, type=n_type, severity=severity, title=title, body=body,
                dedupe_key=f"budget|{month}|all|{status}", action="budget_settings", scope_month=month,
            )

        for cat in summary.get("category_budgets", []) or []:
            if cat.get("status") not in overall:
                continue
            n_type, severity, _, _ = overall[cat["status"]]
            pct = f"{float(cat.get('used_pct', 0)):.0f}"
            verb = "exceeded" if cat["status"] == "exceeded" else f"at {pct}%"
            self.create_once(
                user_id, type=n_type, severity=severity,
                title=f"{cat['category']} budget {verb}",
                body=f"{_money(cat.get('spent', 0))} of {_money(cat.get('limit', 0))} spent.",
                dedupe_key=f"budget|{month}|{cat['category']}|{cat['status']}",
                action="budget_settings", scope_month=month, scope_category=cat["category"],
            )

        self._sync_safe_to_spend(user_id, summary, today)

        recap = summary.get("last_month_recap")
        if recap:
            under = bool(recap.get("under_budget"))
            self.create_once(
                user_id, type="month_recap", severity="success" if under else "warning",
                title=f"{recap['month']} closed {_money(recap.get('difference', 0))} {'under' if under else 'over'} budget",
                body=f"You spent {_money(recap.get('spent', 0))} of {_money(recap.get('budget', 0))}.",
                dedupe_key=f"recap|{recap['month']}", action="dashboard", scope_month=recap["month"],
            )

    def _sync_safe_to_spend(self, user_id: str, summary: Dict[str, Any], today: date) -> None:
        """One record per day. If the budget state changes during the day, the day's text is updated."""
        exceeded = summary.get("budget_status") == "exceeded"
        days_left = int(summary.get("days_left_in_month", 0))
        safe = float(summary.get("safe_to_spend_today", 0.0))
        if exceeded:
            title, body, severity = "No room left in this month's budget", "Anything you spend now adds to the overspend.", "warning"
        else:
            title = f"You can spend about {_money(safe)} today"
            body = f"To stay within budget, with {days_left} day{'' if days_left == 1 else 's'} left this month."
            severity = "info"

        key = f"safe|{today.isoformat()}"
        record, created = self.create_once(
            user_id, type="safe_to_spend", severity=severity, title=title, body=body,
            dedupe_key=key, action="dashboard", scope_day=today.isoformat(),
            scope_month=summary.get("budget_month"),
        )
        if not created and (record.title != title or record.body != body):
            record.title, record.body, record.severity = title, body, severity
            self.db.commit()

    # ------------------------------------------------------------------ uncertain transactions

    def sync_uncertain(self, user_id: str) -> None:
        """Keeps ONE live notification whose count is the real number of transactions still to review.

        Reading or dismissing it never resolves it. It resolves only when the count reaches zero, and it
        comes back (unread, undismissed) if more transactions need review later."""
        count = (
            self.db.query(Transaction)
            .filter(Transaction.user_id == user_id, Transaction.needs_review.is_(True))
            .count()
        )
        record = self._find(user_id, "uncertain|live")
        now = datetime.utcnow()

        if count == 0:
            if record is not None and record.resolved_at is None:
                record.resolved_at = now
                record.live_count = 0
                self.db.commit()
            return

        title = f"{count} transaction{'' if count == 1 else 's'} need{'s' if count == 1 else ''} your review"
        body = "The AI was not confident about these. Confirm the category so they count correctly."

        if record is None:
            self.create_once(
                user_id, type="uncertain_transaction", severity="warning", title=title, body=body,
                dedupe_key="uncertain|live", action="review_uncertain", live_count=count,
            )
            return

        more_to_review = record.resolved_at is not None or (record.live_count or 0) < count
        record.title, record.body, record.live_count = title, body, count
        if more_to_review:
            record.resolved_at = None
            record.dismissed_at = None
            record.read_at = None
            record.created_at = now
        self.db.commit()

    # ------------------------------------------------------------------ events

    def record_cash_expense(self, user_id: str, expense_id: str, amount: float, category: str) -> None:
        self.create_once(
            user_id, type="transaction_success", severity="success", title="Cash expense added",
            body=f"{_money(amount)} for {category}.", dedupe_key=f"cash|{expense_id}", action="transactions",
        )

    def record_statement(self, user_id: str, statement_id: str, bank: str, count: int, flagged: int) -> None:
        body = f"{count} transactions read from your {bank} statement."
        if flagged:
            body += f" {flagged} need your review."
        self.create_once(
            user_id, type="statement_upload", severity="success", title="Statement processed",
            body=body, dedupe_key=f"statement|{statement_id}", action="dashboard",
        )

    def record_system(self, user_id: str, dedupe_key: str, title: str, body: str, severity: str = "info",
                      action: Optional[str] = None) -> None:
        self.create_once(user_id, type="system", severity=severity, title=title, body=body,
                         dedupe_key=dedupe_key, action=action)

    # ------------------------------------------------------------------ full refresh

    def sync(self, user_id: str, today: Optional[date] = None) -> None:
        """Evaluates the budget and the review queue and records whatever is newly due."""
        from .analytics_service import AnalyticsService  # local import: avoids a circular import

        summary = AnalyticsService(db=self.db).get_summary(user_id=user_id, as_of=today)
        self.sync_budget(user_id, summary, today)
        self.sync_uncertain(user_id)

    # ------------------------------------------------------------------ reading and changing state

    def list(self, user_id: str, group: str = "all", include_dismissed: bool = False, limit: int = 100) -> Dict[str, Any]:
        base = self.db.query(Notification).filter(Notification.user_id == user_id)
        active = base.filter(Notification.dismissed_at.is_(None), Notification.resolved_at.is_(None))
        query = base if include_dismissed else active
        if group in GROUPS:
            query = query.filter(Notification.type.in_(GROUPS[group]))
        items: List[Notification] = query.order_by(Notification.created_at.desc()).limit(limit).all()

        active_items = active.all()
        counts = {"all": len(active_items)}
        for name, types in GROUPS.items():
            counts[name] = sum(1 for n in active_items if n.type in types)
        unread = sum(1 for n in active_items if n.read_at is None)
        return {"items": items, "unread_count": unread, "counts": counts}

    def _owned(self, user_id: str, notification_id: str) -> Optional[Notification]:
        return (
            self.db.query(Notification)
            .filter(Notification.id == notification_id, Notification.user_id == user_id)
            .first()
        )

    def set_read(self, user_id: str, notification_id: str, read: bool) -> Optional[Notification]:
        record = self._owned(user_id, notification_id)
        if record is not None:
            record.read_at = datetime.utcnow() if read else None
            self.db.commit()
        return record

    def set_dismissed(self, user_id: str, notification_id: str, dismissed: bool) -> Optional[Notification]:
        record = self._owned(user_id, notification_id)
        if record is not None:
            record.dismissed_at = datetime.utcnow() if dismissed else None
            self.db.commit()
        return record

    def mark_all_read(self, user_id: str, group: str = "all") -> int:
        query = self.db.query(Notification).filter(
            Notification.user_id == user_id, Notification.read_at.is_(None),
            Notification.dismissed_at.is_(None), Notification.resolved_at.is_(None),
        )
        if group in GROUPS:
            query = query.filter(Notification.type.in_(GROUPS[group]))
        rows = query.all()
        now = datetime.utcnow()
        for row in rows:
            row.read_at = now
        self.db.commit()
        return len(rows)
