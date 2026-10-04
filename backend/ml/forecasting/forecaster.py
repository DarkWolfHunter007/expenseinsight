from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple
import numpy as np
import pandas as pd
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tsa.holtwinters import SimpleExpSmoothing, ExponentialSmoothing


class ExpenseForecaster:
    """
    ARIMA and time-series expense forecasting engine conforming to the proposed methodology
    and PRD Sections 27-31.
    """

    MIN_MONTHS_REQUIRED = 1
    CONFIDENT_MONTHS_THRESHOLD = 3
    STANDARD_MONTHS_THRESHOLD = 6

    def __init__(self, smoothing_level: float = 0.4):
        self.smoothing_level = smoothing_level

    def _prepare_monthly_category_matrix(self, transactions: List[Dict[str, Any]]) -> pd.DataFrame:
        """
        Converts list of transaction dicts into a monthly aggregated dataframe by category.
        Filters for expense transactions only (excluding income and internal transfers).
        """
        if not transactions:
            return pd.DataFrame()

        df = pd.DataFrame(transactions)
        
        # Ensure date format
        if "date" in df.columns:
            df["date_dt"] = pd.to_datetime(df["date"])
        else:
            return pd.DataFrame()

        # Exclude income and transfers from spending forecast
        if "transaction_type" in df.columns:
            df = df[df["transaction_type"].isin(["expense", "debit", "DR", "dr"])]
        
        if "category" in df.columns:
            df = df[~df["category"].fillna("").astype(str).str.lower().isin(["income", "transfer", "transfers", "cash withdrawal", "cash_withdrawal"])]

        if df.empty:
            return pd.DataFrame()

        # Group by Month (YYYY-MM) and Category
        df["year_month"] = df["date_dt"].dt.to_period("M")
        pivot = df.pivot_table(
            index="year_month",
            columns="category",
            values="amount",
            aggfunc="sum",
            fill_value=0.0
        )
        pivot = pivot.sort_index()
        return pivot

    def _forecast_series(self, values: np.ndarray, horizon: int = 1) -> Tuple[float, float, float]:
        """
        Forecasts next value(s) for a 1D sequence of monthly expenses using ARIMA (statsmodels).
        Returns: (predicted_amount, lower_bound, upper_bound)
        """
        if len(values) == 0:
            return (0.0, 0.0, 0.0)
        
        if len(values) == 1:
            val = float(values[0])
            return (round(val, 2), round(val * 0.75, 2), round(val * 1.25, 2))

        if len(values) == 2:
            # Weighted average favoring recent month
            pred = float(0.65 * values[-1] + 0.35 * values[-2])
            std = float(abs(values[-1] - values[-2]) * 0.5)
            lower = max(0.0, pred - 1.5 * std)
            upper = pred + 1.5 * std
            return (round(pred, 2), round(lower, 2), round(upper, 2))

        # 3 or more historical points: ARIMA Model (p, d, q)
        pred = None
        lower = None
        upper = None

        try:
            # Attempt ARIMA(1, 1, 0) or ARIMA(1, 0, 0)
            order = (1, 1, 0) if len(values) >= 4 else (1, 0, 0)
            arima_model = ARIMA(
                values,
                order=order,
                enforce_stationarity=False,
                enforce_invertibility=False
            )
            fitted_arima = arima_model.fit()
            fc_res = fitted_arima.get_forecast(steps=horizon)
            pred = float(fc_res.predicted_mean[-1])
            
            # Extract 90% confidence interval
            conf_int = fc_res.conf_int(alpha=0.10)
            lower = max(0.0, float(conf_int[-1, 0]))
            upper = float(conf_int[-1, 1])
        except Exception:
            # Fallback to Exponential Smoothing / Moving Average if ARIMA encounter singularity
            try:
                if len(values) >= 4 and np.all(values > 0):
                    model = ExponentialSmoothing(values, trend="add", seasonal=None, initialization_method="estimated")
                    fitted = model.fit()
                    pred = float(fitted.forecast(horizon)[-1])
                else:
                    model = SimpleExpSmoothing(values, initialization_method="estimated")
                    fitted = model.fit(smoothing_level=self.smoothing_level, optimized=False)
                    pred = float(fitted.forecast(horizon)[-1])
            except Exception:
                weights = np.arange(1, len(values) + 1)
                pred = float(np.average(values, weights=weights))

        pred = max(0.0, pred)
        if lower is None or upper is None:
            residuals = np.diff(values)
            std_dev = float(np.std(residuals)) if len(residuals) > 0 else pred * 0.15
            lower = max(0.0, pred - 1.645 * std_dev)
            upper = pred + 1.645 * std_dev

        return (round(pred, 2), round(lower, 2), round(upper, 2))


    def generate_forecast(self, transactions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Generates full next-month forecast, category breakdown, 7-day and 30-day projections.
        """
        pivot = self._prepare_monthly_category_matrix(transactions)
        
        num_months = len(pivot)
        if num_months == 0:
            return {
                "status": "insufficient_data",
                "message": "No transaction history available to generate forecast.",
                "total_forecast": 0.0,
                "confidence_level": "none",
                "categories": {},
                "explanation": "Upload at least 1 month of statements to see forecasts."
            }

        # Confidence status based on months
        if num_months < self.CONFIDENT_MONTHS_THRESHOLD:
            status = "low_history"
            confidence_level = "low"
            status_message = f"Preliminary estimate based on {num_months} month(s) of data."
        elif num_months < self.STANDARD_MONTHS_THRESHOLD:
            status = "medium_history"
            confidence_level = "medium"
            status_message = f"Forecast based on {num_months} months of historical spending."
        else:
            status = "ready"
            confidence_level = "high"
            status_message = f"Reliable forecast calculated from {num_months} months of statement history."

        category_forecasts = {}
        total_predicted = 0.0
        total_lower = 0.0
        total_upper = 0.0

        for cat in pivot.columns:
            series = pivot[cat].values
            pred, lower, upper = self._forecast_series(series)
            
            # Historical statistics
            recent_avg = float(np.mean(series[-3:])) if len(series) >= 3 else float(np.mean(series))
            last_month_val = float(series[-1])
            trend_pct = round(((last_month_val - recent_avg) / (recent_avg + 1e-5)) * 100, 1)

            category_forecasts[cat] = {
                "predicted_amount": pred,
                "lower_bound": lower,
                "upper_bound": upper,
                "historical_recent_avg": round(recent_avg, 2),
                "last_month_spent": round(last_month_val, 2),
                "trend_percentage": trend_pct,
                "historical_months": len(series)
            }
            total_predicted += pred
            total_lower += lower
            total_upper += upper

        total_predicted = round(total_predicted, 2)
        total_lower = round(total_lower, 2)
        total_upper = round(total_upper, 2)

        # Projections
        next_7_days = round((total_predicted / 30.0) * 7.0, 2)
        next_30_days = total_predicted

        # Generate clear, human-readable explanations based on model inputs
        top_cats = sorted(category_forecasts.items(), key=lambda x: x[1]["predicted_amount"], reverse=True)[:3]
        top_cat_names = [f"{cat} (₹{data['predicted_amount']:,.0f})" for cat, data in top_cats if data["predicted_amount"] > 0]
        
        explanation_bullets = [
            f"Expected total next month spending: ₹{total_predicted:,.0f} (range: ₹{total_lower:,.0f} – ₹{total_upper:,.0f}).",
            f"Major spending categories: {', '.join(top_cat_names)}." if top_cat_names else "Balanced across categories.",
            f"Based on exponential smoothing over {num_months} month(s) of transaction patterns.",
            f"Estimated next 7 days spending: ₹{next_7_days:,.0f}."
        ]

        return {
            "status": status,
            "confidence_level": confidence_level,
            "status_message": status_message,
            "historical_months_count": num_months,
            "total_forecast": total_predicted,
            "lower_bound": total_lower,
            "upper_bound": total_upper,
            "next_7_days_forecast": next_7_days,
            "next_30_days_forecast": next_30_days,
            "category_forecasts": category_forecasts,
            "explanation": " ".join(explanation_bullets),
            "explanation_bullets": explanation_bullets
        }
