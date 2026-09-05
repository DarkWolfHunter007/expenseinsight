# ExpenseInsight 🚀

**ExpenseInsight** is an intelligent, privacy-first personal finance application that extracts, normalizes, categorizes, analyzes, and forecasts expenses from multi-bank PDF statements (Canara Bank e-passbooks, HDFC Bank, State Bank of India, ICICI Bank, Axis Bank, Kotak Mahindra Bank, and generic statements).

Built with a **FastAPI backend** (PyMuPDF, 4-Layer Merchant Normalizer, Supervised ML Classifier, Time-Series Forecaster) and a **Flutter Web / Mobile / Desktop frontend** running in containerized production with Nginx.

---

## 🌟 Key Capabilities & System Architecture

```text
Bank Statement PDF (1-Month to 16+ Page Multi-Month e-Passbooks)
        ↓
[1] PDF Extraction & Tabular Parser (PyMuPDF fitz + Regex Block Grouping)
        ↓
[2] 4-Layer Merchant Normalizer (Regex Noise Stripper -> Alias KB -> RapidFuzz -> Learned Feedback)
        ↓
[3] Supervised ML Categorizer (TF-IDF N-Grams + Calibrated Logistic Regression / LinearSVC)
        ↓
[4] Confidence & Uncertainty Engine (>=85% High, 60-84% Medium, <60% Flagged & Defaulted to "Uncategorized")
        ↓
[5] "Help Me Categorize This" Active Learning Loop (Learned Feedback with Auto-Propagation)
        ↓
[6] Spending Analytics Engine (Total, MoM Change, Category Breakdown, Top Merchants, Subscriptions)
        ↓
[7] Time-Series Expense Forecaster (Holt-Winters / ARIMA with 90% Confidence Intervals)
        ↓
[8] Flutter Cross-Platform Dashboard (Web / PWA via Nginx, Mobile, Windows & macOS Desktop)
```

### Highlights
- **Multi-Bank, Multi-Page Ingestion**: Handles 16+ page Canara e-passbooks, HDFC, SBI, and ICICI statements with multi-line description parsing and IFSC-based bank detection.
- **Uncertainty & Active Learning**: Uncertain transactions (<60% confidence) are assigned to `"Uncategorized"`, where the review UI highlights and places the active tick mark (✔) on `"Uncategorized"`. User corrections update future categorization automatically.
- **Zero-Residue Deletion**: Deleting statements cascades through transactions, category corrections, and forecasts with SQLite foreign-key enforcement.
- **Decoupled ML Pipeline**: Standalone `ml_training/` folder with dataset generators, evaluation metrics, and retraining scripts separated from inference runtime.
- **1-Click Live Sharing**: `python share_live.py` creates an instant public HTTPS tunnel via Cloudflare and displays a scannable QR code directly in the terminal.

---

## 📁 Repository Structure

```text
expenseinsight/
├── README.md                       # Main Documentation & System Guide
├── SETUP_MAC.md                    # Dedicated macOS Setup & Troubleshooting Guide
├── startup guide.txt               # Plain-Text Quick-Reference Cheat Sheet
├── Dockerfile                      # Production Backend Container Image (Python 3.11)
├── docker-compose.yml              # Multi-Container Compose (Frontend + Backend)
├── share_live.py                   # Cloudflare Public Tunnel & Terminal QR Code Generator
├── ExpenseInsight_PRD.md           # Product Requirements Document
│
├── backend/                        # 🚀 Production Backend & Inference Service
│   ├── app/
│   │   ├── api/
│   │   │   ├── endpoints/          # Auth, Statements, Transactions, Analytics, Forecast, Model
│   │   │   ├── deps.py             # JWT Token Auth & Guest Session Management
│   │   │   └── api.py              # Central API Router
│   │   ├── database/               # SQLAlchemy ORM Session & Foreign Key Engine
│   │   ├── models/                 # DB Models (User, Statement, Transaction, Forecast) & Schemas
│   │   ├── services/               # PDF Extractor, Parser, Analytics, Forecaster, Pipeline
│   │   └── main.py                 # FastAPI Application Entrypoint
│   ├── ml/                         # Production Inference ML Modules & Model Weights
│   │   ├── categorization/         # ExpenseClassifier & HybridCategorizer
│   │   ├── forecasting/            # Holt-Winters / ARIMA Time-Series Forecaster
│   │   ├── preprocessing/          # 4-Layer Merchant Normalizer & Text Cleaner
│   │   └── models/                 # Model Artifacts (expense_classifier.joblib, model_metrics.json)
│   ├── sample_statements/          # 6-Month HDFC, SBI, ICICI bank statement PDFs
│   ├── tests/                      # Pytest Unit & Integration Tests (100% Passing)
│   └── requirements.txt            # Production Python Dependencies
│
├── ml_training/                    # 🧪 Decoupled Offline ML Training Pipeline
│   ├── datasets/                   # Synthetic Dataset Generator (10,000+ multi-bank records)
│   ├── evaluation/                 # Accuracy, Macro F1, Confusion Matrix, MAE/MAPE
│   ├── models/                     # Training model definitions
│   ├── scripts/                    # Scripts: train_classifier.py, evaluate_classifier.py, etc.
│   ├── train.py                    # 1-Click Master Training Entrypoint
│   ├── requirements.txt            # Training Dependencies
│   └── README.md                   # ML Training Documentation & Guide
│
└── mobile/
    └── flutter_app/                # 📱 Flutter Cross-Platform Client Application
        ├── Dockerfile              # Lightweight Nginx Web Container
        ├── nginx.conf              # Nginx Reverse Proxy & 50MB Upload Config
        ├── lib/                    # Theme, Models, Providers, Services, Widgets, Screens
        └── test/                   # Flutter Widget & Smoke Tests
```

---

## ⚡ Quick Start Options

### Option 1: Docker Compose (Recommended — Zero Setup)

Runs both the **FastAPI Backend** and the **Flutter Web Nginx Frontend** simultaneously.

```bash
# Build and run containers in background
docker compose up --build -d

# Check running status
docker compose ps

# View live backend logs
docker compose logs -f backend
```

| Service | URL | Description |
| :--- | :--- | :--- |
| **Frontend Web App** | [http://localhost:3000](http://localhost:3000) (or [http://localhost](http://localhost)) | Interactive Dashboard & UI |
| **Backend REST API** | [http://localhost:8000](http://localhost:8000) | FastAPI Engine |
| **Swagger API Docs** | [http://localhost:8000/docs](http://localhost:8000/docs) | Interactive API Documentation |
| **Health Check** | [http://localhost:8000/health](http://localhost:8000/health) | Pipeline Health Verification |

To stop containers:
```bash
docker compose down
```

---

### Option 2: Share Live via Cloudflare Tunnel & QR Code

Share your local running app over a secure public HTTPS link so anyone can scan and test on their phone or remote computer:

```bash
python share_live.py
```

- Spawns a secure Cloudflare tunnel to `http://localhost:3000`.
- Generates a **public HTTPS URL** (e.g. `https://random-name.trycloudflare.com`).
- Renders an **ASCII QR Code** in the terminal for instant phone camera scanning.

---

### Option 3: Local Development (Python + Flutter)

#### 1. Start the FastAPI Backend:
```bash
# Windows PowerShell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r backend/requirements.txt
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000

# macOS / Linux
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

#### 2. Run the Flutter Frontend:
```bash
cd mobile/flutter_app

# Run on Chrome (Web / PWA):
flutter run -d chrome

# Or run natively on Desktop:
flutter run -d windows    # Windows Desktop
flutter run -d macos      # macOS Desktop
```

---

## 🧪 Machine Learning Pipeline (`ml_training/`)

The machine learning pipeline is fully decoupled from the runtime. You can generate synthetic datasets, evaluate models, and train new classifiers:

```bash
# 1-Click Master Training (generates 10,000 txns, trains classifier, exports weights)
python ml_training/train.py

# In-depth edge-case evaluation & confusion matrix
python ml_training/scripts/evaluate_classifier.py

# Backtest Holt-Winters & ARIMA forecasting accuracy
python ml_training/scripts/evaluate_forecaster.py

# Generate realistic 6-month multi-bank sample PDFs
python ml_training/scripts/generate_sample_statements.py
```

### Model Performance Benchmark

| Model Architecture | Accuracy | Macro F1 | Weighted F1 | Latency |
| :--- | :--- | :--- | :--- | :--- |
| **TF-IDF + Calibrated Logistic Regression (Production)** | **99.93%** | **0.9987** | **0.9993** | **< 1.5ms** |
| TF-IDF + Calibrated LinearSVC | 99.87% | 0.9979 | 0.9987 | < 2.0ms |
| TF-IDF + Random Forest | 72.07% | 0.8389 | 0.7420 | 12.0ms |

---

## 🛠️ Running Automated Tests

```bash
# Backend pytest suite (9/9 unit & integration tests)
pytest backend/tests/test_backend.py -v
# (or inside Docker)
docker compose exec backend pytest backend/tests/test_backend.py -v

# Flutter analyze and widget test suite
cd mobile/flutter_app
flutter analyze
flutter test
```

---

## 🍎 macOS Setup

For Apple Silicon (M1/M2/M3/M4) or Intel Mac users, consult [`SETUP_MAC.md`](SETUP_MAC.md) for full Homebrew, Docker Desktop, and Xcode setup steps.
