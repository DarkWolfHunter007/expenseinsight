import os
import sys
import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from backend.app.main import app
from backend.app.database.session import SessionLocal
from backend.app.models.db_models import CashExpense, Statement, Transaction
from backend.app.services.accounting import AccountingPolicy
from backend.app.services.forecasting_service import ForecastingService

client = TestClient(app)


def get_authenticated_user():
    """Helper to create a fresh guest user and get auth headers."""
    res = client.post("/auth/guest")
    assert res.status_code == 200
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    user_info = client.get("/auth/me", headers=headers).json()
    return headers, user_info["id"]


class TestPhase11ActualFailureCase:
    """
    PHASE 11 — TEST THE ACTUAL FAILURE CASE
    Deterministic backend test verifying exact accounting on the reported dataset.
    """

    def test_actual_failure_case_dataset(self):
        headers, user_id = get_authenticated_user()
        db = SessionLocal()

        try:
            stmt = Statement(
                user_id=user_id,
                file_name="statement.pdf",
                bank_name="HDFC Bank",
                account_number="12345678",
                statement_start="2026-09-01",
                statement_end="2026-09-30",
                processing_status="completed",
                total_transactions=5,
            )
            db.add(stmt)
            db.commit()
            db.refresh(stmt)

            # 1. Transfer (DR 2655)
            t1 = Transaction(
                user_id=user_id,
                statement_id=stmt.id,
                date="2026-09-02",
                raw_description="UPI/TRANSFER/ZERODHA",
                merchant="Zerodha",
                normalized_merchant="zerodha",
                amount=2655.0,
                cr_dr="DR",
                transaction_type="transfer",
                category="Transfers",
            )
            # 2. Transfer (DR 1365)
            t2 = Transaction(
                user_id=user_id,
                statement_id=stmt.id,
                date="2026-09-05",
                raw_description="NEFT/TRANSFER TO SELF",
                merchant="Self Transfer",
                normalized_merchant="self_transfer",
                amount=1365.0,
                cr_dr="DR",
                transaction_type="transfer",
                category="Transfers",
            )
            # 3. Real expense (DR 500)
            t3 = Transaction(
                user_id=user_id,
                statement_id=stmt.id,
                date="2026-09-10",
                raw_description="UPI/SWIGGY/FOOD ORDER",
                merchant="Swiggy",
                normalized_merchant="swiggy",
                amount=500.0,
                cr_dr="DR",
                transaction_type="expense",
                category="Food",
            )
            # 4. Income (CR 10000)
            t4 = Transaction(
                user_id=user_id,
                statement_id=stmt.id,
                date="2026-09-01",
                raw_description="SALARY CREDIT FOR SEPT",
                merchant="Company Payroll",
                normalized_merchant="company_payroll",
                amount=10000.0,
                cr_dr="CR",
                transaction_type="income",
                category="Income",
            )
            # 5. Cash withdrawal (DR 2000)
            t5 = Transaction(
                user_id=user_id,
                statement_id=stmt.id,
                date="2026-09-12",
                raw_description="ATM CASH WDL",
                merchant="ATM",
                normalized_merchant="atm",
                amount=2000.0,
                cr_dr="DR",
                transaction_type="cash_withdrawal",
                category="Cash Withdrawal",
            )
            # 6. Cash expense (300 Food)
            c1 = CashExpense(
                user_id=user_id,
                amount=300.0,
                category="Food",
                description="Groceries at local mart",
                expense_date="2026-09-15",
                payment_method="cash",
            )

            db.add_all([t1, t2, t3, t4, t5, c1])
            db.commit()
        finally:
            db.close()

        # Query summary
        res = client.get("/analytics/summary", headers=headers)
        assert res.status_code == 200
        summary = res.json()

        # Verification per Phase 11 specification:
        assert summary["bank_spending"] == 500.0
        assert summary["cash_spending"] == 300.0
        assert summary["total_spending"] == 800.0
        assert summary["total_expense"] == 800.0
        assert summary["total_income"] == 10000.0
        assert summary["net_savings"] == 9200.0
        assert summary["total_transfers"] == 4020.0  # 2655 + 1365

        # Top merchants should contain only genuine personal expenses (Swiggy), not transfers
        merchants = summary["top_merchants"]
        merchant_names = [m["merchant"] for m in merchants]
        assert "Swiggy" in merchant_names
        assert "Zerodha" not in merchant_names
        assert "Self Transfer" not in merchant_names
        assert "ATM" not in merchant_names


class TestPhase12CrossModuleInvariants:
    """
    PHASE 12 — CROSS-MODULE INVARIANT TESTS
    Proves that all analytics and forecasting modules agree on consistent financial accounting.
    """

    @pytest.fixture(autouse=True)
    def setup_data(self):
        headers, user_id = get_authenticated_user()
        self.headers = headers
        self.user_id = user_id
        db = SessionLocal()

        try:
            stmt = Statement(
                user_id=user_id,
                file_name="inv_stmt.pdf",
                bank_name="Test Bank",
                statement_start="2026-05-01",
                statement_end="2026-06-30",
                processing_status="completed",
                total_transactions=6,
            )
            db.add(stmt)
            db.commit()
            db.refresh(stmt)

            txns = [
                # May expenses
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-05-05", raw_description="Uber ride", merchant="Uber", normalized_merchant="uber", amount=350.0, cr_dr="DR", transaction_type="expense", category="Travel"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-05-15", raw_description="Swiggy dinner", merchant="Swiggy", normalized_merchant="swiggy", amount=650.0, cr_dr="DR", transaction_type="expense", category="Food"),
                # May income
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-05-01", raw_description="Salary May", merchant="Employer", normalized_merchant="employer", amount=25000.0, cr_dr="CR", transaction_type="income", category="Income"),
                # May transfer & withdrawal
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-05-10", raw_description="Transfer to broker", merchant="Zerodha", normalized_merchant="zerodha", amount=5000.0, cr_dr="DR", transaction_type="transfer", category="Transfers"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-05-20", raw_description="ATM withdrawal", merchant="ATM", normalized_merchant="atm", amount=3000.0, cr_dr="DR", transaction_type="cash_withdrawal", category="Cash Withdrawal"),

                # June expenses
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-06-05", raw_description="Uber ride", merchant="Uber", normalized_merchant="uber", amount=400.0, cr_dr="DR", transaction_type="expense", category="Travel"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-06-12", raw_description="Amazon shopping", merchant="Amazon", normalized_merchant="amazon", amount=1200.0, cr_dr="DR", transaction_type="expense", category="Shopping"),
                # June income
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-06-01", raw_description="Salary June", merchant="Employer", normalized_merchant="employer", amount=25000.0, cr_dr="CR", transaction_type="income", category="Income"),
            ]

            cash_expenses = [
                CashExpense(user_id=user_id, amount=450.0, category="Food", description="Dinner", expense_date="2026-05-18", payment_method="cash"),
                CashExpense(user_id=user_id, amount=550.0, category="Groceries", description="Veggies", expense_date="2026-06-10", payment_method="cash"),
            ]

            db.add_all(txns + cash_expenses)
            db.commit()
        finally:
            db.close()

    def test_invariant_1_total_spending_equals_bank_plus_cash(self):
        """Invariant 1: summary.total_spending == summary.bank_spending + summary.cash_spending"""
        summary = client.get("/analytics/summary", headers=self.headers).json()
        assert round(summary["total_spending"], 2) == round(summary["bank_spending"] + summary["cash_spending"], 2)
        assert summary["total_expense"] == summary["total_spending"]

    def test_invariant_2_category_total_equals_total_spending(self):
        """Invariant 2: Category total equals total spending."""
        summary = client.get("/analytics/summary", headers=self.headers).json()
        categories = client.get("/analytics/categories", headers=self.headers).json()

        category_sum = round(sum(c["amount"] for c in categories), 2)
        assert category_sum == summary["total_spending"]

        # Also verify Transfers and Cash Withdrawals never appear in categories
        cat_names = [c["category"].lower() for c in categories]
        assert "transfers" not in cat_names
        assert "transfer" not in cat_names
        assert "cash withdrawal" not in cat_names

    def test_invariant_3_monthly_totals_equal_total_spending(self):
        """Invariant 3: Monthly expense totals equal total spending for the same date range."""
        summary = client.get("/analytics/summary", headers=self.headers).json()
        monthly = client.get("/analytics/monthly", headers=self.headers).json()

        monthly_expense_sum = round(sum(m["total_expense"] for m in monthly), 2)
        assert monthly_expense_sum == summary["total_spending"]

        monthly_income_sum = round(sum(m["total_income"] for m in monthly), 2)
        assert monthly_income_sum == summary["total_income"]

    def test_invariants_4_and_5_transfers_and_withdrawals_contribute_zero_spending(self):
        """Invariants 4 & 5: Transfers and Cash withdrawals contribute zero to personal spending."""
        summary = client.get("/analytics/summary", headers=self.headers).json()
        # Bank expenses = 350 + 650 + 400 + 1200 = 2600.0 (excludes 5000 transfer and 3000 cash wdl)
        assert summary["bank_spending"] == 2600.0
        # Cash expenses = 450 + 550 = 1000.0
        assert summary["cash_spending"] == 1000.0
        assert summary["total_spending"] == 3600.0
        assert summary["total_transfers"] == 5000.0

    def test_invariant_6_cash_expenses_contribute_exactly_once(self):
        """Invariant 6: Cash expenses contribute exactly once."""
        summary = client.get("/analytics/summary", headers=self.headers).json()
        assert summary["cash_spending"] == 1000.0

    def test_invariant_7_top_merchants_never_contain_transfers_or_withdrawals(self):
        """Invariant 7: Top merchants never contain transfer-only or withdrawal spending."""
        merchants = client.get("/analytics/merchants", headers=self.headers).json()
        names = [m["merchant"] for m in merchants]
        assert "Zerodha" not in names
        assert "ATM" not in names
        assert "Uber" in names

    def test_invariant_8_recurring_expenses_never_contain_transfers_or_withdrawals(self):
        """Invariant 8: Recurring expenses never contain transfer-only merchants."""
        recurring = client.get("/analytics/recurring", headers=self.headers).json()
        names = [r["merchant"] for r in recurring]
        assert "Zerodha" not in names
        assert "ATM" not in names

    def test_invariant_9_forecast_input_excludes_transfers_and_withdrawals(self):
        """Invariant 9: Forecast input does not include transfers/cash withdrawals as spending."""
        db = SessionLocal()
        try:
            service = ForecastingService(db=db)
            fc = service.generate_user_forecast(user_id=self.user_id, persist=False)
            assert fc["status"] in ("success", "low_history")
            # Categories in forecast must be genuine spending categories
            for cat in fc["category_forecasts"].keys():
                assert cat.lower() not in ("transfers", "transfer", "cash withdrawal", "cash_withdrawal")
        finally:
            db.close()

    def test_invariant_10_transaction_count_matches_window_records(self):
        """Invariant 10: Dashboard transaction count agrees with the transactions actually included in the analytics window."""
        summary = client.get("/analytics/summary", headers=self.headers).json()
        # 8 bank transactions + 2 cash expenses = 10 total transactions
        assert summary["total_transactions_count"] == 10


class TestPhase13StatementDateBoundaryBugs:
    """
    PHASE 13 — TEST THE STATEMENT DATE BUG
    Tests scenarios where statement metadata has a narrow or shifted date range,
    and proves that valid transactions are NEVER silently converted into ₹0 / 0 transactions.
    """

    def test_narrow_statement_bounds_do_not_hide_persisted_transactions(self):
        headers, user_id = get_authenticated_user()
        db = SessionLocal()

        try:
            # Statement says period is narrow: 2026-08-10 to 2026-08-15
            stmt = Statement(
                user_id=user_id,
                file_name="narrow_stmt.pdf",
                bank_name="State Bank of India",
                statement_start="2026-08-10",
                statement_end="2026-08-15",
                processing_status="completed",
                total_transactions=3,
            )
            db.add(stmt)
            db.commit()
            db.refresh(stmt)

            # Persisted transactions fall OUTSIDE the narrow 10th-15th header range:
            t1 = Transaction(user_id=user_id, statement_id=stmt.id, date="2026-08-01", raw_description="Groceries", merchant="Reliance", amount=1500.0, cr_dr="DR", transaction_type="expense", category="Groceries")
            t2 = Transaction(user_id=user_id, statement_id=stmt.id, date="2026-08-20", raw_description="Electronics", merchant="Croma", amount=3000.0, cr_dr="DR", transaction_type="expense", category="Shopping")
            t3 = Transaction(user_id=user_id, statement_id=stmt.id, date="2026-08-30", raw_description="Electricity Bill", merchant="BESCOM", amount=1200.0, cr_dr="DR", transaction_type="expense", category="Bills")

            db.add_all([t1, t2, t3])
            db.commit()
        finally:
            db.close()

        # Query summary with no explicit date range provided
        summary = client.get("/analytics/summary", headers=headers).json()

        # MUST NOT be ₹0 or 0 transactions or "No activity in period"
        assert summary["total_transactions_count"] == 3
        assert summary["bank_spending"] == 5700.0
        assert summary["total_spending"] == 5700.0
        assert summary["statement_period"] != "No activity in period"

        # Monthly & Category must also reflect all 3 transactions
        categories = client.get("/analytics/categories", headers=headers).json()
        assert len(categories) == 3
        assert sum(c["amount"] for c in categories) == 5700.0

        merchants = client.get("/analytics/merchants", headers=headers).json()
        assert len(merchants) == 3

    def test_multiple_statements_with_varying_ranges_aggregate_cleanly(self):
        headers, user_id = get_authenticated_user()
        db = SessionLocal()

        try:
            # Statement 1: July 2026
            stmt1 = Statement(
                user_id=user_id,
                file_name="july_stmt.pdf",
                bank_name="HDFC Bank",
                statement_start="2026-07-01",
                statement_end="2026-07-31",
                processing_status="completed",
                total_transactions=2,
            )
            # Statement 2: September 2026 (gap in August)
            stmt2 = Statement(
                user_id=user_id,
                file_name="sept_stmt.pdf",
                bank_name="ICICI Bank",
                statement_start="2026-09-01",
                statement_end="2026-09-30",
                processing_status="completed",
                total_transactions=2,
            )
            db.add_all([stmt1, stmt2])
            db.commit()
            db.refresh(stmt1)
            db.refresh(stmt2)

            t1 = Transaction(user_id=user_id, statement_id=stmt1.id, date="2026-07-15", raw_description="Fuel", merchant="Shell", amount=2000.0, cr_dr="DR", transaction_type="expense", category="Travel")
            t2 = Transaction(user_id=user_id, statement_id=stmt1.id, date="2026-07-28", raw_description="Dinner", merchant="Barbeque Nation", amount=1800.0, cr_dr="DR", transaction_type="expense", category="Food")

            t3 = Transaction(user_id=user_id, statement_id=stmt2.id, date="2026-09-10", raw_description="Flight", merchant="IndiGo", amount=4500.0, cr_dr="DR", transaction_type="expense", category="Travel")
            t4 = Transaction(user_id=user_id, statement_id=stmt2.id, date="2026-09-22", raw_description="Pharmacy", merchant="Apollo", amount=700.0, cr_dr="DR", transaction_type="expense", category="Healthcare")

            db.add_all([t1, t2, t3, t4])
            db.commit()
        finally:
            db.close()

        summary = client.get("/analytics/summary", headers=headers).json()
        assert summary["statement_count"] == 2
        assert "Multiple Banks" in summary["bank_name"]
        assert summary["total_transactions_count"] == 4
        assert summary["bank_spending"] == 9000.0
        assert summary["total_spending"] == 9000.0

        monthly = client.get("/analytics/monthly", headers=headers).json()
        assert len(monthly) == 2  # July and September
        assert monthly[0]["month"] == "2026-07"
        assert monthly[0]["total_expense"] == 3800.0
        assert monthly[1]["month"] == "2026-09"
        assert monthly[1]["total_expense"] == 5200.0

    def test_recurring_subscriptions_detection_accuracy(self):
        """
        Tests that recurring detection accurately discovers monthly subscriptions
        and rejects repeated transfers, cash withdrawals, and irregular bursts.
        """
        headers, user_id = get_authenticated_user()
        db = SessionLocal()

        try:
            stmt = Statement(
                user_id=user_id,
                file_name="recurring_test.pdf",
                bank_name="HDFC Bank",
                statement_start="2026-01-01",
                statement_end="2026-03-31",
                processing_status="completed",
                total_transactions=12,
            )
            db.add(stmt)
            db.commit()
            db.refresh(stmt)

            txns = [
                # 1. Real monthly subscription: Netflix monthly on 5th
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-01-05", raw_description="UPI/NETFLIX", merchant="Netflix", amount=649.0, cr_dr="DR", transaction_type="expense", category="Entertainment"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-02-05", raw_description="UPI/NETFLIX", merchant="Netflix", amount=649.0, cr_dr="DR", transaction_type="expense", category="Entertainment"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-03-05", raw_description="UPI/NETFLIX", merchant="Netflix", amount=649.0, cr_dr="DR", transaction_type="expense", category="Entertainment"),

                # 2. Repeated transfer: Zerodha repeated 3 times monthly
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-01-10", raw_description="UPI/ZERODHA", merchant="Zerodha", amount=5000.0, cr_dr="DR", transaction_type="transfer", category="Transfers"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-02-10", raw_description="UPI/ZERODHA", merchant="Zerodha", amount=5000.0, cr_dr="DR", transaction_type="transfer", category="Transfers"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-03-10", raw_description="UPI/ZERODHA", merchant="Zerodha", amount=5000.0, cr_dr="DR", transaction_type="transfer", category="Transfers"),

                # 3. Repeated cash withdrawal: ATM WDL repeated 3 times monthly
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-01-15", raw_description="ATM CASH WDL", merchant="ATM", amount=2000.0, cr_dr="DR", transaction_type="cash_withdrawal", category="Cash Withdrawal"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-02-15", raw_description="ATM CASH WDL", merchant="ATM", amount=2000.0, cr_dr="DR", transaction_type="cash_withdrawal", category="Cash Withdrawal"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-03-15", raw_description="ATM CASH WDL", merchant="ATM", amount=2000.0, cr_dr="DR", transaction_type="cash_withdrawal", category="Cash Withdrawal"),

                # 4. Repeated merchant with irregular burst (3 times in 3 days)
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-01-20", raw_description="Starbucks Coffee", merchant="Starbucks", amount=350.0, cr_dr="DR", transaction_type="expense", category="Food"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-01-21", raw_description="Starbucks Coffee", merchant="Starbucks", amount=350.0, cr_dr="DR", transaction_type="expense", category="Food"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-01-22", raw_description="Starbucks Coffee", merchant="Starbucks", amount=350.0, cr_dr="DR", transaction_type="expense", category="Food"),
            ]

            db.add_all(txns)
            db.commit()
        finally:
            db.close()

        recurring_res = client.get("/analytics/recurring", headers=headers).json()

        # Only Netflix should be discovered!
        recurring_merchants = [r["merchant"] for r in recurring_res]
        assert "Netflix" in recurring_merchants
        assert "Zerodha" not in recurring_merchants
        assert "ATM" not in recurring_merchants
        assert "Starbucks" not in recurring_merchants

        netflix = next(r for r in recurring_res if r["merchant"] == "Netflix")
        assert netflix["average_amount"] == 649.0
        assert netflix["occurrences"] == 3

class TestUPIBankSourceSeparation:
    """
    Bank statements may contain both normal bank-rail transactions and UPI
    payments. The transaction list must expose them through separate sources.
    """

    def test_bank_statement_transactions_are_classified_by_payment_rail(self):
        headers, user_id = get_authenticated_user()
        db = SessionLocal()

        try:
            stmt = Statement(
                user_id=user_id,
                file_name="mixed_rails.pdf",
                bank_name="HDFC Bank",
                statement_start="2026-09-01",
                statement_end="2026-09-30",
                processing_status="completed",
                total_transactions=3,
            )
            db.add(stmt)
            db.commit()
            db.refresh(stmt)

            db.add_all([
                Transaction(
                    user_id=user_id,
                    statement_id=stmt.id,
                    date="2026-09-05",
                    raw_description="UPI/DR/NETFLIX/123456789012",
                    merchant="Netflix",
                    normalized_merchant="netflix",
                    amount=649.0,
                    cr_dr="DR",
                    transaction_type="expense",
                    category="Entertainment",
                ),
                Transaction(
                    user_id=user_id,
                    statement_id=stmt.id,
                    date="2026-09-06",
                    raw_description="POS/AMAZON/123456",
                    merchant="Amazon",
                    normalized_merchant="amazon",
                    amount=1200.0,
                    cr_dr="DR",
                    transaction_type="expense",
                    category="Shopping",
                ),
                Transaction(
                    user_id=user_id,
                    statement_id=stmt.id,
                    date="2026-09-07",
                    raw_description="PHONEPE UPI PAYMENT/STARBUCKS",
                    merchant="Starbucks",
                    normalized_merchant="starbucks",
                    amount=350.0,
                    cr_dr="DR",
                    transaction_type="expense",
                    category="Food",
                ),
            ])
            db.commit()
        finally:
            db.close()

        all_items = client.get("/transactions?source=all", headers=headers)
        assert all_items.status_code == 200
        assert len(all_items.json()) == 3

        upi_items = client.get("/transactions?source=upi", headers=headers)
        assert upi_items.status_code == 200
        upi = upi_items.json()
        assert len(upi) == 2
        assert {item["merchant"] for item in upi} == {"Netflix", "Starbucks"}
        assert all(item["source_type"] == "upi" for item in upi)
        assert all(item["payment_method"] == "upi" for item in upi)

        bank_items = client.get("/transactions?source=bank", headers=headers)
        assert bank_items.status_code == 200
        bank = bank_items.json()
        assert len(bank) == 1
        assert bank[0]["merchant"] == "Amazon"
        assert bank[0]["source_type"] == "bank"
        assert bank[0]["payment_method"] == "bank"

    def test_upi_source_detection_handles_common_bank_statement_narrations(self):
        headers, user_id = get_authenticated_user()
        db = SessionLocal()

        try:
            stmt = Statement(
                user_id=user_id,
                file_name="upi_patterns.pdf",
                bank_name="Test Bank",
                statement_start="2026-09-01",
                statement_end="2026-09-30",
                processing_status="completed",
                total_transactions=4,
            )
            db.add(stmt)
            db.commit()
            db.refresh(stmt)

            txns = [
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-09-01", raw_description="UPI/DR/ABC/123456789012", amount=10, cr_dr="DR", transaction_type="expense", category="Other"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-09-02", raw_description="VPA merchant@upi", amount=20, cr_dr="DR", transaction_type="expense", category="Other"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-09-03", raw_description="PhonePe payment", amount=30, cr_dr="DR", transaction_type="expense", category="Other"),
                Transaction(user_id=user_id, statement_id=stmt.id, date="2026-09-04", raw_description="IMPS/P2A/merchant", amount=40, cr_dr="DR", transaction_type="expense", category="Other"),
            ]
            db.add_all(txns)
            db.commit()

            assert txns[0].source_type == "upi"
            assert txns[1].source_type == "upi"
            assert txns[2].source_type == "upi"
            assert txns[3].source_type == "bank"
        finally:
            db.close()
\n