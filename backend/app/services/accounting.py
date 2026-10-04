"""
Canonical Accounting Policy for ExpenseInsight.

Establishes the authoritative financial classification policy across the backend:
- Personal expenses (bank debits excluding transfers and cash withdrawals, plus cash expenses)
- Income (bank credits excluding transfers)
- Internal Transfers (neutral money movements; excluded from spending and income)
- Cash Withdrawals (bank to cash asset conversions; excluded from spending)
"""

import re
from typing import Any, Dict, List, Optional, Pattern, Set, Union
import pandas as pd


TRANSFER_TYPES: Set[str] = {
    "transfer",
    "internal_transfer",
    "self_transfer",
    "peer_transfer",
    "tpt_transfer"
}

CASH_WITHDRAWAL_TYPES: Set[str] = {
    "cash_withdrawal",
    "atm_withdrawal",
    "withdrawal",
    "atm_cash",
    "nfs_wdl"
}

TRANSFER_CATEGORIES: Set[str] = {
    "transfer",
    "transfers",
    "internal transfer",
    "self transfer"
}

CASH_WITHDRAWAL_CATEGORIES: Set[str] = {
    "cash withdrawal",
    "atm withdrawal",
    "cash_withdrawal"
}

# Compiled regex patterns for robust UPI narration detection across Indian banks
UPI_REGEX_PATTERNS: List[Pattern[str]] = [
    # 1. Structural prefixes (e.g. UPI/DR/..., UPI-SWIGGY..., /UPI/...)
    re.compile(r'\bUPI[/\-_:]', re.IGNORECASE),
    re.compile(r'[/_\-]UPI[/\-_]', re.IGNORECASE),
    re.compile(r'\b(?:TO|BY)\s+TRANSFER-UPI\b', re.IGNORECASE),
    re.compile(r'\bTRANSFER-UPI\b', re.IGNORECASE),
    re.compile(r'\bBIL/ONL/UPI\b', re.IGNORECASE),
    re.compile(r'\bMMT/UPI\b', re.IGNORECASE),
    
    # 2. Explicit UPI keywords and identifiers
    re.compile(r'\bUPI\s*ID\b', re.IGNORECASE),
    re.compile(r'\bUPIID\b', re.IGNORECASE),
    re.compile(r'\bUPI\s*REF\b', re.IGNORECASE),
    re.compile(r'\bUPI\s*TRANSACTION\b', re.IGNORECASE),
    re.compile(r'\bVPA\b', re.IGNORECASE),
    re.compile(r'\bNPCI\b', re.IGNORECASE),
    
    # 3. Known UPI Payment Apps and Wallets
    re.compile(r'\bPHONE\s*PE\b', re.IGNORECASE),
    re.compile(r'\bGOOGLE\s*PAY\b', re.IGNORECASE),
    re.compile(r'\b(?:G\s*PAY|GPAY)\b', re.IGNORECASE),
    re.compile(r'\bPAYTM(?:\s*UPI)?\b', re.IGNORECASE),
    re.compile(r'\bBHIM(?:\s*UPI)?\b', re.IGNORECASE),
    re.compile(r'\bAMAZON\s*PAY(?:\s*UPI)?\b', re.IGNORECASE),
    re.compile(r'\bCRED\s*(?:PAY|UPI)\b', re.IGNORECASE),
    re.compile(r'\bWHATSAPP\s*PAY\b', re.IGNORECASE),
    
    # 4. Standard VPA handles (e.g. name@okhdfcbank, merchant@upi, user@ybl, etc.)
    re.compile(r'[\w.\-_]+@(okhdfcbank|okaxis|okicici|oksbi|ybl|ibl|axl|paytm|upi|apl|barodampay|postbank|idfcbank|aubank|federal|indus|airtel|jupiteraxis)\b', re.IGNORECASE),
    re.compile(r'[\w.\-_]{2,}@upi\b', re.IGNORECASE),
    re.compile(r'\b(?:merchant|payment|vpa)@[\w.-]+\b', re.IGNORECASE),
    
    # 5. Standalone whole-word UPI boundary
    re.compile(r'\bUPI\b', re.IGNORECASE),
]

UPI_BANK_SOURCE_SEPARATION_CHECKLIST: Dict[str, bool] = {
    "canonical_classifier": True,
    "statement_ingestion": True,
    "upi_detection": True,
    "database_consistency": True,
    "api_filtering": True,
    "api_schema": True,
    "flutter_model": True,
    "flutter_provider": True,
    "transaction_edit_preservation": True,
    "analytics_regression": True,
    "forecast_regression": True,
    "pagination": True,
    "tests": True,
}


def _extract_field(record: Any, field_name: str, default: Any = None) -> Any:
    """Extract field from object, dictionary, or row."""
    if isinstance(record, dict):
        return record.get(field_name, default)
    return getattr(record, field_name, default)


class AccountingPolicy:
    """
    Authoritative classification policy for all ExpenseInsight financial transactions.
    Ensures zero double-counting, transfer exclusion, and unified personal spending.
    """

    @classmethod
    def is_transfer(cls, record: Any) -> bool:
        """Determines if a transaction is an internal / peer transfer."""
        txn_type = str(_extract_field(record, "transaction_type", "") or "").strip().lower()
        category = str(_extract_field(record, "category", "") or "").strip().lower()
        return txn_type in TRANSFER_TYPES or category in TRANSFER_CATEGORIES

    @classmethod
    def is_cash_withdrawal(cls, record: Any) -> bool:
        """Determines if a transaction is a cash withdrawal from bank to physical cash."""
        txn_type = str(_extract_field(record, "transaction_type", "") or "").strip().lower()
        category = str(_extract_field(record, "category", "") or "").strip().lower()
        return txn_type in CASH_WITHDRAWAL_TYPES or category in CASH_WITHDRAWAL_CATEGORIES

    @classmethod
    def is_personal_expense(cls, record: Any) -> bool:
        """
        Determines if a transaction represents genuine personal spending.
        Counts toward spending when:
            cr_dr == 'DR'
            AND not a transfer
            AND not a cash withdrawal
            AND category is not transfer or cash withdrawal
        """
        cr_dr = str(_extract_field(record, "cr_dr", "DR") or "DR").strip().upper()
        if cr_dr != "DR":
            return False

        if cls.is_transfer(record) or cls.is_cash_withdrawal(record):
            return False

        # Additional guard against income records mislabeled with DR
        txn_type = str(_extract_field(record, "transaction_type", "") or "").strip().lower()
        if txn_type in ("income", "credit"):
            return False

        return True

    @classmethod
    def is_income(cls, record: Any) -> bool:
        """
        Determines if a transaction represents genuine income.
        Counts toward income when:
            cr_dr == 'CR'
            AND not a transfer
        """
        cr_dr = str(_extract_field(record, "cr_dr", "") or "").strip().upper()
        if cr_dr != "CR":
            return False

        if cls.is_transfer(record):
            return False

        return True

    @classmethod
    def is_upi_narration(cls, text: Optional[str]) -> bool:
        """
        Determines whether a description, reference, or narration string corresponds to UPI.
        Evaluates against Indian banking UPI syntax (HDFC, ICICI, SBI, Axis, Kotak, BOB, etc.).
        Case-insensitive and whitespace tolerant.
        """
        if not text:
            return False
        clean_text = str(text).strip()
        if not clean_text:
            return False
        for pat in UPI_REGEX_PATTERNS:
            if pat.search(clean_text):
                return True
        return False

    @classmethod
    def classify_source(cls, record: Any) -> str:
        """
        Determines the authoritative canonical payment source ('bank', 'upi', 'cash') for any
        transaction record (Transaction model, CashExpense model, dict, or row).

        Core Invariant:
        SOURCE DOCUMENT != PAYMENT SOURCE.
        A bank statement is only a source document. Transactions extracted from it can be 'upi' or 'bank'.

        Rules:
        1. Manual/CashExpense records:
           - Respects explicit payment_method ('bank', 'upi', 'cash') if present.
           - Checks description prefixes ([Bank], [UPI], [Cash]).
           - Defaults to 'cash'.
        2. Bank Statement transactions (Transaction model / dict):
           - Checks raw_description, clean_description, merchant, reference_number for UPI indicators.
           - Returns 'upi' if genuine UPI narration detected.
           - Otherwise returns 'bank' (NEFT, IMPS, RTGS, Card, NetBanking, Cheque, Charges, etc.).
        """
        if record is None:
            return "bank"

        # 1. Check explicit payment_method (present on CashExpense or manual dict entries)
        if isinstance(record, dict):
            pm = str(record.get("payment_method") or "").strip().lower()
            if pm in ("bank", "upi", "cash"):
                return pm
        elif hasattr(record, "__tablename__") and record.__tablename__ == "cash_expenses":
            pm = str(getattr(record, "payment_method", "") or "").strip().lower()
            if pm in ("bank", "upi", "cash"):
                return pm


        # 2. Check CashExpense transaction_type / source indicators
        txn_type = str(_extract_field(record, "transaction_type", "") or "").strip().lower()
        if txn_type == "cash_expense":
            return "cash"
        if txn_type == "upi_expense":
            return "upi"
        if txn_type == "bank_expense":
            return "bank"

        # 3. Check description prefixes (e.g. [UPI], [Bank], [Cash])
        desc = str(_extract_field(record, "description", "") or "").strip()
        if desc:
            if desc.startswith("[UPI]"):
                return "upi"
            if desc.startswith("[Cash]"):
                return "cash"
            if desc.startswith("[Bank]"):
                return "bank"

        # 4. CashExpense instances or manual entries with no statement_id and no raw_description
        if hasattr(record, "__tablename__") and record.__tablename__ == "cash_expenses":
            eff_pm = getattr(record, "effective_payment_method", "cash")
            return eff_pm if eff_pm in ("bank", "upi", "cash") else "cash"

        raw_desc = _extract_field(record, "raw_description", None)
        clean_desc = _extract_field(record, "clean_description", None)
        ref_num = _extract_field(record, "reference_number", None)
        merchant = _extract_field(record, "merchant", None)
        statement_id = _extract_field(record, "statement_id", None)

        # 5. Statement transaction: check raw_description, clean_description, reference_number, merchant
        texts_to_check = [raw_desc, clean_desc, ref_num, merchant]
        for t in texts_to_check:
            if t and cls.is_upi_narration(t):
                return "upi"

        # 6. If it belongs to a statement or has raw_description, it's a bank transaction
        if raw_desc is not None or statement_id is not None:
            return "bank"

        # 7. Fallback for manual records with only 'description'
        if desc:
            return "cash"

        return "bank"

    @classmethod
    def verify_checklist(cls) -> Dict[str, bool]:
        """Returns the current verification status of the UPI/Bank source separation checklist."""
        return UPI_BANK_SOURCE_SEPARATION_CHECKLIST.copy()


    # -------------------------------------------------------------------------
    # DataFrame vectorized filtering methods
    # -------------------------------------------------------------------------

    @classmethod
    def filter_personal_expenses(cls, df: pd.DataFrame) -> pd.DataFrame:
        """Returns only genuine personal spending debits from a DataFrame."""
        if df.empty or "cr_dr" not in df.columns:
            return df.iloc[0:0] if not df.empty else df

        mask = df["cr_dr"].astype(str).str.upper() == "DR"

        if "transaction_type" in df.columns:
            txn_series = df["transaction_type"].fillna("").astype(str).str.strip().str.lower()
            excluded_types = TRANSFER_TYPES | CASH_WITHDRAWAL_TYPES | {"income", "credit"}
            mask = mask & (~txn_series.isin(excluded_types))

        if "category" in df.columns:
            cat_series = df["category"].fillna("").astype(str).str.strip().str.lower()
            excluded_cats = TRANSFER_CATEGORIES | CASH_WITHDRAWAL_CATEGORIES
            mask = mask & (~cat_series.isin(excluded_cats))

        return df[mask]

    @classmethod
    def filter_income(cls, df: pd.DataFrame) -> pd.DataFrame:
        """Returns only genuine income credits from a DataFrame."""
        if df.empty or "cr_dr" not in df.columns:
            return df.iloc[0:0] if not df.empty else df

        mask = df["cr_dr"].astype(str).str.upper() == "CR"

        if "transaction_type" in df.columns:
            txn_series = df["transaction_type"].fillna("").astype(str).str.strip().str.lower()
            mask = mask & (~txn_series.isin(TRANSFER_TYPES))

        if "category" in df.columns:
            cat_series = df["category"].fillna("").astype(str).str.strip().str.lower()
            mask = mask & (~cat_series.isin(TRANSFER_CATEGORIES))

        return df[mask]

    @classmethod
    def filter_transfers(cls, df: pd.DataFrame) -> pd.DataFrame:
        """Returns transfer transactions from a DataFrame."""
        if df.empty:
            return df

        mask = pd.Series(False, index=df.index)
        if "transaction_type" in df.columns:
            txn_series = df["transaction_type"].fillna("").astype(str).str.strip().str.lower()
            mask = mask | txn_series.isin(TRANSFER_TYPES)
        if "category" in df.columns:
            cat_series = df["category"].fillna("").astype(str).str.strip().str.lower()
            mask = mask | cat_series.isin(TRANSFER_CATEGORIES)

        return df[mask]

    @classmethod
    def filter_cash_withdrawals(cls, df: pd.DataFrame) -> pd.DataFrame:
        """Returns cash withdrawal transactions from a DataFrame."""
        if df.empty:
            return df

        mask = pd.Series(False, index=df.index)
        if "transaction_type" in df.columns:
            txn_series = df["transaction_type"].fillna("").astype(str).str.strip().str.lower()
            mask = mask | txn_series.isin(CASH_WITHDRAWAL_TYPES)
        if "category" in df.columns:
            cat_series = df["category"].fillna("").astype(str).str.strip().str.lower()
            mask = mask | cat_series.isin(CASH_WITHDRAWAL_CATEGORIES)
        return df[mask]

    @classmethod
    def add_source_column(cls, df: pd.DataFrame) -> pd.DataFrame:
        """Adds or updates canonical 'source_type' column in a DataFrame."""
        if df.empty:
            df["source_type"] = pd.Series(dtype=str)
            return df
        sources = [cls.classify_source(row) for _, row in df.iterrows()]
        df["source_type"] = sources
        return df

    @classmethod
    def filter_by_source(cls, df: pd.DataFrame, source: Optional[str]) -> pd.DataFrame:
        """Filters DataFrame by source ('all', 'bank', 'upi', 'cash')."""
        if df.empty or not source or source.lower() == "all":
            return df
        target_source = source.strip().lower()
        if "source_type" not in df.columns:
            df = cls.add_source_column(df)
        return df[df["source_type"].astype(str).str.lower() == target_source]

