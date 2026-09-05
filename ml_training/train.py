#!/usr/bin/env python3
"""
ExpenseInsight - Standalone ML Training Runner
Can be executed anywhere (standalone folder, Google Colab, Kaggle, remote server)
"""

import argparse
import json
import os
import sys
from pathlib import Path

# Ensure UTF-8 console output
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Add current folder to sys.path so it works standalone
CURRENT_DIR = Path(__file__).resolve().parent
if str(CURRENT_DIR) not in sys.path:
    sys.path.insert(0, str(CURRENT_DIR))

# Also check for parent repo if present
REPO_ROOT = CURRENT_DIR.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from datasets.synthetic_generator import generate_synthetic_transactions, split_dataset
from evaluation.metrics import evaluate_classification_model
from models.classifier import ExpenseClassifier
from models.merchant_normalizer import MerchantNormalizer
from models.hybrid_categorizer import HybridCategorizer

def run_training(
    dataset_csv: str = None,
    output_dir: str = None,
    compare_all: bool = True,
    evaluate_edge_cases: bool = True
):
    print("=" * 70)
    print("🚀 ExpenseInsight ML Model Training Pipeline (Standalone)")
    print("=" * 70)

    # 1. Dataset Loading / Synthesis
    if dataset_csv and os.path.exists(dataset_csv):
        import pandas as pd
        print(f"[1/5] Loading custom dataset from: {dataset_csv}")
        if dataset_csv.endswith(".csv"):
            df = pd.read_csv(dataset_csv)
        elif dataset_csv.endswith(".json"):
            df = pd.read_json(dataset_csv)
        else:
            raise ValueError("Supported dataset formats: .csv, .json")
        
        # Verify required columns
        if "raw_description" not in df.columns or "category" not in df.columns:
            raise ValueError("Dataset must contain 'raw_description' and 'category' columns.")
        print(f"Loaded {len(df)} records across {df['category'].nunique()} categories.")
    else:
        print("[1/5] Generating 10,000 realistic bank transactions with Indian banking noise...")
        df = generate_synthetic_transactions(num_records=10000)

    train_df, val_df, test_df = split_dataset(df, train_ratio=0.70, val_ratio=0.15, test_ratio=0.15)
    print(f"Dataset split: Train={len(train_df)}, Val={len(val_df)}, Test={len(test_df)}")

    # 2. Output directory resolution
    if output_dir is None:
        # If running inside full repository, default to backend/ml/models
        backend_models = REPO_ROOT / "backend" / "ml" / "models"
        if backend_models.exists():
            output_dir = str(backend_models)
        else:
            output_dir = str(CURRENT_DIR / "output")
    
    os.makedirs(output_dir, exist_ok=True)
    model_path = os.path.join(output_dir, "expense_classifier.joblib")
    metrics_path = os.path.join(output_dir, "model_metrics.json")
    normalizer = MerchantNormalizer()

    # 3. Model Architecture Training & Benchmarking
    comparison_results = {}
    if compare_all:
        print("\n[2/5] Training and benchmarking candidate architectures...")
        models = {
            "TF-IDF + Calibrated LinearSVC (SVM)": ExpenseClassifier(model_type="linear_svc"),
            "TF-IDF + Logistic Regression": ExpenseClassifier(model_type="logistic_regression"),
            "TF-IDF + Random Forest": ExpenseClassifier(model_type="random_forest")
        }

        # Check if sentence-transformers is available for optional deep embedding candidate
        try:
            import sentence_transformers
            models["Sentence-Transformers (all-MiniLM-L6-v2) + SVM"] = ExpenseClassifier(
                model_type="linear_svc",
                embedding_type="sentence_transformers"
            )
        except ImportError:
            pass

        best_model_name = "TF-IDF + Calibrated LinearSVC (SVM)"
        best_f1 = 0.0
        best_classifier = None

        for name, clf in models.items():
            print(f"  --> Training {name}...")
            clf.fit(train_df["raw_description"].tolist(), train_df["category"].tolist(), normalizer)
            
            val_probs = clf.predict_proba(val_df["raw_description"].tolist(), normalizer)
            val_preds = [clf.classes_[idx] for idx in val_probs.argmax(axis=1)]
            
            metrics = evaluate_classification_model(val_df["category"].tolist(), val_preds, list(clf.classes_))
            comparison_results[name] = {
                "accuracy": metrics["accuracy"],
                "accuracy_percentage": metrics["accuracy_percentage"],
                "macro_f1": metrics["macro_f1"],
                "weighted_f1": metrics["weighted_f1"],
                "macro_precision": metrics["macro_precision"],
                "macro_recall": metrics["macro_recall"]
            }
            print(f"      Validation Accuracy: {metrics['accuracy_percentage']}, Macro F1: {metrics['macro_f1']:.4f}")

            if metrics["macro_f1"] > best_f1:
                best_f1 = metrics["macro_f1"]
                best_model_name = name
                best_classifier = clf
    else:
        print("\n[2/5] Training production architecture (TF-IDF + Calibrated LinearSVC - SVM)...")
        best_model_name = "TF-IDF + Calibrated LinearSVC (SVM)"
        best_classifier = ExpenseClassifier(model_type="linear_svc")
        best_classifier.fit(train_df["raw_description"].tolist(), train_df["category"].tolist(), normalizer)

    print(f"\n[3/5] Selected Production Model: '{best_model_name}'")

    # 4. Final Evaluation on Holdout Test Set
    print("\n[4/5] Evaluating on Holdout Test Split (15%)...")
    test_probs = best_classifier.predict_proba(test_df["raw_description"].tolist(), normalizer)
    test_preds = [best_classifier.classes_[idx] for idx in test_probs.argmax(axis=1)]
    final_metrics = evaluate_classification_model(test_df["category"].tolist(), test_preds, list(best_classifier.classes_))

    print(f"  Holdout Test Accuracy:  {final_metrics['accuracy_percentage']}")
    print(f"  Holdout Macro F1 Score: {final_metrics['macro_f1']:.4f}")
    print(f"  Holdout Weighted F1:    {final_metrics['weighted_f1']:.4f}")

    # 5. Save Artifacts
    best_classifier.save(model_path)
    print(f"\n[5/5] Saved trained model weights to: {model_path}")

    # Also save copy in local output/ dir
    local_output = os.path.join(CURRENT_DIR, "output")
    os.makedirs(local_output, exist_ok=True)
    if os.path.abspath(output_dir) != os.path.abspath(local_output):
        best_classifier.save(os.path.join(local_output, "expense_classifier.joblib"))

    metadata = {
        "model_name": best_model_name,
        "algorithm": "Support Vector Machine (Calibrated LinearSVC) with N-Gram Text Features",
        "version": "1.0.0",
        "sample_count": len(df),
        "train_samples": len(train_df),
        "test_samples": len(test_df),
        "test_metrics": {
            "accuracy": final_metrics["accuracy"],
            "accuracy_percentage": final_metrics["accuracy_percentage"],
            "macro_f1": final_metrics["macro_f1"],
            "weighted_f1": final_metrics["weighted_f1"],
            "macro_precision": final_metrics["macro_precision"],
            "macro_recall": final_metrics["macro_recall"]
        },
        "classes": final_metrics["classes"],
        "confusion_matrix": final_metrics["confusion_matrix"],
        "comparison_experiment": comparison_results
    }
    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)
    print(f"Saved model metrics metadata to: {metrics_path}")

    if os.path.abspath(output_dir) != os.path.abspath(local_output):
        with open(os.path.join(local_output, "model_metrics.json"), "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2)


    # Save sample test records
    sample_out = os.path.join(CURRENT_DIR, "datasets", "sample_transactions.json")
    test_df.head(200).to_json(sample_out, orient="records", indent=2)

    # 6. Optional Edge Case Check
    if evaluate_edge_cases:
        print("\n" + "-" * 70)
        print("Running Quick Edge-Case Sanity Check:")
        hybrid = HybridCategorizer(classifier=best_classifier, normalizer=normalizer)
        sample_tests = [
            ("UPI/3249820192/SWIGGY/ORDER123", "Food"),
            ("POS 48392 AMAZON SELLER BANGALORE", "Shopping"),
            ("UPI/987231/UBER INDIA/RIDE", "Travel"),
            ("NEFT/ABC ELECTRICITY LTD/98732", "Bills"),
            ("UPI-NETFLIX-MTHLY-RECURRING", "Entertainment"),
            ("POS/DMART READY/MUMBAI/0984", "Groceries"),
            ("UPI/APOLLO PHARMACY/MEDICINE", "Healthcare"),
            ("SALARY CREDIT FOR JAN 2026", "Income")
        ]
        passed = 0
        for desc, expected in sample_tests:
            res = hybrid.categorize_transaction(desc)
            ok = res["category"].lower() == expected.lower()
            if ok:
                passed += 1
            mark = "✓" if ok else "✗"
            print(f"  {mark} {desc[:35]:<35} -> {res['category']} ({res['confidence_percentage']})")
        print(f"Edge case check: {passed}/{len(sample_tests)} passed.")

    print("\n" + "=" * 70)
    print("🎉 Training Complete!")
    print(f"Artifacts ready in: {output_dir}")
    print("=" * 70)
    return metadata

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ExpenseInsight ML Training")
    parser.add_argument("--dataset", type=str, default=None, help="Path to custom CSV or JSON dataset")
    parser.add_argument("--output-dir", type=str, default=None, help="Output directory for model artifacts")
    parser.add_argument("--no-compare", action="store_true", help="Skip candidate architecture comparison (faster)")
    parser.add_argument("--no-eval", action="store_true", help="Skip edge-case sanity check")
    
    args = parser.parse_args()
    run_training(
        dataset_csv=args.dataset,
        output_dir=args.output_dir,
        compare_all=not args.no_compare,
        evaluate_edge_cases=not args.no_eval
    )
