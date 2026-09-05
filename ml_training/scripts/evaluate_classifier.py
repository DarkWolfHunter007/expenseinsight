import json
import os
import sys

# Ensure UTF-8 stdout on Windows console
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Add project root and ml_training to sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from backend.ml.categorization.classifier import ExpenseClassifier
from backend.ml.categorization.hybrid_categorizer import HybridCategorizer
from backend.ml.preprocessing.merchant_normalizer import MerchantNormalizer
from ml_training.evaluation.metrics import evaluate_classification_model

def run_evaluation():
    print("=" * 60)
    print("ExpenseInsight Classifier In-Depth Evaluation")
    print("=" * 60)

    model_path = os.getenv(
        "MODEL_PATH",
        os.path.join(PROJECT_ROOT, "backend", "ml", "models", "expense_classifier.joblib")
    )
    if not os.path.exists(model_path):
        print("Model file not found. Running training first...")
        from ml_training.scripts.train_classifier import train_and_evaluate
        train_and_evaluate()

    classifier = ExpenseClassifier.load(model_path)
    normalizer = MerchantNormalizer()
    hybrid = HybridCategorizer(classifier=classifier, normalizer=normalizer)

    # Test edge cases and unseen merchants (PRD Section 42)
    test_cases = [
        # Known merchants with complex noise
        ("UPI/3249820192/SWIGGY/ORDER123", "Food"),
        ("POS 48392 AMAZON SELLER BANGALORE", "Shopping"),
        ("UPI/987231/UBER INDIA/RIDE", "Travel"),
        ("NEFT/ABC ELECTRICITY LTD/98732", "Bills"),
        ("UPI-NETFLIX-MTHLY-RECURRING", "Entertainment"),
        ("POS/DMART READY/MUMBAI/0984", "Groceries"),
        ("UPI/APOLLO PHARMACY/MEDICINE", "Healthcare"),
        ("POS INDIAN OIL CORP PUMP 21", "Fuel"),
        ("NOBROKER TECHNOLOGIES RENT PAYMENT", "Rent"),
        ("SALARY CREDIT FOR JAN 2026", "Income"),
        ("ATM CASH WDL HDFC BANK", "Cash Withdrawal"),
        
        # Unseen / variations of merchants
        ("UPI/3948210928/BURGER KING CONNAUGHT/PAY", "Food"),
        ("POS/DECATHLON SPORTS ANAND NAGAR", "Shopping"),
        ("RAPIDO BIKE TAXI HYDERABAD", "Travel"),
        ("BESCOM BANGALORE ELECTRICITY ONLINE", "Bills"),
        ("ZEPTO 10 MIN GROCERY ORDER", "Groceries"),
        ("TATA 1MG HEALTHCARE PHARMACY", "Healthcare"),
    ]

    print("\nEvaluating Individual Test Cases:")
    print("-" * 60)
    correct_count = 0
    for raw_desc, expected_cat in test_cases:
        res = hybrid.categorize_transaction(raw_desc)
        is_correct = (res["category"].lower() == expected_cat.lower())
        if is_correct:
            correct_count += 1
            status = "✓ PASS"
        else:
            status = "✗ FAIL"

        print(f"{status} | Input: {raw_desc}")
        print(f"       Normalized: '{res['merchant']}' | Pred: {res['category']} ({res['confidence_percentage']}) | Expected: {expected_cat}")
        print(f"       Source: {res['source']} | Needs Review: {res['needs_review']}")
        print()

    accuracy = (correct_count / len(test_cases)) * 100
    print("-" * 60)
    print(f"Edge Case Test Accuracy: {accuracy:.1f}% ({correct_count}/{len(test_cases)})")
    print("=" * 60)

if __name__ == "__main__":
    run_evaluation()
