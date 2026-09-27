#!/usr/bin/env python3
"""
ExpenseInsight - Standalone ML Training Runner
Can be executed anywhere (standalone folder, Google Colab, Kaggle, remote server)
Supports synthetic transactions + real multi-bank statement PDF extraction (Canara, GPay, HDFC, SBI, ICICI).
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Optional

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

import pandas as pd
from datasets.synthetic_generator import generate_synthetic_transactions, split_dataset
from datasets.pdf_dataset_loader import extract_transactions_from_pdf_dir
from evaluation.metrics import evaluate_classification_model
from models.classifier import ExpenseClassifier
from models.merchant_normalizer import MerchantNormalizer
from models.hybrid_categorizer import HybridCategorizer


def run_training(
    dataset_csv: Optional[str] = None,
    pdf_dir: Optional[str] = None,
    output_dir: Optional[str] = None,
    evaluate_edge_cases: bool = True,
    synthetic_count: int = 10000
):
    print("=" * 70)
    print("🚀 ExpenseInsight ML Model Training Pipeline")
    print("=" * 70)

    # 1. Dataset Loading / Synthesis + PDF Ingestion
    pdf_dir_path = Path(pdf_dir) if pdf_dir else CURRENT_DIR / "pdfs"
    pdf_df = pd.DataFrame()

    if pdf_dir_path.exists():
        print(f"[1/4] Ingesting & labeling real bank statement PDFs from: {pdf_dir_path} ...")
        pdf_df = extract_transactions_from_pdf_dir(str(pdf_dir_path))
        if not pdf_df.empty:
            print(f"      -> Extracted {len(pdf_df)} real-world transactions across {pdf_df['category'].nunique()} categories from {pdf_df['source_pdf'].nunique()} PDF statements.")
            # Persist extracted PDF dataset
            pdf_out_csv = CURRENT_DIR / "datasets" / "pdf_transactions.csv"
            pdf_df.to_csv(pdf_out_csv, index=False)
            print(f"      -> Saved extracted PDF dataset to: {pdf_out_csv}")
        else:
            print("      -> No PDF files found or 0 transactions extracted from PDF directory.")

    if dataset_csv and os.path.exists(dataset_csv):
        print(f"[1/4] Loading custom dataset from: {dataset_csv}")
        if dataset_csv.endswith(".csv"):
            custom_df = pd.read_csv(dataset_csv)
        elif dataset_csv.endswith(".json"):
            custom_df = pd.read_json(dataset_csv)
        else:
            raise ValueError("Supported dataset formats: .csv, .json")
        
        if "raw_description" not in custom_df.columns or "category" not in custom_df.columns:
            raise ValueError("Dataset must contain 'raw_description' and 'category' columns.")
        
        if not pdf_df.empty:
            df = pd.concat([custom_df, pdf_df], ignore_index=True)
            print(f"Combined custom dataset ({len(custom_df)}) + PDF dataset ({len(pdf_df)}) = {len(df)} total records.")
        else:
            df = custom_df
            print(f"Loaded {len(df)} records across {df['category'].nunique()} categories.")
    else:
        print(f"[1/4] Synthesizing {synthetic_count} transactions with multi-bank noise patterns...")
        synth_df = generate_synthetic_transactions(num_records=synthetic_count)
        
        if not pdf_df.empty:
            df = pd.concat([synth_df, pdf_df], ignore_index=True)
            print(f"Combined synthetic dataset ({len(synth_df)}) + real PDF dataset ({len(pdf_df)}) = {len(df)} total records.")
        else:
            df = synth_df
            print(f"Total dataset: {len(df)} synthetic records.")

    # Save combined dataset for transparency
    combined_out_csv = CURRENT_DIR / "datasets" / "combined_training_dataset.csv"
    df.to_csv(combined_out_csv, index=False)

    train_df, val_df, test_df = split_dataset(df, train_ratio=0.70, val_ratio=0.15, test_ratio=0.15)
    print(f"Dataset split: Train={len(train_df)}, Val={len(val_df)}, Test={len(test_df)}")

    # 2. Output directory resolution
    if output_dir is None:
        backend_models = REPO_ROOT / "backend" / "ml" / "models"
        if backend_models.exists():
            output_dir = str(backend_models)
        else:
            output_dir = str(CURRENT_DIR / "output")
    
    os.makedirs(output_dir, exist_ok=True)
    model_path = os.path.join(output_dir, "expense_classifier.joblib")
    metrics_path = os.path.join(output_dir, "model_metrics.json")
    normalizer = MerchantNormalizer()

    # 3. Model Architecture Training (Production: TF-IDF + Calibrated LinearSVC - SVM)
    print("\n[2/4] Training Production Model (TF-IDF + Calibrated LinearSVC - SVM)...")
    best_model_name = "TF-IDF + Calibrated LinearSVC (SVM)"
    best_classifier = ExpenseClassifier(model_type="linear_svc")
    best_classifier.fit(train_df["raw_description"].tolist(), train_df["category"].tolist(), normalizer)

    val_probs = best_classifier.predict_proba(val_df["raw_description"].tolist(), normalizer)
    val_preds = [best_classifier.classes_[idx] for idx in val_probs.argmax(axis=1)]
    val_metrics = evaluate_classification_model(val_df["category"].tolist(), val_preds, list(best_classifier.classes_))
    print(f"      Validation Accuracy: {val_metrics['accuracy_percentage']}, Macro F1: {val_metrics['macro_f1']:.4f}")

    # 4. Final Evaluation on Holdout Test Set
    print("\n[3/4] Evaluating on Holdout Test Split (15%)...")
    test_probs = best_classifier.predict_proba(test_df["raw_description"].tolist(), normalizer)
    test_preds = [best_classifier.classes_[idx] for idx in test_probs.argmax(axis=1)]
    final_metrics = evaluate_classification_model(test_df["category"].tolist(), test_preds, list(best_classifier.classes_))

    print(f"  Holdout Test Accuracy:  {final_metrics['accuracy_percentage']}")
    print(f"  Holdout Macro F1 Score: {final_metrics['macro_f1']:.4f}")
    print(f"  Holdout Weighted F1:    {final_metrics['weighted_f1']:.4f}")

    # If PDF transactions were extracted, evaluate holdout on real PDF subset specifically
    pdf_eval_metrics = None
    if not pdf_df.empty:
        pdf_test_subset = test_df[test_df["source_pdf"].notna()] if "source_pdf" in test_df.columns else pd.DataFrame()
        if not pdf_test_subset.empty:
            pdf_probs = best_classifier.predict_proba(pdf_test_subset["raw_description"].tolist(), normalizer)
            pdf_preds = [best_classifier.classes_[idx] for idx in pdf_probs.argmax(axis=1)]
            pdf_eval_metrics = evaluate_classification_model(pdf_test_subset["category"].tolist(), pdf_preds, list(best_classifier.classes_))
            print(f"  Real PDF Test Accuracy: {pdf_eval_metrics['accuracy_percentage']} ({len(pdf_test_subset)} real holdout samples)")

    # 5. Save Artifacts
    best_classifier.save(model_path)
    print(f"\n[4/4] Saved trained model weights to: {model_path}")

    # Also save copy in local output/ dir
    local_output = os.path.join(CURRENT_DIR, "output")
    os.makedirs(local_output, exist_ok=True)
    if os.path.abspath(output_dir) != os.path.abspath(local_output):
        best_classifier.save(os.path.join(local_output, "expense_classifier.joblib"))

    metadata = {
        "model_name": best_model_name,
        "algorithm": "Support Vector Machine (Calibrated LinearSVC) with N-Gram Text Features",
        "version": "1.1.0",
        "sample_count": len(df),
        "synthetic_samples": len(df) - len(pdf_df),
        "real_pdf_samples": len(pdf_df),
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
        "real_pdf_test_metrics": {
            "accuracy": pdf_eval_metrics["accuracy"] if pdf_eval_metrics else None,
            "accuracy_percentage": pdf_eval_metrics["accuracy_percentage"] if pdf_eval_metrics else None,
            "macro_f1": pdf_eval_metrics["macro_f1"] if pdf_eval_metrics else None,
            "sample_count": len(pdf_test_subset) if not pdf_df.empty and not pdf_test_subset.empty else 0
        },
        "classes": final_metrics["classes"],
        "confusion_matrix": final_metrics["confusion_matrix"]
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
            ("SALARY CREDIT FOR JAN 2026", "Income"),
            ("Paid to MAR BASELIOS COLLEGE OF ENGINEER via GPay", "Education"),
            ("UPI/DR/624320672397/KERALA ST/YESB/**DQR01@YBL/PAYMENT", "Bills"),
            ("UPI/DR/533158928527/CHOCO BAE/FDRL/**BAE01@FBPE/PAY", "Food")
        ]
        passed = 0
        for desc, expected in sample_tests:
            res = hybrid.categorize_transaction(desc)
            ok = res["category"].lower() == expected.lower()
            if ok:
                passed += 1
            mark = "✓" if ok else "✗"
            print(f"  {mark} {desc[:42]:<42} -> {res['category']} ({res['confidence_percentage']})")
        print(f"Edge case check: {passed}/{len(sample_tests)} passed.")

    print("\n" + "=" * 70)
    print("🎉 Training Complete!")
    print(f"Artifacts ready in: {output_dir}")
    print("=" * 70)
    return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ExpenseInsight ML Training")
    parser.add_argument("--dataset", type=str, default=None, help="Path to custom CSV or JSON dataset")
    parser.add_argument("--pdf-dir", type=str, default=None, help="Directory containing bank statement PDFs")
    parser.add_argument("--output-dir", type=str, default=None, help="Output directory for model artifacts")
    parser.add_argument("--no-eval", action="store_true", help="Skip edge-case sanity check")
    parser.add_argument("--synthetic-count", type=int, default=10000, help="Number of synthetic records to generate")
    
    args = parser.parse_args()
    run_training(
        dataset_csv=args.dataset,
        pdf_dir=args.pdf_dir,
        output_dir=args.output_dir,
        evaluate_edge_cases=not args.no_eval,
        synthetic_count=args.synthetic_count
    )
