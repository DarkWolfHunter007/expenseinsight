import io
import re
from typing import Any, Dict, List, Optional, Tuple

try:
    import pymupdf as fitz  # PyMuPDF
    HAS_PYMUPDF = True
except ImportError:
    try:
        import fitz  # PyMuPDF fallback
        HAS_PYMUPDF = True
    except ImportError:
        HAS_PYMUPDF = False

try:
    import pdfplumber
    HAS_PDFPLUMBER = True
except ImportError:
    HAS_PDFPLUMBER = False

from pypdf import PdfReader

class PDFExtractor:
    """
    Extracts text and tabular records from bank statement PDFs using PyMuPDF (fitz)
    as the primary engine conforming to the proposed methodology and PRD Section 9.
    """

    IFSC_PREFIX_MAP = {
        "CNRB": "Canara Bank",
        "HDFC": "HDFC Bank",
        "SBIN": "State Bank of India",
        "ICIC": "ICICI Bank",
        "UTIB": "Axis Bank",
        "KKBK": "Kotak Mahindra Bank",
        "PUNB": "Punjab National Bank",
        "BARB": "Bank of Baroda",
        "UBIN": "Union Bank of India",
        "INDB": "IndusInd Bank",
        "IDFB": "IDFC FIRST Bank",
        "YESB": "Yes Bank",
        "FDRL": "Federal Bank",
        "SCBL": "Standard Chartered Bank",
        "CITI": "Citibank",
        "HSBC": "HSBC Bank",
        "AIRP": "Airtel Payments Bank",
        "PYTM": "Paytm Payments Bank",
        "IOBA": "Indian Overseas Bank",
        "CBIN": "Central Bank of India",
        "BKID": "Bank of India"
    }

    BANK_PATTERNS = [
        ("Canara Bank", [r"canara\s*bank", r"canara\s*sb", r"\bcanara\b"]),
        ("State Bank of India", [r"state\s*bank\s*of\s*india", r"\bsbi\s+general\b", r"\bsbi\b"]),
        ("ICICI Bank", [r"icici\s*bank", r"\bicici\b"]),
        ("HDFC Bank", [r"hdfc\s*bank", r"hdfc\s*ltd", r"\bhdfc\s+bank\b"]),
        ("Axis Bank", [r"axis\s*bank", r"\baxis\b"]),
        ("Kotak Mahindra Bank", [r"kotak\s*mahindra", r"kotak\s*bank", r"\bkotak\b"]),
        ("Punjab National Bank", [r"punjab\s*national\s*bank", r"\bpnb\b"]),
        ("Bank of Baroda", [r"bank\s*of\s*baroda", r"\bbob\b"]),
        ("Union Bank of India", [r"union\s*bank", r"\bunion\b"]),
        ("IndusInd Bank", [r"indusind\s*bank", r"\bindusind\b"]),
        ("IDFC FIRST Bank", [r"idfc\s*first", r"idfc\s*bank", r"\bidfc\b"]),
        ("Yes Bank", [r"yes\s*bank", r"\byes\s*bank\b"]),
        ("Federal Bank", [r"federal\s*bank", r"\bfederal\b"]),
        ("Standard Chartered Bank", [r"standard\s*chartered", r"\bstan\s*chart\b"]),
        ("Citibank", [r"citibank", r"citi\s*bank", r"\bcitibank\b"]),
        ("HSBC Bank", [r"hsbc\s*bank", r"\bhsbc\b"]),
        ("Google Pay", [r"google\s*pay", r"\bgpay\b", r"payments\s+made\s+by\s+you\s+on\s+the\s+google\s+pay\s+app"])
    ]

    def __init__(self):
        pass

    def extract_from_file_or_bytes(self, file_path_or_bytes) -> Dict[str, Any]:
        """
        Extracts structured pages, table rows, and metadata from a bank statement PDF
        using PyMuPDF (fitz) with fallback to pdfplumber/PyPDF.
        """
        all_pages_text = []
        raw_tables = []
        full_text = ""

        # Primary Engine: PyMuPDF (fitz)
        if HAS_PYMUPDF:
            try:
                if isinstance(file_path_or_bytes, (bytes, bytearray)):
                    doc = fitz.open(stream=file_path_or_bytes, filetype="pdf")
                else:
                    doc = fitz.open(file_path_or_bytes)

                for page_idx in range(len(doc)):
                    page = doc[page_idx]
                    page_text = page.get_text() or ""
                    all_pages_text.append(page_text)
                    full_text += f"\n--- Page {page_idx + 1} ---\n" + page_text

                    # Try extracting tables using PyMuPDF native table finder if available
                    try:
                        tabs = page.find_tables()
                        if tabs and tabs.tables:
                            for tab in tabs.tables:
                                extracted_tab = tab.extract()
                                # Keep if more than 1 row or non-empty
                                if extracted_tab and len(extracted_tab) > 0:
                                    raw_tables.append(extracted_tab)
                    except Exception:
                        pass
                doc.close()
            except Exception:
                all_pages_text = []
                raw_tables = []
                full_text = ""

        # If PyMuPDF extraction did not get text, use pdfplumber
        if HAS_PDFPLUMBER and not full_text:
            try:
                with pdfplumber.open(file_path_or_bytes) as pdf:
                    for page_idx, page in enumerate(pdf.pages):
                        page_text = page.extract_text() or ""
                        all_pages_text.append(page_text)
                        full_text += f"\n--- Page {page_idx + 1} ---\n" + page_text

                        tables = page.extract_tables()
                        for table in tables:
                            if table:
                                raw_tables.append(table)
            except Exception:
                pass

        # Final Fallback to PyPDF
        if not full_text:
            try:
                if isinstance(file_path_or_bytes, (bytes, bytearray)):
                    reader = PdfReader(io.BytesIO(file_path_or_bytes))
                else:
                    reader = PdfReader(file_path_or_bytes)
                
                for idx, page in enumerate(reader.pages):
                    pt = page.extract_text() or ""
                    all_pages_text.append(pt)
                    full_text += f"\n--- Page {idx + 1} ---\n" + pt
            except Exception as fallback_e:
                raise ValueError(f"Could not extract text from PDF: {str(fallback_e)}")

        raw_lines = [l.strip() for l in full_text.splitlines() if l.strip()]

        # Metadata extraction
        detected_bank = self._detect_bank(full_text, all_pages_text)
        account_number = self._extract_account_number(full_text)
        period_start, period_end = self._extract_statement_period(full_text)

        return {
            "total_pages": len(all_pages_text),
            "page_count": len(all_pages_text),
            "full_text": full_text,
            "pages_text": all_pages_text,
            "raw_lines": raw_lines,
            "raw_tables": raw_tables,
            "detected_bank": detected_bank,
            "account_number": account_number,
            "statement_period_start": period_start,
            "statement_period_end": period_end
        }

    def _detect_bank(self, full_text: str, pages_text: Optional[List[str]] = None) -> str:
        """
        Identifies issuing bank from statement header, IFSC code, and brand keywords.
        Prioritizes the first page / header section to avoid false-positives from UPI counterparties.
        """
        header_text = ""
        if pages_text and len(pages_text) > 0:
            header_text = pages_text[0][:2500].lower()
        else:
            header_text = full_text[:2500].lower()

        # 1. Check IFSC Code in header of Page 1
        ifsc_match = re.search(r'ifsc(?:\s*code)?[:\s]*([a-z]{4})0[a-z0-9]{6}', header_text)
        if ifsc_match:
            prefix = ifsc_match.group(1).upper()
            if prefix in self.IFSC_PREFIX_MAP:
                return self.IFSC_PREFIX_MAP[prefix]

        # 2. Check IFSC Code anywhere in document if explicitly labeled
        ifsc_any = re.search(r'ifsc(?:\s*code)?[:\s]*([a-z]{4})0[a-z0-9]{6}', full_text.lower())
        if ifsc_any:
            prefix = ifsc_any.group(1).upper()
            if prefix in self.IFSC_PREFIX_MAP:
                return self.IFSC_PREFIX_MAP[prefix]

        # 3. Check Bank Name Patterns in Header Text
        for bank_name, patterns in self.BANK_PATTERNS:
            for p in patterns:
                if re.search(p, header_text):
                    return bank_name

        # 4. Fallback search across full text with specific patterns
        for bank_name, patterns in self.BANK_PATTERNS:
            for p in patterns:
                if re.search(p, full_text.lower()):
                    return bank_name

        return "Bank Statement"

    def _extract_account_number(self, text: str) -> Optional[str]:
        """Extracts masked or unmasked account number."""
        match = re.search(r'(?:account|a/c)\s*(?:no|num|number)?[:\s.]*([X\d]{8,18})', text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
        return None

    def _extract_statement_period(self, text: str) -> Tuple[Optional[str], Optional[str]]:
        """Extracts start and end date of statement period supporting multiple formats."""
        date_pat = r'(?:\d{1,2}[-/.\s](?:[A-Za-z]{3,9}|\d{1,2})[-/.\s]\d{2,4})'
        period_match = re.search(
            rf'(?:period|from)[:\s]*({date_pat})\s*(?:to|-)\s*({date_pat})',
            text,
            re.IGNORECASE
        )
        if period_match:
            return period_match.group(1).strip(), period_match.group(2).strip()
        return None, None
