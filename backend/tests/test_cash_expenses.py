import os
import sys
import pytest
from datetime import datetime, date
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from backend.app.main import app
from backend.app.database.session import SessionLocal
from backend.app.models.db_models import Statement, Transaction, User, CashExpense

client = TestClient(app)


def get_authenticated_user():
    """Helper to create a fresh guest user and get auth headers."""
    res = client.post("/auth/guest")
    assert res.status_code == 200
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    user_info = client.get("/auth/me", headers=headers).json()
    return headers, user_info["id"]


class TestCashExpenseCRUD:
    def test_cash_expense_lifecycle(self):
        headers, user_id = get_authenticated_user()

        # 1. Create Cash Expense
        create_payload = {
            "amount": 250.75,
            "category": "Food",
            "description": "Lunch with team",
            "expense_date": "2026-09-27",
        }
        res = client.post("/cash-expenses", json=create_payload, headers=headers)
        assert res.status_code == 201
        data = res.json()
        expense_id = data["id"]
        assert data["amount"] == 250.75
        assert data["category"] == "Food"
        assert data["description"] == "Lunch with team"
        assert data["expense_date"] == "2026-09-27"
        assert data["user_id"] == user_id
        assert "created_at" in data
        assert "updated_at" in data

        # 2. Get Single Cash Expense
        get_res = client.get(f"/cash-expenses/{expense_id}", headers=headers)
        assert get_res.status_code == 200
        assert get_res.json()["id"] == expense_id

        # 3. List Cash Expenses
        list_res = client.get("/cash-expenses", headers=headers)
        assert list_res.status_code == 200
        items = list_res.json()
        assert len(items) == 1
        assert items[0]["id"] == expense_id

        # 4. Update Cash Expense
        update_payload = {
            "amount": 300.0,
            "category": "Dining Out",
            "description": "Dinner with team",
            "expense_date": "2026-09-28",
        }
        put_res = client.put(f"/cash-expenses/{expense_id}", json=update_payload, headers=headers)
        assert put_res.status_code == 200
        updated = put_res.json()
        assert updated["amount"] == 300.0
        assert updated["category"] == "Dining Out"
        assert updated["description"] == "Dinner with team"
        assert updated["expense_date"] == "2026-09-28"

        # 5. Partial Update Cash Expense
        partial_put = client.put(f"/cash-expenses/{expense_id}", json={"amount": 350.5}, headers=headers)
        assert partial_put.status_code == 200
        assert partial_put.json()["amount"] == 350.5
        assert partial_put.json()["category"] == "Dining Out"

        # 6. Delete Cash Expense
        del_res = client.delete(f"/cash-expenses/{expense_id}", headers=headers)
        assert del_res.status_code == 200
        assert del_res.json()["status"] == "success"

        # 7. Verify deletion
        get_after_del = client.get(f"/cash-expenses/{expense_id}", headers=headers)
        assert get_after_del.status_code == 404

        list_after_del = client.get("/cash-expenses", headers=headers)
        assert list_after_del.status_code == 200
        assert len(list_after_del.json()) == 0


class TestCashExpenseValidation:
    def test_invalid_amounts(self):
        headers, _ = get_authenticated_user()

        # Zero amount
        res = client.post(
            "/cash-expenses",
            json={"amount": 0.0, "category": "Food", "expense_date": "2026-09-27"},
            headers=headers,
        )
        assert res.status_code == 422

        # Negative amount
        res = client.post(
            "/cash-expenses",
            json={"amount": -50.0, "category": "Food", "expense_date": "2026-09-27"},
            headers=headers,
        )
        assert res.status_code == 422

    def test_invalid_category(self):
        headers, _ = get_authenticated_user()

        # Empty string category
        res = client.post(
            "/cash-expenses",
            json={"amount": 100.0, "category": "   ", "expense_date": "2026-09-27"},
            headers=headers,
        )
        assert res.status_code == 422

    def test_invalid_dates(self):
        headers, _ = get_authenticated_user()

        # Nonexistent calendar date
        res = client.post(
            "/cash-expenses",
            json={"amount": 100.0, "category": "Food", "expense_date": "2026-02-31"},
            headers=headers,
        )
        assert res.status_code == 422

        # Invalid format
        res = client.post(
            "/cash-expenses",
            json={"amount": 100.0, "category": "Food", "expense_date": "27-09-2026"},
            headers=headers,
        )
        assert res.status_code == 422


class TestCashExpenseUserIsolation:
    def test_cross_user_isolation(self):
        user1_headers, user1_id = get_authenticated_user()
        user2_headers, user2_id = get_authenticated_user()
        assert user1_id != user2_id

        # User 1 creates expense
        res1 = client.post(
            "/cash-expenses",
            json={"amount": 500.0, "category": "Secret", "expense_date": "2026-09-27"},
            headers=user1_headers,
        )
        assert res1.status_code == 201
        u1_exp_id = res1.json()["id"]

        # User 2 tries to GET User 1's expense -> 404 Not Found
        get_res = client.get(f"/cash-expenses/{u1_exp_id}", headers=user2_headers)
        assert get_res.status_code == 404

        # User 2 tries to PUT User 1's expense -> 404 Not Found
        put_res = client.put(
            f"/cash-expenses/{u1_exp_id}",
            json={"amount": 999.0},
            headers=user2_headers,
        )
        assert put_res.status_code == 404

        # User 2 tries to DELETE User 1's expense -> 404 Not Found
        del_res = client.delete(f"/cash-expenses/{u1_exp_id}", headers=user2_headers)
        assert del_res.status_code == 404

        # User 2 lists cash expenses -> User 1's expense is NOT present
        list_u2 = client.get("/cash-expenses", headers=user2_headers).json()
        assert len(list_u2) == 0

        # User 1 lists cash expenses -> User 1's expense IS present
        list_u1 = client.get("/cash-expenses", headers=user1_headers).json()
        assert len(list_u1) == 1
        assert list_u1[0]["id"] == u1_exp_id


class TestCashExpenseAnalytics:
    def test_analytics_cash_only(self):
        headers, _ = get_authenticated_user()

        # Add two cash expenses
        client.post(
            "/cash-expenses",
            json={"amount": 500.0, "category": "Food", "expense_date": "2026-06-10"},
            headers=headers,
        )
        client.post(
            "/cash-expenses",
            json={"amount": 300.0, "category": "Transport", "expense_date": "2026-06-15"},
            headers=headers,
        )

        summary = client.get("/analytics/summary", headers=headers).json()
        assert summary["bank_spending"] == 0.0
        assert summary["cash_spending"] == 800.0
        assert summary["total_spending"] == 800.0
        assert summary["total_expense"] == 800.0
        assert summary["total_income"] == 0.0

        # Category breakdown
        cat_map = {c["category"]: c for c in summary["categories_breakdown"]}
        assert "Food" in cat_map
        assert cat_map["Food"]["amount"] == 500.0
        assert cat_map["Food"]["cash_amount"] == 500.0
        assert cat_map["Food"]["bank_amount"] == 0.0

        assert "Transport" in cat_map
        assert cat_map["Transport"]["amount"] == 300.0
        assert cat_map["Transport"]["cash_amount"] == 300.0
        assert cat_map["Transport"]["bank_amount"] == 0.0

        # Monthly breakdown
        monthly = client.get("/analytics/monthly", headers=headers).json()
        assert len(monthly) == 1
        assert monthly[0]["month"] == "2026-06"
        assert monthly[0]["total_expense"] == 800.0
        assert monthly[0]["cash_expense"] == 800.0
        assert monthly[0]["bank_expense"] == 0.0

    def test_analytics_date_boundary_filtering(self):
        headers, user_id = get_authenticated_user()
        db = SessionLocal()

        try:
            # Create a mock statement for period 2026-04-01 to 2026-04-30 with ₹2,000 bank spending
            stmt = Statement(
                user_id=user_id,
                file_name="test_stmt.pdf",
                bank_name="Test Bank",
                account_number="123456",
                statement_start="2026-04-01",
                statement_end="2026-04-30",
                processing_status="completed",
                total_transactions=1,
            )
            db.add(stmt)
            db.commit()
            db.refresh(stmt)

            txn = Transaction(
                statement_id=stmt.id,
                user_id=user_id,
                date="2026-04-15",
                raw_description="Groceries",
                amount=2000.0,
                cr_dr="DR",
                category="Groceries",
                balance=10000.0,
            )
            db.add(txn)
            db.commit()
        finally:
            db.close()

        # Add 4 cash expenses:
        # 1. 2026-03-31 (1 day before start date) -> MUST BE EXCLUDED
        client.post(
            "/cash-expenses",
            json={"amount": 100.0, "category": "Food", "expense_date": "2026-03-31"},
            headers=headers,
        )
        # 2. 2026-04-01 (exact start date) -> MUST BE INCLUDED
        client.post(
            "/cash-expenses",
            json={"amount": 250.0, "category": "Food", "expense_date": "2026-04-01"},
            headers=headers,
        )
        # 3. 2026-04-30 (exact end date) -> MUST BE INCLUDED
        client.post(
            "/cash-expenses",
            json={"amount": 350.0, "category": "Transport", "expense_date": "2026-04-30"},
            headers=headers,
        )
        # 4. 2026-05-01 (1 day after end date) -> MUST BE EXCLUDED
        client.post(
            "/cash-expenses",
            json={"amount": 400.0, "category": "Shopping", "expense_date": "2026-05-01"},
            headers=headers,
        )

        # Query summary for the statement period
        summary = client.get("/analytics/summary", headers=headers).json()
        assert summary["bank_spending"] == 2000.0
        # Only 250.0 + 350.0 = 600.0 should be included! 100 (Mar 31) and 400 (May 1) must be excluded.
        assert summary["cash_spending"] == 600.0
        assert summary["total_spending"] == 2600.0
        assert summary["total_expense"] == 2600.0

    def test_multi_month_range_aggregation(self):
        headers, _ = get_authenticated_user()

        # Post cash expenses in Jan, Feb, Mar, Apr, May, Jun, Jul
        months = [
            ("2026-01-15", 3000.0),
            ("2026-02-15", 2500.0),
            ("2026-03-15", 4000.0),
            ("2026-04-15", 1500.0),
            ("2026-05-15", 3200.0),
            ("2026-06-15", 2800.0),
            ("2026-07-15", 5000.0),  # Should be excluded if filtering Jan-Jun
        ]
        for exp_date, amt in months:
            client.post(
                "/cash-expenses",
                json={"amount": amt, "category": "Living", "expense_date": exp_date},
                headers=headers,
            )

        # Query Jan 1 -> Jun 30
        res = client.get("/analytics/summary?start_date=2026-01-01&end_date=2026-06-30", headers=headers)
        assert res.status_code == 200
        summary = res.json()
        # Sum of Jan-Jun: 3000 + 2500 + 4000 + 1500 + 3200 + 2800 = 17000
        assert summary["cash_spending"] == 17000.0
        assert summary["total_spending"] == 17000.0


class TestStatementLifecycleWithCashExpenses:
    def test_statement_deletion_preserves_cash_and_recomputes_forecast(self):
        headers, _ = get_authenticated_user()

        # Seed sample bank statement
        seed_res = client.post("/statements/seed-sample?bank=HDFC%20Bank", headers=headers)
        assert seed_res.status_code == 200
        stmt = seed_res.json()
        stmt_id = stmt["id"]

        # Add cash expense
        cash_res = client.post(
            "/cash-expenses",
            json={"amount": 1500.0, "category": "Food", "expense_date": "2026-04-15"},
            headers=headers,
        )
        assert cash_res.status_code == 201
        cash_id = cash_res.json()["id"]

        # Verify combined summary
        summary_before = client.get("/analytics/summary", headers=headers).json()
        assert summary_before["bank_spending"] > 0
        assert summary_before["cash_spending"] >= 1500.0

        # Delete statement
        del_stmt = client.delete(f"/statements/{stmt_id}", headers=headers)
        assert del_stmt.status_code == 200

        # Verify cash expense is STILL alive and untouched!
        cash_check = client.get(f"/cash-expenses/{cash_id}", headers=headers)
        assert cash_check.status_code == 200
        assert cash_check.json()["amount"] == 1500.0

        # Verify analytics reflects bank=0, cash=1500, total=1500
        summary_after = client.get("/analytics/summary", headers=headers).json()
        assert summary_after["bank_spending"] == 0.0
        assert summary_after["cash_spending"] == 1500.0
        assert summary_after["total_spending"] == 1500.0

        # Verify forecast recomputed without crashing
        forecast_res = client.get("/forecast", headers=headers)
        assert forecast_res.status_code == 200


class TestFullScenarioSection43:
    """End-to-end verification scenario explicitly outlined in Section 43 of requirements."""

    def test_section_43_scenario(self):
        headers, user_id = get_authenticated_user()
        db = SessionLocal()

        # Step 1: Add cash expenses
        # 2026-09-01: ₹250 (Food)
        # 2026-09-05: ₹100 (Transport)
        # 2026-09-10: ₹500 (Shopping)
        client.post(
            "/cash-expenses",
            json={"amount": 250.0, "category": "Food", "description": "Lunch", "expense_date": "2026-09-01"},
            headers=headers,
        )
        client.post(
            "/cash-expenses",
            json={"amount": 100.0, "category": "Transport", "description": "Auto", "expense_date": "2026-09-05"},
            headers=headers,
        )
        client.post(
            "/cash-expenses",
            json={"amount": 500.0, "category": "Shopping", "description": "Shirt", "expense_date": "2026-09-10"},
            headers=headers,
        )

        # Step 2: Upload / Seed bank transactions for Sep 1 - Sep 30 totaling ₹5,000
        try:
            stmt = Statement(
                user_id=user_id,
                file_name="sep_statement.pdf",
                bank_name="HDFC Bank",
                account_number="987654",
                statement_start="2026-09-01",
                statement_end="2026-09-30",
                processing_status="completed",
                total_transactions=2,
            )
            db.add(stmt)
            db.commit()
            db.refresh(stmt)

            t1 = Transaction(
                statement_id=stmt.id,
                user_id=user_id,
                date="2026-09-08",
                raw_description="Supermarket",
                amount=3000.0,
                cr_dr="DR",
                category="Groceries",
                balance=15000.0,
            )
            t2 = Transaction(
                statement_id=stmt.id,
                user_id=user_id,
                date="2026-09-20",
                raw_description="Electronics",
                amount=2000.0,
                cr_dr="DR",
                category="Shopping",
                balance=13000.0,
            )
            db.add_all([t1, t2])
            db.commit()
            stmt_id = stmt.id
        finally:
            db.close()

        # Check total spending: Bank ₹5,000 + Cash ₹850 = ₹5,850
        summary1 = client.get("/analytics/summary", headers=headers).json()
        assert summary1["bank_spending"] == 5000.0
        assert summary1["cash_spending"] == 850.0
        assert summary1["total_spending"] == 5850.0

        # Step 3: Add cash expense on 2026-09-30 of ₹300 (Food)
        client.post(
            "/cash-expenses",
            json={"amount": 300.0, "category": "Food", "description": "Dinner", "expense_date": "2026-09-30"},
            headers=headers,
        )

        # Total spending must update to ₹6,150 (Bank ₹5,000 + Cash ₹1,150)
        summary2 = client.get("/analytics/summary", headers=headers).json()
        assert summary2["bank_spending"] == 5000.0
        assert summary2["cash_spending"] == 1150.0
        assert summary2["total_spending"] == 6150.0

        # Step 4: Add cash expense outside statement period: 2026-10-01 of ₹1,000 (Rent)
        client.post(
            "/cash-expenses",
            json={"amount": 1000.0, "category": "Rent", "description": "October rent cash", "expense_date": "2026-10-01"},
            headers=headers,
        )

        # Querying Sep 1 - Sep 30: Spending MUST REMAIN ₹6,150! The Oct 1 expense is not included.
        summary3 = client.get("/analytics/summary?start_date=2026-09-01&end_date=2026-09-30", headers=headers).json()
        assert summary3["bank_spending"] == 5000.0
        assert summary3["cash_spending"] == 1150.0
        assert summary3["total_spending"] == 6150.0

        # Step 5: Delete bank statement
        del_res = client.delete(f"/statements/{stmt_id}", headers=headers)
        assert del_res.status_code == 200

        # Statement deleted -> Bank spending drops to ₹0
        # If querying the Sep period:
        summary_sep_after_del = client.get(
            "/analytics/summary?start_date=2026-09-01&end_date=2026-09-30", headers=headers
        ).json()
        assert summary_sep_after_del["bank_spending"] == 0.0
        assert summary_sep_after_del["cash_spending"] == 1150.0
        assert summary_sep_after_del["total_spending"] == 1150.0

        # Overall summary without date filters: includes all cash expenses (₹1,150 + ₹1,000 = ₹2,150)
        summary_all_after_del = client.get("/analytics/summary", headers=headers).json()
        assert summary_all_after_del["bank_spending"] == 0.0
        assert summary_all_after_del["cash_spending"] == 2150.0
        assert summary_all_after_del["total_spending"] == 2150.0

        # All 5 cash expenses are intact in DB
        cash_list = client.get("/cash-expenses", headers=headers).json()
        assert len(cash_list) == 5
