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
from backend.app.models.db_models import CashExpense, Statement, Transaction, User
from backend.app.services.accounting import (
    AccountingPolicy,
    UPI_BANK_SOURCE_SEPARATION_CHECKLIST,
)
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
        db_session.query(Transaction).filter(Transaction.user_id == user.id).delete()
        db_session.query(CashExpense).filter(CashExpense.user_id == user.id).delete()
        db_session.query(Statement).filter(Statement.user_id == user.id).delete()
        db_session.commit()

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
