from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient

from backend.app.database.session import SessionLocal
from backend.app.main import app
from backend.app.models.db_models import Transaction
from backend.app.services.notification_service import NotificationService

client = TestClient(app)
TODAY = date.today().isoformat()


def _user():
    token = client.post("/auth/guest").json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    return headers, client.get("/auth/me", headers=headers).json()["id"]


def _set_limit(headers, amount):
    client.put("/budget/settings", json={"auto_limits": False, "monthly_limit": amount}, headers=headers)


def _spend(headers, amount, category="Food"):
    res = client.post("/cash-expenses", json={"amount": amount, "category": category, "expense_date": TODAY}, headers=headers)
    assert res.status_code == 201


def _items(headers, **params):
    return client.get("/notifications", params=params, headers=headers).json()


def _types(headers, **params):
    return [n["type"] for n in _items(headers, **params)["items"]]


# ---------- the API needs a login, and notifications belong to one user ----------

def test_notifications_require_a_login():
    assert client.get("/notifications").status_code == 401
    assert client.post("/notifications/sync").status_code == 401


def test_one_users_notifications_are_invisible_to_another():
    first, _ = _user()
    _set_limit(first, 1000)
    _spend(first, 850)
    assert "budget_warning" in _types(first)

    second, _ = _user()
    assert _items(second)["items"] == []
    mine = _items(first)["items"][0]["id"]
    assert client.post(f"/notifications/{mine}/read", headers=second).status_code == 404
    assert client.post(f"/notifications/{mine}/dismiss", headers=second).status_code == 404


# ---------- budget transitions create one record per level, never duplicates ----------

def test_each_budget_level_is_recorded_once_as_spending_rises():
    headers, _ = _user()
    _set_limit(headers, 1000)

    _spend(headers, 500)
    assert not {"budget_warning", "budget_critical", "budget_exceeded"} & set(_types(headers))

    _spend(headers, 320)   # 82%
    _spend(headers, 100)   # 92%
    _spend(headers, 200)   # 112%
    types = _types(headers)
    assert types.count("budget_warning") == 1
    assert types.count("budget_critical") == 1
    assert types.count("budget_exceeded") == 1


def test_refreshing_never_duplicates_a_notification():
    headers, _ = _user()
    _set_limit(headers, 1000)
    _spend(headers, 900)
    before = len(_items(headers)["items"])
    for _ in range(4):
        client.post("/notifications/sync", headers=headers)
        client.get("/analytics/summary", headers=headers)
    assert len(_items(headers)["items"]) == before


def test_the_daily_allowance_is_one_record_per_day_and_updates_in_place():
    headers, _ = _user()
    _set_limit(headers, 3000)
    _spend(headers, 100)
    safe = [n for n in _items(headers)["items"] if n["type"] == "safe_to_spend"]
    assert len(safe) == 1 and safe[0]["scope_day"] == TODAY
    first_title = safe[0]["title"]

    _spend(headers, 2000)  # the budget state changes during the day
    safe = [n for n in _items(headers)["items"] if n["type"] == "safe_to_spend"]
    assert len(safe) == 1
    assert safe[0]["title"] != first_title


def test_an_exceeded_budget_changes_the_allowance_message():
    headers, _ = _user()
    _set_limit(headers, 500)
    _spend(headers, 900)
    safe = next(n for n in _items(headers)["items"] if n["type"] == "safe_to_spend")
    assert "No room left" in safe["title"]


def test_month_recap_is_recorded_once_in_the_first_week_of_a_month():
    headers, user_id = _user()
    _set_limit(headers, 1000)
    first_of_this_month = date.today().replace(day=1)
    last_month = first_of_this_month - timedelta(days=10)
    client.post("/cash-expenses", json={"amount": 600, "category": "Food", "expense_date": last_month.isoformat()}, headers=headers)

    db = SessionLocal()
    try:
        service = NotificationService(db)
        for _ in range(3):
            service.sync(user_id, today=first_of_this_month + timedelta(days=2))
    finally:
        db.close()
    recaps = [n for n in _items(headers)["items"] if n["type"] == "month_recap"]
    assert len(recaps) == 1
    assert recaps[0]["severity"] == "success"
    assert recaps[0]["scope_month"] == last_month.strftime("%Y-%m")


# ---------- read, unread, dismiss are separate ----------

def test_reading_does_not_dismiss_and_dismissing_does_not_read():
    headers, _ = _user()
    _set_limit(headers, 1000)
    _spend(headers, 850)
    result = _items(headers)
    target = next(n for n in result["items"] if n["type"] == "budget_warning")
    unread_before = result["unread_count"]
    assert target["read"] is False

    client.post(f"/notifications/{target['id']}/read", headers=headers)
    after = _items(headers)
    assert after["unread_count"] == unread_before - 1
    assert target["id"] in [n["id"] for n in after["items"]]  # read, but still there

    client.post(f"/notifications/{target['id']}/unread", headers=headers)
    assert _items(headers)["unread_count"] == unread_before

    client.post(f"/notifications/{target['id']}/dismiss", headers=headers)
    assert target["id"] not in [n["id"] for n in _items(headers)["items"]]
    history = _items(headers, include_dismissed=True)["items"]
    dismissed = next(n for n in history if n["id"] == target["id"])
    assert dismissed["dismissed"] is True and dismissed["read"] is False

    client.post(f"/notifications/{target['id']}/restore", headers=headers)
    assert target["id"] in [n["id"] for n in _items(headers)["items"]]


def test_filters_and_counts_split_budget_transactions_and_system():
    headers, _ = _user()
    _set_limit(headers, 1000)
    _spend(headers, 850)
    result = _items(headers)
    assert result["counts"]["all"] == len(result["items"])
    assert result["counts"]["budget"] >= 2     # the warning and the daily allowance
    assert result["counts"]["transactions"] >= 1  # "cash expense added"
    assert all(n["group"] == "budget" for n in _items(headers, group="budget")["items"])
    assert all(n["group"] == "transactions" for n in _items(headers, group="transactions")["items"])


def test_mark_all_read_only_touches_the_users_own_unread_items():
    headers, _ = _user()
    other, _ = _user()
    _set_limit(headers, 1000)
    _spend(headers, 850)
    _set_limit(other, 1000)
    _spend(other, 850)
    assert _items(headers)["unread_count"] > 0
    client.post("/notifications/read-all", headers=headers)
    assert _items(headers)["unread_count"] == 0
    assert _items(other)["unread_count"] > 0


# ---------- the review count is live: only really reviewing resolves it ----------

def _flag(user_id, count, flagged=True):
    db = SessionLocal()
    try:
        if flagged:
            for i in range(count):
                db.add(Transaction(user_id=user_id, date="2026-01-0%d" % (i + 1), raw_description=f"UPI/DR/{i}/UNKNOWN SHOP",
                                   amount=10.0 + i, cr_dr="DR", category="Uncategorized", needs_review=True))
        else:
            db.query(Transaction).filter(Transaction.user_id == user_id).update({Transaction.needs_review: False})
        db.commit()
    finally:
        db.close()


def test_the_review_notification_shows_the_exact_count_and_survives_being_read():
    headers, user_id = _user()
    _flag(user_id, 3)
    client.post("/notifications/sync", headers=headers)
    review = next(n for n in _items(headers)["items"] if n["type"] == "uncertain_transaction")
    assert review["live_count"] == 3 and review["action"] == "review_uncertain"
    assert "3 transactions" in review["title"]

    client.post(f"/notifications/{review['id']}/read", headers=headers)
    client.post("/notifications/sync", headers=headers)
    still = [n for n in _items(headers)["items"] if n["type"] == "uncertain_transaction"]
    assert len(still) == 1 and still[0]["read"] is True and still[0]["live_count"] == 3


def test_the_review_notification_resolves_only_when_transactions_are_reviewed_and_returns_if_more_arrive():
    headers, user_id = _user()
    _flag(user_id, 2)
    client.post("/notifications/sync", headers=headers)
    assert "uncertain_transaction" in _types(headers)

    _flag(user_id, 0, flagged=False)       # the user actually reviewed them
    client.post("/notifications/sync", headers=headers)
    assert "uncertain_transaction" not in _types(headers)
    assert "uncertain_transaction" in _types(headers, include_dismissed=True)  # kept as history

    _flag(user_id, 4)                      # new uncertain rows arrive later
    client.post("/notifications/sync", headers=headers)
    again = next(n for n in _items(headers)["items"] if n["type"] == "uncertain_transaction")
    assert again["live_count"] == 4 and again["read"] is False


def test_dismissing_the_review_notification_hides_it_until_more_transactions_need_review():
    headers, user_id = _user()
    _flag(user_id, 2)
    client.post("/notifications/sync", headers=headers)
    review = next(n for n in _items(headers)["items"] if n["type"] == "uncertain_transaction")
    client.post(f"/notifications/{review['id']}/dismiss", headers=headers)
    client.post("/notifications/sync", headers=headers)
    assert "uncertain_transaction" not in _types(headers)

    _flag(user_id, 1)
    client.post("/notifications/sync", headers=headers)
    assert "uncertain_transaction" in _types(headers)


# ---------- events create their own records ----------

def test_adding_a_cash_expense_records_a_success_notification_once():
    headers, _ = _user()
    _spend(headers, 120, "Food")
    notes = [n for n in _items(headers)["items"] if n["type"] == "transaction_success"]
    assert len(notes) == 1
    assert "₹120" in notes[0]["body"] and notes[0]["action"] == "transactions"


def test_uploading_a_statement_records_a_notification():
    headers, _ = _user()
    assert client.post("/statements/seed-sample?bank=HDFC%20Bank", headers=headers).status_code == 200
    assert "statement_upload" in _types(headers)


def test_no_notifications_are_invented_for_a_new_user():
    headers, _ = _user()
    result = _items(headers)
    assert result["items"] == [] and result["unread_count"] == 0
    assert result["counts"] == {"all": 0, "budget": 0, "transactions": 0, "system": 0}


def test_unknown_types_are_rejected():
    _, user_id = _user()
    db = SessionLocal()
    try:
        with pytest.raises(ValueError):
            NotificationService(db).create_once(user_id, type="made_up", dedupe_key="x", title="t", body="b")
    finally:
        db.close()


# ---------- a guest session that signs in to an existing account ----------

def test_signing_a_guest_into_an_account_keeps_notifications_separate_and_does_not_fail():
    import uuid

    existing_email = f"notify_{uuid.uuid4().hex[:8]}@example.com"
    account = client.post("/auth/identify", json={"email": existing_email}).json()
    account_headers = {"Authorization": f"Bearer {account['access_token']}"}
    _set_limit(account_headers, 5000)

    guest, _ = _user()
    _set_limit(guest, 1000)
    _spend(guest, 850)   # creates guest notifications, budget settings and a cash expense
    assert _items(guest)["items"]

    merged = client.post("/auth/identify", json={"email": existing_email}, headers=guest)
    assert merged.status_code == 200
    token = merged.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # The account keeps its own budget settings, and the guest's notifications were not copied across
    assert client.get("/budget/settings", headers=headers).json()["monthly_limit"] == 5000.0
    assert not [n for n in _items(headers)["items"] if n["type"] == "transaction_success"]
    # The guest session no longer exists
    assert client.get("/notifications", headers=guest).status_code == 401
