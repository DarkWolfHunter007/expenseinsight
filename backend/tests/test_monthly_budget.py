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


# ---- critical tier, manual limits, categories, daily allowance, recap, settings API

AUTO = {"auto_limits": True, "monthly_limit": None, "category_limits": {}}


def _budget_with(settings, cash_rows, as_of):
    cash = _df(cash_rows) if cash_rows else EMPTY
    return AnalyticsService(db=None)._compute_budget("u", BASELINE, cash, as_of, settings=settings)


def test_critical_between_ninety_and_hundred_percent():
    result = _budget_with(AUTO, [("2026-02-05", 2900.0)], date(2026, 2, 10))
    assert 90.0 <= result["budget_used_pct"] <= 100.0
    assert result["budget_status"] == "critical"


def test_manual_monthly_limit_overrides_automatic_figure():
    settings = {"auto_limits": True, "monthly_limit": 1000.0, "category_limits": {}}
    result = _budget_with(settings, [("2026-02-05", 950.0)], date(2026, 2, 10))
    assert result["monthly_budget"] == 1000.0
    assert result["budget_status"] == "critical"


def test_manual_mode_uses_only_preapproved_limits():
    settings = {"auto_limits": False, "monthly_limit": None, "category_limits": {"Food": 500.0, "Travel": 300.0}}
    result = _budget_with(settings, [], date(2026, 2, 10))
    assert result["budget_mode"] == "manual"
    assert result["monthly_budget"] == 800.0
    assert {c["category"] for c in result["category_budgets"]} == {"Food", "Travel"}


def test_manual_mode_without_any_limit_has_no_budget():
    settings = {"auto_limits": False, "monthly_limit": None, "category_limits": {}}
    assert _budget_with(settings, [], date(2026, 2, 10))["budget_status"] == "none"


def test_category_budget_tracks_its_own_spending():
    settings = {"auto_limits": False, "monthly_limit": 5000.0, "category_limits": {"Food": 500.0}}
    result = _budget_with(settings, [("2026-02-05", 480.0)], date(2026, 2, 10))
    food = result["category_budgets"][0]
    assert food["category"] == "Food"
    assert food["spent"] == 480.0
    assert food["status"] == "critical"


def test_safe_to_spend_today_divides_remaining_by_days_left():
    result = _budget_with(AUTO, [("2026-02-05", 1000.0)], date(2026, 2, 10))
    days_left = 28 - 10 + 1
    assert result["days_left_in_month"] == days_left
    assert result["safe_to_spend_today"] == round(result["budget_remaining"] / days_left, 2)


def test_safe_to_spend_is_zero_once_exceeded():
    result = _budget_with(AUTO, [("2026-02-05", 9000.0)], date(2026, 2, 10))
    assert result["budget_status"] == "exceeded"
    assert result["safe_to_spend_today"] == 0.0


def test_month_end_recap_only_in_first_days_of_next_month():
    early = _budget_with(AUTO, [("2026-02-05", 1000.0)], date(2026, 3, 2))
    assert early["last_month_recap"]["month"] == "2026-02"
    assert early["last_month_recap"]["under_budget"] is True
    assert early["last_month_recap"]["spent"] == 1000.0

    late = _budget_with(AUTO, [("2026-02-05", 1000.0)], date(2026, 3, 20))
    assert late["last_month_recap"] is None


def test_recap_reports_overspend():
    result = _budget_with(AUTO, [("2026-02-05", 9000.0)], date(2026, 3, 2))
    assert result["last_month_recap"]["under_budget"] is False
    assert result["last_month_recap"]["difference"] < 0


def _headers():
    from fastapi.testclient import TestClient
    from backend.app.main import app

    client = TestClient(app)
    token = client.post("/auth/guest").json()["access_token"]
    return client, {"Authorization": f"Bearer {token}"}


def test_settings_default_to_automatic():
    client, headers = _headers()
    body = client.get("/budget/settings", headers=headers).json()
    assert body == {"auto_limits": True, "monthly_limit": None, "category_limits": {}}


def test_settings_round_trip_and_are_per_user():
    client, headers = _headers()
    saved = client.put(
        "/budget/settings",
        json={"auto_limits": False, "monthly_limit": 4000, "category_limits": {" Food ": 1500, "Travel": 0}},
        headers=headers,
    )
    assert saved.status_code == 200
    assert saved.json()["category_limits"] == {"Food": 1500.0}
    assert client.get("/budget/settings", headers=headers).json()["monthly_limit"] == 4000.0

    _, other_headers = _headers()
    assert client.get("/budget/settings", headers=other_headers).json()["auto_limits"] is True


def test_settings_reject_negative_limits():
    client, headers = _headers()
    res = client.put("/budget/settings", json={"monthly_limit": -5}, headers=headers)
    assert res.status_code == 422
    res = client.put("/budget/settings", json={"category_limits": {"Food": -1}}, headers=headers)
    assert res.status_code == 422


def test_summary_reflects_saved_manual_limit():
    client, headers = _headers()
    client.put("/budget/settings", json={"auto_limits": False, "monthly_limit": 1000}, headers=headers)
    client.post("/cash-expenses", json={"amount": 950, "category": "Food", "expense_date": date.today().isoformat()}, headers=headers)
    summary = client.get("/analytics/summary", headers=headers).json()
    assert summary["monthly_budget"] == 1000.0
    assert summary["budget_status"] == "critical"


# ---- forecast input: gaps filled, partly covered months left out

def _txn(day, amount, category="Food"):
    return {"date": day, "amount": amount, "category": category, "transaction_type": "expense", "cr_dr": "DR"}


def _forecaster():
    from backend.ml.forecasting.forecaster import ExpenseForecaster

    return ExpenseForecaster()


FULL_MONTHS = [_txn(f"2026-{m:02d}-15", 100.0 * m) for m in (1, 2, 3, 4, 5)]


def test_forecast_fills_a_missing_month_with_zero():
    txns = [_txn("2026-01-15", 100), _txn("2026-02-15", 100), _txn("2026-04-15", 100), _txn("2026-05-15", 100)]
    pivot = _forecaster()._prepare_monthly_category_matrix(txns, ("2026-01-01", "2026-05-31"))
    assert [str(p) for p in pivot.index] == ["2026-01", "2026-02", "2026-03", "2026-04", "2026-05"]
    assert pivot.loc["2026-03", "Food"] == 0.0


def test_forecast_leaves_out_a_partly_covered_last_month():
    txns = FULL_MONTHS + [_txn("2026-06-03", 50)]
    pivot = _forecaster()._prepare_monthly_category_matrix(txns, ("2026-01-01", "2026-06-04"))
    assert "2026-06" not in [str(p) for p in pivot.index]
    assert len(pivot) == 5


def test_forecast_leaves_out_a_partly_covered_first_month():
    txns = [_txn("2026-01-20", 50)] + [_txn(f"2026-{m:02d}-15", 100.0) for m in (2, 3, 4, 5)]
    pivot = _forecaster()._prepare_monthly_category_matrix(txns, ("2026-01-11", "2026-05-31"))
    assert "2026-01" not in [str(p) for p in pivot.index]


def _months(txns, coverage):
    pivot = _forecaster()._prepare_monthly_category_matrix(txns, coverage)
    return [str(p) for p in pivot.index]


def test_forecast_drops_a_thin_partial_month_when_history_is_short():
    # January is complete, February has 10 of its 28 days: it must not carry the two-month weighting
    txns = [_txn("2026-01-15", 100), _txn("2026-02-10", 100)]
    assert _months(txns, ("2026-01-01", "2026-02-10")) == ["2026-01"]


def test_forecast_keeps_a_partial_month_that_covers_at_least_half():
    txns = [_txn("2026-01-15", 100), _txn("2026-02-10", 100)]
    assert _months(txns, ("2026-01-01", "2026-02-20")) == ["2026-01", "2026-02"]  # 20 of 28 days


def test_forecast_treats_an_almost_full_month_as_complete():
    # a statement that starts on the 2nd still covers 30 of August's 31 days
    txns = [_txn("2026-08-03", 100), _txn("2026-09-02", 50)]
    assert _months(txns, ("2026-08-02", "2026-09-03")) == ["2026-08"]


def test_forecast_keeps_everything_when_no_month_is_complete():
    txns = [_txn("2026-01-20", 100), _txn("2026-01-25", 50)]
    assert _months(txns, ("2026-01-19", "2026-01-26")) == ["2026-01"]


def test_forecast_for_a_one_month_statement_ignores_the_three_day_tail():
    august = [_txn("2026-08-03", 1000), _txn("2026-08-20", 1468)]
    september = [_txn("2026-09-02", 118)]
    result = _forecaster().generate_forecast(august + september, ("2026-08-02", "2026-09-03"))
    assert result["historical_months_count"] == 1
    assert result["total_forecast"] == 2468.0  # August repeated, not 0.65 x 118 + 0.35 x 2468


def test_forecast_explanation_names_arima():
    result = _forecaster().generate_forecast(FULL_MONTHS, ("2026-01-01", "2026-05-31"))
    assert "ARIMA" in result["explanation"]
    assert "exponential smoothing" not in result["explanation"]
