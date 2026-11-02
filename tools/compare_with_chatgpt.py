"""
Compares ChatGPT's independent reading of a bank statement with what ExpenseInsight stored and calculated.

    python tools/compare_with_chatgpt.py --email you@example.com --chatgpt chatgpt_answer.json

See docs/CHATGPT_VERIFICATION.md for the prompt to give ChatGPT and how to read the report.
Uses only the standard library. The app must be running (default http://localhost:3000).
"""
import argparse
import collections
import json
import re
import sys
import urllib.error
import urllib.request

TOLERANCE = 0.01
TRANSFER = {"transfer", "transfers", "internal transfer", "self transfer"}
CASH_WITHDRAWAL = {"cash withdrawal", "atm withdrawal", "cash_withdrawal"}

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


# ----------------------------------------------------------------------------- loading

def load_chatgpt(path):
    text = open(path, encoding="utf-8-sig").read()
    try:
        return json.loads(text)
    except ValueError:
        pass
    # ChatGPT often wraps the JSON in a code fence or adds a sentence around it
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        sys.exit("Could not find a JSON object in the ChatGPT file.")
    try:
        return json.loads(text[start:end + 1])
    except ValueError as error:
        sys.exit(f"The ChatGPT file is not valid JSON: {error}")


def norm_date(value):
    value = str(value).strip()
    match = re.match(r"^(\d{4})-(\d{2})-(\d{2})", value)
    if match:
        return f"{match.group(1)}-{match.group(2)}-{match.group(3)}"
    match = re.match(r"^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$", value)
    if match:
        return f"{match.group(3)}-{int(match.group(2)):02d}-{int(match.group(1)):02d}"
    return value


def money(value):
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return round(float(value), 2)
    return round(float(re.sub(r"[^\d.\-]", "", str(value)) or 0), 2)


def normalize_gpt_rows(data):
    rows = []
    for index, t in enumerate(data.get("transactions", []), start=1):
        rows.append({
            "n": t.get("n", index),
            "date": norm_date(t.get("date", "")),
            "type": str(t.get("type", "")).strip().upper()[:2],
            "amount": money(t.get("amount")),
            "balance": money(t.get("balance")) if t.get("balance") is not None else None,
            "category": str(t.get("category") or "").strip(),
            "description": str(t.get("description") or ""),
            "uncertain": bool(t.get("uncertain")),
        })
    return rows


class App:
    def __init__(self, base_url, email):
        self.base = base_url.rstrip("/")
        body = json.dumps({"email": email}).encode()
        data = self._call("/auth/identify", body)
        self.token = data.get("access_token") or data.get("token")
        if not self.token:
            sys.exit("Could not sign in to the app with that email.")

    def _call(self, path, body=None):
        request = urllib.request.Request(self.base + path, data=body, headers={"Content-Type": "application/json"})
        if getattr(self, "token", None):
            request.add_header("Authorization", f"Bearer {self.token}")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.loads(response.read())
        except urllib.error.URLError as error:
            sys.exit(f"Could not reach the app at {self.base}: {error}. Is Docker running?")

    def get(self, path):
        return self._call(path)


def load_app_rows(app, statement_filter):
    statements = app.get("/statements")
    chosen = {
        s["id"]: s for s in statements
        if not statement_filter or statement_filter.lower() in (s.get("file_name") or "").lower()
    }
    if not chosen:
        sys.exit("The app has no statement" + (f" matching '{statement_filter}'." if statement_filter else " for this account."))
    raw = app.get("/transactions?limit=1000")
    items = raw if isinstance(raw, list) else raw.get("transactions", [])
    rows = []
    for t in items:
        if t.get("statement_id") not in chosen:
            continue
        rows.append({
            "date": norm_date(t["date"]),
            "type": str(t.get("cr_dr", "")).upper()[:2],
            "amount": money(t["amount"]),
            "balance": money(t["balance"]) if t.get("balance") is not None else None,
            "category": t.get("category") or "",
            "description": t.get("raw_description") or "",
        })
    return list(chosen.values()), rows


# ----------------------------------------------------------------------------- calculations

def cat(row):
    return row["category"].strip().lower()


def totals_from_rows(rows):
    out = sum(r["amount"] for r in rows if r["type"] == "DR")
    inn = sum(r["amount"] for r in rows if r["type"] == "CR")
    t_out = sum(r["amount"] for r in rows if r["type"] == "DR" and cat(r) in TRANSFER)
    t_in = sum(r["amount"] for r in rows if r["type"] == "CR" and cat(r) in TRANSFER)
    cash = sum(r["amount"] for r in rows if r["type"] == "DR" and cat(r) in CASH_WITHDRAWAL)
    return {
        "money_out": round(out, 2),
        "money_in": round(inn, 2),
        "transfers_out": round(t_out, 2),
        "transfers_in": round(t_in, 2),
        "cash_withdrawals": round(cash, 2),
        "spending": round(out - t_out - cash, 2),
        "income": round(inn - t_in, 2),
    }


def spending_rows(rows):
    return [r for r in rows if r["type"] == "DR" and cat(r) not in TRANSFER and cat(r) not in CASH_WITHDRAWAL]


def by_month(rows):
    result = collections.defaultdict(float)
    for r in spending_rows(rows):
        result[r["date"][:7]] += r["amount"]
    return {k: round(v, 2) for k, v in sorted(result.items())}


def match_rows(gpt, app):
    """Pairs rows by (date, type, amount), using the balance to break ties. Returns pairs and leftovers."""
    pool = collections.defaultdict(list)
    for r in app:
        pool[(r["date"], r["type"], r["amount"])].append(r)
    pairs, only_gpt = [], []
    for g in gpt:
        candidates = pool.get((g["date"], g["type"], g["amount"]), [])
        pick = None
        for c in candidates:
            if g["balance"] is not None and c["balance"] is not None and abs(g["balance"] - c["balance"]) <= TOLERANCE:
                pick = c
                break
        if pick is None and candidates:
            pick = candidates[0]
        if pick is None:
            only_gpt.append(g)
        else:
            candidates.remove(pick)
            pairs.append((g, pick))
    only_app = [r for rows in pool.values() for r in rows]
    return pairs, only_gpt, only_app


def same(a, b):
    return abs(a - b) <= TOLERANCE


# ----------------------------------------------------------------------------- report

class Report:
    def __init__(self):
        self.lines = []
        self.hard = []  # (name, passed, detail)

    def say(self, text=""):
        self.lines.append(text)

    def check(self, name, passed, detail=""):
        self.hard.append((name, passed, detail))
        self.say(f"  [{'OK  ' if passed else 'DIFF'}] {name}" + (f": {detail}" if detail else ""))


def fmt(value):
    return f"{value:,.2f}"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--email", required=True, help="the account the statement was uploaded to")
    parser.add_argument("--chatgpt", required=True, help="the JSON file ChatGPT produced")
    parser.add_argument("--base-url", default="http://localhost:3000")
    parser.add_argument("--statement", help="only compare statements whose file name contains this text")
    parser.add_argument("--report", help="also save the report to this file")
    args = parser.parse_args()

    data = load_chatgpt(args.chatgpt)
    gpt = normalize_gpt_rows(data)
    app = App(args.base_url, args.email)
    statements, app_rows = load_app_rows(app, args.statement)
    summary = app.get("/analytics/summary")

    r = Report()
    r.say("=" * 76)
    r.say("ExpenseInsight vs ChatGPT")
    r.say("=" * 76)
    r.say(f"Statement(s) in the app : {', '.join(s.get('file_name', '?') for s in statements)}")
    r.say(f"Rows                    : ChatGPT {len(gpt)} | app {len(app_rows)}")

    # ---- 1. is ChatGPT itself consistent?
    r.say("\n1. Is ChatGPT's own answer consistent?")
    st = data.get("statement", {})
    opening = money(st.get("opening_balance")) if st.get("opening_balance") is not None else None
    breaks = []
    if opening is not None:
        prev = opening
        for g in gpt:
            expected = round(prev + g["amount"] if g["type"] == "CR" else prev - g["amount"], 2)
            if g["balance"] is None or not same(expected, g["balance"]):
                breaks.append(g["n"])
            prev = g["balance"] if g["balance"] is not None else expected
        r.check("balance chain (opening + credits - debits) holds for every row", not breaks,
                f"breaks at row(s) {breaks[:15]}" if breaks else "")
        closing = st.get("closing_balance")
        if closing is not None and gpt:
            calc = round(opening + sum(g["amount"] for g in gpt if g["type"] == "CR") - sum(g["amount"] for g in gpt if g["type"] == "DR"), 2)
            r.check("opening + deposits - withdrawals = closing balance", same(calc, money(closing)),
                    f"calculated {fmt(calc)} vs stated {fmt(money(closing))}")
    else:
        r.say("  (no opening balance given, balance chain not checked)")
    if st.get("row_count") is not None:
        r.check("stated row count equals the rows it returned", int(st["row_count"]) == len(gpt),
                f"stated {st['row_count']}, returned {len(gpt)}")
    gpt_own = totals_from_rows(gpt)
    stated = data.get("totals", {})
    bad = [k for k in gpt_own if k in stated and not same(gpt_own[k], money(stated[k]))]
    r.check("its stated totals add up from its own rows", not bad,
            ", ".join(f"{k}: rows give {fmt(gpt_own[k])}, stated {fmt(money(stated[k]))}" for k in bad[:5]))

    # ---- 2. extraction
    r.say("\n2. Did the app read the same rows from the PDF?")
    pairs, only_gpt, only_app = match_rows(gpt, app_rows)
    r.check("every ChatGPT row exists in the app", not only_gpt, f"{len(only_gpt)} missing in the app" if only_gpt else f"{len(pairs)} matched")
    r.check("the app has no extra rows", not only_app, f"{len(only_app)} extra in the app" if only_app else "")
    balance_diff = [(g, a) for g, a in pairs if g["balance"] is not None and a["balance"] is not None and not same(g["balance"], a["balance"])]
    r.check("running balance agrees on every matched row", not balance_diff, f"{len(balance_diff)} differ" if balance_diff else "")

    # ---- 3. totals recalculated from the rows
    r.say("\n3. Totals calculated from each side's rows (same rules for both)")
    app_own = totals_from_rows(app_rows)
    for key in ("money_out", "money_in", "transfers_out", "transfers_in", "cash_withdrawals", "spending", "income"):
        hard = key in ("money_out", "money_in")
        passed = same(gpt_own[key], app_own[key])
        line = f"{key:17} ChatGPT {fmt(gpt_own[key]):>12} | app {fmt(app_own[key]):>12}"
        if hard:
            r.check(line + "  (hard)", passed)
        else:
            r.say(f"  [{'OK  ' if passed else 'DIFF'}] {line}  (depends on categories)")

    # ---- 4. the numbers the dashboard shows
    r.say("\n4. The app's own dashboard figures against ChatGPT")
    dash = [
        ("bank_money_out", "money_out", True),
        ("bank_money_in", "money_in", True),
        ("transfers_out", "transfers_out", False),
        ("transfers_in", "transfers_in", False),
        ("bank_spending", "spending", False),
    ]
    only_one = len(statements) == 1 and summary.get("cash_spending", 0) == 0
    for api_key, gpt_key, hard in dash:
        if api_key not in summary:
            r.say(f"  [skip] {api_key}: this version of the app does not report it")
            continue
        app_value = money(summary[api_key])
        passed = same(app_value, gpt_own[gpt_key])
        line = f"{api_key:15} app {fmt(app_value):>12} | ChatGPT {fmt(gpt_own[gpt_key]):>12}"
        if hard and only_one:
            r.check(line + "  (hard)", passed)
        else:
            r.say(f"  [{'OK  ' if passed else 'DIFF'}] {line}")
    if not only_one:
        r.say("  Note: the account has more than one statement or cash expenses, so the dashboard mixes them;")
        r.say("        run again with --statement to compare a single statement.")

    # ---- 5. categories
    r.say("\n5. Categories (partly a judgement call, listed for you to read)")
    agree = [(g, a) for g, a in pairs if g["category"].strip().lower() == a["category"].strip().lower()]
    rate = (100.0 * len(agree) / len(pairs)) if pairs else 0.0
    r.say(f"  Same category on {len(agree)} of {len(pairs)} matched rows ({rate:.1f}%)")
    differ = [(g, a) for g, a in pairs if g["category"].strip().lower() != a["category"].strip().lower()]
    for g, a in differ[:30]:
        flag = " (ChatGPT unsure)" if g["uncertain"] else ""
        r.say(f"    {g['date']} {g['type']} {fmt(g['amount']):>10}  ChatGPT: {g['category']:<14} app: {a['category']:<14}{flag}  {g['description'][:48]}")
    if len(differ) > 30:
        r.say(f"    ... and {len(differ) - 30} more")
    gpt_month, app_month = by_month(gpt), by_month(app_rows)
    r.say("\n  Spending per month (each side's own categories)")
    for month in sorted(set(gpt_month) | set(app_month)):
        a_val, g_val = app_month.get(month, 0.0), gpt_month.get(month, 0.0)
        r.say(f"    {month}  ChatGPT {fmt(g_val):>12} | app {fmt(a_val):>12}  {'ok' if same(a_val, g_val) else 'differs'}")

    # ---- detail on mismatches
    if only_gpt or only_app or balance_diff:
        r.say("\nRows to check by eye against the PDF")
        for g in only_gpt[:20]:
            r.say(f"    only in ChatGPT: {g['date']} {g['type']} {fmt(g['amount']):>10} bal {g['balance']}  {g['description'][:50]}")
        for a in only_app[:20]:
            r.say(f"    only in the app: {a['date']} {a['type']} {fmt(a['amount']):>10} bal {a['balance']}  {a['description'][:50]}")
        for g, a in balance_diff[:20]:
            r.say(f"    balance differs: {g['date']} {g['type']} {fmt(g['amount']):>10} ChatGPT {g['balance']} vs app {a['balance']}")

    # ---- verdict
    failed = [name for name, passed, _ in r.hard if not passed]
    consistent = all(passed for name, passed, _ in r.hard if name.startswith(("balance chain", "opening +", "stated row", "its stated")))
    r.say("\n" + "=" * 76)
    if not failed:
        r.say("VERDICT: PASS. Every row and every hard total agrees. The app read the statement and calculated its")
        r.say("         totals correctly. Category differences above are judgement calls, not errors.")
    elif not consistent:
        r.say("VERDICT: INCONCLUSIVE. ChatGPT's own answer is inconsistent, so it cannot be used to judge the app.")
        r.say("         Ask ChatGPT to fix the rows listed in section 1 and run this again.")
    else:
        r.say("VERDICT: DIFFERENCES FOUND in: " + "; ".join(failed))
        r.say("         ChatGPT's answer is internally consistent, so check the listed rows against the PDF.")
    r.say("=" * 76)

    text = "\n".join(r.lines)
    print(text)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as handle:
            handle.write(text + "\n")
        print(f"\nReport saved to {args.report}")
    sys.exit(0 if not failed else 1)


if __name__ == "__main__":
    main()
