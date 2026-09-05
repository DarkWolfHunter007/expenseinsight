import json
import os
import sys

# Add project root and ml_training to sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from ml_training.datasets.synthetic_generator import generate_synthetic_transactions, split_dataset
from ml_training.evaluation.metrics import evaluate_classification_model
from backend.ml.categorization.classifier import ExpenseClassifier
from backend.ml.preprocessing.merchant_normalizer import MerchantNormalizer

def train_and_evaluate(compare_all: bool = True, output_dir: str = None):
    print("=" * 60)
    print("ExpenseInsight ML Model Training Pipeline")
    print("=" * 60)

    # 1. Generate synthetic dataset
    print("[1/5] Generating 10,000 realistic bank transactions...")
    df = generate_synthetic_transactions(num_records=10000)
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
    
    # Load existing comparisons if available
    comparison_results = {}
    if os.path.exists(metrics_path):
        try:
            with open(metrics_path, "r", encoding="utf-8") as f:
                existing_meta = json.load(f)
                comparison_results = existing_meta.get("comparison_experiment", {})
        except Exception:
            pass

    if compare_all:
        models = {
            "TF-IDF + Calibrated LinearSVC (SVM)": ExpenseClassifier(model_type="linear_svc"),
            "TF-IDF + Logistic Regression": ExpenseClassifier(model_type="logistic_regression"),
            "TF-IDF + Random Forest": ExpenseClassifier(model_type="random_forest")
        }

        # Check for sentence-transformers
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

        # 3. Train and compare models
        print("\n[2/5] Training and comparing candidate model architectures...")
        for name, clf in models.items():
            print(f"  --> Training {name}...")
            clf.fit(train_df["raw_description"].tolist(), train_df["category"].tolist(), normalizer)
            
            # Predict on validation set
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
        # Fast retraining of production model in ~1.5s
        print("\n[2/5] Retraining production architecture (TF-IDF + Calibrated LinearSVC - SVM)...")
        best_model_name = "TF-IDF + Calibrated LinearSVC (SVM)"
        best_classifier = ExpenseClassifier(model_type="linear_svc")
        best_classifier.fit(train_df["raw_description"].tolist(), train_df["category"].tolist(), normalizer)

    print(f"\n[3/5] Active model: '{best_model_name}'")

    # 4. Final Evaluation on Holdout Test Set
    print("\n[4/5] Evaluating selected model on Holdout Test Set (15%)...")
    test_probs = best_classifier.predict_proba(test_df["raw_description"].tolist(), normalizer)
    test_preds = [best_classifier.classes_[idx] for idx in test_probs.argmax(axis=1)]
    final_test_metrics = evaluate_classification_model(test_df["category"].tolist(), test_preds, list(best_classifier.classes_))

    print(f"  Holdout Test Accuracy: {final_test_metrics['accuracy_percentage']}")
    print(f"  Holdout Macro F1 Score: {final_test_metrics['macro_f1']:.4f}")
    print(f"  Holdout Weighted F1 Score: {final_test_metrics['weighted_f1']:.4f}")

    # 5. Save Model and Artifacts
    model_path = os.path.join(output_dir, "expense_classifier.joblib")
    best_classifier.save(model_path)
    print(f"\n[5/5] Saved model pipeline to: {model_path}")

    # Also save copy in local output/ dir
    local_output = os.path.join(PROJECT_ROOT, "ml_training", "output")
    os.makedirs(local_output, exist_ok=True)
    if os.path.abspath(output_dir) != os.path.abspath(local_output):
        best_classifier.save(os.path.join(local_output, "expense_classifier.joblib"))

    # Save metrics metadata
    metadata = {
        "model_name": best_model_name,
        "algorithm": "Support Vector Machine (Calibrated LinearSVC) with N-Gram Text Features",
        "version": "1.0.0",
        "sample_count": len(df),
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
        "classes": final_test_metrics["classes"],
        "confusion_matrix": final_test_metrics["confusion_matrix"],
        "comparison_experiment": comparison_results
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
    train_and_evaluate(compare_all=True)
