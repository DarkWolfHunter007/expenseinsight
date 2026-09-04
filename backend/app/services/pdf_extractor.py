import io
import re
from typing import Any, Dict, List, Optional, Tuple
import pdfplumber
from pypdf import PdfReader

class PDFExtractor:
    """
    Extracts text and tabular records from bank statement PDFs conforming to PRD Section 9.
    """

    BANK_PATTERNS = {
        "HDFC Bank": [r"hdfc\s*bank", r"hdfc000\d+", r"hdfc"],
        "State Bank of India": [r"state\s*bank\s*of\s*india", r"sbin000\d+", r"\bsbi\b"],
        "ICICI Bank": [r"icici\s*bank", r"icic000\d+", r"icici"],
        "Axis Bank": [r"axis\s*bank", r"utib000\d+"],
        "Kotak Mahindra Bank": [r"kotak\s*mahindra", r"kkbk000\d+"]
    }

    def __init__(self):
        pass

    def extract_from_file_or_bytes(self, file_path_or_bytes) -> Dict[str, Any]:
        """
        Extracts structured pages, table rows, and metadata from a bank statement PDF.
        """
        all_pages_text = []
        raw_tables = []
        full_text = ""

        try:
            with pdfplumber.open(file_path_or_bytes) as pdf:
                for page_idx, page in enumerate(pdf.pages):
                    page_text = page.extract_text() or ""
                    all_pages_text.append(page_text)
                    full_text += f"\n--- Page {page_idx + 1} ---\n" + page_text

                    # Extract tabular structures if present
                    tables = page.extract_tables()
                    for table in tables:
                        if table:
                            raw_tables.append(table)
        except Exception as e:
            # Fallback to PyPDF if pdfplumber encounters formatting quirks
            try:
                if isinstance(file_path_or_bytes, bytes):
                    reader = PdfReader(io.BytesIO(file_path_or_bytes))
                else:
                    reader = PdfReader(file_path_or_bytes)
                
                for idx, page in enumerate(reader.pages):
                    pt = page.extract_text() or ""
                    all_pages_text.append(pt)
                    full_text += f"\n--- Page {idx + 1} ---\n" + pt
            except Exception as fallback_e:
                raise ValueError(f"Could not extract text from PDF: {str(e)} | Fallback error: {str(fallback_e)}")

        # Metadata extraction
        detected_bank = self._detect_bank(full_text)
        account_number = self._extract_account_number(full_text)
        period_start, period_end = self._extract_statement_period(full_text)

        return {
            "total_pages": len(all_pages_text),
            "full_text": full_text,
            "pages_text": all_pages_text,
            "raw_tables": raw_tables,
            "detected_bank": detected_bank,
            "account_number": account_number,
            "statement_period_start": period_start,
            "statement_period_end": period_end
        }

    def _detect_bank(self, text: str) -> str:
        """Identifies bank from text patterns."""
        lower_text = text.lower()
        for bank_name, patterns in self.BANK_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, lower_text):
                    return bank_name
        return "Bank Statement"

    def _extract_account_number(self, text: str) -> Optional[str]:
        """Extracts masked or unmasked account number."""
        match = re.search(r'(?:account|a/c)\s*(?:no|num|number)?[:\s.]*([X\d]{8,18})', text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
        return None

    def _extract_statement_period(self, text: str) -> Tuple[Optional[str], Optional[str]]:
        """Extracts start and end date of statement period."""
        period_match = re.search(
            r'(?:period|from)[:\s]*(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})\s*(?:to|-)\s*(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})',
            text,
            re.IGNORECASE
        )
        if period_match:
            return period_match.group(1).strip(), period_match.group(2).strip()
        return None, None
