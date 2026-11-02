import pytest
from fastapi.testclient import TestClient

from backend.app.main import app

client = TestClient(app)


@pytest.fixture(scope="module")
def seeded():
    token = client.post("/auth/guest").json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    assert client.post("/statements/seed-sample?bank=HDFC%20Bank", headers=headers).status_code == 200
    txns = client.get("/transactions?limit=1000", headers=headers).json()
    summary = client.get("/analytics/summary", headers=headers).json()
    return txns, summary


def _sum(txns, direction, predicate=lambda t: True):
    return round(sum(t["amount"] for t in txns if t["cr_dr"] == direction and predicate(t)), 2)


def test_money_out_and_in_match_the_statement_totals(seeded):
    txns, summary = seeded
    assert summary["bank_money_out"] == _sum(txns, "DR")
    assert summary["bank_money_in"] == _sum(txns, "CR")


def test_money_out_splits_into_spending_transfers_and_the_rest(seeded):
    _, summary = seeded
    parts = summary["bank_spending"] + summary["transfers_out"] + summary["other_money_out"]
    assert round(parts, 2) == summary["bank_money_out"]
    assert summary["other_money_out"] >= 0


def test_transfers_are_reported_by_direction(seeded):
    txns, summary = seeded
    transfers = lambda t: (t["category"] or "").lower() in ("transfer", "transfers")
    assert summary["transfers_out"] == _sum(txns, "DR", transfers)
    assert summary["transfers_in"] == _sum(txns, "CR", transfers)
    assert round(summary["transfers_out"] + summary["transfers_in"], 2) == summary["total_transfers"]


def test_a_user_with_no_data_gets_zeros():
    token = client.post("/auth/guest").json()["access_token"]
    summary = client.get("/analytics/summary", headers={"Authorization": f"Bearer {token}"}).json()
    for key in ("bank_money_out", "bank_money_in", "transfers_out", "transfers_in", "other_money_out"):
        assert summary[key] == 0.0


def test_net_cash_flow_is_the_real_change_in_the_account():
    token = client.post("/auth/guest").json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    client.post("/statements/seed-sample?bank=HDFC%20Bank", headers=headers)
    txns = client.get("/transactions?limit=1000", headers=headers).json()
    money_in = round(sum(t["amount"] for t in txns if t["cr_dr"] == "CR"), 2)
    money_out = round(sum(t["amount"] for t in txns if t["cr_dr"] == "DR"), 2)
    summary = client.get("/analytics/summary", headers=headers).json()
    assert summary["net_cash_flow"] == round(money_in - money_out - summary["cash_spending"], 2)
    assert summary["this_month_label"]  # names the month the "this month" figure belongs to


def test_monthly_items_carry_money_in_and_out():
    token = client.post("/auth/guest").json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    client.post("/statements/seed-sample?bank=HDFC%20Bank", headers=headers)
    txns = client.get("/transactions?limit=1000", headers=headers).json()
    months = client.get("/analytics/monthly", headers=headers).json()
    assert months
    assert round(sum(m["money_out"] for m in months), 2) == round(sum(t["amount"] for t in txns if t["cr_dr"] == "DR"), 2)
    assert round(sum(m["money_in"] for m in months), 2) == round(sum(t["amount"] for t in txns if t["cr_dr"] == "CR"), 2)
