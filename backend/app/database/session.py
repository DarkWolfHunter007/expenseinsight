import os
from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./expenseinsight.db")

# Auto-create parent directory for SQLite if it doesn't exist
if DATABASE_URL.startswith("sqlite:///"):
    db_file_path = DATABASE_URL.replace("sqlite:///", "")
    db_dir = os.path.dirname(os.path.abspath(db_file_path))
    if db_dir:
        os.makedirs(db_dir, exist_ok=True)

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    echo=False
)

# Enable SQLite foreign key cascade support
if DATABASE_URL.startswith("sqlite"):
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        try:
            cursor.execute("PRAGMA table_info(users)")
            cols = [row[1] for row in cursor.fetchall()]
            if cols and "updated_at" not in cols:
                cursor.execute("ALTER TABLE users ADD COLUMN updated_at DATETIME")
        except Exception:
            pass
        try:
            cursor.execute("PRAGMA table_info(cash_expenses)")
            cols = [row[1] for row in cursor.fetchall()]
            if cols and "payment_method" not in cols:
                cursor.execute("ALTER TABLE cash_expenses ADD COLUMN payment_method VARCHAR(20) DEFAULT 'cash'")
        except Exception:
            pass
        cursor.close()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """Dependency that provides a database session and ensures cleanup."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
