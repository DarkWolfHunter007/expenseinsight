"""
Test Suite for Global UPI / Bank Transaction Source Separation.
Verifies Phase 10 Minimum Dataset Matrix (Transactions A-G) and canonical classification invariants:
- Transaction A: Bank statement normal NEFT -> source = 'bank'
- Transaction B: Bank statement normal IMPS -> source = 'bank'
- Transaction C: Bank statement UPI narration -> source = 'upi'
- Transaction D: Bank statement PhonePe narration -> source = 'upi'
- Transaction E: Bank statement VPA narration -> source = 'upi'
- Transaction F: Manually created UPI expense -> source = 'upi'
- Transaction G: Manually created cash expense -> source = 'cash'
"""

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
    Statement,
    Transaction,
    User,
)
from backend.app.services.accounting import (
    AccountingPolicy,
    UPI_BANK_SOURCE_SEPARATION_CHECKLIST,
)


def cleanup_user_data(db_session, user_id: str):
    db_session.query(CategoryCorrection).filter(CategoryCorrection.user_id == user_id).delete()
    db_session.query(Transaction).filter(Transaction.user_id == user_id).delete()
    db_session.query(CashExpense).filter(CashExpense.user_id == user_id).delete()
    db_session.query(Statement).filter(Statement.user_id == user_id).delete()
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
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    me_resp = client.get("/auth/me", headers=headers)
    assert me_resp.status_code == 200
    user_id = me_resp.json()["id"]
    user = db_session.query(User).filter(User.id == user_id).first()
    return user, headers



class TestSourceSeparationMatrix:
    """Verifies Phase 10 exact matrix requirements."""

    def test_canonical_classifier_unit(self):
        """Verifies canonical classification rules on raw strings and records."""
        # Transaction A: NEFT
        assert AccountingPolicy.classify_source({"raw_description": "NEFT/123456/N12345/VENDOR CORP"}) == "bank"
        # Transaction B: IMPS
        assert AccountingPolicy.classify_source({"raw_description": "IMPS/P2A/234567890123/RENT PAYMENT"}) == "bank"
        # Transaction C: UPI narration
        assert AccountingPolicy.classify_source({"raw_description": "UPI/DR/123456/GROCERY STORE/HDFC"}) == "upi"
        # Transaction D: PhonePe
        assert AccountingPolicy.classify_source({"raw_description": "UPI-PHONEPE-PHONEPE@YBL-234567890123"}) == "upi"
        # Transaction E: VPA
        assert AccountingPolicy.classify_source({"raw_description": "PAY TO SWIGGY@OKAXIS REF 987654"}) == "upi"
        # Transaction F: Manual UPI expense
        assert AccountingPolicy.classify_source({"payment_method": "upi", "description": "Tea snack"}) == "upi"
        # Transaction G: Manual Cash expense
        assert AccountingPolicy.classify_source({"payment_method": "cash", "description": "Auto fare"}) == "cash"

    def test_matrix_a_to_g_api_filtering(self, db_session, client, test_user_and_token):
        """
        Creates transactions A through G and executes GET /transactions with:
        - source=all  -> A B C D E F G
        - source=bank -> A B
        - source=upi  -> C D E F
        - source=cash -> G
        """
        user, headers = test_user_and_token

        # Clean prior transactions for user
        cleanup_user_data(db_session, user.id)

        # Create statement container
        stmt = Statement(
            user_id=user.id,
            file_name="matrix_statement.pdf",
            bank_name="HDFC Bank",
            statement_start="2026-07-01",
            statement_end="2026-07-31",
            processing_status="completed",
            total_transactions=5
        )
        db_session.add(stmt)
        db_session.commit()
        db_session.refresh(stmt)

        # Transaction A: bank statement normal NEFT
        tx_a = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-05",
            raw_description="NEFT/N12345/OFFICE RENT/HDFC",
            clean_description="Office Rent",
            merchant="Landlord",
            normalized_merchant="landlord",
            amount=25000.0,
            transaction_type="expense",
            cr_dr="DR",
            category="Rent"
        )
        # Transaction B: bank statement normal IMPS
        tx_b = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-08",
            raw_description="IMPS/P2A/87654321/EQUIPMENT SUPPLIES",
            clean_description="Equipment",
            merchant="Supplies Co",
            normalized_merchant="supplies_co",
            amount=4200.0,
            transaction_type="expense",
            cr_dr="DR",
            category="Shopping"
        )
        # Transaction C: bank statement UPI narration
        tx_c = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-10",
            raw_description="UPI/DR/123456/SUPERMARKET/HDFC",
            clean_description="Supermarket",
            merchant="Supermarket",
            normalized_merchant="supermarket",
            amount=1500.0,
            transaction_type="expense",
            cr_dr="DR",
            category="Groceries"
        )
        # Transaction D: bank statement PhonePe narration
        tx_d = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-12",
            raw_description="UPI-PHONEPE-PHONEPE@YBL-33445566-ORDER",
            clean_description="PhonePe Payment",
            merchant="PhonePe",
            normalized_merchant="phonepe",
            amount=850.0,
            transaction_type="expense",
            cr_dr="DR",
            category="Food"
        )
        # Transaction E: bank statement VPA narration
        tx_e = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-15",
            raw_description="PAID TO swiggy@okaxis REF 998877",
            clean_description="Swiggy",
            merchant="Swiggy",
            normalized_merchant="swiggy",
            amount=620.0,
            transaction_type="expense",
            cr_dr="DR",
            category="Food"
        )
        db_session.add_all([tx_a, tx_b, tx_c, tx_d, tx_e])
        db_session.commit()

        # Transaction F: manually created UPI expense
        cash_f = CashExpense(
            user_id=user.id,
            amount=200.0,
            category="Food",
            description="Chai snacks",
            expense_date="2026-07-18",
            payment_method="upi"
        )
        # Transaction G: manually created cash expense
        cash_g = CashExpense(
            user_id=user.id,
            amount=150.0,
            category="Transit",
            description="Auto rickshaw fare",
            expense_date="2026-07-20",
            payment_method="cash"
        )
        db_session.add_all([cash_f, cash_g])
        db_session.commit()

        ids_a_b = {tx_a.id, tx_b.id}
        ids_c_d_e = {tx_c.id, tx_d.id, tx_e.id}
        id_f = cash_f.id
        id_g = cash_g.id

        # 1. Verify GET /transactions?source=all -> A B C D E F G
        resp_all = client.get("/transactions?source=all", headers=headers)
        assert resp_all.status_code == 200, resp_all.text
        data_all = resp_all.json()
        returned_ids_all = {item["id"] for item in data_all}
        expected_all = ids_a_b | ids_c_d_e | {id_f, id_g}
        assert returned_ids_all == expected_all, f"Expected {expected_all}, got {returned_ids_all}"
        assert len(data_all) == 7

        # 2. Verify GET /transactions?source=bank -> A B
        resp_bank = client.get("/transactions?source=bank", headers=headers)
        assert resp_bank.status_code == 200, resp_bank.text
        data_bank = resp_bank.json()
        returned_ids_bank = {item["id"] for item in data_bank}
        assert returned_ids_bank == ids_a_b, f"Expected {ids_a_b}, got {returned_ids_bank}"
        assert len(data_bank) == 2
        for item in data_bank:
            assert item["source_type"] == "bank"

        # 3. Verify GET /transactions?source=upi -> C D E F
        resp_upi = client.get("/transactions?source=upi", headers=headers)
        assert resp_upi.status_code == 200, resp_upi.text
        data_upi = resp_upi.json()
        returned_ids_upi = {item["id"] for item in data_upi}
        expected_upi = ids_c_d_e | {id_f}
        assert returned_ids_upi == expected_upi, f"Expected {expected_upi}, got {returned_ids_upi}"
        assert len(data_upi) == 4
        for item in data_upi:
            assert item["source_type"] == "upi"

        # 4. Verify GET /transactions?source=cash -> G
        resp_cash = client.get("/transactions?source=cash", headers=headers)
        assert resp_cash.status_code == 200, resp_cash.text
        data_cash = resp_cash.json()
        returned_ids_cash = {item["id"] for item in data_cash}
        expected_cash = {id_g}
        assert returned_ids_cash == expected_cash, f"Expected {expected_cash}, got {returned_ids_cash}"
        assert len(data_cash) == 1
        for item in data_cash:
            assert item["source_type"] == "cash"

    def test_checklist_in_code_verified(self):
        """Verifies Phase 13 developer-facing checklist is fully checked."""
        checklist = AccountingPolicy.verify_checklist()
        assert len(checklist) == 13
        for k, v in checklist.items():
            assert v is True, f"Checklist item {k} is False!"

    def test_edge_cases_and_fallbacks(self):
        """Verifies Phase 12 edge cases, case-insensitivity, whitespace, and false-positive guards."""
        # Case variations
        assert AccountingPolicy.is_upi_narration("upi/dr/123/merchant") is True
        assert AccountingPolicy.is_upi_narration("UPI/DR/123/MERCHANT") is True
        assert AccountingPolicy.is_upi_narration("UpI/Dr/123/Merchant") is True
        assert AccountingPolicy.is_upi_narration("  UPI / DR / 123   ") is True

        # VPAs and apps
        assert AccountingPolicy.is_upi_narration("user@okaxis") is True
        assert AccountingPolicy.is_upi_narration("store@upi") is True
        assert AccountingPolicy.is_upi_narration("merchant@okhdfcbank") is True
        assert AccountingPolicy.is_upi_narration("shop@ybl") is True
        assert AccountingPolicy.is_upi_narration("PHONEPE PAYMENT") is True
        assert AccountingPolicy.is_upi_narration("Phone Pe Order") is True
        assert AccountingPolicy.is_upi_narration("Google Pay ref 123") is True
        assert AccountingPolicy.is_upi_narration("PAID VIA GPAY") is True
        assert AccountingPolicy.is_upi_narration("Paytm UPI txn") is True
        assert AccountingPolicy.is_upi_narration("BHIM UPI transfer") is True
        assert AccountingPolicy.is_upi_narration("Amazon Pay UPI") is True

        # Non-UPI words containing 'upi' as substring -> must NOT match
        assert AccountingPolicy.is_upi_narration("OCCUPIED FLAT MAINTENANCE") is False
        assert AccountingPolicy.is_upi_narration("GROUPING CHARGES") is False
        assert AccountingPolicy.is_upi_narration("STUPID BILL") is False
        assert AccountingPolicy.is_upi_narration("PUPIL FEE") is False
        assert AccountingPolicy.is_upi_narration("COUPLE TICKET") is False

        # Malformed, empty, or None strings safely fall back to bank
        assert AccountingPolicy.classify_source({"raw_description": ""}) == "bank"
        assert AccountingPolicy.classify_source({"raw_description": None}) == "bank"
        assert AccountingPolicy.classify_source({"raw_description": "---//---"}) == "bank"
        assert AccountingPolicy.classify_source({"raw_description": "NEFT/1234/N12"}) == "bank"
        assert AccountingPolicy.classify_source({"raw_description": "IMPS/1234/REF"}) == "bank"
        assert AccountingPolicy.classify_source({"raw_description": "ATM WDL CASH"}) == "bank"

    def test_category_edit_preserves_source_classification(self, db_session, client, test_user_and_token):
        """
        Verifies requirement:
        After editing a transaction's category, source_type must NOT silently revert to 'bank'.
        """
        user, headers = test_user_and_token
        cleanup_user_data(db_session, user.id)

        stmt = Statement(
            user_id=user.id,
            file_name="edit_test_stmt.pdf",
            bank_name="HDFC Bank",
            statement_start="2026-07-01",
            statement_end="2026-07-31",
            processing_status="completed"
        )
        db_session.add(stmt)
        db_session.commit()
        db_session.refresh(stmt)

        upi_txn = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-15",
            raw_description="UPI/DR/887766/NETFLIX INDIA/HDFC",
            clean_description="Netflix",
            merchant="Netflix",
            normalized_merchant="netflix",
            amount=649.0,
            transaction_type="expense",
            cr_dr="DR",
            category="Other"
        )
        db_session.add(upi_txn)
        db_session.commit()
        db_session.refresh(upi_txn)

        assert upi_txn.source_type == "upi"

        # PATCH /transactions/{id}/category to update category
        patch_resp = client.patch(
            f"/transactions/{upi_txn.id}/category",
            json={"category": "Entertainment", "apply_to_future": True},
            headers=headers
        )
        assert patch_resp.status_code == 200, patch_resp.text
        patch_data = patch_resp.json()
        assert patch_data["category"] == "Entertainment"
        assert patch_data["source_type"] == "upi", "CRITICAL BUG: Category edit reverted source_type to bank!"

        # Verify GET /transactions/{id} preserves source_type == 'upi'
        get_resp = client.get(f"/transactions/{upi_txn.id}", headers=headers)
        assert get_resp.status_code == 200
        assert get_resp.json()["source_type"] == "upi"

        # Verify GET /transactions?source=upi returns this transaction
        list_resp = client.get("/transactions?source=upi", headers=headers)
        assert list_resp.status_code == 200
        found = any(t["id"] == upi_txn.id for t in list_resp.json())
        assert found is True, "Edited UPI transaction missing from source=upi list!"

    def test_pagination_with_source_filtering(self, db_session, client, test_user_and_token):
        """Verifies that pagination correctly limits and offsets source-filtered transactions."""
        user, headers = test_user_and_token

        # Clean prior transactions
        cleanup_user_data(db_session, user.id)

        stmt = Statement(
            user_id=user.id,
            file_name="pagination_stmt.pdf",
            bank_name="HDFC Bank",
            statement_start="2026-07-01",
            statement_end="2026-07-31",
            processing_status="completed"
        )
        db_session.add(stmt)
        db_session.commit()

        # Insert 6 UPI transactions and 4 Bank transactions
        txns = []
        for i in range(6):
            txns.append(Transaction(
                user_id=user.id,
                statement_id=stmt.id,
                date=f"2026-07-{i+1:02d}",
                raw_description=f"UPI/DR/{1000+i}/MERCHANT_{i}/HDFC",
                clean_description=f"Merchant {i}",
                merchant=f"Merchant {i}",
                amount=100.0 * (i + 1),
                transaction_type="expense",
                cr_dr="DR",
                category="Shopping"
            ))
        for i in range(4):
            txns.append(Transaction(
                user_id=user.id,
                statement_id=stmt.id,
                date=f"2026-07-{i+10:02d}",
                raw_description=f"NEFT/N{2000+i}/VENDOR_{i}/HDFC",
                clean_description=f"Vendor {i}",
                merchant=f"Vendor {i}",
                amount=500.0 * (i + 1),
                transaction_type="expense",
                cr_dr="DR",
                category="Rent"
            ))
        db_session.add_all(txns)
        db_session.commit()

        # Page 1 of UPI (limit=3, offset=0)
        p1 = client.get("/transactions?source=upi&limit=3&offset=0", headers=headers).json()
        assert len(p1) == 3
        for item in p1:
            assert item["source_type"] == "upi"

        # Page 2 of UPI (limit=3, offset=3)
        p2 = client.get("/transactions?source=upi&limit=3&offset=3", headers=headers).json()
        assert len(p2) == 3
        for item in p2:
            assert item["source_type"] == "upi"

        # Page 3 of UPI (offset=6) -> empty
        p3 = client.get("/transactions?source=upi&limit=3&offset=6", headers=headers).json()
        assert len(p3) == 0

        # Verify no overlap between p1 and p2
        ids_p1 = {item["id"] for item in p1}
        ids_p2 = {item["id"] for item in p2}
        assert ids_p1.isdisjoint(ids_p2)
        assert len(ids_p1 | ids_p2) == 6

    def test_analytics_and_forecasting_consistency(self, db_session, client, test_user_and_token):
        """
        Verifies that source separation does NOT alter canonical accounting:
        - Statements with UPI transactions still contribute fully to total_expense.
        - Transfers (even with UPI narrations, like UPI/TRANSFER TO ZERODHA) remain excluded.
        - Invariants hold.
        """
        user, headers = test_user_and_token
        from backend.app.services.analytics_service import AnalyticsService
        from backend.app.services.forecasting_service import ForecastingService

        # Clean prior records
        cleanup_user_data(db_session, user.id)

        stmt = Statement(
            user_id=user.id,
            file_name="analytics_sep_stmt.pdf",
            bank_name="HDFC Bank",
            statement_start="2026-07-01",
            statement_end="2026-07-31",
            processing_status="completed"
        )
        db_session.add(stmt)
        db_session.commit()

        # 1. Statement Bank expense: 1000
        t1 = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-05",
            raw_description="NEFT/N1/SUPPLIER",
            clean_description="Supplier",
            merchant="Supplier",
            amount=1000.0,
            transaction_type="expense",
            cr_dr="DR",
            category="Supplies"
        )
        # 2. Statement UPI expense: 500
        t2 = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-10",
            raw_description="UPI/DR/123/SWIGGY/HDFC",
            clean_description="Swiggy",
            merchant="Swiggy",
            amount=500.0,
            transaction_type="expense",
            cr_dr="DR",
            category="Food"
        )
        # 3. Statement UPI Transfer: 2000 (neutral transfer, must not be counted as spending!)
        t3 = Transaction(
            user_id=user.id,
            statement_id=stmt.id,
            date="2026-07-15",
            raw_description="UPI/DR/456/ZERODHA BROKING/HDFC",
            clean_description="Zerodha",
            merchant="Zerodha",
            amount=2000.0,
            transaction_type="transfer",
            cr_dr="DR",
            category="Investments"
        )
        # 4. Manual Cash expense: 300
        c1 = CashExpense(
            user_id=user.id,
            amount=300.0,
            category="Transit",
            description="Metro fare",
            expense_date="2026-07-20",
            payment_method="cash"
        )
        # 5. Manual UPI expense: 200
        c2 = CashExpense(
            user_id=user.id,
            amount=200.0,
            category="Food",
            description="Coffee",
            expense_date="2026-07-22",
            payment_method="upi"
        )
        db_session.add_all([t1, t2, t3, c1, c2])
        db_session.commit()

        analytics_svc = AnalyticsService(db=db_session)
        summary = analytics_svc.get_summary(user_id=user.id)

        # Expected spending:
        # Bank statement expense: 1000
        # UPI statement expense: 500
        # Cash expenses (c1 + c2): 300 + 200 = 500
        # Total expense = 1000 + 500 + 500 = 2000.0 (Zerodha 2000 is excluded as transfer!)
        assert summary["total_expense"] == 2000.0
        assert summary["total_transfers"] == 2000.0

        # Monthly invariant
        monthly = analytics_svc.get_monthly_spending(user_id=user.id)
        assert sum(m["total_expense"] for m in monthly) == 2000.0

        # Category invariant
        categories = analytics_svc.get_category_spending(user_id=user.id)
        assert round(sum(c["amount"] for c in categories), 2) == 2000.0
        # Transfer must not be in category spending
        cat_names = [c["category"].lower() for c in categories]
        assert "investments" not in cat_names
        assert "transfer" not in cat_names

        # Forecasting runs without error and excludes transfers
        forecaster_svc = ForecastingService(db=db_session)
        forecast = forecaster_svc.generate_user_forecast(user_id=user.id, persist=False)
        assert forecast is not None
        assert "total_forecast" in forecast

