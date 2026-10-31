from datetime import date

import pandas as pd

from backend.app.services.analytics_service import AnalyticsService


def _df(rows):
    df = pd.DataFrame(rows, columns=["date", "amount"])
    df["date_dt"] = pd.to_datetime(df["date"])
    df["transaction_type"] = "expense"
    df["cr_dr"] = "DR"
    df["source"] = "bank"
    df["category"] = "Food"
    df["normalized_merchant"] = "shop"
    return df


# 31 days of baseline at 100/day -> about 3,044 per average month
BASELINE = _df([(f"2026-01-{d:02d}", 100.0) for d in range(1, 32)])
EMPTY = pd.DataFrame(columns=["date", "amount", "date_dt"])


def _budget(cash_rows, as_of):
    cash = _df(cash_rows) if cash_rows else EMPTY
    return AnalyticsService(db=None)._compute_budget("u", BASELINE, cash, as_of)


def test_budget_is_average_monthly_spend_of_the_baseline():
    result = _budget([], date(2026, 2, 10))
    assert result["monthly_budget"] == round(3100.0 / 31 * 30.4375, 2)
    assert result["budget_status"] == "on_track"
    assert result["budget_spent"] == 0.0


def test_cash_this_month_counts_against_budget():
    result = _budget([("2026-02-05", 1000.0)], date(2026, 2, 10))
    assert result["budget_spent"] == 1000.0
    assert result["budget_remaining"] == round(result["monthly_budget"] - 1000.0, 2)


def test_warning_near_the_limit():
    result = _budget([("2026-02-05", 2600.0)], date(2026, 2, 10))
    assert result["budget_status"] == "warning"


def test_exceeded_over_the_limit():
    result = _budget([("2026-02-05", 3500.0)], date(2026, 2, 10))
    assert result["budget_status"] == "exceeded"
    assert result["budget_used_pct"] > 100.0
    assert result["budget_remaining"] < 0


def test_other_months_do_not_count():
    result = _budget([("2026-01-20", 5000.0)], date(2026, 2, 10))
    assert result["budget_spent"] == 0.0


def test_no_baseline_means_no_budget():
    result = AnalyticsService(db=None)._compute_budget("u", EMPTY, EMPTY, date(2026, 2, 10))
    assert result["budget_status"] == "none"
    assert result["monthly_budget"] == 0.0
