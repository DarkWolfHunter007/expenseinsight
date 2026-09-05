# ExpenseInsight 🚀

**ExpenseInsight** is an intelligent personal-finance application that automatically extracts, normalizes, categorizes, analyzes, and forecasts personal expenses from bank-statement PDFs (HDFC Bank, State Bank of India, ICICI Bank, Axis Bank, etc.).

---

## 🌟 Architecture & Key Features

```
Bank Statement PDF (Single or 6-Month Multi-Statement)
        ↓
[1] PDF Text Extraction & Tabular Parser (PyMuPDF fitz + pdfplumber)
        ↓
[2] Merchant Normalization Layer (4-Layer: Regex -> Alias Dictionary -> Fuzzy RapidFuzz -> User Feedback)
        ↓
[3] NLP Preprocessing & Feature Extraction (Sentence-Transformers all-MiniLM-L6-v2 / TF-IDF N-Grams)
        ↓
[4] Supervised ML Categorizer (Calibrated Support Vector Machine - LinearSVC)
        ↓
[5] Confidence & Uncertainty Evaluation (>=85% High, 60-84% Medium, <60% Low Review Deck)
        ↓
[6] "Help Me Categorize This" Active Learning Loop (Persistent Feedback Memory)
        ↓
[7] Spending Analytics Engine (Total, Monthly MoM Trends, Category Donut, Top Merchants, Subscriptions)
        ↓
[8] Time-Series Expense Forecasting (Statsmodels ARIMA + 90% Confidence Intervals)
        ↓
[9] Flutter Cross-Platform Dashboard (Mobile, Web, Desktop)

```

---

## 📁 Project Structure

```text
expenseinsight/
│
├── ExpenseInsight_PRD.md           # Product Requirements Document
├── README.md                       # Comprehensive Guide & Documentation
├── Dockerfile                      # Production Backend Container Image
├── docker-compose.yml              # Production Docker Compose Orchestration
│
├── backend/                        # 🚀 Production Backend & Inference Service
│   ├── app/
│   │   ├── api/
│   │   │   ├── endpoints/          # Auth, Statements, Transactions, Analytics, Forecast, Model
│   │   │   ├── deps.py             # JWT Token Auth & Guest Session Management
│   │   │   └── api.py              # Central Router
│   │   ├── database/               # SQLAlchemy ORM Session & Engine
│   │   ├── models/                 # DB Models (User, Statement, Transaction, Forecast, etc.) & Schemas
│   │   ├── services/               # PDF Extractor, Parser, Analytics, Forecaster, Pipeline
│   │   └── main.py                 # FastAPI Application Entrypoint
│   ├── ml/                         # Production Inference ML Modules & Model Weights
│   │   ├── categorization/         # ExpenseClassifier & HybridCategorizer
│   │   ├── forecasting/            # Holt-Winters Time-Series Forecaster
│   │   ├── preprocessing/          # 4-Layer Merchant Normalizer & Text Cleaner
│   │   └── models/                 # Serialized Model Artifacts (expense_classifier.joblib, model_metrics.json)
│   ├── sample_statements/          # Realistic 6-Month HDFC, SBI, ICICI bank statement PDFs
│   ├── tests/                      # Pytest Unit & Integration Tests (100% Passing)
│   └── requirements.txt            # Production Python Dependencies
│
├── ml_training/                    # 🧪 Decoupled Offline ML Training Pipeline
│   ├── datasets/                   # Synthetic Dataset Generator (10,000+ multi-bank records)
│   ├── evaluation/                 # Metrics Evaluator (Accuracy, Macro F1, Confusion Matrix, MAE/MAPE)
│   ├── scripts/
│   │   ├── train_classifier.py     # Trains ML models & exports weights to backend/ml/models/
│   │   ├── evaluate_classifier.py  # Runs in-depth edge-case and confusion matrix evaluation
│   │   ├── evaluate_forecaster.py  # Backtests forecasting models and computes MAE/MAPE
│   │   └── generate_sample_statements.py # Generates realistic 6-month statement PDFs
│   ├── requirements-training.txt   # Training & evaluation dependencies
│   └── README.md                   # ML Training Documentation & Guide
│
└── mobile/
    └── flutter_app/                # Flutter Cross-Platform Client Application
        ├── lib/                    # Theme, Models, Providers, Services, Widgets, Screens
        └── test/                   # Flutter Widget & Smoke Tests
```

---

## ⚡ Quick Start Guide

### 1. Docker Deployment (Inference-Only Container)

The backend runs in a lightweight Docker container dedicated purely to inference, PDF processing, spending analytics, and forecasting.

```bash
# Build and run backend container with Docker Compose
docker compose up --build -d

# Check backend container logs
docker compose logs -f backend

# Verify health status
curl http://localhost:8000/health
```

#### Persistent Volumes & Weights Hot-Swapping:
- `./data`: Stores the persistent SQLite database (`expenseinsight.db`) and uploaded statement PDFs.
- `./backend/ml/models`: Mounted read-only (`:ro`). Model weights can be updated offline on the host and hot-swapped without rebuilding the container.

---

### 2. Local Backend Setup (Alternative)

```bash
# 1. Activate virtual environment
.venv\Scripts\activate

# 2. Run backend test suite
pytest backend/tests/test_backend.py -v

# 3. Start FastAPI server
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

FastAPI Swagger Documentation will be available at: `http://127.0.0.1:8000/docs`.

---

### 3. Machine Learning Pipeline (Decoupled Offline Training)

Model training and evaluation are decoupled from the Docker inference runtime and executed separately on the host / training environment:

```bash
# Train ML classification models & export artifacts to backend/ml/models/
python ml_training/scripts/train_classifier.py

# In-depth edge case evaluation & confusion matrix
python ml_training/scripts/evaluate_classifier.py

# Backtest forecasting accuracy & MAPE
python ml_training/scripts/evaluate_forecaster.py

# Generate fresh 6-month statement PDFs for HDFC, SBI, ICICI
python ml_training/scripts/generate_sample_statements.py
```

#### Academic Evaluation Benchmark Results:
| Model Architecture | Accuracy | Macro F1 | Weighted F1 |
| :--- | :--- | :--- | :--- |
| **TF-IDF + Calibrated Logistic Regression (Production)** | **99.93%** | **0.9987** | **0.9993** |
| TF-IDF + Calibrated LinearSVC | 99.87% | 0.9979 | 0.9987 |
| TF-IDF + Random Forest | 72.07% | 0.8389 | 0.7420 |

---

### 3. Flutter Mobile & Web Client

```bash
cd mobile/flutter_app

# Run Flutter tests
flutter test

# Run Flutter Web / Desktop app
flutter run -d chrome
# or
flutter run -d windows
```

---

## 🎯 End-to-End User Experience

1. **Onboarding**: 1-Click Launch with pre-loaded 6-month bank statement data or custom account registration.
2. **Statement Ingestion**: Upload custom PDF or click **HDFC Bank / SBI / ICICI Bank** to test live 7-stage processing stepper with animated progress.
3. **Interactive Dashboard**:
   - Total Spend, This Month, Projected Next Month, and Net Savings cards.
   - Interactive Category Donut Chart with center hover legend.
   - Monthly Income vs Expense Trend Line Chart.
   - Top Spending Merchant Ranking with progress bar distributions.
   - Detected recurring subscription cycles (Netflix, Spotify, Broadband, Rent, Electricity).
4. **Transactions & Search**: Filter by category chips, instant keyword search, sort by date/amount/merchant, and tap to view raw text vs normalized merchant or change category.
5. **Help Me Categorize This (Review Deck)**: Interactive review card deck for low-confidence items with one-tap category pill buttons and persistent feedback learning.
6. **Expense Forecasting**:
   - 90% confidence interval band (`lower_bound` to `upper_bound`).
   - 7-day and 30-day projected budget breakdowns.
   - AI statistical explanations explaining the underlying trends.
7. **ML Model Benchmark**: View academic evaluation metrics, ablation comparisons, and trigger continuous retraining.
