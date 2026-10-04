from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

# ----------------- Auth Schemas -----------------
class UserIdentifyRequest(BaseModel):
    email: EmailStr

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().lower()
        return v

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().lower()
        return v

class UserLogin(BaseModel):
    email: EmailStr
    password: str

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().lower()
        return v

class UserResponse(BaseModel):
    id: str
    email: str
    is_guest: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse

class UserIdentifyResponse(BaseModel):
    user_id: str
    email: str
    is_new_user: bool
    access_token: str
    token_type: str = "bearer"
    user: UserResponse

class TokenData(BaseModel):
    user_id: Optional[str] = None


# ----------------- Statement Schemas -----------------
class StatementResponse(BaseModel):
    id: str
    user_id: str
    file_name: str
    bank_name: str
    account_number: Optional[str] = None
    statement_start: Optional[str] = None
    statement_end: Optional[str] = None
    processing_status: str
    processing_step: str
    processing_progress: float
    total_transactions: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class StatementStatusResponse(BaseModel):
    statement_id: str
    status: str
    step: str
    progress: float
    total_transactions: int
    completed_steps: List[str]


# ----------------- Transaction Schemas -----------------
class TransactionResponse(BaseModel):
    id: str
    user_id: str
    statement_id: Optional[str] = None
    date: str
    raw_description: str
    clean_description: Optional[str] = None
    merchant: Optional[str] = None
    normalized_merchant: Optional[str] = None
    amount: float
    currency: str
    transaction_type: str
    cr_dr: str
    balance: Optional[float] = None
    reference_number: Optional[str] = None
    category: str
    category_confidence: float
    category_source: str
    needs_review: bool
    is_duplicate: bool
    created_at: datetime
    source_type: Optional[str] = "bank"
    payment_method: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class TransactionUpdateCategory(BaseModel):
    category: str
    apply_to_future: bool = True

class UncertainTransactionReview(BaseModel):
    transaction_id: str
    merchant: str
    raw_description: str
    amount: float
    date: str
    predicted_category: str
    confidence: float
    confidence_percentage: str
    suggested_categories: List[str]


# ----------------- Analytics Schemas -----------------
class CategorySpendingItem(BaseModel):
    category: str
    amount: float
    percentage: float
    transaction_count: int
    bank_amount: float = 0.0
    cash_amount: float = 0.0

class MonthlySpendingItem(BaseModel):
    month: str # YYYY-MM
    month_name: str
    total_expense: float
    total_income: float
    net_savings: float
    transaction_count: int
    bank_expense: float = 0.0
    cash_expense: float = 0.0

class MerchantSpendingItem(BaseModel):
    merchant: str
    canonical_name: str
    category: str
    total_amount: float
    transaction_count: int
    percentage_of_total: float

class RecurringExpenseItem(BaseModel):
    merchant: str
    category: str
    average_amount: float
    frequency: str # monthly, weekly
    last_payment_date: str
    occurrences: int

class AnalyticsSummaryResponse(BaseModel):
    total_expense: float
    total_income: float
    total_transfers: float
    net_savings: float
    this_month_spent: float
    previous_month_spent: float
    month_over_month_change_pct: float
    average_daily_spend: float
    total_transactions_count: int
    statement_period: Optional[str] = None
    bank_name: Optional[str] = "Bank Statement"
    statement_count: int = 0
    categories_breakdown: List[CategorySpendingItem]
    top_merchants: List[MerchantSpendingItem]
    recurring_expenses: List[RecurringExpenseItem]
    bank_spending: float = 0.0
    cash_spending: float = 0.0
    total_spending: float = 0.0


# ----------------- Forecast Schemas -----------------
class CategoryForecastDetail(BaseModel):
    predicted_amount: float
    lower_bound: float
    upper_bound: float
    historical_recent_avg: float
    last_month_spent: float
    trend_percentage: float
    historical_months: int

class ForecastResponse(BaseModel):
    status: str
    confidence_level: str
    status_message: str
    historical_months_count: int
    total_forecast: float
    lower_bound: float
    upper_bound: float
    next_7_days_forecast: float
    next_30_days_forecast: float
    category_forecasts: Dict[str, CategoryForecastDetail]
    explanation: str
    explanation_bullets: List[str]


# ----------------- Model & Metrics Schemas -----------------
class ModelMetricsResponse(BaseModel):
    model_name: str
    version: str
    algorithm: str
    accuracy: float
    accuracy_percentage: str
    macro_f1: float
    weighted_f1: float
    macro_precision: float
    macro_recall: float
    classes: List[str]
    sample_count: int
    comparison_experiment: Optional[Dict[str, Any]] = None

class ModelRetrainResponse(BaseModel):
    status: str
    message: str
    new_accuracy: float
    new_macro_f1: float
    retrained_samples_count: int


# ----------------- Cash Expense Schemas -----------------
class CashExpenseCreate(BaseModel):
    amount: float = Field(..., gt=0, description="Expense amount (must be positive)")
    category: str = Field(..., min_length=1, max_length=50, description="Expense category")
    expense_date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$", description="Expense date YYYY-MM-DD")
    description: Optional[str] = Field(None, max_length=255, description="Optional note or description")
    payment_method: Optional[str] = Field("cash", description="Payment method: bank, upi, or cash")

    @field_validator("payment_method")
    @classmethod
    def validate_payment_method(cls, v: Optional[str]) -> str:
        if v is None:
            return "cash"
        s = v.strip().lower()
        if s not in ["bank", "upi", "cash"]:
            raise ValueError("Payment method must be one of: bank, upi, cash")
        return s

    @field_validator("expense_date")
    @classmethod
    def validate_date(cls, v: str) -> str:
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError:
            raise ValueError("Invalid calendar date, must be valid YYYY-MM-DD")
        return v

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError("Category cannot be empty or whitespace")
        return s


class CashExpenseUpdate(BaseModel):
    amount: Optional[float] = Field(None, gt=0, description="Expense amount (must be positive)")
    category: Optional[str] = Field(None, min_length=1, max_length=50, description="Expense category")
    expense_date: Optional[str] = Field(None, pattern=r"^\d{4}-\d{2}-\d{2}$", description="Expense date YYYY-MM-DD")
    description: Optional[str] = Field(None, max_length=255, description="Optional note or description")
    payment_method: Optional[str] = Field(None, description="Payment method: bank, upi, or cash")

    @field_validator("payment_method")
    @classmethod
    def validate_payment_method(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            s = v.strip().lower()
            if s not in ["bank", "upi", "cash"]:
                raise ValueError("Payment method must be one of: bank, upi, cash")
            return s
        return v

    @field_validator("expense_date")
    @classmethod
    def validate_date(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            try:
                datetime.strptime(v, "%Y-%m-%d")
            except ValueError:
                raise ValueError("Invalid calendar date, must be valid YYYY-MM-DD")
        return v

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            s = v.strip()
            if not s:
                raise ValueError("Category cannot be empty or whitespace")
            return s
        return v


class CashExpenseResponse(BaseModel):
    id: str
    user_id: str
    amount: float
    category: str
    expense_date: str
    description: Optional[str] = None
    payment_method: str = "cash"
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
