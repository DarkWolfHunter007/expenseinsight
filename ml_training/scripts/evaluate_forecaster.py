import os
import sys
from datetime import datetime, timedelta
import pandas as pd
import numpy as np

# Ensure UTF-8 stdout on Windows console
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Add project root and ml_training to sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from backend.ml.forecasting.forecaster import ExpenseForecaster
from ml_training.evaluation.metrics import evaluate_forecast_predictions
from ml_training.datasets.synthetic_generator import generate_synthetic_transactions

def run_forecaster_evaluation():
    print("=" * 60)
    print("ExpenseInsight Forecaster Evaluation (PRD Section 40)")
    print("=" * 60)

    forecaster = ExpenseForecaster()

    # Generate 6 months of historical transactions
    start_date = datetime(2026, 1, 1)
    df = generate_synthetic_transactions(num_records=4000, start_date=start_date)
    transactions = df.to_dict(orient="records")

    forecast_result = forecaster.generate_forecast(transactions)

    print(f"Status: {forecast_result['status']} (Confidence: {forecast_result['confidence_level']})")
    print(f"History Length: {forecast_result['historical_months_count']} months")
    print(f"\nNext Month Projected Spending: ₹{forecast_result['total_forecast']:,.2f}")
    print(f"Confidence Range (90% CI): ₹{forecast_result['lower_bound']:,.2f} - ₹{forecast_result['upper_bound']:,.2f}")
    print(f"Next 7 Days Projected: ₹{forecast_result['next_7_days_forecast']:,.2f}")
    print(f"Next 30 Days Projected: ₹{forecast_result['next_30_days_forecast']:,.2f}")

    print("\nCategory-wise Forecast Breakdown:")
    print("-" * 60)
    for cat, data in forecast_result["category_forecasts"].items():
        print(f"  {cat:<15}: Predicted: ₹{data['predicted_amount']:>8,.2f} | Range: [₹{data['lower_bound']:>8,.2f} - ₹{data['upper_bound']:>8,.2f}] | Trend: {data['trend_percentage']:+5.1f}%")

    print("\nExplanations:")
    for b in forecast_result["explanation_bullets"]:
        print(f"  • {b}")

    # Backtesting simulation: simulate 5 months historical -> predict month 6 and compare with actual
    print("\n" + "=" * 60)
    print("Backtesting Simulation (Month 1-5 -> Predict Month 6)")
    print("=" * 60)

    # Filter transactions for first 5 months vs 6th month
    df["dt"] = pd.to_datetime(df["date"])
    month_6_start = start_date + timedelta(days=150)
    
    train_txns = df[df["dt"] < month_6_start].to_dict(orient="records")
    actual_m6_txns = df[(df["dt"] >= month_6_start) & (df["transaction_type"] == "expense")]
    actual_m6_total = actual_m6_txns["amount"].sum()

    m6_forecast = forecaster.generate_forecast(train_txns)
    pred_m6_total = m6_forecast["total_forecast"]

    metrics = evaluate_forecast_predictions([actual_m6_total], [pred_m6_total])
    print(f"Actual Month 6 Total Expense:    ₹{actual_m6_total:,.2f}")
    print(f"Predicted Month 6 Total Expense: ₹{pred_m6_total:,.2f}")
    print(f"Absolute Error (MAE):            ₹{metrics['mae']:,.2f}")
    print(f"Percentage Error (MAPE):         {metrics['mape']:.2f}%")
    print("=" * 60)

if __name__ == "__main__":
    run_forecaster_evaluation()
