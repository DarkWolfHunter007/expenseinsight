"""
Test Suite for Forecast Refresh and Invalidation after Expense Mutations.
Verifies the complete lifecycle:
    Add/Update/Delete Expense
        ↓
    Database persistence
        ↓
    Forecast recalculation
        ↓
    GET /forecast reflects new data
"""

import logging
import os
import sys
import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from backend.app.database.session import Base, SessionLocal, engine
from backend.app.main import app
from backend.app.models.db_models import (
    CashExpense,
    CategoryCorrection,
    Forecast,
    Statement,
    Transaction,
    User,
)
from backend.app.services.forecasting_service import (
    ForecastingService,
    FORECAST_REFRESH_CHECKLIST,
)


def cleanup_user_data(db_session, user_id: str):
    db_session.query(CategoryCorrection).filter(CategoryCorrection.user_id == user_id).delete()
    db_session.query(Transaction).filter(Transaction.user_id == user_id).delete()
    db_session.query(CashExpense).filter(CashExpense.user_id == user_id).delete()
    db_session.query(Statement).filter(Statement.user_id == user_id).delete()
    db_session.query(Forecast).filter(Forecast.user_id == user_id).delete()
    db_session.commit()


@pytest.fixture(scope="module")
def client():
    return TestClient(app)


@pytest.fixture(scope="module")
def db_session():
    Base.metadata.create_all(bind=engine)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture(scope="module")
def test_user_and_token(db_session, client):
    res = client.post("/auth/guest")
    assert res.status_code == 200, res.text
    data = res.json()
    token = data["access_token"]
    user_id = data["user"]["id"]
    headers = {"Authorization": f"Bearer {token}"}
    return user_id, headers


class TestForecastExpenseMutation:
    """Verifies that every mutation impacting personal spending updates the forecast."""

    def test_checklist_in_code_verified(self):
        for key, val in FORECAST_REFRESH_CHECKLIST.items():
            assert val is True, f"Checklist item {key} must be True"

    def test_1_create_cash_expense_triggers_forecast_recalculation(self, client, db_session, test_user_and_token):
        user_id, headers = test_user_and_token
        cleanup_user_data(db_session, user_id)

        # Baseline forecast with no transactions
        res_initial = client.get("/forecast", headers=headers)
        assert res_initial.status_code == 200
        assert res_initial.json()["total_forecast"] == 0.0

        # Create cash expense: Food ₹500
        res_create = client.post(
            "/cash-expenses",
            json={
                "amount": 500.0,
                "category": "Food",
                "expense_date": "2026-10-01",
                "description": "Lunch at cafe",
                "payment_method": "cash"
            },
            headers=headers
        )
        assert res_create.status_code == 201

        # GET /forecast must now reflect the new cash expense
        res_forecast = client.get("/forecast", headers=headers)
        assert res_forecast.status_code == 200
        data = res_forecast.json()
        assert data["total_forecast"] == 500.0
        assert "Food" in data["category_forecasts"]
        assert data["category_forecasts"]["Food"]["predicted_amount"] == 500.0

        # Persisted Forecast rows must match
        persisted = db_session.query(Forecast).filter(Forecast.user_id == user_id, Forecast.category == "Food").first()
        assert persisted is not None
        assert persisted.predicted_amount == 500.0

    def test_2_create_upi_expense_triggers_forecast_recalculation(self, client, db_session, test_user_and_token):
        user_id, headers = test_user_and_token
        cleanup_user_data(db_session, user_id)

        res_create = client.post(
            "/cash-expenses",
            json={
                "amount": 1200.0,
                "category": "Shopping",
                "expense_date": "2026-10-02",
                "description": "Clothing purchase",
                "payment_method": "upi"
            },
            headers=headers
        )
        assert res_create.status_code == 201

        res_forecast = client.get("/forecast", headers=headers)
        assert res_forecast.status_code == 200
        data = res_forecast.json()
        assert data["total_forecast"] == 1200.0
        assert "Shopping" in data["category_forecasts"]
        assert data["category_forecasts"]["Shopping"]["predicted_amount"] == 1200.0

    def test_3_bank_statement_expense_included_in_forecast(self, client, db_session, test_user_and_token):
        user_id, headers = test_user_and_token
        cleanup_user_data(db_session, user_id)

        stmt = Statement(
            user_id=user_id,
            file_name="bank_statement.pdf",
            bank_name="HDFC Bank",
            statement_start="2026-09-01",
            statement_end="2026-09-30",
            processing_status="completed",
            total_transactions=2
        )
        db_session.add(stmt)
        db_session.commit()
        db_session.refresh(stmt)

        # 1 normal bank personal expense (Card/POS)
        txn1 = Transaction(
            user_id=user_id,
            statement_id=stmt.id,
            date="2026-09-10",
            raw_description="POS DMART GROCERY",
            merchant="DMart",
            normalized_merchant="dmart",
            amount=2500.0,
            cr_dr="DR",
            transaction_type="expense",
            category="Groceries"
        )
        # 1 neutral transfer (MUST NOT be in forecast)
        txn2 = Transaction(
            user_id=user_id,
            statement_id=stmt.id,
            date="2026-09-15",
            raw_description="TRANSFER TO AC 123456",
            merchant="Self Transfer",
            amount=10000.0,
            cr_dr="DR",
            transaction_type="transfer",
            category="Transfers"
        )
        db_session.add_all([txn1, txn2])
        db_session.commit()

        # Recalculate
        ForecastingService.refresh_user_forecast_safe(db_session, user_id, trigger="test_statement")

        res = client.get("/forecast", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert data["total_forecast"] == 2500.0
        assert "Groceries" in data["category_forecasts"]
        assert "Transfers" not in data["category_forecasts"]

    def test_4_delete_expense_recalculates_forecast(self, client, db_session, test_user_and_token):
        user_id, headers = test_user_and_token
        cleanup_user_data(db_session, user_id)

        # Create 2 expenses: Food 400, Travel 600
        res1 = client.post(
            "/cash-expenses",
            json={"amount": 400.0, "category": "Food", "expense_date": "2026-10-01", "payment_method": "cash"},
            headers=headers
        )
        res2 = client.post(
            "/cash-expenses",
            json={"amount": 600.0, "category": "Travel", "expense_date": "2026-10-02", "payment_method": "cash"},
            headers=headers
        )
        exp1_id = res1.json()["id"]
        exp2_id = res2.json()["id"]

        fc_before = client.get("/forecast", headers=headers).json()
        assert fc_before["total_forecast"] == 1000.0

        # Delete Travel expense
        del_res = client.delete(f"/cash-expenses/{exp2_id}", headers=headers)
        assert del_res.status_code == 200

        fc_after = client.get("/forecast", headers=headers).json()
        assert fc_after["total_forecast"] == 400.0
        assert "Travel" not in fc_after["category_forecasts"]
        assert "Food" in fc_after["category_forecasts"]

    def test_5_update_expense_amount_recalculates_forecast(self, client, db_session, test_user_and_token):
        user_id, headers = test_user_and_token
        cleanup_user_data(db_session, user_id)

        res_create = client.post(
            "/cash-expenses",
            json={"amount": 300.0, "category": "Food", "expense_date": "2026-10-01", "payment_method": "cash"},
            headers=headers
        )
        exp_id = res_create.json()["id"]

        res_update = client.put(
            f"/cash-expenses/{exp_id}",
            json={"amount": 750.0},
            headers=headers
        )
        assert res_update.status_code == 200
        assert res_update.json()["amount"] == 750.0

        fc = client.get("/forecast", headers=headers).json()
        assert fc["total_forecast"] == 750.0
        assert fc["category_forecasts"]["Food"]["predicted_amount"] == 750.0

    def test_6_category_change_recalculates_category_forecast(self, client, db_session, test_user_and_token):
        user_id, headers = test_user_and_token
        cleanup_user_data(db_session, user_id)

        # Create expense in Food
        res_create = client.post(
            "/cash-expenses",
            json={"amount": 800.0, "category": "Food", "expense_date": "2026-10-01", "payment_method": "cash"},
            headers=headers
        )
        exp_id = res_create.json()["id"]

        fc1 = client.get("/forecast", headers=headers).json()
        assert "Food" in fc1["category_forecasts"]
        assert "Shopping" not in fc1["category_forecasts"]

        # Change category: Food -> Shopping via PUT /transactions/{id}/category
        res_cat = client.put(
            f"/transactions/{exp_id}/category",
            json={"category": "Shopping", "apply_to_future": False},
            headers=headers
        )
        assert res_cat.status_code == 200

        fc2 = client.get("/forecast", headers=headers).json()
        assert "Shopping" in fc2["category_forecasts"]
        assert "Food" not in fc2["category_forecasts"]
        assert fc2["category_forecasts"]["Shopping"]["predicted_amount"] == 800.0

    def test_7_forecast_failure_is_logged_safely(self, caplog, client, db_session, test_user_and_token):
        user_id, _ = test_user_and_token
        # Invoking safe refresh with invalid database or monkeypatched error logs forecast_refresh_failed
        class BrokenSession:
            def query(self, *args):
                raise RuntimeError("Simulated DB forecast calculation failure")

        with caplog.at_level(logging.ERROR):
            res = ForecastingService.refresh_user_forecast_safe(
                db=BrokenSession(), # type: ignore
                user_id=user_id,
                trigger="unit_test_failure"
            )
            assert res is None
            assert any("forecast_refresh_failed" in r.message for r in caplog.records)

    def test_8_upi_transaction_from_bank_statement_included_in_forecast(self, client, db_session, test_user_and_token):
        user_id, headers = test_user_and_token
        cleanup_user_data(db_session, user_id)

        stmt = Statement(
            user_id=user_id,
            file_name="upi_statement.pdf",
            bank_name="Axis Bank",
            statement_start="2026-09-01",
            statement_end="2026-09-30",
            processing_status="completed",
            total_transactions=1
        )
        db_session.add(stmt)
        db_session.commit()
        db_session.refresh(stmt)

        upi_statement_txn = Transaction(
            user_id=user_id,
            statement_id=stmt.id,
            date="2026-09-15",
            raw_description="UPI/DR/SWIGGY/123456789012",
            merchant="Swiggy",
            normalized_merchant="swiggy",
            amount=650.0,
            cr_dr="DR",
            transaction_type="expense",
            category="Food"
        )
        db_session.add(upi_statement_txn)
        db_session.commit()

        # Check that Transaction is recognized as UPI
        assert upi_statement_txn.source_type == "upi"

        # Refresh forecast
        ForecastingService.refresh_user_forecast_safe(db_session, user_id, trigger="upi_statement_test")

        fc = client.get("/forecast", headers=headers).json()
        assert fc["total_forecast"] == 650.0
        assert "Food" in fc["category_forecasts"]
        assert fc["category_forecasts"]["Food"]["predicted_amount"] == 650.0
