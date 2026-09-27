from collections import defaultdict
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple
import numpy as np
import pandas as pd
from sqlalchemy.orm import Session

from ..models.db_models import CashExpense, Statement, Transaction

class AnalyticsService:
    """
    Computes unified personal spending analytics, combining Bank Transactions and Cash Expenses
    into Total Personal Spending with date-range boundaries (PRD Sections 25-26 & Cash Expense Tracking).
    """

    def __init__(self, db: Session):
        self.db = db

    def _get_user_transactions_df(self, user_id: str) -> pd.DataFrame:
        """Fetches user bank transactions and returns as Pandas DataFrame."""
        txns = self.db.query(Transaction).filter(Transaction.user_id == user_id).all()
        if not txns:
            return pd.DataFrame()

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
        cash_list = self.db.query(CashExpense).filter(CashExpense.user_id == user_id).all()
        if not cash_list:
            return pd.DataFrame()

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
        stmts = self.db.query(Statement).filter(Statement.user_id == user_id).all()
        starts = []
        ends = []
        for s in stmts:
            if s.statement_start and len(s.statement_start) >= 10:
                starts.append(s.statement_start[:10])
            if s.statement_end and len(s.statement_end) >= 10:
                ends.append(s.statement_end[:10])

        start_date = min(starts) if starts else None
        end_date = max(ends) if ends else None
        return start_date, end_date

    def get_summary(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Calculates high-level spending analytics summary combining Bank Transactions
        and Cash Expenses within the applicable analytics window.
        """
        bank_df = self._get_user_transactions_df(user_id)
        cash_df = self._get_user_cash_expenses_df(user_id)

        # Retrieve active statements for statement context
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
                "total_spending": 0.0
            }

        # Determine effective date range
        period_start = start_date
        period_end = end_date

        if not period_start or not period_end:
            stmt_start, stmt_end = self._get_statement_date_bounds(user_id)
            if not bank_df.empty:
                period_start = stmt_start or bank_df["date"].min()
                period_end = stmt_end or bank_df["date"].max()
            else:
                period_start = cash_df["date"].min()
                period_end = cash_df["date"].max()

        # Filter Bank Transactions within range
        if not bank_df.empty and period_start and period_end:
            bank_in_range_df = bank_df[
                (bank_df["date"] >= period_start) & (bank_df["date"] <= period_end)
            ]
        else:
            bank_in_range_df = bank_df

        # Filter Cash Expenses within the exact same statement/analytics range
        if not cash_df.empty and period_start and period_end:
            cash_in_range_df = cash_df[
                (cash_df["date"] >= period_start) & (cash_df["date"] <= period_end)
            ]
        else:
            cash_in_range_df = cash_df

        # Calculate Bank vs Cash Debits
        bank_expenses_df = bank_in_range_df[bank_in_range_df["cr_dr"] == "DR"] if not bank_in_range_df.empty else pd.DataFrame()
        bank_spending = float(bank_expenses_df["amount"].sum()) if not bank_expenses_df.empty else 0.0
        cash_spending = float(cash_in_range_df["amount"].sum()) if not cash_in_range_df.empty else 0.0
        total_spending = round(bank_spending + cash_spending, 2)
        total_expense = total_spending

        # Incomes and Transfers (from bank)
        income_df = bank_in_range_df[bank_in_range_df["cr_dr"] == "CR"] if not bank_in_range_df.empty else pd.DataFrame()
        transfers_df = bank_in_range_df[bank_in_range_df["transaction_type"] == "transfer"] if not bank_in_range_df.empty else pd.DataFrame()

        total_income = float(income_df["amount"].sum()) if not income_df.empty else 0.0
        total_transfers = float(transfers_df["amount"].sum()) if not transfers_df.empty else 0.0
        net_savings = round(total_income - total_expense, 2)

        # Date range & daily average
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
            period_str = "No activity in period"

        # Month-over-month (combining bank and cash expenses)
        all_expenses_list = []
        if not bank_expenses_df.empty:
            all_expenses_list.append(bank_expenses_df[["date_dt", "amount"]])
        if not cash_in_range_df.empty:
            all_expenses_list.append(cash_in_range_df[["date_dt", "amount"]])

        if all_expenses_list:
            combined_exp_df = pd.concat(all_expenses_list)
            monthly_exp = combined_exp_df.groupby(combined_exp_df["date_dt"].dt.to_period("M"))["amount"].sum()
            months_list = sorted(monthly_exp.index)
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

        # Unified Category Breakdown
        categories_breakdown = self.get_category_spending(
            user_id=user_id,
            start_date=period_start,
            end_date=period_end
        )

        # Top Merchants (bank only)
        top_merchants = self.get_merchant_spending(user_id)[:10]

        # Recurring Expenses (bank only)
        recurring = self.get_recurring_expenses(user_id)

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
            "total_spending": total_spending
        }

    def get_monthly_spending(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Returns chronological monthly breakdown of income and expenses,
        combining bank spending and cash spending by month based on expense_date.
        """
        bank_df = self._get_user_transactions_df(user_id)
        cash_df = self._get_user_cash_expenses_df(user_id)

        if bank_df.empty and cash_df.empty:
            return []

        # Effective date range: if statements exist, match statement period
        period_start = start_date
        period_end = end_date
        if not period_start or not period_end:
            stmt_start, stmt_end = self._get_statement_date_bounds(user_id)
            if stmt_start and stmt_end:
                period_start = stmt_start
                period_end = stmt_end

        if not bank_df.empty and period_start and period_end:
            bank_df = bank_df[(bank_df["date"] >= period_start) & (bank_df["date"] <= period_end)]
        if not cash_df.empty and period_start and period_end:
            cash_df = cash_df[(cash_df["date"] >= period_start) & (cash_df["date"] <= period_end)]

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

            bank_exp = float(b_group[b_group["cr_dr"] == "DR"]["amount"].sum()) if not b_group.empty else 0.0
            cash_exp = float(c_group["amount"].sum()) if not c_group.empty else 0.0
            bank_inc = float(b_group[b_group["cr_dr"] == "CR"]["amount"].sum()) if not b_group.empty else 0.0

            total_exp = round(bank_exp + cash_exp, 2)
            total_inc = round(bank_inc, 2)
            txn_count = len(b_group) + len(c_group)

            dt = ym.to_timestamp()
            monthly_items.append({
                "month": str(ym),
                "month_name": dt.strftime("%B %Y"),
                "total_expense": total_exp,
                "total_income": total_inc,
                "net_savings": round(total_inc - total_exp, 2),
                "transaction_count": txn_count,
                "bank_expense": round(bank_exp, 2),
                "cash_expense": round(cash_exp, 2)
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
        """
        bank_df = self._get_user_transactions_df(user_id)
        cash_df = self._get_user_cash_expenses_df(user_id)

        # Apply date range filtering if applicable
        if not start_date or not end_date:
            stmt_start, stmt_end = self._get_statement_date_bounds(user_id)
            if not bank_df.empty:
                start_date = stmt_start or bank_df["date"].min()
                end_date = stmt_end or bank_df["date"].max()
            elif not cash_df.empty:
                start_date = cash_df["date"].min()
                end_date = cash_df["date"].max()

        if not bank_df.empty and start_date and end_date:
            bank_df = bank_df[(bank_df["date"] >= start_date) & (bank_df["date"] <= end_date)]
        if not cash_df.empty and start_date and end_date:
            cash_df = cash_df[(cash_df["date"] >= start_date) & (cash_df["date"] <= end_date)]

        bank_exp_df = bank_df[bank_df["cr_dr"] == "DR"] if not bank_df.empty else pd.DataFrame()

        # Collect all unique categories
        categories = set()
        if not bank_exp_df.empty:
            categories.update(bank_exp_df["category"].dropna().unique())
        if not cash_df.empty:
            categories.update(cash_df["category"].dropna().unique())

        if not categories:
            return []

        # Sum per category
        bank_cat_sums = bank_exp_df.groupby("category")["amount"].sum().to_dict() if not bank_exp_df.empty else {}
        bank_cat_counts = bank_exp_df.groupby("category")["id"].count().to_dict() if not bank_exp_df.empty else {}

        cash_cat_sums = cash_df.groupby("category")["amount"].sum().to_dict() if not cash_df.empty else {}
        cash_cat_counts = cash_df.groupby("category")["id"].count().to_dict() if not cash_df.empty else {}

        rows = []
        overall_total = 0.0

        for cat in categories:
            b_amt = float(bank_cat_sums.get(cat, 0.0))
            c_amt = float(cash_cat_sums.get(cat, 0.0))
            tot_amt = round(b_amt + c_amt, 2)
            tot_count = int(bank_cat_counts.get(cat, 0)) + int(cash_cat_counts.get(cat, 0))
            overall_total += tot_amt
            rows.append({
                "category": str(cat),
                "amount": tot_amt,
                "transaction_count": tot_count,
                "bank_amount": round(b_amt, 2),
                "cash_amount": round(c_amt, 2)
            })

        # Calculate percentages and sort descending
        results = []
        for r in sorted(rows, key=lambda x: x["amount"], reverse=True):
            pct = round((r["amount"] / overall_total) * 100.0, 1) if overall_total > 0 else 0.0
            r["percentage"] = pct
            results.append(r)

        return results

    def get_merchant_spending(self, user_id: str) -> List[Dict[str, Any]]:
        """Returns top bank merchants ranked by total expenditure."""
        df = self._get_user_transactions_df(user_id)
        if df.empty:
            return []

        exp_df = df[df["cr_dr"] == "DR"]
        if exp_df.empty:
            return []

        total_exp = exp_df["amount"].sum()
        grouped = exp_df.groupby(["merchant", "category"]).agg(
            total_amount=("amount", "sum"),
            txn_count=("id", "count")
        ).reset_index()

        grouped = grouped.sort_values(by="total_amount", ascending=False)

        results = []
        for _, row in grouped.iterrows():
            amt = float(row["total_amount"])
            pct = round((amt / total_exp) * 100.0, 1) if total_exp > 0 else 0.0
            merchant_name = str(row["merchant"])
            results.append({
                "merchant": merchant_name,
                "canonical_name": merchant_name,
                "category": str(row["category"]),
                "total_amount": round(amt, 2),
                "transaction_count": int(row["txn_count"]),
                "percentage_of_total": pct
            })
        return results

    def get_recurring_expenses(self, user_id: str) -> List[Dict[str, Any]]:
        """Identifies repeating monthly / periodic expenses (PRD Section 26)."""
        df = self._get_user_transactions_df(user_id)
        if df.empty:
            return []

        exp_df = df[df["cr_dr"] == "DR"]
        if exp_df.empty:
            return []

        recurring_list = []
        for merchant, group in exp_df.groupby("merchant"):
            if len(group) >= 2:
                dates = sorted(group["date_dt"].tolist())
                diffs = [(dates[i+1] - dates[i]).days for i in range(len(dates)-1)]
                avg_interval = np.mean(diffs) if diffs else 0
                
                if 20 <= avg_interval <= 35 or len(group) >= 3:
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
