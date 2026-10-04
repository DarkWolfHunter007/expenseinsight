import uuid
from datetime import datetime
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from ..database.session import Base

def generate_uuid():
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    is_guest = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    statements = relationship("Statement", back_populates="user", cascade="all, delete-orphan")
    transactions = relationship("Transaction", back_populates="user", cascade="all, delete-orphan")
    corrections = relationship("CategoryCorrection", back_populates="user", cascade="all, delete-orphan")
    forecasts = relationship("Forecast", back_populates="user", cascade="all, delete-orphan")
    cash_expenses = relationship("CashExpense", back_populates="user", cascade="all, delete-orphan")


class Statement(Base):
    __tablename__ = "statements"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    file_name = Column(String(255), nullable=False)
    file_path = Column(String(512), nullable=True)
    bank_name = Column(String(100), default="Unknown Bank")
    account_number = Column(String(50), nullable=True)
    statement_start = Column(String(20), nullable=True)
    statement_end = Column(String(20), nullable=True)
    processing_status = Column(String(50), default="uploaded") # uploaded, processing, completed, failed
    processing_step = Column(String(100), default="Uploaded")
    processing_progress = Column(Float, default=0.0)
    total_transactions = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="statements")
    transactions = relationship("Transaction", back_populates="statement", cascade="all, delete-orphan")


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    statement_id = Column(String(36), ForeignKey("statements.id"), nullable=True, index=True)
    
    date = Column(String(20), nullable=False, index=True) # YYYY-MM-DD
    raw_description = Column(Text, nullable=False)
    clean_description = Column(String(255), nullable=True)
    merchant = Column(String(100), nullable=True)
    normalized_merchant = Column(String(100), nullable=True, index=True)
    
    amount = Column(Float, nullable=False)
    currency = Column(String(10), default="INR")
    transaction_type = Column(String(30), default="expense") # expense, income, transfer, cash_withdrawal
    cr_dr = Column(String(10), default="DR") # DR or CR
    balance = Column(Float, nullable=True)
    reference_number = Column(String(100), nullable=True)
    
    category = Column(String(50), default="Uncategorized", index=True)
    category_confidence = Column(Float, default=0.0)
    category_source = Column(String(50), default="ml") # ml, merchant_kb, rule_override, manual_user
    needs_review = Column(Boolean, default=False, index=True)
    is_duplicate = Column(Boolean, default=False)
    
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="transactions")
    statement = relationship("Statement", back_populates="transactions")
    corrections = relationship("CategoryCorrection", back_populates="transaction", cascade="all, delete-orphan")

    @property
    def source_type(self) -> str:
        """
        Classify the payment rail represented by a bank-statement transaction.

        A transaction can originate from a bank statement while still having been
        executed through UPI. Derive the source from the statement narration so
        existing databases do not require a schema migration.
        """
        description = (self.raw_description or "").upper()

        upi_markers = (
            "UPI/",
            "UPI-",
            "UPI ",
            "/UPI/",
            "@UPI",
            "UPI ID",
            "UPIID",
            "VPA",
            "PHONEPE",
            "PHONE PE",
            "GOOGLE PAY",
            "GPAY",
            "G PAY",
            "PAYTM UPI",
            "BHIM UPI",
            "AMAZON PAY UPI",
        )

        if any(marker in description for marker in upi_markers):
            return "upi"
        return "bank"

    @property
    def payment_method(self) -> str:
        """Expose the same canonical payment-rail classification to API clients."""
        return self.source_type


class Merchant(Base):
    __tablename__ = "merchants"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    canonical_name = Column(String(100), unique=True, index=True, nullable=False)
    aliases = Column(Text, nullable=True) # JSON or comma-separated list
    default_category = Column(String(50), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class CategoryCorrection(Base):
    __tablename__ = "category_corrections"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    transaction_id = Column(String(36), ForeignKey("transactions.id"), nullable=False, index=True)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    old_category = Column(String(50), nullable=False)
    new_category = Column(String(50), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    transaction = relationship("Transaction", back_populates="corrections")
    user = relationship("User", back_populates="corrections")


class Forecast(Base):
    __tablename__ = "forecasts"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    forecast_date = Column(String(20), nullable=False) # e.g. "2026-07"
    category = Column(String(50), nullable=False)
    predicted_amount = Column(Float, nullable=False)
    lower_bound = Column(Float, nullable=False)
    upper_bound = Column(Float, nullable=False)
    model_version = Column(String(50), default="1.0.0")
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="forecasts")


class ModelVersion(Base):
    __tablename__ = "model_versions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    model_name = Column(String(100), nullable=False)
    version = Column(String(50), nullable=False)
    algorithm = Column(String(100), nullable=False)
    features = Column(String(255), nullable=True)
    accuracy = Column(Float, nullable=True)
    precision = Column(Float, nullable=True)
    recall = Column(Float, nullable=True)
    f1_score = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class CashExpense(Base):
    __tablename__ = "cash_expenses"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    
    amount = Column(Float, nullable=False)
    category = Column(String(50), nullable=False, index=True)
    description = Column(String(255), nullable=True)
    expense_date = Column(String(20), nullable=False, index=True)  # YYYY-MM-DD
    payment_method = Column(String(20), default="cash", nullable=False, index=True)  # bank, upi, cash
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="cash_expenses")

    @property
    def effective_payment_method(self) -> str:
        if self.payment_method and self.payment_method.lower() in ("bank", "upi", "cash"):
            return self.payment_method.lower()
        if self.description:
            if self.description.startswith("[Bank]"):
                return "bank"
            if self.description.startswith("[UPI]"):
                return "upi"
        return "cash"

    @property
    def clean_description(self) -> str | None:
        if not self.description:
            return None
        d = self.description
        for pfx in ("[Bank] ", "[Bank]", "[UPI] ", "[UPI]", "[Cash] ", "[Cash]"):
            if d.startswith(pfx):
                d = d[len(pfx):].strip()
                break
        return d or None

    @property
    def source_type(self) -> str:
        return self.effective_payment_method

