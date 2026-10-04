import json
import os
import sys
import pytest
import pandas as pd
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from backend.app.main import app
from backend.ml.preprocessing.merchant_normalizer import MerchantNormalizer
from backend.ml.preprocessing.text_cleaner import TextCleaner
from backend.ml.categorization.classifier import ExpenseClassifier
from backend.ml.categorization.hybrid_categorizer import HybridCategorizer

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert data["product"] == "ExpenseInsight"

def test_text_cleaner():
    cleaner = TextCleaner()
    cleaned = cleaner.clean("UPI/3249820192/SWIGGY/ORDER123")
    assert "swiggy" in cleaned

    cleaned_pos = cleaner.clean("POS 48392 AMAZON SELLER")
    assert "amazon" in cleaned_pos

def test_bank_detection():
    from backend.app.services.pdf_extractor import PDFExtractor
    extractor = PDFExtractor()
    assert extractor._detect_bank("This is an HDFC Bank Statement for account") == "HDFC Bank"
    assert extractor._detect_bank("STATE BANK OF INDIA E-STATEMENT") == "State Bank of India"
    assert extractor._detect_bank("ICICI Bank Ltd - Statement of Account") == "ICICI Bank"
    assert extractor._detect_bank("Axis Bank Ltd transaction list") == "Axis Bank"
    assert extractor._detect_bank("Kotak Mahindra Bank e-stmt") == "Kotak Mahindra Bank"
    assert extractor._detect_bank("Unknown Bank Document") == "Bank Statement"


def test_statement_period_is_normalized_to_transaction_date_format():
    from backend.app.services.pdf_extractor import PDFExtractor

    extractor = PDFExtractor()

    assert extractor._extract_statement_period(
        "Statement period: 01/09/2026 to 30/09/2026"
    ) == ("2026-09-01", "2026-09-30")

    assert extractor._extract_statement_period(
        "Statement from 04-Aug-2026 to 03-Sep-2026"
    ) == ("2026-08-04", "2026-09-03")


def test_analytics_spending_excludes_internal_transfers_and_cash_withdrawals():
    from backend.app.services.analytics_service import AnalyticsService

    service = AnalyticsService(db=None)
    df = pd.DataFrame([
        {"cr_dr": "DR", "transaction_type": "expense", "amount": 100.0},
        {"cr_dr": "DR", "transaction_type": "transfer", "amount": 500.0},
        {"cr_dr": "DR", "transaction_type": "cash_withdrawal", "amount": 200.0},
        {"cr_dr": "CR", "transaction_type": "income", "amount": 1000.0},
    ])

    spending = service._is_spending_transaction(df)
    assert spending["amount"].tolist() == [100.0]


def test_merchant_normalizer():
    normalizer = MerchantNormalizer()
    
    # Layer 2: Alias match
    display, key, cat, conf = normalizer.normalize("UPI/3249820192/SWIGGY/ORDER")
    assert display == "Swiggy"
    assert cat == "Food"
    assert conf >= 0.90

    # Uber
    display, key, cat, conf = normalizer.normalize("UPI/987231/UBER INDIA")
    assert display == "Uber"
    assert cat == "Travel"

    # Netflix
    display, key, cat, conf = normalizer.normalize("UPI-NETFLIX-MTHLY")
    assert display == "Netflix"
    assert cat == "Entertainment"

def test_hybrid_categorizer():
    normalizer = MerchantNormalizer()
    model_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "ml", "models", "expense_classifier.joblib")
    )
    classifier = ExpenseClassifier.load(model_path) if os.path.exists(model_path) else None
    hybrid = HybridCategorizer(classifier=classifier, normalizer=normalizer)

    result = hybrid.categorize_transaction("UPI/3249820192/SWIGGY/ORDER123")
    assert result["category"] == "Food"
    assert result["needs_review"] is False
    assert result["confidence"] >= 0.85

    # Salary Rule Override
    sal_result = hybrid.categorize_transaction("SALARY CREDIT FOR MONTH OF JAN")
    assert sal_result["category"] == "Income"
    assert sal_result["needs_review"] is False

    # Low Confidence / Uncertain Classification
    unc_result = hybrid.categorize_transaction("XYZRANDOMUNKNOWN_TRANSACTION_987654")
    assert unc_result["needs_review"] is True
    assert unc_result["category"] == "Uncategorized"

def test_auth_and_user_flow():
    # Test Guest Login
    guest_res = client.post("/auth/guest")
    assert guest_res.status_code == 200
    token = guest_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Test /auth/me
    me_res = client.get("/auth/me", headers=headers)
    assert me_res.status_code == 200
    assert me_res.json()["is_guest"] is True

def test_sample_statement_seeding_and_analytics():
    # Register/Get token
    guest_res = client.post("/auth/guest")
    token = guest_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Seed Sample 6-Month HDFC Statement
    seed_res = client.post("/statements/seed-sample?bank=HDFC%20Bank", headers=headers)
    assert seed_res.status_code == 200
    stmt = seed_res.json()
    assert stmt["processing_status"] == "completed"
    assert stmt["bank_name"] == "HDFC Bank"
    assert stmt["total_transactions"] > 50

    # Verify Transactions API
    txns_res = client.get("/transactions", headers=headers)
    assert txns_res.status_code == 200
    txns = txns_res.json()
    assert len(txns) > 50

    # Verify Analytics Summary API
    summary_res = client.get("/analytics/summary", headers=headers)
    assert summary_res.status_code == 200
    summary = summary_res.json()
    assert summary["bank_name"] == "HDFC Bank"
    assert summary["total_expense"] > 0
    assert summary["total_income"] > 0
    assert len(summary["categories_breakdown"]) > 0
    assert len(summary["top_merchants"]) > 0

    # Verify Monthly Spending API
    monthly_res = client.get("/analytics/monthly", headers=headers)
    assert monthly_res.status_code == 200
    assert len(monthly_res.json()) >= 3

    # Verify Forecast API
    forecast_res = client.get("/forecast", headers=headers)
    assert forecast_res.status_code == 200
    fc = forecast_res.json()
    assert fc["total_forecast"] > 0
    assert "Food" in fc["category_forecasts"] or len(fc["category_forecasts"]) > 0

    # Verify Model Status and Metrics APIs
    model_status_res = client.get("/model/status")
    assert model_status_res.status_code == 200
    metrics_res = client.get("/model/metrics")
    assert metrics_res.status_code == 200
    assert metrics_res.json()["accuracy"] > 0.90

    # Verify Model Compare API
    compare_res = client.get("/model/compare")
    assert compare_res.status_code == 200
    assert "comparison_table" in compare_res.json()

    # Verify Decoupled Model Retrain API
    retrain_res = client.post("/model/retrain")
    assert retrain_res.status_code == 200
    assert retrain_res.json()["status"] == "success"

    # Verify Statement Deletion API
    del_res = client.delete(f"/statements/{stmt['id']}", headers=headers)
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "success"

    # Verify statement no longer exists
    stmts_list_res = client.get("/statements", headers=headers)
    assert stmts_list_res.status_code == 200
    assert len(stmts_list_res.json()) == 0

    # Verify transactions were cascade deleted (zero residue)
    txns_after_del = client.get("/transactions", headers=headers)
    assert txns_after_del.status_code == 200
    assert len(txns_after_del.json()) == 0

    # Verify analytics summary is cleanly reset
    summary_after_del = client.get("/analytics/summary", headers=headers).json()
    assert summary_after_del["total_expense"] == 0.0
    assert summary_after_del["total_income"] == 0.0
    assert summary_after_del["total_transactions_count"] == 0
    assert len(summary_after_del["categories_breakdown"]) == 0

    # Verify forecast is cleanly reset (zero residue)
    forecast_after_del = client.get("/forecast", headers=headers).json()
    assert forecast_after_del["total_forecast"] == 0.0
    assert forecast_after_del["status"] == "insufficient_data"
    assert len(forecast_after_del["category_forecasts"]) == 0


def test_env_model_path_and_processor():
    from backend.app.services.statement_processor import StatementProcessor
    from backend.app.database.session import SessionLocal

    db = SessionLocal()
    try:
        # Test loading processor with default or env path
        processor = StatementProcessor(db=db)
        assert processor.hybrid_categorizer is not None
        assert processor.normalizer is not None
    finally:
        db.close()

def test_multiline_block_parsing():
    from backend.app.services.transaction_parser import TransactionParser
    parser = TransactionParser()

    multiline_text = """
    Statement for A/c XXXXXXXX6956 for the period 04-Aug-2026 to 03-Sep-2026
    Date Particulars Deposits Withdrawals Balance
    02-08-2026
    UPI/DR/658034336497/KALABH
    AVA/YESB/**05343@YBL/UPI//I
    CI1955406B7B0949C3A051D17
    238AF8DC5/02/08/2026 22:23:16
    Chq: 658034336497
    240.00
    1,909.10
    03-08-2026
    UPI/CR/658142397157/LEKSHM
    Y
    S/CNRB/**07775@SUPERYES/
    PAID
    VIA//SMY250319065087XLAPM
    H3E7VYTBMIWXVXM/03/08/202
    6 15:36:03
    Chq: 658142397157
    136.00
    2,045.10
    """

    txns = parser.parse_from_blocks(multiline_text)
    assert len(txns) == 2
    assert txns[0]["date"] == "2026-08-02"
    assert txns[0]["amount"] == 240.00
    assert txns[0]["cr_dr"] == "DR"
    assert txns[0]["balance"] == 1909.10
    assert txns[0]["reference_number"] == "658034336497"

    assert txns[1]["date"] == "2026-08-03"
    assert txns[1]["amount"] == 136.00
    assert txns[1]["cr_dr"] == "CR"
    assert txns[1]["balance"] == 2045.10
    assert txns[1]["reference_number"] == "658142397157"

