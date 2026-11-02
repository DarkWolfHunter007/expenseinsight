import importlib.util
import os

SPEC = importlib.util.spec_from_file_location(
    "compare_with_chatgpt", os.path.join(os.path.dirname(__file__), "..", "..", "tools", "compare_with_chatgpt.py")
)
compare = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compare)


def row(date, typ, amount, balance, category=""):
    return {"date": date, "type": typ, "amount": amount, "balance": balance, "category": category,
            "description": "", "uncertain": False, "n": 0}


def test_dates_are_accepted_in_common_formats():
    assert compare.norm_date("2026-08-04") == "2026-08-04"
    assert compare.norm_date("04-08-2026") == "2026-08-04"
    assert compare.norm_date("4/8/2026") == "2026-08-04"


def test_amounts_ignore_currency_signs_and_commas():
    assert compare.money("₹1,234.50") == 1234.5
    assert compare.money(None) == 0.0


def test_totals_follow_the_apps_rules():
    rows = [
        row("2026-08-01", "DR", 100.0, 900.0, "Food"),
        row("2026-08-02", "DR", 500.0, 400.0, "Transfers"),
        row("2026-08-03", "DR", 200.0, 200.0, "Cash Withdrawal"),
        row("2026-08-04", "CR", 1000.0, 1200.0, "Income"),
        row("2026-08-05", "CR", 300.0, 1500.0, "Transfers"),
    ]
    totals = compare.totals_from_rows(rows)
    assert totals["money_out"] == 800.0
    assert totals["money_in"] == 1300.0
    assert totals["spending"] == 100.0          # not transfers, not cash withdrawals
    assert totals["transfers_out"] == 500.0 and totals["transfers_in"] == 300.0
    assert totals["cash_withdrawals"] == 200.0
    assert totals["income"] == 1000.0           # credits that are not transfers


def test_rows_are_matched_and_leftovers_reported():
    gpt = [row("2026-08-01", "DR", 100.0, 900.0), row("2026-08-02", "DR", 50.0, 850.0), row("2026-08-03", "CR", 10.0, 860.0)]
    app = [row("2026-08-01", "DR", 100.0, 900.0), row("2026-08-02", "DR", 55.0, 845.0)]
    pairs, only_gpt, only_app = compare.match_rows(gpt, app)
    assert len(pairs) == 1
    assert [(r["date"], r["amount"]) for r in only_gpt] == [("2026-08-02", 50.0), ("2026-08-03", 10.0)]
    assert [(r["date"], r["amount"]) for r in only_app] == [("2026-08-02", 55.0)]


def test_identical_rows_on_one_day_use_the_balance_to_pair_up():
    gpt = [row("2026-08-01", "DR", 20.0, 980.0), row("2026-08-01", "DR", 20.0, 960.0)]
    app = [row("2026-08-01", "DR", 20.0, 960.0), row("2026-08-01", "DR", 20.0, 980.0)]
    pairs, only_gpt, only_app = compare.match_rows(gpt, app)
    assert not only_gpt and not only_app
    assert all(g["balance"] == a["balance"] for g, a in pairs)


def test_json_wrapped_in_a_code_fence_and_text_is_read(tmp_path):
    path = tmp_path / "answer.json"
    path.write_text('Here you go:\n```json\n{"transactions": [], "totals": {}}\n```\nDone.', encoding="utf-8")
    assert compare.load_chatgpt(str(path)) == {"transactions": [], "totals": {}}
