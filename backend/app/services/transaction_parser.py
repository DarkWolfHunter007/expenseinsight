import re
from datetime import datetime
from typing import Any, Dict, List, Optional, Set, Tuple

class TransactionParser:
    """
    Robust multi-bank statement transaction parser conforming to PRD Sections 10, 43, 44.
    """

    DATE_PATTERNS = [
        r'(\d{2}/\d{2}/\d{4})',
        r'(\d{2}-\d{2}-\d{4})',
        r'(\d{2}/\d{2}/\d{2})',
        r'(\d{2}-\d{2}-\d{2})',
        r'(\d{4}-\d{2}-\d{2})',
        r'(\d{2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})'
    ]

    def __init__(self):
        self._date_regexes = [re.compile(p, re.IGNORECASE) for p in self.DATE_PATTERNS]

    def _parse_amount(self, amt_str: Any) -> Optional[float]:
        """Cleans and converts amount string to float."""
        if amt_str is None:
            return None
        if isinstance(amt_str, (int, float)):
            return float(amt_str)
        
        s = str(amt_str).strip()
        if not s or s == "-" or s.lower() == "nil":
            return None
        
        # Remove currency symbols and commas
        cleaned = re.sub(r'[₹$,\s]', '', s)
        # Check if ends with Dr/Cr
        cleaned = re.sub(r'(?:dr|cr)', '', cleaned, flags=re.IGNORECASE).strip()
        
        try:
            return abs(float(cleaned))
        except ValueError:
            return None

    def _normalize_date(self, date_str: str) -> Optional[str]:
        """Converts varied date strings into standardized YYYY-MM-DD."""
        if not date_str:
            return None
        d = date_str.strip()
        
        formats = [
            "%d/%m/%Y", "%d-%m-%Y", "%d/%m/%y", "%d-%m-%y",
            "%Y-%m-%d", "%Y/%m/%d", "%d %b %Y", "%d %B %Y",
            "%d %b %y", "%d-%b-%Y", "%d-%b-%y"
        ]
        for fmt in formats:
            try:
                dt = datetime.strptime(d, fmt)
                # Ensure sensible year
                if dt.year < 2000:
                    dt = dt.replace(year=dt.year + 2000)
                return dt.strftime("%Y-%m-%d")
            except ValueError:
                continue
        return None

    def parse_from_tables(self, raw_tables: List[List[List[Any]]]) -> List[Dict[str, Any]]:
        """Parses transactions from structured PDF table extractions."""
        parsed_transactions = []
        seen_keys: Set[str] = set()

        for table in raw_tables:
            if not table or len(table) < 2:
                continue

            # Identify column indexes from header row
            header = [str(col).lower() if col is not None else "" for col in table[0]]
            
            date_idx = -1
            desc_idx = -1
            ref_idx = -1
            dr_idx = -1
            cr_idx = -1
            bal_idx = -1

            for idx, col_name in enumerate(header):
                if any(k in col_name for k in ["date", "txn dt", "value dt"]):
                    if date_idx == -1:
                        date_idx = idx
                elif any(k in col_name for k in ["narration", "description", "particulars", "details", "remark"]):
                    desc_idx = idx
                elif any(k in col_name for k in ["chq", "ref", "reference", "utr"]):
                    ref_idx = idx
                elif any(k in col_name for k in ["withdrawal", "debit", "dr"]):
                    dr_idx = idx
                elif any(k in col_name for k in ["deposit", "credit", "cr"]):
                    cr_idx = idx
                elif any(k in col_name for k in ["balance", "bal"]):
                    bal_idx = idx

            # If headers not clearly labeled, try fallback by position
            if date_idx == -1 and len(header) >= 4:
                date_idx = 0
                desc_idx = 1
                dr_idx = 2 if len(header) > 2 else -1
                cr_idx = 3 if len(header) > 3 else -1
                bal_idx = 4 if len(header) > 4 else -1

            # Iterate data rows
            for row in table[1:]:
                if not row or len(row) < 3:
                    continue

                raw_date = row[date_idx] if date_idx < len(row) else ""
                norm_date = self._normalize_date(str(raw_date))
                if not norm_date:
                    continue

                raw_desc = str(row[desc_idx]).strip() if desc_idx != -1 and desc_idx < len(row) else ""
                if not raw_desc or raw_desc.lower() in ["opening balance", "total", "closing balance"]:
                    continue

                ref_num = str(row[ref_idx]).strip() if ref_idx != -1 and ref_idx < len(row) and row[ref_idx] else None
                
                # Check DR vs CR
                dr_val = self._parse_amount(row[dr_idx]) if dr_idx != -1 and dr_idx < len(row) else None
                cr_val = self._parse_amount(row[cr_idx]) if cr_idx != -1 and cr_idx < len(row) else None
                bal_val = self._parse_amount(row[bal_idx]) if bal_idx != -1 and bal_idx < len(row) else None

                if dr_val is not None and dr_val > 0:
                    amount = dr_val
                    cr_dr = "DR"
                    txn_type = self._determine_txn_type(raw_desc, "expense")
                elif cr_val is not None and cr_val > 0:
                    amount = cr_val
                    cr_dr = "CR"
                    txn_type = self._determine_txn_type(raw_desc, "income")
                else:
                    continue

                # Duplicate detection
                dup_key = f"{norm_date}_{amount:.2f}_{cr_dr}_{raw_desc[:30]}"
                is_duplicate = dup_key in seen_keys
                seen_keys.add(dup_key)

                parsed_transactions.append({
                    "date": norm_date,
                    "raw_description": raw_desc,
                    "amount": round(amount, 2),
                    "currency": "INR",
                    "transaction_type": txn_type,
                    "cr_dr": cr_dr,
                    "balance": round(bal_val, 2) if bal_val is not None else None,
                    "reference_number": ref_num,
                    "is_duplicate": is_duplicate
                })

        return parsed_transactions

    def parse_from_text_lines(self, full_text: str) -> List[Dict[str, Any]]:
        """Fallback line-by-line regex parser when tabular structure is loose."""
        transactions = []
        lines = full_text.splitlines()
        seen_keys: Set[str] = set()

        for line in lines:
            line_str = line.strip()
            if not line_str:
                continue

            # Look for date pattern at start of line
            date_match = None
            date_end_idx = 0
            for regex in self._date_regexes:
                m = regex.search(line_str)
                if m and m.start() < 10: # Date is near start of line
                    date_match = m.group(1)
                    date_end_idx = m.end()
                    break

            if not date_match:
                continue

            norm_date = self._normalize_date(date_match)
            if not norm_date:
                continue

            rest_of_line = line_str[date_end_idx:].strip()
            
            # Find amounts at end of line (e.g. 485.00 or 1,299.00 45,000.00)
            amount_matches = re.findall(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2}))', rest_of_line)
            if not amount_matches:
                continue

            # If two amounts, usually [Debit/Credit, Balance]
            if len(amount_matches) >= 2:
                amount_str = amount_matches[-2]
                balance_str = amount_matches[-1]
                bal_val = self._parse_amount(balance_str)
            else:
                amount_str = amount_matches[-1]
                bal_val = None

            amount = self._parse_amount(amount_str)
            if not amount or amount <= 0:
                continue

            # Description is text before amount
            amt_idx = rest_of_line.rfind(amount_str)
            raw_desc = rest_of_line[:amt_idx].strip()
            if not raw_desc:
                continue

            # Check for CR indicator
            cr_dr = "CR" if re.search(r'\b(?:CR|CREDIT|SALARY|REFUND)\b', line_str, re.IGNORECASE) else "DR"
            txn_type = self._determine_txn_type(raw_desc, "income" if cr_dr == "CR" else "expense")

            dup_key = f"{norm_date}_{amount:.2f}_{cr_dr}_{raw_desc[:30]}"
            is_duplicate = dup_key in seen_keys
            seen_keys.add(dup_key)

            transactions.append({
                "date": norm_date,
                "raw_description": raw_desc,
                "amount": round(amount, 2),
                "currency": "INR",
                "transaction_type": txn_type,
                "cr_dr": cr_dr,
                "balance": round(bal_val, 2) if bal_val is not None else None,
                "reference_number": None,
                "is_duplicate": is_duplicate
            })

        return transactions

    def _determine_txn_type(self, description: str, default_type: str) -> str:
        """Categorizes transaction into income, expense, transfer, or cash_withdrawal (PRD Section 44)."""
        d = description.upper()
        if any(k in d for k in ["SALARY", "PAYROLL", "STIPEND", "INTEREST CREDIT", "DIVIDEND"]):
            return "income"
        elif any(k in d for k in ["ATM WDL", "CASH WDL", "ATM CASH", "NFS WDL"]):
            return "cash_withdrawal"
        elif any(k in d for k in ["ZERODHA", "GROWW", "MUTUAL FUND", "TRANSFER TO SELF", "TPT SELF", "INVESTMENT"]):
            return "transfer"
        return default_type

    def parse(self, extraction_result: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Runs table extraction first, falls back to text parsing if needed."""
        txns = self.parse_from_tables(extraction_result.get("raw_tables", []))
        if len(txns) >= 5:
            return txns
        
        # Fallback to text parsing
        text_txns = self.parse_from_text_lines(extraction_result.get("full_text", ""))
        return text_txns if len(text_txns) > len(txns) else txns
