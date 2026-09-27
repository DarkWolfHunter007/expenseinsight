import json
import os
import sys
from pathlib import Path

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

from ml_training.datasets.synthetic_generator import generate_synthetic_transactions, split_dataset
from ml_training.datasets.pdf_dataset_loader import extract_transactions_from_pdf_dir
from ml_training.evaluation.metrics import evaluate_classification_model
from backend.ml.categorization.classifier import ExpenseClassifier
from backend.ml.preprocessing.merchant_normalizer import MerchantNormalizer
import pandas as pd


def train_and_evaluate(output_dir: str = None, synthetic_count: int = 10000):
    print("=" * 60)
    print("ExpenseInsight ML Model Training Pipeline")
    print("=" * 60)

    # 1. Ingest PDF statements if available
    pdf_dir = Path(PROJECT_ROOT) / "ml_training" / "pdfs"
    pdf_df = pd.DataFrame()
    if pdf_dir.exists():
        print(f"[1/4] Ingesting & labeling real bank statement PDFs from: {pdf_dir} ...")
        pdf_df = extract_transactions_from_pdf_dir(str(pdf_dir))
        if not pdf_df.empty:
            print(f"      -> Extracted {len(pdf_df)} real-world transactions from {pdf_df['source_pdf'].nunique()} PDFs.")

    print(f"[1/4] Generating {synthetic_count} realistic synthetic bank transactions...")
    synth_df = generate_synthetic_transactions(num_records=synthetic_count)

    if not pdf_df.empty:
        df = pd.concat([synth_df, pdf_df], ignore_index=True)
        print(f"Combined synthetic ({len(synth_df)}) + real PDF ({len(pdf_df)}) = {len(df)} total records.")
    else:
        df = synth_df

    train_df, val_df, test_df = split_dataset(df, train_ratio=0.70, val_ratio=0.15, test_ratio=0.15)
    print(f"Dataset split: Train={len(train_df)}, Val={len(val_df)}, Test={len(test_df)}")

    # 2. Initialize Normalizer and Model Paths
    normalizer = MerchantNormalizer()
    if output_dir is None:
        output_dir = os.getenv(
            "MODEL_OUTPUT_DIR",
            os.path.abspath(os.path.join(PROJECT_ROOT, "backend", "ml", "models"))
        )
    os.makedirs(output_dir, exist_ok=True)
    metrics_path = os.path.join(output_dir, "model_metrics.json")
    model_path = os.path.join(output_dir, "expense_classifier.joblib")

    # 3. Train Production Model (TF-IDF + Calibrated LinearSVC - SVM)
    print("\n[2/4] Training Production Model (TF-IDF + Calibrated LinearSVC - SVM)...")
    best_model_name = "TF-IDF + Calibrated LinearSVC (SVM)"
    best_classifier = ExpenseClassifier(model_type="linear_svc")
    best_classifier.fit(train_df["raw_description"].tolist(), train_df["category"].tolist(), normalizer)

    val_probs = best_classifier.predict_proba(val_df["raw_description"].tolist(), normalizer)
    val_preds = [best_classifier.classes_[idx] for idx in val_probs.argmax(axis=1)]
    val_metrics = evaluate_classification_model(val_df["category"].tolist(), val_preds, list(best_classifier.classes_))
    print(f"      Validation Accuracy: {val_metrics['accuracy_percentage']}, Macro F1: {val_metrics['macro_f1']:.4f}")

    # 4. Final Evaluation on Holdout Test Set
    print("\n[3/4] Evaluating selected model on Holdout Test Set (15%)...")
    test_probs = best_classifier.predict_proba(test_df["raw_description"].tolist(), normalizer)
    test_preds = [best_classifier.classes_[idx] for idx in test_probs.argmax(axis=1)]
    final_test_metrics = evaluate_classification_model(test_df["category"].tolist(), test_preds, list(best_classifier.classes_))

    print(f"  Holdout Test Accuracy:     {final_test_metrics['accuracy_percentage']}")
    print(f"  Holdout Macro F1 Score:    {final_test_metrics['macro_f1']:.4f}")
    print(f"  Holdout Weighted F1 Score: {final_test_metrics['weighted_f1']:.4f}")

    pdf_eval_metrics = None
    if not pdf_df.empty:
        pdf_test_subset = test_df[test_df["source_pdf"].notna()] if "source_pdf" in test_df.columns else pd.DataFrame()
        if not pdf_test_subset.empty:
            pdf_probs = best_classifier.predict_proba(pdf_test_subset["raw_description"].tolist(), normalizer)
            pdf_preds = [best_classifier.classes_[idx] for idx in pdf_probs.argmax(axis=1)]
            pdf_eval_metrics = evaluate_classification_model(pdf_test_subset["category"].tolist(), pdf_preds, list(best_classifier.classes_))
            print(f"  Real PDF Test Accuracy:    {pdf_eval_metrics['accuracy_percentage']} ({len(pdf_test_subset)} real holdout samples)")

    # 5. Save Model and Artifacts
    best_classifier.save(model_path)
    print(f"\n[4/4] Saved model pipeline to: {model_path}")

    # Also save copy in local output/ dir
    local_output = os.path.join(PROJECT_ROOT, "ml_training", "output")
    os.makedirs(local_output, exist_ok=True)
    if os.path.abspath(output_dir) != os.path.abspath(local_output):
        best_classifier.save(os.path.join(local_output, "expense_classifier.joblib"))

    # Save metrics metadata
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
            "accuracy": final_test_metrics["accuracy"],
            "accuracy_percentage": final_test_metrics["accuracy_percentage"],
            "macro_f1": final_test_metrics["macro_f1"],
            "weighted_f1": final_test_metrics["weighted_f1"],
            "macro_precision": final_test_metrics["macro_precision"],
            "macro_recall": final_test_metrics["macro_recall"]
        },
        "real_pdf_test_metrics": {
            "accuracy": pdf_eval_metrics["accuracy"] if pdf_eval_metrics else None,
            "accuracy_percentage": pdf_eval_metrics["accuracy_percentage"] if pdf_eval_metrics else None,
            "macro_f1": pdf_eval_metrics["macro_f1"] if pdf_eval_metrics else None,
            "sample_count": len(pdf_test_subset) if not pdf_df.empty and not pdf_test_subset.empty else 0
        },
        "classes": final_test_metrics["classes"],
        "confusion_matrix": final_test_metrics["confusion_matrix"]
    }
    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)
    print(f"Saved model metrics metadata to: {metrics_path}")

    if os.path.abspath(output_dir) != os.path.abspath(local_output):
        with open(os.path.join(local_output, "model_metrics.json"), "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2)

    # Save sample test dataset for reproducible tests
    dataset_path = os.path.join(PROJECT_ROOT, "ml_training", "datasets", "sample_transactions.json")
    test_df.head(200).to_json(dataset_path, orient="records", indent=2)

    print("\nTraining complete successfully!")
    return metadata


if __name__ == "__main__":
    train_and_evaluate()
