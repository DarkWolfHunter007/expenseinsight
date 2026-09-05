import os
import sys
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..")))

from backend.ml.forecasting.forecaster import ExpenseForecaster
from ..models.db_models import Forecast, Transaction

class ForecastingService:
    """
    Forecasting service layer integrating database transactions with time-series ML models.
    """

    def __init__(self, db: Session):
        self.db = db
        self.forecaster = ExpenseForecaster()

    def generate_user_forecast(self, user_id: str, persist: bool = True) -> Dict[str, Any]:
        """
        Generates next month forecast for a user and stores results.
        Clears all stale forecast records if transactions are empty.
        """
        txns = self.db.query(Transaction).filter(Transaction.user_id == user_id).all()
        if not txns:
            if persist:
                self.db.query(Forecast).filter(Forecast.user_id == user_id).delete(synchronize_session=False)
                self.db.commit()

            return {
                "status": "insufficient_data",
                "confidence_level": "none",
                "status_message": "No transactions found for user.",
                "historical_months_count": 0,
                "total_forecast": 0.0,
                "lower_bound": 0.0,
                "upper_bound": 0.0,
                "next_7_days_forecast": 0.0,
                "next_30_days_forecast": 0.0,
                "category_forecasts": {},
                "explanation": "Upload at least 1-3 months of bank statements to generate forecasts.",
                "explanation_bullets": ["Upload bank statements to view predictive spending forecasts."]
            }

        # Convert to dicts for forecaster
        txn_dicts = [
            {
                "date": t.date,
                "amount": t.amount,
                "category": t.category,
                "transaction_type": t.transaction_type,
                "cr_dr": t.cr_dr
            }
            for t in txns
        ]

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
