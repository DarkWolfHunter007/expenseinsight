"""
Canonical Accounting Policy for ExpenseInsight.

Establishes the authoritative financial classification policy across the backend:
- Personal expenses (bank debits excluding transfers and cash withdrawals, plus cash expenses)
- Income (bank credits excluding transfers)
- Internal Transfers (neutral money movements; excluded from spending and income)
- Cash Withdrawals (bank to cash asset conversions; excluded from spending)
"""

from typing import Any, Dict, Set, Union
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
