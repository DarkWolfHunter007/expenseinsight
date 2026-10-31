"""
Generates synthetic Canara-style e-passbook PDFs with a ground-truth file, for testing the
statement extraction, merchant normalization, analytics and budget logic end to end.

Everything in the output is made up (name, account, people, references). The expected category
for each row is decided here from the merchant, independently of the app's own classifier, so the
app's answers can be checked against it.

    python tools/synthetic_statement.py --out <dir>

Writes into <dir>:
    synthetic_main.pdf          Jan-Jun 2026, ~170 transactions
    ground_truth_main.json
    synthetic_followup.pdf      1-10 Jul 2026, continues from the main statement's closing balance
    ground_truth_followup.json
"""
import argparse
import json
import random
import textwrap
from datetime import date, timedelta

import pymupdf

WRAP = 26  # the real passbook breaks narrations at about 26 characters

# name shown in the narration (the bank cuts payee names to 9 characters), bank code, vpa suffix,
# expected category and the amounts this payee typically gets
MERCHANTS = [
    ("ZOMATO LI", "UTIB", "ZOMATO.GPAY@OKPAYAXIS", "Food", "zomato", (180, 650)),
    ("SWIGGY", "ICIC", "SWIGGY@ICICI", "Food", "swiggy", (150, 700)),
    ("BIGBASKET", "HDFC", "BIGBASKET@HDFCBANK", "Groceries", "bigbasket", (400, 2200)),
    ("AMAZON PA", "UTIB", "AMAZONPAY@APL", "Shopping", "amazon", (300, 3500)),
    ("UBER INDI", "HDFC", "UBER@AXISBANK", "Travel", "uber", (90, 480)),
    ("IRCTC WEB", "SBIN", "IRCTC@SBI", "Travel", "irctc", (300, 1800)),
    ("KERALA ST", "YESB", "DQR01@YBL", "Travel", "ksrtc", (10, 30)),
    ("NETFLIX C", "ICIC", "NETFLIX@ICICI", "Entertainment", "netflix", (199, 199)),
    ("SPOTIFY I", "HDFC", "SPOTIFY@HDFCBANK", "Entertainment", "spotify", (119, 119)),
    ("JIO POSTP", "YESB", "JIO17591@PTYBL", "Bills", "jio", (399, 399)),
    ("KSEB LTD", "CNRB", "KSEB@OKSBI", "Bills", "kseb", (600, 1400)),
    ("APOLLO PH", "UTIB", "APOLLO@OKAXIS", "Healthcare", "apollo", (120, 900)),
]
PEOPLE = ["ASHOK MENON", "BINDU NAIR", "CHITRA SUNIL", "DEEPAK RAJ", "ELSA GEORGE", "FAZIL AHMED", "GOKUL KRISHNAN"]
BANKS = ["SBIN", "HDFC", "ICIC", "CNRB", "YESB", "UTIB"]


class Builder:
    def __init__(self, rng, opening, start):
        self.rng = rng
        self.balance = round(opening, 2)
        self.opening = self.balance
        self.cursor = start
        self.rows = []

    def ref(self):
        return str(self.rng.randint(10**11, 10**12 - 1))

    def hash(self):
        return "".join(self.rng.choice("0123456789ABCDEF") for _ in range(30))

    def stamp(self, d):
        return f"{d.day:02d}/{d.month:02d}/{d.year} {self.rng.randint(6, 23):02d}:{self.rng.randint(0, 59):02d}:{self.rng.randint(0, 59):02d}"

    def add(self, d, narration, amount, credit, expected, ref=None):
        amount = round(amount, 2)
        if not credit and amount > self.balance - 50:
            return False  # keep the balance healthy
        self.balance = round(self.balance + amount if credit else self.balance - amount, 2)
        self.rows.append({
            "date": d,
            "narration": narration,
            "ref": ref,
            "amount": amount,
            "credit": credit,
            "balance": self.balance,
            "expected": expected,
        })
        return True

    def upi(self, d, name, bank, vpa, amount, credit, expected):
        ref = self.ref()
        direction = "CR" if credit else "DR"
        narration = f"UPI/{direction}/{ref}/{name}/{bank}/**{vpa}/UPI//{self.hash()}/{self.stamp(d)}"
        return self.add(d, narration, amount, credit, expected, ref)


def month_days(year, month):
    d = date(year, month, 1)
    while d.month == month:
        yield d
        d += timedelta(days=1)


def build_main(rng):
    b = Builder(rng, 20000.00, date(2026, 1, 1))
    for month in range(1, 7):
        days = list(month_days(2026, month))
        # salary on the 1st
        b.add(days[0], f"NEFT CR-CNRB{rng.randint(10**9, 10**10 - 1)}-SYNTH TECH PVT LTD-SALARY",
              45000.00, True, {"category": "Income", "merchant": "salary", "spending": False, "kind": "salary"})
        # rent to a person
        b.upi(days[2], "ASHOK MEN", "SBIN", "ASHOK12@OKSBI", 12000.00, False,
              {"category": "Transfers", "merchant": "person", "spending": False, "kind": "person"})
        # recurring bills
        b.upi(days[4], "JIO POSTP", "YESB", "JIO17591@PTYBL", 399.00, False,
              {"category": "Bills", "merchant": "jio", "spending": True, "kind": "merchant"})
        b.upi(days[5], "NETFLIX C", "ICIC", "NETFLIX@ICICI", 199.00, False,
              {"category": "Entertainment", "merchant": "netflix", "spending": True, "kind": "merchant"})
        b.upi(days[6], "SPOTIFY I", "HDFC", "SPOTIFY@HDFCBANK", 119.00, False,
              {"category": "Entertainment", "merchant": "spotify", "spending": True, "kind": "merchant"})
        if month % 2 == 0:
            amt = float(rng.randint(600, 1400))
            b.upi(days[9], "KSEB LTD", "CNRB", "KSEB@OKSBI", amt, False,
                  {"category": "Bills", "merchant": "kseb", "spending": True, "kind": "merchant"})
        # daily life
        for d in days:
            if d.day in (1, 3, 5, 6, 7, 10):
                pass
            for _ in range(rng.choice([0, 1, 1, 2])):
                name, bank, vpa, cat, key, (lo, hi) = rng.choice(MERCHANTS[:7] + MERCHANTS[11:])
                if key in ("ksrtc",):
                    amt = float(rng.choice([10, 13, 15, 18, 30]))
                else:
                    amt = float(rng.randint(lo, hi))
                b.upi(d, name, bank, vpa, amt, False,
                      {"category": cat, "merchant": key, "spending": True, "kind": "merchant"})
            # friends: small transfers both ways
            if rng.random() < 0.18:
                person = rng.choice(PEOPLE)
                bank = rng.choice(BANKS)
                credit = rng.random() < 0.45
                b.upi(d, person[:9], bank, f"{person.split()[0][:6]}{rng.randint(1, 99)}@OKSBI",
                      float(rng.randint(50, 1500)), credit,
                      {"category": "Transfers", "merchant": "person", "spending": False, "kind": "person"})
        # one ATM withdrawal and one refund per month
        b.add(days[14], f"ATM WDL-CNRB ATM TVM {rng.randint(1000, 9999)} {days[14].day:02d}/{month:02d}/2026",
              float(rng.choice([1000, 2000, 3000])), False,
              {"category": "Cash Withdrawal", "merchant": "atm", "spending": False, "kind": "atm"})
        b.upi(days[20], "AMAZON PA", "UTIB", "AMAZONPAY@APL", float(rng.randint(200, 900)), True,
              {"category": "Shopping", "merchant": "amazon", "spending": False, "kind": "refund"})
        b.add(days[-1], "SMS CHARGES ON ACTUAL BASIS", 12.00, False,
              {"category": "Bills", "merchant": "bank_charges", "spending": True, "kind": "charge"})
        if month in (3, 6):
            b.add(days[-1], f"SBINT FOR THE PERIOD FROM01-{month - 2:02d}-26 TO {days[-1].day}-{month:02d}-26",
                  float(rng.randint(40, 120)), True,
                  {"category": "Income", "merchant": "interest", "spending": False, "kind": "interest"})
    return b


def build_followup(rng, opening):
    b = Builder(rng, opening, date(2026, 7, 1))
    b.add(date(2026, 7, 1), f"NEFT CR-CNRB{rng.randint(10**9, 10**10 - 1)}-SYNTH TECH PVT LTD-SALARY",
          45000.00, True, {"category": "Income", "merchant": "salary", "spending": False, "kind": "salary"})
    rows = [
        (2, "ZOMATO LI", "UTIB", "ZOMATO.GPAY@OKPAYAXIS", 420.0, "Food", "zomato"),
        (3, "ZOMATO LI", "UTIB", "ZOMATO.GPAY@OKPAYAXIS", 275.0, "Food", "zomato"),
        (5, "BIGBASKET", "HDFC", "BIGBASKET@HDFCBANK", 1250.0, "Groceries", "bigbasket"),
        (6, "UBER INDI", "HDFC", "UBER@AXISBANK", 210.0, "Travel", "uber"),
        (8, "KERALA ST", "YESB", "DQR01@YBL", 15.0, "Travel", "ksrtc"),
    ]
    for day, name, bank, vpa, amt, cat, key in rows:
        b.upi(date(2026, 7, day), name, bank, vpa, amt, False,
              {"category": cat, "merchant": key, "spending": True, "kind": "merchant"})
    return b


def write_pdf(builder, path, period_start, period_end, account="XXXXXXXX1234"):
    doc = pymupdf.open()
    state = {"page": None, "y": 0, "n": 0}
    font = "helv"

    def new_page(first):
        if state["page"] is not None:
            put(40, 820, f"page {state['n']}")
        state["n"] += 1
        state["page"] = doc.new_page(width=595, height=842)
        state["y"] = 40
        if first:
            for line in [
                f"Statement for A/c {account} for the period {period_start} to {period_end}",
                "Customer Id", "XXXXXX00", "Name", "SYNTHETIC TEST USER", "Phone", "+910000000000",
                "Address", "1 TEST ROAD, SAMPLE NAGAR", "KERALA IN 000000",
                "Branch Code", "9999", "Branch Name", "TEST BRANCH", "Product Code", "101",
                "Product Name", "CANARA SB GENERAL", "IFSC Code", "CNRB0009999",
            ]:
                put(40, state["y"], line)
                state["y"] += 11
        for col, x in (("Date", 40), ("Particulars", 110), ("Deposits", 380), ("Withdrawals", 440), ("Balance", 510)):
            put(x, state["y"], col)
        state["y"] += 14

    def put(x, y, text):
        state["page"].insert_text((x, y), text, fontsize=8, fontname=font)

    new_page(True)
    put(110, state["y"], "Opening Balance")
    put(510, state["y"], f"{builder.opening:,.2f}")
    state["y"] += 14

    for r in builder.rows:
        lines = textwrap.wrap(r["narration"], WRAP, break_long_words=True, break_on_hyphens=False)
        if r["ref"]:
            lines.append(f"Chq: {r['ref']}")
        else:
            lines.append("Chq:")
        needed = 11 * (len(lines) + 1) + 6
        if state["y"] + needed > 805:
            new_page(False)
        top = state["y"]
        put(40, top, r["date"].strftime("%d-%m-%Y"))
        y = top
        for line in lines:
            put(110, y, line)
            y += 11
        amount_x = 380 if r["credit"] else 440
        put(amount_x, top, f"{r['amount']:,.2f}")
        put(510, top, f"{r['balance']:,.2f}")
        state["y"] = max(y, top + 11) + 6
    put(40, 820, f"page {state['n']}")
    doc.save(path)
    doc.close()


def ground_truth(builder, label):
    rows = []
    for r in builder.rows:
        rows.append({
            "date": r["date"].isoformat(),
            "cr_dr": "CR" if r["credit"] else "DR",
            "amount": r["amount"],
            "balance": r["balance"],
            "expected_category": r["expected"]["category"],
            "expected_merchant_key": r["expected"]["merchant"],
            "kind": r["expected"]["kind"],
            "counts_as_spending": r["expected"]["spending"] and not r["credit"],
            "narration": r["narration"],
        })
    spending = [x for x in rows if x["counts_as_spending"]]
    by_month, by_category = {}, {}
    for x in spending:
        by_month[x["date"][:7]] = round(by_month.get(x["date"][:7], 0) + x["amount"], 2)
        by_category[x["expected_category"]] = round(by_category.get(x["expected_category"], 0) + x["amount"], 2)
    return {
        "label": label,
        "opening_balance": builder.opening,
        "closing_balance": builder.balance,
        "transaction_count": len(rows),
        "expected_personal_spending_total": round(sum(x["amount"] for x in spending), 2),
        "expected_personal_spending_by_month": dict(sorted(by_month.items())),
        "expected_personal_spending_by_category": dict(sorted(by_category.items())),
        "expected_income_total": round(sum(x["amount"] for x in rows if x["kind"] in ("salary", "interest")), 2),
        "definitions": {
            "personal_spending": "debits to merchants/bills/charges; excludes person-to-person transfers and ATM cash withdrawals",
            "income": "salary and interest credits; credits from people are transfers, refunds are not income",
        },
        "transactions": rows,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--seed", type=int, default=20260601)
    args = parser.parse_args()

    import os
    os.makedirs(args.out, exist_ok=True)
    rng = random.Random(args.seed)

    main_b = build_main(rng)
    write_pdf(main_b, os.path.join(args.out, "synthetic_main.pdf"), "01-Jan-2026", "30-Jun-2026")
    with open(os.path.join(args.out, "ground_truth_main.json"), "w", encoding="utf-8") as f:
        json.dump(ground_truth(main_b, "main"), f, indent=1)

    follow_b = build_followup(rng, main_b.balance)
    write_pdf(follow_b, os.path.join(args.out, "synthetic_followup.pdf"), "01-Jul-2026", "10-Jul-2026")
    with open(os.path.join(args.out, "ground_truth_followup.json"), "w", encoding="utf-8") as f:
        json.dump(ground_truth(follow_b, "followup"), f, indent=1)

    print(f"main: {len(main_b.rows)} transactions, closing balance {main_b.balance:,.2f}")
    print(f"followup: {len(follow_b.rows)} transactions")


if __name__ == "__main__":
    main()
