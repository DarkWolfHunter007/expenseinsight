import calendar
import json
from collections import defaultdict
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple
import numpy as np
import pandas as pd
from sqlalchemy.orm import Session

from ..models.db_models import BudgetSettings, CashExpense, Statement, Transaction
from .accounting import AccountingPolicy


class AnalyticsService:
    """
    Computes unified personal spending analytics, combining Bank Transactions and Cash Expenses
    into Total Personal Spending with date-range boundaries (PRD Sections 25-26 & Cash Expense Tracking).

    Transaction dates are stored canonically as YYYY-MM-DD. Statement metadata can arrive in
    several display formats, so all analytics date boundaries are normalized before filtering.
    """

    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _normalize_date(value: Optional[str]) -> Optional[str]:
        """Normalize statement/date metadata to canonical YYYY-MM-DD."""
        if not value:
            return None
        text = str(value).strip()
        for fmt in (
            "%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y",
            "%d/%m/%y", "%d-%m-%y", "%d.%m.%y",
            "%d %b %Y", "%d %B %Y", "%d-%b-%Y", "%d-%b-%y",
            "%d %b %y", "%d %B %y",
        ):
            try:
                return datetime.strptime(text, fmt).strftime("%Y-%m-%d")
            except ValueError:
                continue
        return None

    @classmethod
    def _normalize_range(cls, start_date: Optional[str], end_date: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
        """Return canonical inclusive date boundaries."""
        start = cls._normalize_date(start_date)
        end = cls._normalize_date(end_date)
        if start and end and start > end:
            return end, start
        return start, end

    @staticmethod
    def _is_spending_transaction(df: pd.DataFrame) -> pd.DataFrame:
        """
        Return actual spending debits, excluding transfers and cash withdrawals.
        Delegates to canonical AccountingPolicy.
        """
        return AccountingPolicy.filter_personal_expenses(df)

    STANDARD_COLUMNS = [
        "id", "date", "amount", "category", "merchant", "normalized_merchant",
        "transaction_type", "cr_dr", "needs_review", "created_at", "source", "date_dt"
    ]

    @classmethod
    def _empty_df(cls) -> pd.DataFrame:
        df = pd.DataFrame(columns=cls.STANDARD_COLUMNS)
        df["amount"] = df["amount"].astype(float)
        df["date_dt"] = pd.to_datetime(df["date_dt"])
        return df

    def _get_user_transactions_df(self, user_id: str) -> pd.DataFrame:
        """Fetches user bank transactions and returns as Pandas DataFrame."""
        if self.db is None:
            return self._empty_df()
        txns = self.db.query(Transaction).filter(Transaction.user_id == user_id).all()
        if not txns:
            return self._empty_df()

        data = []
        for t in txns:
            data.append({
                "id": t.id,
                "date": t.date,
                "amount": float(t.amount),
                "category": t.category,
                "merchant": t.merchant or "Unknown",
                "normalized_merchant": t.normalized_merchant or "unknown",
                "transaction_type": t.transaction_type,
                "cr_dr": t.cr_dr,
                "needs_review": t.needs_review,
                "created_at": t.created_at,
                "source": "bank"
            })

        df = pd.DataFrame(data)
        df["date_dt"] = pd.to_datetime(df["date"])
        df = df.sort_values(by="date_dt")
        return df

    def _get_user_cash_expenses_df(self, user_id: str) -> pd.DataFrame:
        """Fetches user cash expenses and returns as Pandas DataFrame."""
        if self.db is None:
            return self._empty_df()
        cash_list = self.db.query(CashExpense).filter(CashExpense.user_id == user_id).all()
        if not cash_list:
            return self._empty_df()

        data = []
        for c in cash_list:
            data.append({
                "id": c.id,
                "date": c.expense_date,
                "amount": float(c.amount),
                "category": c.category,
                "merchant": "Cash Expense",
                "normalized_merchant": "cash_expense",
                "transaction_type": "expense",
                "cr_dr": "DR",
                "needs_review": False,
                "created_at": c.created_at,
                "source": "cash"
            })

        df = pd.DataFrame(data)
        df["date_dt"] = pd.to_datetime(df["date"])
        df = df.sort_values(by="date_dt")
        return df

    def _get_statement_date_bounds(self, user_id: str) -> Tuple[Optional[str], Optional[str]]:
        """
        Retrieves the earliest start date and latest end date from the user's uploaded statements.
        """
        if self.db is None:
            return None, None
        stmts = self.db.query(Statement).filter(Statement.user_id == user_id).all()
        starts = []
        ends = []
        for s in stmts:
            normalized_start = self._normalize_date(s.statement_start)
            normalized_end = self._normalize_date(s.statement_end)
            if normalized_start:
                starts.append(normalized_start)
            if normalized_end:
                ends.append(normalized_end)

        start_date = min(starts) if starts else None
        end_date = max(ends) if ends else None
        return start_date, end_date

    def _get_effective_date_bounds(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        bank_df: Optional[pd.DataFrame] = None,
        cash_df: Optional[pd.DataFrame] = None
    ) -> Tuple[Optional[str], Optional[str]]:
        """
        Determines the single authoritative effective analytics date range:
        1. Explicit start_date/end_date supplied -> Use those normalized dates.
        2. If statements or bank transactions exist -> Union of statement coverage
           and bank transaction dates so that no persisted transactions are hidden.
        3. If cash-only (no statements/bank transactions) -> Span of cash expenses.
        """
        norm_start, norm_end = self._normalize_range(start_date, end_date)
        if norm_start and norm_end:
            return norm_start, norm_end

        auto_start, auto_end = self._derive_default_bounds(user_id, bank_df, cash_df)
        # A single explicit bound (open-ended range) is honoured; the other side falls back to the data span.
        return norm_start or auto_start, norm_end or auto_end

    def _derive_default_bounds(
        self,
        user_id: str,
        bank_df: Optional[pd.DataFrame] = None,
        cash_df: Optional[pd.DataFrame] = None
    ) -> Tuple[Optional[str], Optional[str]]:
        """Span of the user's own data when no explicit date range is requested (rules 2-3 above)."""
        stmt_start, stmt_end = self._get_statement_date_bounds(user_id)

        bank_dates: List[str] = []
        if bank_df is not None and not bank_df.empty and "date" in bank_df.columns:
            bank_dates = [d for raw_d in bank_df["date"].dropna().astype(str) if (d := self._normalize_date(raw_d))]

        cash_dates: List[str] = []
        if cash_df is not None and not cash_df.empty and "date" in cash_df.columns:
            cash_dates = [d for raw_d in cash_df["date"].dropna().astype(str) if (d := self._normalize_date(raw_d))]

        # If statements or bank transactions exist, derive range from statement bounds + bank transactions
        if stmt_start or stmt_end or bank_dates:
            min_candidates = [d for d in [stmt_start, (min(bank_dates) if bank_dates else None)] if d]
            max_candidates = [d for d in [stmt_end, (max(bank_dates) if bank_dates else None)] if d]
            # The statement is the baseline: cash logged after it extends the window, cash before it does not
            last_baseline = max(max_candidates) if max_candidates else None
            later_cash = [d for d in cash_dates if last_baseline and d > last_baseline]
            if later_cash:
                max_candidates.append(max(later_cash))
            eff_start = min(min_candidates) if min_candidates else None
            eff_end = max(max_candidates) if max_candidates else None
            return eff_start, eff_end

        # If no statements or bank transactions exist, derive from cash expenses
        if cash_dates:
            return min(cash_dates), max(cash_dates)

        return None, None

    @classmethod
    def _filter_df_by_date(
        cls,
        df: pd.DataFrame,
        start_date: Optional[str],
        end_date: Optional[str]
    ) -> pd.DataFrame:
        """Filters a DataFrame containing date_dt column to [start_date, end_date]; either bound may be open."""
        if df.empty:
            return df
        if start_date:
            df = df[df["date_dt"] >= pd.Timestamp(start_date)]
        if end_date:
            df = df[df["date_dt"] <= pd.Timestamp(end_date)]
        return df

    BUDGET_WARNING_PCT = 80.0
    BUDGET_CRITICAL_PCT = 90.0
    DAYS_PER_MONTH = 30.4375
    MIN_AUTO_CATEGORY_LIMIT = 100.0
    RECAP_WINDOW_DAYS = 7

    @classmethod
    def _budget_status(cls, used_pct: float) -> str:
        if used_pct > 100.0:
            return "exceeded"
        if used_pct >= cls.BUDGET_CRITICAL_PCT:
            return "critical"
        if used_pct >= cls.BUDGET_WARNING_PCT:
            return "warning"
        return "on_track"

    def _load_budget_settings(self, user_id: str) -> Dict[str, Any]:
        defaults: Dict[str, Any] = {"auto_limits": True, "monthly_limit": None, "category_limits": {}}
        if self.db is None:
            return defaults
        row = self.db.query(BudgetSettings).filter(BudgetSettings.user_id == user_id).first()
        if row is None:
            return defaults
        try:
            limits = json.loads(row.category_limits or "{}")
        except ValueError:
            limits = {}
        return {
            "auto_limits": bool(row.auto_limits),
            "monthly_limit": row.monthly_limit,
            "category_limits": limits,
        }

    @staticmethod
    def _spent_in_month(frames: List[pd.DataFrame], period: pd.Period, category: Optional[str] = None) -> float:
        total = 0.0
        for frame in frames:
            if frame is None or frame.empty or "amount" not in frame.columns:
                continue
            in_month = frame[frame["date_dt"].dt.to_period("M") == period]
            if category is not None:
                in_month = in_month[in_month["category"].astype(str).str.lower() == category.lower()]
            total += float(in_month["amount"].sum())
        return round(total, 2)

    def _compute_budget(
        self,
        user_id: str,
        bank_df: pd.DataFrame,
        cash_df: pd.DataFrame,
        as_of: Optional[date] = None,
        settings: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Monthly budget indicator.

        Automatic mode: the uploaded statement history is the baseline, so the limit is the average
        personal spend per day across it scaled to a month (overall and per category). A manual
        monthly limit or manual category limits always take priority over the automatic figures.
        Manual mode: only the limits the user pre-approved are used.

        This month's bank + cash spending is compared against the limits and mapped to
        on_track / warning (80%) / critical (90%) / exceeded (over 100%).
        """
        today = pd.Timestamp(as_of or date.today())
        period = today.to_period("M")
        settings = settings or self._load_budget_settings(user_id)
        auto = bool(settings.get("auto_limits", True))
        manual_total = settings.get("monthly_limit") or 0.0
        manual_cats = {k: float(v) for k, v in (settings.get("category_limits") or {}).items() if float(v) > 0}

        days_in_month = calendar.monthrange(today.year, today.month)[1]
        days_left = days_in_month - today.day + 1

        base = {
            "monthly_budget": 0.0,
            "budget_month": today.strftime("%Y-%m"),
            "budget_spent": 0.0,
            "budget_remaining": 0.0,
            "budget_used_pct": 0.0,
            "budget_status": "none",
            "budget_mode": "auto" if auto else "manual",
            "days_left_in_month": days_left,
            "safe_to_spend_today": 0.0,
            "category_budgets": [],
            "last_month_recap": None,
            "last_month_spent": 0.0,
            "last_month_label": "",
        }

        baseline_df = AccountingPolicy.filter_personal_expenses(bank_df) if not bank_df.empty else bank_df
        auto_total = 0.0
        auto_cats: Dict[str, float] = {}
        if auto and not baseline_df.empty and "amount" in baseline_df.columns:
            baseline_days = max(1, (baseline_df["date_dt"].max() - baseline_df["date_dt"].min()).days + 1)
            scale = self.DAYS_PER_MONTH / baseline_days
            auto_total = float(baseline_df["amount"].sum()) * scale
            if "category" in baseline_df.columns:
                for cat, amount in baseline_df.groupby("category")["amount"].sum().items():
                    if cat and float(amount) * scale >= self.MIN_AUTO_CATEGORY_LIMIT:
                        auto_cats[str(cat)] = round(float(amount) * scale, 2)

        if auto:
            overall = manual_total or auto_total
            cat_limits = {**auto_cats, **manual_cats}
        else:
            overall = manual_total or sum(manual_cats.values())
            cat_limits = dict(manual_cats)

        overall = round(overall, 2)
        if overall <= 0:
            return base

        frames = [baseline_df, cash_df]
        spent = self._spent_in_month(frames, period)
        remaining = round(overall - spent, 2)
        # The tier is decided from the exact percentage: rounding first would show 100.0% (critical)
        # for a budget that is over by a few paise.
        raw_used_pct = spent / overall * 100.0
        used_pct = round(raw_used_pct, 1)

        category_budgets = []
        for cat, limit in cat_limits.items():
            cat_spent = self._spent_in_month(frames, period, cat)
            raw_cat_pct = cat_spent / limit * 100.0
            cat_pct = round(raw_cat_pct, 1)
            category_budgets.append({
                "category": cat,
                "limit": round(limit, 2),
                "spent": cat_spent,
                "remaining": round(limit - cat_spent, 2),
                "used_pct": cat_pct,
                "status": self._budget_status(raw_cat_pct),
            })
        category_budgets.sort(key=lambda c: c["used_pct"], reverse=True)

        recap = None
        prev_period = period - 1
        prev_spent = self._spent_in_month(frames, prev_period)
        if today.day <= self.RECAP_WINDOW_DAYS:
            if prev_spent > 0:
                diff = round(overall - prev_spent, 2)
                recap = {
                    "month": str(prev_period),
                    "spent": prev_spent,
                    "budget": overall,
                    "difference": diff,
                    "under_budget": diff >= 0,
                }

        base.update({
            "monthly_budget": overall,
            "budget_spent": spent,
            "budget_remaining": remaining,
            "budget_used_pct": used_pct,
            "budget_status": self._budget_status(raw_used_pct),
            "safe_to_spend_today": round(max(0.0, remaining) / days_left, 2),
            "category_budgets": category_budgets,
            "last_month_recap": recap,
            "last_month_spent": prev_spent,
            "last_month_label": prev_period.strftime("%B %Y") if prev_spent > 0 else "",
        })
        return base

    def get_summary(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        as_of: Optional[date] = None
    ) -> Dict[str, Any]:
        """
        Calculates high-level spending analytics summary combining Bank Transactions
        and Cash Expenses within the applicable analytics window.
        """
        bank_df = self._get_user_transactions_df(user_id)
        cash_df = self._get_user_cash_expenses_df(user_id)

        # Retrieve active statements for statement context
        stmt_count = 0
        distinct_banks = []
        if self.db is not None:
            user_stmts = self.db.query(Statement).filter(Statement.user_id == user_id).order_by(Statement.created_at.desc()).all()
            stmt_count = len(user_stmts)
            distinct_banks = [b for b in dict.fromkeys(s.bank_name for s in user_stmts if s.bank_name and s.bank_name not in ("Generic Bank", "Bank Statement"))]

        if stmt_count > 1:
            if len(distinct_banks) == 1:
                bank_name = distinct_banks[0]
            elif len(distinct_banks) > 1:
                bank_name = f"Multiple Banks ({', '.join(distinct_banks)})"
            else:
                bank_name = "Multiple Statements"
        elif stmt_count == 1:
            bank_name = user_stmts[0].bank_name or "Bank Statement"
        elif not cash_df.empty and bank_df.empty:
            bank_name = "Cash & Liquid Expenses"
        else:
            bank_name = "Bank Statement"

        if bank_df.empty and cash_df.empty:
            period_str = "No statements uploaded"
            if stmt_count > 0:
                stmt_start, stmt_end = self._get_statement_date_bounds(user_id)
                if stmt_start and stmt_end:
                    period_str = f"{stmt_start} - {stmt_end}"
                else:
                    period_str = "Active Statement Period"

            return {
                "total_expense": 0.0,
                "total_income": 0.0,
                "total_transfers": 0.0,
                "net_savings": 0.0,
                "this_month_spent": 0.0,
                "previous_month_spent": 0.0,
                "month_over_month_change_pct": 0.0,
                "average_daily_spend": 0.0,
                "total_transactions_count": 0,
                "statement_period": period_str,
                "bank_name": bank_name,
                "statement_count": stmt_count,
                "categories_breakdown": [],
                "top_merchants": [],
                "recurring_expenses": [],
                "bank_spending": 0.0,
                "cash_spending": 0.0,
                "total_spending": 0.0,
                "bank_money_out": 0.0,
                "bank_money_in": 0.0,
                "transfers_out": 0.0,
                "transfers_in": 0.0,
                "other_money_out": 0.0,
                "net_cash_flow": 0.0,
                "this_month_label": "",
                **self._compute_budget(user_id, bank_df, cash_df, as_of)
            }

        # Determine authoritative effective date range
        period_start, period_end = self._get_effective_date_bounds(
            user_id,
            start_date=start_date,
            end_date=end_date,
            bank_df=bank_df,
            cash_df=cash_df
        )

        bank_in_range_df = self._filter_df_by_date(bank_df, period_start, period_end)
        cash_in_range_df = self._filter_df_by_date(cash_df, period_start, period_end)

        # Actual personal spending debits: exclude transfers and cash withdrawals
        bank_expenses_df = AccountingPolicy.filter_personal_expenses(bank_in_range_df)
        bank_spending = round(float(bank_expenses_df["amount"].sum()), 2) if not bank_expenses_df.empty and "amount" in bank_expenses_df.columns else 0.0
        cash_spending = round(float(cash_in_range_df["amount"].sum()), 2) if not cash_in_range_df.empty and "amount" in cash_in_range_df.columns else 0.0
        total_spending = round(bank_spending + cash_spending, 2)
        total_expense = total_spending

        # Income: credits excluding transfers
        income_df = AccountingPolicy.filter_income(bank_in_range_df)
        total_income = round(float(income_df["amount"].sum()), 2) if not income_df.empty and "amount" in income_df.columns else 0.0

        # Transfers: neutral money movements
        transfers_df = AccountingPolicy.filter_transfers(bank_in_range_df)
        total_transfers = round(float(transfers_df["amount"].sum()), 2) if not transfers_df.empty and "amount" in transfers_df.columns else 0.0

        # Everything the bank statement shows leaving and entering the account (what the PDF's own
        # "total withdrawals" / "total deposits" add up to), split into purchases, transfers and the rest
        def _direction_total(frame: pd.DataFrame, direction: str) -> float:
            if frame.empty or "amount" not in frame.columns or "cr_dr" not in frame.columns:
                return 0.0
            side = frame[frame["cr_dr"].astype(str).str.upper() == direction]
            return round(float(side["amount"].sum()), 2)

        bank_money_out = _direction_total(bank_in_range_df, "DR")
        bank_money_in = _direction_total(bank_in_range_df, "CR")
        transfers_out = _direction_total(transfers_df, "DR")
        transfers_in = _direction_total(transfers_df, "CR")
        other_money_out = round(max(0.0, bank_money_out - bank_spending - transfers_out), 2)
        # The real change in the account over the period: everything in, minus everything out (bank
        # withdrawals and cash spending). Unlike "income minus spending" it does not ignore transfers.
        net_cash_flow = round(bank_money_in - bank_money_out - cash_spending, 2)

        net_savings = round(total_income - total_expense, 2)

        # Date range & daily average calculation
        date_series_list = []
        if not bank_in_range_df.empty:
            date_series_list.append(bank_in_range_df["date_dt"])
        if not cash_in_range_df.empty:
            date_series_list.append(cash_in_range_df["date_dt"])

        if date_series_list:
            all_dates = pd.concat(date_series_list)
            min_date = all_dates.min()
            max_date = all_dates.max()
            days_span = max(1, (max_date - min_date).days + 1)
            avg_daily = round(total_expense / days_span, 2)
            period_str = f"{min_date.strftime('%b %d, %Y')} - {max_date.strftime('%b %d, %Y')}"
        else:
            days_span = 1
            avg_daily = 0.0
            if stmt_count > 0 or not cash_df.empty or not bank_df.empty:
                period_str = "No activity in period"
            else:
                period_str = "No statements uploaded"

        # Month-over-month calculation (combining bank and cash expenses)
        this_month_label = ""
        all_expenses_list = []
        if not bank_expenses_df.empty:
            all_expenses_list.append(bank_expenses_df[["date_dt", "amount"]])
        if not cash_in_range_df.empty:
            all_expenses_list.append(cash_in_range_df[["date_dt", "amount"]])

        if all_expenses_list:
            combined_exp_df = pd.concat(all_expenses_list)
            monthly_exp = combined_exp_df.groupby(combined_exp_df["date_dt"].dt.to_period("M"))["amount"].sum()
            months_list = sorted(monthly_exp.index)
            this_month_label = months_list[-1].strftime("%b %Y") if months_list else ""
            if len(months_list) >= 2:
                this_month_spent = float(monthly_exp.loc[months_list[-1]])
                prev_month_spent = float(monthly_exp.loc[months_list[-2]])
                mom_change = round(((this_month_spent - prev_month_spent) / (prev_month_spent + 1e-5)) * 100.0, 1)
            elif len(months_list) == 1:
                this_month_spent = float(monthly_exp.loc[months_list[-1]])
                prev_month_spent = 0.0
                mom_change = 0.0
            else:
                this_month_spent = 0.0
                prev_month_spent = 0.0
                mom_change = 0.0
        else:
            this_month_spent = 0.0
            prev_month_spent = 0.0
            mom_change = 0.0

        # Unified Category Breakdown (sharing exact same period)
        categories_breakdown = self.get_category_spending(
            user_id=user_id,
            start_date=period_start,
            end_date=period_end
        )

        # Top Merchants (sharing exact same period and accounting policy)
        top_merchants = self.get_merchant_spending(
            user_id=user_id,
            start_date=period_start,
            end_date=period_end
        )[:10]

        # Recurring Expenses (sharing exact same period and accounting policy)
        recurring = self.get_recurring_expenses(
            user_id=user_id,
            start_date=period_start,
            end_date=period_end
        )

        if not cash_in_range_df.empty and bank_in_range_df.empty:
            bank_name = "Cash & Liquid Expenses"

        total_txns_count = len(bank_in_range_df) + len(cash_in_range_df)

        return {
            "total_expense": round(total_expense, 2),
            "total_income": round(total_income, 2),
            "total_transfers": round(total_transfers, 2),
            "net_savings": net_savings,
            "this_month_spent": round(this_month_spent, 2),
            "previous_month_spent": round(prev_month_spent, 2),
            "month_over_month_change_pct": mom_change,
            "average_daily_spend": avg_daily,
            "total_transactions_count": total_txns_count,
            "statement_period": period_str,
            "bank_name": bank_name,
            "statement_count": stmt_count,
            "categories_breakdown": categories_breakdown,
            "top_merchants": top_merchants,
            "recurring_expenses": recurring,
            "bank_spending": round(bank_spending, 2),
            "cash_spending": round(cash_spending, 2),
            "total_spending": total_spending,
            "bank_money_out": bank_money_out,
            "bank_money_in": bank_money_in,
            "transfers_out": transfers_out,
            "transfers_in": transfers_in,
            "other_money_out": other_money_out,
            "net_cash_flow": net_cash_flow,
            "this_month_label": this_month_label,
            **self._compute_budget(user_id, bank_df, cash_df, as_of)
        }

    def get_monthly_spending(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Returns chronological monthly breakdown of income and expenses,
        combining bank spending and cash spending by month based on date.
        Reconciles with get_summary() total_expense across identical date bounds.
        """
        bank_df = self._get_user_transactions_df(user_id)
        cash_df = self._get_user_cash_expenses_df(user_id)

        if bank_df.empty and cash_df.empty:
            return []

        period_start, period_end = self._get_effective_date_bounds(
            user_id,
            start_date=start_date,
            end_date=end_date,
            bank_df=bank_df,
            cash_df=cash_df
        )

        bank_df = self._filter_df_by_date(bank_df, period_start, period_end)
        cash_df = self._filter_df_by_date(cash_df, period_start, period_end)

        # Collect distinct year_month periods
        periods = set()
        if not bank_df.empty:
            bank_df["year_month"] = bank_df["date_dt"].dt.to_period("M")
            periods.update(bank_df["year_month"].unique())
        if not cash_df.empty:
            cash_df["year_month"] = cash_df["date_dt"].dt.to_period("M")
            periods.update(cash_df["year_month"].unique())

        monthly_items = []
        for ym in sorted(periods):
            b_group = bank_df[bank_df["year_month"] == ym] if not bank_df.empty else pd.DataFrame()
            c_group = cash_df[cash_df["year_month"] == ym] if not cash_df.empty else pd.DataFrame()

            b_exp = AccountingPolicy.filter_personal_expenses(b_group)
            b_inc = AccountingPolicy.filter_income(b_group)

            bank_exp = float(b_exp["amount"].sum()) if not b_exp.empty else 0.0
            cash_exp = float(c_group["amount"].sum()) if not c_group.empty else 0.0
            bank_inc = float(b_inc["amount"].sum()) if not b_inc.empty else 0.0

            total_exp = round(bank_exp + cash_exp, 2)
            total_inc = round(bank_inc, 2)
            txn_count = len(b_group) + len(c_group)

            def _side(frame, direction):
                if frame.empty or "cr_dr" not in frame.columns:
                    return 0.0
                return round(float(frame[frame["cr_dr"].astype(str).str.upper() == direction]["amount"].sum()), 2)

            money_out = _side(b_group, "DR")
            money_in = _side(b_group, "CR")

            dt = ym.to_timestamp()
            monthly_items.append({
                "month": str(ym),
                "month_name": dt.strftime("%B %Y"),
                "total_expense": total_exp,
                "total_income": total_inc,
                "net_savings": round(total_inc - total_exp, 2),
                "transaction_count": txn_count,
                "bank_expense": round(bank_exp, 2),
                "cash_expense": round(cash_exp, 2),
                "money_in": money_in,
                "money_out": money_out,
            })

        return monthly_items

    def get_category_spending(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Returns aggregated spending per category combining Bank Debits and Cash Expenses.
        Includes bank_amount, cash_amount, total amount, and percentage share.
        Guarantees:
          SUM(category.amount) == total personal spending
        """
        bank_df = self._get_user_transactions_df(user_id)
        cash_df = self._get_user_cash_expenses_df(user_id)

        period_start, period_end = self._get_effective_date_bounds(
            user_id,
            start_date=start_date,
            end_date=end_date,
            bank_df=bank_df,
            cash_df=cash_df
        )

        bank_df = self._filter_df_by_date(bank_df, period_start, period_end)
        cash_df = self._filter_df_by_date(cash_df, period_start, period_end)

        bank_exp_df = AccountingPolicy.filter_personal_expenses(bank_df)

        categories = set()
        if not bank_exp_df.empty:
            categories.update(bank_exp_df["category"].dropna().unique())
        if not cash_df.empty:
            categories.update(cash_df["category"].dropna().unique())

        if not categories:
            return []

        bank_cat_sums = bank_exp_df.groupby("category")["amount"].sum().to_dict() if not bank_exp_df.empty else {}
        bank_cat_counts = bank_exp_df.groupby("category")["id"].count().to_dict() if not bank_exp_df.empty else {}

        cash_cat_sums = cash_df.groupby("category")["amount"].sum().to_dict() if not cash_df.empty else {}
        cash_cat_counts = cash_df.groupby("category")["id"].count().to_dict() if not cash_df.empty else {}

        rows = []
        for cat in categories:
            b_amt = round(float(bank_cat_sums.get(cat, 0.0)), 2)
            c_amt = round(float(cash_cat_sums.get(cat, 0.0)), 2)
            tot_amt = round(b_amt + c_amt, 2)
            tot_count = int(bank_cat_counts.get(cat, 0)) + int(cash_cat_counts.get(cat, 0))
            rows.append({
                "category": str(cat),
                "amount": tot_amt,
                "transaction_count": tot_count,
                "bank_amount": b_amt,
                "cash_amount": c_amt
            })

        overall_total = round(sum(r["amount"] for r in rows), 2)

        results = []
        for r in sorted(rows, key=lambda x: x["amount"], reverse=True):
            pct = round((r["amount"] / overall_total) * 100.0, 1) if overall_total > 0 else 0.0
            r["percentage"] = pct
            results.append(r)

        return results

    def get_merchant_spending(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Returns top bank merchants ranked by total expenditure within the analytics window.
        Strictly excludes internal transfers and cash withdrawals.
        """
        df = self._get_user_transactions_df(user_id)
        if df.empty:
            return []

        period_start, period_end = self._get_effective_date_bounds(
            user_id,
            start_date=start_date,
            end_date=end_date,
            bank_df=df
        )
        df = self._filter_df_by_date(df, period_start, period_end)

        exp_df = AccountingPolicy.filter_personal_expenses(df)
        if exp_df.empty:
            return []

        total_exp = float(exp_df["amount"].sum())
        grouped = exp_df.groupby(["merchant", "category"]).agg(
            total_amount=("amount", "sum"),
            txn_count=("id", "count")
        ).reset_index()

        grouped = grouped.sort_values(by="total_amount", ascending=False)

        results = []
        for _, row in grouped.iterrows():
            amt = round(float(row["total_amount"]), 2)
            pct = round((amt / total_exp) * 100.0, 1) if total_exp > 0 else 0.0
            merchant_name = str(row["merchant"])
            results.append({
                "merchant": merchant_name,
                "canonical_name": merchant_name,
                "category": str(row["category"]),
                "total_amount": amt,
                "transaction_count": int(row["txn_count"]),
                "percentage_of_total": pct
            })
        return results

    def get_recurring_expenses(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Identifies repeating monthly / periodic expenses (PRD Section 26).
        Strictly operates on genuine personal expenses only (excluding transfers and withdrawals).
        Requires monthly cycle spacing (interval ~20-35 days) with no immediate bursts.
        """
        df = self._get_user_transactions_df(user_id)
        if df.empty:
            return []

        if start_date or end_date:
            period_start, period_end = self._normalize_range(start_date, end_date)
            df = self._filter_df_by_date(df, period_start, period_end)

        exp_df = AccountingPolicy.filter_personal_expenses(df)
        if exp_df.empty:
            return []

        recurring_list = []
        for merchant, group in exp_df.groupby("merchant"):
            if len(group) >= 2:
                dates = sorted(group["date_dt"].tolist())
                diffs = [(dates[i+1] - dates[i]).days for i in range(len(dates)-1)]
                avg_interval = np.mean(diffs) if diffs else 0
                min_interval = min(diffs) if diffs else 0

                # Must be a monthly cycle: avg interval between 20 and 35 days,
                # and no immediate repeat within 15 days (avoids irregular bursts)
                if (20 <= avg_interval <= 35) and (min_interval >= 15):
                    avg_amt = float(group["amount"].mean())
                    last_dt = dates[-1].strftime("%Y-%m-%d")
                    cat = group["category"].iloc[0]
                    recurring_list.append({
                        "merchant": str(merchant),
                        "category": str(cat),
                        "average_amount": round(avg_amt, 2),
                        "frequency": "Monthly",
                        "last_payment_date": last_dt,
                        "occurrences": len(group)
                    })

        return sorted(recurring_list, key=lambda x: x["average_amount"], reverse=True)
