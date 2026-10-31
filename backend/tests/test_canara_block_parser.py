from backend.app.services.transaction_parser import TransactionParser

PASSBOOK_TEXT = """Date
Particulars
Deposits
Withdrawals
Balance
Opening Balance
1,000.00
24-09-2025
UPI/CR/563338903702/KANNAN
S/CNRB/**995-
1@OKAXIS/UPI//AXI70AA76455
7514162A6AEA7E6CB09832B/2
4/09/2025 09:08:00
Chq: 563338903702
2,000.00
3,000.00
28-09-2025
SBINT FOR THE PERIOD
FROM28-JUN-25 TO 27-SEP-25
Chq:
26.00
3,026.00
29-09-2025
UPI/DR/526725684650/ABHIRAM A/HDFC/**P05-
Chq: 526725684650
500.00
2,526.00
"""


def _parse():
    return TransactionParser().parse_from_blocks(PASSBOOK_TEXT)


def test_wrapped_date_time_fragment_does_not_split_row():
    txns = _parse()
    assert len(txns) == 3
    assert txns[0]["date"] == "2025-09-24"
    assert txns[0]["amount"] == 2000.0


def test_reference_number_is_never_used_as_amount():
    assert all(t["amount"] < 1_000_000 for t in _parse())


def test_balance_chain_decides_credit_or_debit():
    txns = _parse()
    assert [t["cr_dr"] for t in txns] == ["CR", "CR", "DR"]
    assert txns[1]["amount"] == 26.0


def test_truncated_kerala_st_payee_is_transport_not_electricity():
    from backend.ml.preprocessing.merchant_normalizer import MerchantNormalizer

    normalizer = MerchantNormalizer()
    bus = normalizer.normalize("UPI/DR/637537435728/KERALA ST/YESB/**DQR01@YBL/PAYM ENT")
    assert (bus[1], bus[2]) == ("ksrtc", "Travel")
    bill = normalizer.normalize("UPI/DR/1/KSEB LTD/CNRB/**1@OKSBI/UPI")
    assert (bill[1], bill[2]) == ("kerala_state_electricity", "Bills")


def test_bare_date_inside_a_wrapped_narration_does_not_split_the_row():
    text = """Date
Particulars
Deposits
Withdrawals
Balance
Opening Balance
10,000.00
15-01-2026
ATM WDL-CNRB ATM TVM 4908
15/01/2026
Chq:
3,000.00
7,000.00
16-01-2026
SMS CHARGES ON ACTUAL BASIS
Chq:
12.00
6,988.00
"""
    txns = TransactionParser().parse_from_blocks(text)
    assert [(t["date"], t["amount"], t["balance"]) for t in txns] == [
        ("2026-01-15", 3000.0, 7000.0),
        ("2026-01-16", 12.0, 6988.0),
    ]
