# ExpenseInsight — Standalone ML Training Package 🧪

This folder is **100% self-contained**. You can zip this entire `ml_training` directory, send it to a teammate/friend, or upload it to Google Colab/Kaggle, and run training without needing the rest of the repository.

---

## 🏛️ Architecture & Proposed Methodology

```text
[PDF Bank Statement] 
         │
         ▼ (1. PyMuPDF Extraction)
[Raw Text & Tables]
         │
         ▼ (2. Transaction Parser)
[Structured Transactions: Date, Description, Amount, Type]
         │
         ▼ (3. RapidFuzz Merchant Normalization)
[Clean Merchant Token & Aliases]
         │
         ▼ (4. ML Classification Engine)
   ┌─────────────────────────────────────────────────────────┐
   │ Text Embedding: (all-MiniLM-L6-v2 / TF-IDF N-Grams)     │
   │ SVM Classifier: (Calibrated LinearSVC / SVM Probabilities)│
   └─────────────────────────────────────────────────────────┘
         │
         ▼
[Category + Calibrated Confidence Score]
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
(5. Spending Analytics)     (6. ARIMA Time-Series Forecasting)
```

---

## 📁 Package Contents

```text
ml_training/
│
├── train.py                     # ⚡ 1-Click Standalone Training Entrypoint
├── requirements-training.txt    # Python dependencies for training
├── requirements.txt             # Pip dependencies
├── README.md                    # This guide
│
├── datasets/
│   ├── synthetic_generator.py   # Synthesizes 10,000+ realistic multi-bank transactions
│   └── sample_transactions.json # Sample test records
│
├── models/                      # Self-contained model architecture & normalizer definitions
│   ├── classifier.py            # Sentence-Transformers / TF-IDF + Calibrated LinearSVC (SVM)
│   ├── hybrid_categorizer.py    # Hybrid categorization engine & confidence thresholding
│   ├── merchant_normalizer.py   # 4-layer merchant normalizer & alias knowledge base
│   ├── text_cleaner.py          # Banking description text cleaner
│   └── forecaster.py            # ARIMA time-series forecaster
│
├── evaluation/
│   └── metrics.py               # Confusion matrix, macro/weighted F1, accuracy, MAPE
│
└── scripts/
    ├── train_classifier.py      # Production training runner
    ├── evaluate_classifier.py   # Edge case test evaluation
    ├── evaluate_forecaster.py   # ARIMA forecasting evaluation & backtesting
    └── generate_sample_statements.py # PyMuPDF / ReportLab bank statement generator
```

---

## 🚀 How to Run Training

### Step 1: Install Dependencies
```bash
pip install -r requirements.txt
```

### Step 2: Run Training (Default: 10,000 Synthetic + Real Statement PDFs)
```bash
python train.py
```

### Step 3: (Optional) Train with a Custom Dataset (CSV / JSON)
If you have real bank transaction data:
```bash
python train.py --dataset path/to/real_transactions.csv
```
> **CSV Format Requirements**: The CSV file should have at least:
> - `raw_description`: Raw bank statement transaction text (e.g. `UPI/3249820192/SWIGGY/ORDER`)
> - `category`: Ground truth category label (e.g. `Food`, `Travel`, `Shopping`)

---

## 📦 What Artifacts Are Produced?

After training completes, it outputs:
1. `output/expense_classifier.joblib`: The trained SVM model weights.
2. `output/model_metrics.json`: Accuracy, F1 score, and confusion matrix.

---

## 🔌 Decoupled Docker Deployment: How the Model Plugs into Docker

Only the serialized model weights are required by the Docker container:
```bash
# Copy trained weights to the backend models directory
cp output/expense_classifier.joblib ../backend/ml/models/
cp output/model_metrics.json ../backend/ml/models/
```
The Docker container will automatically pick up the new model via the `./backend/ml/models` volume mount **without needing any container rebuild**!

