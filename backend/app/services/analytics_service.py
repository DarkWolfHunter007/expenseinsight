from collections import defaultdict
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional
import pandas as pd
import numpy as np
from sqlalchemy.orm import Session

from ..models.db_models import Transaction, Statement

class AnalyticsService:
    """
    Computes spending analytics, trends, recurring subscriptions conforming to PRD Section 25 & 26.
    """

    def __init__(self, db: Session):
        self.db = db

    def _get_user_transactions_df(self, user_id: str) -> pd.DataFrame:
        """Fetches user transactions and returns as Pandas DataFrame."""
        txns = self.db.query(Transaction).filter(Transaction.user_id == user_id).all()
        if not txns:
            return pd.DataFrame()

        data = []
        for t in txns:
            data.append({
                "id": t.id,
                "date": t.date,
                "amount": t.amount,
                "category": t.category,
                "merchant": t.merchant or "Unknown",
                "normalized_merchant": t.normalized_merchant or "unknown",
                "transaction_type": t.transaction_type,
                "cr_dr": t.cr_dr,
                "needs_review": t.needs_review,
                "created_at": t.created_at
            })

        df = pd.DataFrame(data)
        df["date_dt"] = pd.to_datetime(df["date"])
        df = df.sort_values(by="date_dt")
        return df

    def get_summary(self, user_id: str) -> Dict[str, Any]:
        """Calculates high-level spending analytics summary."""
        df = self._get_user_transactions_df(user_id)
        if df.empty:
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
                "statement_period": "No statements uploaded",
                "categories_breakdown": [],
                "top_merchants": [],
                "recurring_expenses": []
            }

        # Filter expense vs income
        expenses_df = df[df["cr_dr"] == "DR"]
        income_df = df[df["cr_dr"] == "CR"]
        transfers_df = df[df["transaction_type"] == "transfer"]

        total_expense = float(expenses_df["amount"].sum()) if not expenses_df.empty else 0.0
        total_income = float(income_df["amount"].sum()) if not income_df.empty else 0.0
        total_transfers = float(transfers_df["amount"].sum()) if not transfers_df.empty else 0.0
        net_savings = round(total_income - total_expense, 2)

        # Date range & daily average
        min_date = df["date_dt"].min()
        max_date = df["date_dt"].max()
        days_span = max(1, (max_date - min_date).days + 1)
        avg_daily = round(total_expense / days_span, 2)
        period_str = f"{min_date.strftime('%b %d, %Y')} - {max_date.strftime('%b %d, %Y')}"

        # This month vs previous month
        df["year_month"] = df["date_dt"].dt.to_period("M")
        monthly_exp = expenses_df.groupby(expenses_df["date_dt"].dt.to_period("M"))["amount"].sum()
        
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

        # Category Breakdown
        categories_breakdown = self.get_category_spending(user_id)
        # Top Merchants
        top_merchants = self.get_merchant_spending(user_id)[:10]
        # Recurring Expenses
        recurring = self.get_recurring_expenses(user_id)

        return {
            "total_expense": round(total_expense, 2),
            "total_income": round(total_income, 2),
            "total_transfers": round(total_transfers, 2),
            "net_savings": net_savings,
            "this_month_spent": round(this_month_spent, 2),
            "previous_month_spent": round(prev_month_spent, 2),
            "month_over_month_change_pct": mom_change,
            "average_daily_spend": avg_daily,
            "total_transactions_count": len(df),
            "statement_period": period_str,
            "categories_breakdown": categories_breakdown,
            "top_merchants": top_merchants,
            "recurring_expenses": recurring
        }

    def get_monthly_spending(self, user_id: str) -> List[Dict[str, Any]]:
        """Returns chronological monthly breakdown of income and expenses."""
        df = self._get_user_transactions_df(user_id)
        if df.empty:
            return []

        df["year_month"] = df["date_dt"].dt.to_period("M")
        
        monthly_items = []
        for ym, group in df.groupby("year_month"):
            exp = float(group[group["cr_dr"] == "DR"]["amount"].sum())
            inc = float(group[group["cr_dr"] == "CR"]["amount"].sum())
            dt = ym.to_timestamp()
            monthly_items.append({
                "month": str(ym),
                "month_name": dt.strftime("%B %Y"),
                "total_expense": round(exp, 2),
                "total_income": round(inc, 2),
                "net_savings": round(inc - exp, 2),
                "transaction_count": len(group)
            })

        return sorted(monthly_items, key=lambda x: x["month"])

    def get_category_spending(self, user_id: str) -> List[Dict[str, Any]]:
        """Returns aggregated spending per category with percentage share."""
        df = self._get_user_transactions_df(user_id)
        if df.empty:
            return []

        exp_df = df[df["cr_dr"] == "DR"]
        if exp_df.empty:
            return []

        total_exp = exp_df["amount"].sum()
        grouped = exp_df.groupby("category").agg(
            total_amount=("amount", "sum"),
            txn_count=("id", "count")
        ).reset_index()

        grouped = grouped.sort_values(by="total_amount", ascending=False)

        results = []
        for _, row in grouped.iterrows():
            amt = float(row["total_amount"])
            pct = round((amt / total_exp) * 100.0, 1) if total_exp > 0 else 0.0
            results.append({
                "category": str(row["category"]),
                "amount": round(amt, 2),
                "percentage": pct,
                "transaction_count": int(row["txn_count"])
            })
        return results

    def get_merchant_spending(self, user_id: str) -> List[Dict[str, Any]]:
        """Returns top merchants ranked by total expenditure."""
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
                # Check intervals between dates
                dates = sorted(group["date_dt"].tolist())
                diffs = [(dates[i+1] - dates[i]).days for i in range(len(dates)-1)]
                avg_interval = np.mean(diffs) if diffs else 0
                
                # If interval is roughly monthly (20-35 days) or regular
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
