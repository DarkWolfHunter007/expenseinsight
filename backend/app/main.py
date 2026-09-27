import os
import sys
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from backend.app.database.session import Base, engine, get_db
from backend.app.models.db_models import Merchant, User
from backend.app.api.api import api_router
from backend.app.api.endpoints import analytics, auth, cash_expenses, forecast, model, statements, transactions
from backend.ml.preprocessing.merchant_normalizer import DEFAULT_MERCHANT_KB

# Create all database tables
Base.metadata.create_all(bind=engine)

# Schema evolution: ensure payment_method column exists in cash_expenses
try:
    with engine.connect() as _conn:
        _cursor = _conn.connection.cursor()
        _cursor.execute("PRAGMA table_info(cash_expenses)")
        _cols = [row[1] for row in _cursor.fetchall()]
        if _cols and "payment_method" not in _cols:
            _cursor.execute("ALTER TABLE cash_expenses ADD COLUMN payment_method VARCHAR(20) DEFAULT 'cash'")
            _conn.connection.commit()
except Exception:
    pass

app = FastAPI(
    title="ExpenseInsight API",
    description="Intelligent personal-finance API for bank-statement extraction, normalization, categorization, analytics, and forecasting.",
    version="1.0.0"
)

# CORS configuration for Flutter Mobile, Web, and Desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router at /api/v1 as well as root-level prefixes from PRD Section 37
app.include_router(api_router, prefix="/api/v1")
app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(statements.router, prefix="/statements", tags=["Statements"])
app.include_router(transactions.router, prefix="/transactions", tags=["Transactions"])
app.include_router(cash_expenses.router, prefix="/cash-expenses", tags=["Cash Expenses"])
app.include_router(analytics.router, prefix="/analytics", tags=["Analytics"])
app.include_router(forecast.router, prefix="/forecast", tags=["Forecast"])
app.include_router(model.router, prefix="/model", tags=["ML Model"])

# Mount sample statements and uploads directory
samples_dir = os.getenv("SAMPLE_STATEMENTS_DIR", os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "sample_statements")))
if os.path.exists(samples_dir):
    app.mount("/static/samples", StaticFiles(directory=samples_dir), name="samples")

@app.on_event("startup")
def startup_event():
    """Initializes default merchants and verifies ML model on startup."""
    db = next(get_db())
    try:
        # Check if merchants seeded
        count = db.query(Merchant).count()
        if count == 0:
            print("Seeding default merchant knowledge base...")
            for name, data in DEFAULT_MERCHANT_KB.items():
                m = Merchant(
                    canonical_name=name,
                    aliases=",".join(data["aliases"]),
                    default_category=data["default_category"]
                )
                db.add(m)
            db.commit()

        # Schema evolution: ensure payment_method column exists in cash_expenses
        with engine.connect() as conn:
            try:
                cursor = conn.connection.cursor()
                cursor.execute("PRAGMA table_info(cash_expenses)")
                cols = [row[1] for row in cursor.fetchall()]
                if cols and "payment_method" not in cols:
                    cursor.execute("ALTER TABLE cash_expenses ADD COLUMN payment_method VARCHAR(20) DEFAULT 'cash'")
                    conn.connection.commit()
            except Exception:
                pass
    finally:
        db.close()

@app.get("/health")
def health_check():
    """System health check endpoint."""
    return {
        "status": "online",
        "product": "ExpenseInsight",
        "version": "1.0.0",
        "pipeline": "PDF -> Parser -> Normalizer -> ML Categorizer -> Analytics -> Forecaster"
    }

@app.post("/demo/seed")
def seed_demo_data(db: Session = Depends(get_db)):
    """Seeds the demo user with a full 6-month bank statement dataset."""
    from backend.app.api.endpoints.statements import seed_sample_statement
    demo_user = db.query(User).filter(User.email == "demo@expenseinsight.app").first()
    if not demo_user:
        demo_user = User(
            email="demo@expenseinsight.app",
            hashed_password="demo_hashed_pw",
            is_guest=True
        )
        db.add(demo_user)
        db.commit()
        db.refresh(demo_user)

    stmt = seed_sample_statement(bank="HDFC Bank", db=db, current_user=demo_user)
    return {
        "status": "success",
        "message": "Demo data seeded successfully with 6-month HDFC Bank statement.",
        "statement_id": stmt.id,
        "total_transactions": stmt.total_transactions,
        "user_email": demo_user.email
    }

# Mount Progressive Web App (PWA) build if available
web_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "mobile", "flutter_app", "build", "web"))
if os.path.exists(web_dir):
    app.mount("/", StaticFiles(directory=web_dir, html=True), name="pwa")

