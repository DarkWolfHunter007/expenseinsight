import os
import sys
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..")))

from backend.ml.forecasting.forecaster import ExpenseForecaster
from ..models.db_models import CashExpense, Forecast, Transaction
from .accounting import AccountingPolicy

class ForecastingService:
    """
    Forecasting service layer integrating database transactions and cash expenses with time-series ML models.
    """

    def __init__(self, db: Session):
        self.db = db
        self.forecaster = ExpenseForecaster()

    def generate_user_forecast(self, user_id: str, persist: bool = True) -> Dict[str, Any]:
        """
        Generates next month forecast for a user based on total personal spending
        (Bank Transactions + Cash Expenses) and stores results.
        Clears all stale forecast records if both transactions and cash expenses are empty.
        """
        txns = self.db.query(Transaction).filter(Transaction.user_id == user_id).all()
        cash_list = self.db.query(CashExpense).filter(CashExpense.user_id == user_id).all()

        if not txns and not cash_list:
            if persist:
                self.db.query(Forecast).filter(Forecast.user_id == user_id).delete(synchronize_session=False)
                self.db.commit()

            return {
                "status": "insufficient_data",
                "confidence_level": "none",
                "status_message": "No transactions or cash expenses found for user.",
                "historical_months_count": 0,
                "total_forecast": 0.0,
                "lower_bound": 0.0,
                "upper_bound": 0.0,
                "next_7_days_forecast": 0.0,
                "next_30_days_forecast": 0.0,
                "category_forecasts": {},
                "explanation": "Upload at least 1-3 months of bank statements or cash expenses to generate forecasts.",
                "explanation_bullets": ["Upload bank statements or record cash expenses to view predictive spending forecasts."]
            }

        # Convert bank transactions to dicts for forecaster, excluding transfers & cash withdrawals
        txn_dicts = [
            {
                "date": t.date,
                "amount": t.amount,
                "category": t.category,
                "transaction_type": "expense",
                "cr_dr": "DR"
            }
            for t in txns
            if AccountingPolicy.is_personal_expense(t)
        ]

        # Add manual cash expenses into total spending stream
        for c in cash_list:
            txn_dicts.append({
                "date": c.expense_date,
                "amount": c.amount,
                "category": c.category,
                "transaction_type": "expense",
                "cr_dr": "DR"
            })

        forecast_res = self.forecaster.generate_forecast(txn_dicts)

        # Optionally persist to database
        if persist:
            # Clear older forecasts for user
            self.db.query(Forecast).filter(Forecast.user_id == user_id).delete(synchronize_session=False)
            
            if forecast_res.get("category_forecasts"):
                for cat, data in forecast_res["category_forecasts"].items():
                    fc_record = Forecast(
                        user_id=user_id,
                        forecast_date="Next Month",
                        category=cat,
                        predicted_amount=data["predicted_amount"],
                        lower_bound=data["lower_bound"],
                        upper_bound=data["upper_bound"],
                        model_version="1.0.0"
                    )
                    self.db.add(fc_record)
            self.db.commit()

        return forecast_res
