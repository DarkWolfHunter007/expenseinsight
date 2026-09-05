import re
from typing import List, Optional

class TextCleaner:
    """
    Cleans raw bank statement descriptions and extracts meaningful merchant tokens.
    Implements Layer 1 cleaning from the PRD.
    """

    # Banking channels and payment gateway prefixes/suffixes
    CHANNEL_PREFIXES = [
        r'\bUPI[-/:]?',
        r'\bPOS[-/:\s]?',
        r'\bNEFT[-/:]?',
        r'\bRTGS[-/:]?',
        r'\bIMPS[-/:]?',
        r'\bACH[-/:]?',
        r'\bBIL[-/:]?',
        r'\bINB[-/:]?',
        r'\bECS[-/:]?',
        r'\bECOM[-/:]?',
        r'\bATM[-/:]?',
        r'\bNACH[-/:]?',
        r'\bCMS[-/:]?',
        r'\bTPT[-/:]?',
        r'\bBBPS[-/:]?',
        r'\bIB[-/:]?',
        r'\bMB[-/:]?',
        r'\bDR[-/:]?',
        r'\bCR[-/:]?',
    ]

    # Sub-strings or noise tokens commonly seen in statement descriptions
    NOISE_PATTERNS = [
        r'\b\d{6,}\b',                     # Long numbers / transaction IDs / UTRs
        r'\bP2[MPA]\b',                     # P2M, P2P, P2A
        r'\bRAZORPAY\b',                    # Gateway names if acting as proxy
        r'\bBILLDESK\b',
        r'\bPAYU\b',
        r'\bCCAVENUE\b',
        r'\bPAYTM[-_]?QR\b',
        r'\bPHONEPE[-_]?QR\b',
        r'\bGPAY[-_]?QR\b',
        r'\bBHARATPE\b',
        r'\bAIRPAY\b',
        r'\bCASHIER\b',
        r'\bSTORE\s*\d+\b',
        r'\bBRANCH\s*\d+\b',
        r'\bTERMINAL\s*\d+\b',
        r'\bREF\s*NO[:\s]*\w+\b',
        r'\bTXN\s*ID[:\s]*\w+\b',
        r'\bUTR[:\s]*\w+\b',
        r'\bVAL[:\s]*\d{2}[-/]\d{2}[-/]\d{2,4}\b',
        r'\b\d{2}[-/]\d{2}[-/]\d{2,4}\b',   # Date strings inside description
        r'\b(?:PVT|LTD|LIMITED|INC|LLC|CORP|SERVICES|ENTERPRISES|INDIA)\b', # Corp suffixes (handled carefully)
    ]

    def __init__(self):
        self.prefix_regex = re.compile('|'.join(self.CHANNEL_PREFIXES), re.IGNORECASE)
        self.noise_regex = re.compile('|'.join(self.NOISE_PATTERNS), re.IGNORECASE)

    def clean(self, raw_description: str) -> str:
        """
        Cleans a raw statement transaction description into a normalized text representation.
        """
        if not raw_description or not isinstance(raw_description, str):
            return ""

        text = raw_description.strip()

        # Step 1: Replace common delimiter characters with spaces
        text = re.sub(r'[/\\*_\-:,|#@~]', ' ', text)

        # Step 2: Strip known banking channel prefixes
        text = self.prefix_regex.sub(' ', text)

        # Step 3: Remove standalone noise patterns (IDs, dates, gateways)
        text = self.noise_regex.sub(' ', text)

        # Step 4: Remove remaining standalone alphanumeric codes / hex / numeric fragments (>=4 digits)
        text = re.sub(r'\b[0-9a-fA-F]{6,}\b', ' ', text)
        text = re.sub(r'\b\d+\b', ' ', text)

        # Step 5: Remove special characters, keep letters and spaces
        text = re.sub(r'[^a-zA-Z\s]', ' ', text)

        # Step 6: Collapse whitespace and lowercase
        text = re.sub(r'\s+', ' ', text).strip().lower()

        return text

    def tokenize(self, text: str) -> List[str]:
        """
        Tokenizes cleaned text into meaningful word tokens.
        """
        cleaned = self.clean(text)
        return [tok for tok in cleaned.split() if len(tok) > 1]
