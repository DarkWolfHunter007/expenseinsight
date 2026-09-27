import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
import pandas as pd

# Ensure UTF-8 console output
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Fallback PyMuPDF import
try:
    import pymupdf as fitz
except ImportError:
    try:
        import fitz
    except ImportError:
        fitz = None


def extract_text_from_pdf(pdf_path: str) -> str:
    """Extracts full text from a PDF statement using PyMuPDF / pdfplumber."""
    if fitz is not None:
        try:
            doc = fitz.open(pdf_path)
            pages = [doc[i].get_text() or "" for i in range(len(doc))]
            doc.close()
            return "\n".join(pages)
        except Exception:
            pass

    try:
        import pdfplumber
        with pdfplumber.open(pdf_path) as pdf:
            return "\n".join(p.extract_text() or "" for p in pdf.pages)
    except Exception:
        pass

    try:
        from pypdf import PdfReader
        reader = PdfReader(pdf_path)
        return "\n".join(p.extract_text() or "" for p in reader.pages)
    except Exception as e:
        raise ValueError(f"Failed to extract text from {pdf_path}: {e}")


def parse_canara_epassbook_text(full_text: str) -> List[Dict[str, Any]]:
    """
    Parses Canara Bank e-Passbook format with high fidelity:
    [DD-MM-YYYY]
    [Particulars / UPI multi-line text]
    Chq: [Ref/Cheque No]
    [Amount]
    [Balance]
    """
    lines = full_text.splitlines()
    blocks = []
    current_date = None
    current_lines = []
    date_re = re.compile(r'^(\d{2}-\d{2}-\d{4})$')

    for line in lines:
        s = line.strip()
        if not s:
            continue
        m = date_re.match(s)
        if m:
            if current_date and current_lines:
                blocks.append((current_date, current_lines))
            current_date = m.group(1)
            current_lines = []
        elif current_date:
            current_lines.append(s)

    if current_date and current_lines:
        blocks.append((current_date, current_lines))

    txns = []
    for dt_str, blk in blocks:
        combined = " ".join(blk)
        if any(ign in combined for ign in ["Opening Balance", "Closing Balance", "Brought Forward"]):
            continue

        # Filter header noise
        filtered = [
            l for l in blk if not re.search(
                r'^(?:Date|Particulars|Deposits|Withdrawals|Balance|Statement for|Customer Id|Name|Phone|Address|Branch|Product|IFSC|---\s*Page|\d+\s*of\s*\d+)',
                l,
                re.IGNORECASE
            )
        ]
        if not filtered:
            continue

        chq_idx = -1
        ref_num = None
        for i, l in enumerate(filtered):
            if l.startswith("Chq:"):
                chq_idx = i
                ref_num = l.replace("Chq:", "").strip()
                break

        if chq_idx != -1 and chq_idx + 1 < len(filtered):
            raw_desc_lines = filtered[:chq_idx]
            amt_lines = filtered[chq_idx + 1:]
        else:
            raw_desc_lines = filtered[:-2] if len(filtered) >= 3 else filtered[:-1]
            amt_lines = filtered[-2:] if len(filtered) >= 3 else filtered[-1:]

        raw_desc = " ".join(raw_desc_lines).strip()

        amounts = []
        for l in amt_lines:
            found = re.findall(r'(\d{1,3}(?:,\d{3})*\.\d{2})', l)
            for f in found:
                try:
                    amounts.append(float(f.replace(',', '')))
                except ValueError:
                    pass

        if not amounts:
            continue

        amt = amounts[0]
        bal = amounts[1] if len(amounts) > 1 else None

        if "UPI/CR/" in raw_desc or "/CR/" in raw_desc:
            cr_dr = "CR"
        elif "UPI/DR/" in raw_desc or "/DR/" in raw_desc:
            cr_dr = "DR"
        elif any(k in raw_desc.upper() for k in ["CREDIT", "REFUND", "SALARY", "INTEREST"]):
            cr_dr = "CR"
        else:
            cr_dr = "DR"

        try:
            norm_date = datetime.strptime(dt_str, "%d-%m-%Y").strftime("%Y-%m-%d")
        except ValueError:
            norm_date = dt_str

        txns.append({
            "date": norm_date,
            "raw_description": raw_desc,
            "amount": amt,
            "cr_dr": cr_dr,
            "balance": bal,
            "reference_number": ref_num,
            "bank": "Canara Bank"
        })
    return txns


def parse_gpay_statement_text(full_text: str) -> List[Dict[str, Any]]:
    """
    Parses Google Pay (GPay) Transaction Statement export.
    """
    pattern = re.compile(
        r'(\d{1,2}\s+[A-Za-z]{3},\s+\d{4})\s*\n'
        r'(\d{1,2}:\d{2}\s+(?:AM|PM))\s*\n'
        r'(Paid to|Received from)\s+([^\n]+)\s*\n'
        r'(?:UPI Transaction ID:\s*([^\n]+)\s*\n)?'
        r'(?:(?:Paid by|Paid to)\s+([^\n]+)\s*\n)?'
        r'[₹Rs\.]*\s*([\d,]+(?:\.\d{2})?)',
        re.IGNORECASE
    )
    matches = pattern.findall(full_text)
    txns = []
    for dt_str, tm_str, direction, counterparty, txn_id, bank_info, amt_str in matches:
        try:
            amt = float(amt_str.replace(',', ''))
        except ValueError:
            continue

        cr_dr = "CR" if "Received" in direction else "DR"
        clean_date_str = dt_str.replace(',', '').strip()
        try:
            dt_obj = datetime.strptime(clean_date_str, "%d %b %Y")
            norm_date = dt_obj.strftime("%Y-%m-%d")
        except ValueError:
            norm_date = clean_date_str

        raw_desc = f"{direction.strip()} {counterparty.strip()} via GPay"
        txns.append({
            "date": norm_date,
            "raw_description": raw_desc,
            "amount": amt,
            "cr_dr": cr_dr,
            "balance": None,
            "reference_number": txn_id.strip() if txn_id else None,
            "bank": "Google Pay"
        })
    return txns


def label_extracted_transaction(t: Dict[str, Any]) -> Tuple[str, str, str]:
    """
    Categorizes raw banking transaction and assigns:
    Returns: (category, merchant_name, transaction_type)
    """
    desc = t["raw_description"].upper()
    amt = t.get("amount", 0.0)
    cr_dr = t.get("cr_dr", "DR")

    # 1. Income
    if any(k in desc for k in ["SBINT", "SAVINGS BANK INTEREST", "INTEREST CREDIT", "INTEREST PAID"]):
        return "Income", "Bank Interest", "income"
    if any(k in desc for k in ["SALARY", "PAYROLL", "STIPEND"]):
        return "Income", "Salary", "income"
    if "DIVIDEND" in desc:
        return "Income", "Dividend", "income"
    if any(k in desc for k in ["REFUND", "CASHBACK"]):
        return "Income", "Cashback / Refund", "income"
    if "GOOGLE IN" in desc and cr_dr == "CR" and amt <= 5:
        return "Income", "Google Micro-Deposit Verification", "income"

    # 2. Education
    if any(k in desc for k in ["COLLEGE", "UNIVERSITY", "SCHOOL", "BASELIOS", "TUITION", "CAMPUS", "ACADEMY", "COURSERA", "UDEMY", "EDX"]):
        return "Education", "Education / College Fee", "expense"

    # 3. Bills & Utilities
    if "BSNL" in desc:
        return "Bills", "BSNL Telecom", "expense"
    if "JIO" in desc:
        return "Bills", "Jio", "expense"
    if "AIRTEL" in desc:
        return "Bills", "Airtel", "expense"
    if any(k in desc for k in ["VI ", "VODAFONE", "IDEA "]):
        return "Bills", "Vodafone Idea", "expense"
    if any(k in desc for k in ["KERALA ST", "KSEB", "ELECTRICITY", "POWER", "BESCOM", "TATA POWER", "ADANI ELEC", "WATER BILL", "BWSSB"]):
        return "Bills", "Electricity & Utilities", "expense"
    if any(k in desc for k in ["SMS CHARGES", "BANK CHARGES", "SERVICE CHARGE", "LEDGER FEE", "CHG ON ACTUAL"]):
        return "Bills", "Bank Charges & Fees", "expense"

    # 4. Entertainment & Media
    if any(k in desc for k in ["BIGTRE", "BOOKMYSHOW"]):
        return "Entertainment", "BookMyShow", "expense"
    if any(k in desc for k in ["APPLE MED", "APPLE.COM", "ITUNES"]):
        return "Entertainment", "Apple Services", "expense"
    if any(k in desc for k in ["SPORTS KE", "SPORTSKEEDA"]):
        return "Entertainment", "Sportskeeda Media", "expense"
    if any(k in desc for k in ["NETFLIX", "SPOTIFY", "HOTSTAR", "PRIME VIDEO", "YOUTUBE", "SONYLIV", "ZEE5", "PVR", "INOX", "CINEPOLIS"]):
        return "Entertainment", "Entertainment Streaming", "expense"

    # 5. Food & Dining
    if any(k in desc for k in [
        "ZOMATO", "SWIGGY", "MCDONALDS", "DOMINO", "KFC", "STARBUCKS", "BURGER KING",
        "PIZZA", "BAKERY", "CAFE", "RESTAURANT", "DHABA", "HOTEL", "TEA", "CHAI",
        "ARYAA", "KICHUS FA", "CHOCO BAE", "FOOD", "EATERY", "BIRYANI", "CANTEEN",
        "JUICE", "SNACKS", "KITCHEN", "TIFFIN", "SARAVANA", "SHG", "MOMO", "BURGER"
    ]):
        return "Food", "Food & Dining", "expense"

    # 6. Groceries & Supermarkets
    if any(k in desc for k in [
        "ZEPTO", "BLINKIT", "BIGBASKET", "DMART", "RELIANCE SMART", "SUPERMARKET",
        "KIRANA", "PROVISION", "VEGETABLE", "FRUIT", "MILK", "MILMA", "DAIRY",
        "BAZAAR", "STORE", "MART", "HYPER", "NATURES BASKET"
    ]):
        return "Groceries", "Groceries & Supermarket", "expense"

    # 7. Fuel
    if any(k in desc for k in ["PETROL", "DIESEL", "IOCL", "INDIAN OIL", "HPCL", "BPCL", "SHELL", "AUTO CARE", "CNG"]):
        return "Fuel", "Fuel Station", "expense"

    # 8. Travel & Commute
    if any(k in desc for k in ["UBER", "OLA", "RAPIDO", "IRCTC", "RAILWAY", "METRO", "BUS", "KSRTC", "FASTAG", "TOLL", "AIRLINE", "INDIGO", "AUTO", "TAXI"]):
        return "Travel", "Travel & Commute", "expense"

    # 9. Healthcare & Pharmacy
    if any(k in desc for k in ["APOLLO", "PHARMACY", "MEDPLUS", "1MG", "PHARMEASY", "HOSPITAL", "CLINIC", "DOCTOR", "LAB", "PATHLAB", "MEDICAL", "HEALTH", "DR ", "DENTAL", "VETER"]):
        return "Healthcare", "Healthcare & Medical", "expense"

    # 10. Shopping & Retail
    if any(k in desc for k in ["AMAZON", "FLIPKART", "MYNTRA", "AJIO", "NYKAA", "MEESHO", "ZARA", "H&M", "DECATHLON", "CROMA", "RELIANCE DIGITAL", "FASHION", "APPAREL", "CLOTH", "FOOTWEAR", "ELECTRONIC"]):
        return "Shopping", "Shopping & Retail", "expense"

    # 11. Rent & Society
    if any(k in desc for k in ["NOBROKER", "MYGATE", "HOUSE RENT", "FLAT RENT", "MAINTENANCE"]):
        return "Rent", "Housing Rent / Maintenance", "expense"

    # 12. Cash Withdrawal
    if any(k in desc for k in ["ATM WDL", "CASH WDL", "NFS WDL", "ATM CASH", "SELF WDL"]):
        return "Cash Withdrawal", "ATM Cash Withdrawal", "transfer"

    # 13. Investments
    if any(k in desc for k in ["ZERODHA", "GROWW", "UPSTOX", "MUTUAL FUND", "CAMS", "KFINTECH"]):
        return "Investments", "Investments", "transfer"

    # 14. Transfers / Peer Remittances
    if cr_dr == "CR":
        return "Transfers", "Peer Transfer (Received)", "transfer"
    else:
        return "Transfers", "Peer Transfer (Sent)", "transfer"


def extract_transactions_from_pdf_dir(pdf_dir: str) -> pd.DataFrame:
    """
    Extracts, cleans, and labels all transactions across PDFs in a directory.
    """
    pdf_path_obj = Path(pdf_dir)
    if not pdf_path_obj.exists():
        return pd.DataFrame()

    pdf_files = list(pdf_path_obj.glob("*.pdf")) + list(pdf_path_obj.glob("*.PDF"))
    if not pdf_files:
        return pd.DataFrame()

    records = []
    for pdf_file in pdf_files:
        try:
            full_text = extract_text_from_pdf(str(pdf_file))
            if not full_text:
                continue

            if "google pay" in full_text.lower() or "gpay" in pdf_file.name.lower():
                txns = parse_gpay_statement_text(full_text)
            else:
                txns = parse_canara_epassbook_text(full_text)

            for idx, t in enumerate(txns):
                cat, merchant_name, txn_type = label_extracted_transaction(t)
                records.append({
                    "id": f"pdf_{pdf_file.stem[:8]}_{idx+1:04d}",
                    "date": t["date"],
                    "raw_description": t["raw_description"],
                    "merchant_ground_truth": merchant_name,
                    "category": cat,
                    "amount": float(t["amount"]),
                    "transaction_type": txn_type,
                    "cr_dr": t["cr_dr"],
                    "balance": t.get("balance"),
                    "bank": t.get("bank", "Bank Statement"),
                    "source_pdf": pdf_file.name
                })
        except Exception as err:
            print(f"Warning: Failed to process {pdf_file.name}: {err}")

    if not records:
        return pd.DataFrame()

    df = pd.DataFrame(records)
    return df
