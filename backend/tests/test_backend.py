import json
import os
import sys
import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from backend.app.main import app
from ml.preprocessing.merchant_normalizer import MerchantNormalizer
from ml.preprocessing.text_cleaner import TextCleaner
from ml.categorization.classifier import ExpenseClassifier
from ml.categorization.hybrid_categorizer import HybridCategorizer

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
        os.path.join(os.path.dirname(__file__), "..", "..", "ml", "models", "expense_classifier.joblib")
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
