from collections import Counter
from datetime import date

import pandas as pd
import pytest
from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.services.analytics_service import AnalyticsService

client = TestClient(app)


def _user():
    token = client.post("/auth/guest").json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _seed(headers):
    res = client.post("/statements/seed-sample?bank=HDFC%20Bank", headers=headers)
    assert res.status_code == 200
    return res.json()["id"]


def _transactions(headers):
    return client.get("/transactions?limit=1000", headers=headers).json()


def _most_common_merchant(txns):
    merchant, _ = Counter(t["normalized_merchant"] for t in txns if t["normalized_merchant"]).most_common(1)[0]
    return merchant


# ---------- a login is always required ----------

@pytest.mark.parametrize("method,path", [
    ("get", "/transactions"),
    ("get", "/analytics/summary"),
    ("get", "/budget/settings"),
    ("get", "/cash-expenses"),
    ("get", "/forecast"),
    ("get", "/statements"),
    ("post", "/model/retrain"),
])
def test_no_token_is_rejected(method, path):
    assert getattr(client, method)(path).status_code == 401


def test_garbage_token_is_rejected():
    res = client.get("/transactions", headers={"Authorization": "Bearer not-a-real-token"})
    assert res.status_code == 401


def test_guest_login_still_works_without_a_token():
    assert client.post("/auth/guest").status_code == 200


# ---------- corrections are learned per user, by merchant ----------

def test_correction_applies_to_the_next_statement():
    headers = _user()
    _seed(headers)
    txns = _transactions(headers)
    merchant = _most_common_merchant(txns)
    target = next(t for t in txns if t["normalized_merchant"] == merchant)

    res = client.patch(
        f"/transactions/{target['id']}/category",
        json={"category": "Entertainment", "apply_to_future": True},
        headers=headers,
    )
    assert res.status_code == 200

    new_statement = _seed(headers)
    new_rows = [t for t in _transactions(headers) if t.get("statement_id") == new_statement and t["normalized_merchant"] == merchant]
    assert new_rows, "the second statement should contain the same merchant"
    assert {t["category"] for t in new_rows} == {"Entertainment"}
    assert all(t["needs_review"] is False for t in new_rows)


def test_correction_without_apply_to_future_is_not_learned():
    headers = _user()
    _seed(headers)
    txns = _transactions(headers)
    merchant = _most_common_merchant(txns)
    original = {t["category"] for t in txns if t["normalized_merchant"] == merchant}
    target = next(t for t in txns if t["normalized_merchant"] == merchant)

    client.patch(
        f"/transactions/{target['id']}/category",
        json={"category": "Entertainment", "apply_to_future": False},
        headers=headers,
    )
    new_statement = _seed(headers)
    new_rows = [t for t in _transactions(headers) if t.get("statement_id") == new_statement and t["normalized_merchant"] == merchant]
    assert new_rows
    assert {t["category"] for t in new_rows} == original


def test_learned_rules_belong_to_one_user():
    first = _user()
    _seed(first)
    txns = _transactions(first)
    merchant = _most_common_merchant(txns)
    original = {t["category"] for t in txns if t["normalized_merchant"] == merchant}
    target = next(t for t in txns if t["normalized_merchant"] == merchant)
    client.patch(
        f"/transactions/{target['id']}/category",
        json={"category": "Entertainment", "apply_to_future": True},
        headers=first,
    )

    second = _user()
    _seed(second)
    other_rows = [t for t in _transactions(second) if t["normalized_merchant"] == merchant]
    assert other_rows and {t["category"] for t in other_rows} == original


def test_retrain_is_honest_and_scoped_to_the_user():
    headers = _user()
    _seed(headers)
    target = _transactions(headers)[0]
    client.patch(
        f"/transactions/{target['id']}/category",
        json={"category": "Entertainment", "apply_to_future": True},
        headers=headers,
    )
    body = client.post("/model/retrain", headers=headers).json()
    assert "not changed" in body["message"]
    assert "1 of your corrections" in body["message"]


# ---------- a budget over its limit by a hair is "exceeded", not "critical" ----------

def _frame(rows):
    df = pd.DataFrame(rows, columns=["date", "amount"])
    df["date_dt"] = pd.to_datetime(df["date"])
    df["transaction_type"] = "expense"
    df["cr_dr"] = "DR"
    df["category"] = "Shopping"
    return df


def test_tier_uses_the_unrounded_percentage():
    service = AnalyticsService(db=None)
    settings = {"auto_limits": False, "monthly_limit": 5000.0, "category_limits": {"Shopping": 5000.0}}
    cash = _frame([("2026-02-05", 5000.01)])
    result = service._compute_budget("u", pd.DataFrame(), cash, date(2026, 2, 10), settings=settings)
    assert result["budget_used_pct"] == 100.0
    assert result["budget_status"] == "exceeded"
    assert result["category_budgets"][0]["status"] == "exceeded"
