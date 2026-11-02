import re
from typing import Any, Dict, List, Optional, Tuple
from ..preprocessing.merchant_normalizer import MerchantNormalizer
from .classifier import ExpenseClassifier

class HybridCategorizer:
    """
    Hybrid expense categorization engine combining:
    1. Layered Merchant Normalization
    2. Known Merchant Knowledge Base & User Overrides
    3. Supervised ML Classifier (TF-IDF + Calibrated Logistic Regression)
    4. Configurable Confidence Thresholding and Uncertainty Detection
    5. Explainability Layer
    """

    # A payee is only trusted as "a person" (so a transfer) when it looks like a personal name. The ML
    # model was trained mostly on synthetic data where a named UPI payee meant a person, so it calls
    # every unfamiliar payee a transfer with ~99% confidence, even a shop or gibberish.
    UNVERIFIED_TRANSFER_CONFIDENCE = 0.55
    _PAYEE_PATTERN = re.compile(r"UPI/(?:DR|CR)/\d+/([^/]+)/")
    # Short words must match a whole token ("CHIT" must not match the name CHITRA); long ones by prefix
    # because the bank cuts payee names ("RESTAURA").
    _BUSINESS_WORDS = {
        "STORE", "STORES", "MART", "SHOP", "SHOPS", "BOOK", "BOOKS", "CAFE", "TEA", "FOOD", "FOODS", "FUEL",
        "CHIT", "CHITS", "BAKE", "PAY", "LTD", "PVT", "TECH", "LAB", "LABS", "GYM", "CABS", "TAXI", "AUTO", "SPA", "BAR",
        "CLOUD", "PLAY", "GOLD", "TOUR", "TOURS", "SWEETS", "HOTEL", "HOTELS", "AGENCY", "CLINIC",
    }
    _BUSINESS_PREFIXES = (
        "MEDICAL", "PHARMA", "BAKE", "PETROL", "RESTAUR", "SUPER", "MARKET", "TRADER", "TRADING", "ENTERPR",
        "SERVICE", "HOSPITAL", "STATION", "STATIONERY", "TEXTILE", "FASHION", "JEWEL", "FINANCE", "INSURANCE",
        "SOFTWARE", "SYSTEM", "SOLUTION", "CORPORAT", "PAYMENT", "RECHARGE", "WALLET", "STUDIO", "KITCHEN",
        "COFFEE", "JUICE", "GROCER", "VEGETABL", "DAIRY", "PRINT", "XEROX", "COMPUTER", "MOBILE", "ELECTRIC",
        "ELECTRON", "HARDWARE", "TRAVEL", "MOTOR", "GARAGE", "FLOWER", "OPTICAL", "FITNESS", "SALON",
        "PARLOUR", "SCHOOL", "COLLEGE", "ACADEMY", "INSTITUT", "ASSOCIAT", "SOCIETY", "TRUST", "ENTERTAIN",
    )

    HIGH_CONFIDENCE_THRESHOLD = 0.85
    MEDIUM_CONFIDENCE_THRESHOLD = 0.60

    def __init__(
        self,
        classifier: Optional[ExpenseClassifier] = None,
        normalizer: Optional[MerchantNormalizer] = None,
        high_threshold: float = HIGH_CONFIDENCE_THRESHOLD,
        medium_threshold: float = MEDIUM_CONFIDENCE_THRESHOLD
    ):
        self.classifier = classifier
        self.normalizer = normalizer or MerchantNormalizer()
        self.high_threshold = high_threshold
        self.medium_threshold = medium_threshold

    def _brand_words(self) -> set:
        """First words (4+ letters) of every known merchant alias, e.g. 'google', 'flipkart'."""
        if not hasattr(self, "_brand_word_cache"):
            words = set()
            for data in getattr(self.normalizer, "kb", {}).values():
                for alias in data.get("aliases", []):
                    first = alias.split()[0].upper() if alias.split() else ""
                    if len(first) >= 4 and first.isalpha():
                        words.add(first)
            self._brand_word_cache = words
        return self._brand_word_cache

    def payee_looks_like_person(self, raw_description: str) -> Optional[bool]:
        """True/False for a UPI narration, None when there is no UPI payee to judge."""
        match = self._PAYEE_PATTERN.search(raw_description or "")
        if not match:
            return None
        raw_tokens = match.group(1).replace(".", " ").upper().split()
        # Wrapped lines leave fragments of the payment handle glued to the name ("KANNAN S99", "PM@");
        # a token that is only digits ("ICGAIFE 3") is a real code and stays as it is.
        tokens = [re.sub(r"[\d@]+$", "", tk) if re.search(r"[A-Z]", tk) else tk for tk in raw_tokens]
        if not 1 <= len(tokens) <= 4:
            return False
        brands = self._brand_words()
        for token in tokens:
            if not token.isalpha() or token in self._BUSINESS_WORDS or token in brands:
                return False
            if len(token) >= 5 and token.startswith(self._BUSINESS_PREFIXES):
                return False
        return True

    def categorize_transaction(
        self,
        raw_description: str,
        amount: Optional[float] = None,
        transaction_type: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Runs the full hybrid categorization pipeline on a transaction.
        """
        # Step 1: Merchant Normalization
        merchant_display, merchant_key, default_cat, norm_conf = self.normalizer.normalize(raw_description)

        category = "Uncategorized"
        confidence = 0.0
        source = "heuristic"
        prob_dist = {}
        explanation = ""

        # Step 2: Check if merchant KB has a strong match
        if default_cat and norm_conf >= 0.88:
            category = default_cat
            confidence = norm_conf
            source = "merchant_kb"
            explanation = f"Matched known merchant '{merchant_display}' with default category '{default_cat}'."
            prob_dist = {default_cat: round(confidence, 4)}

        # Step 3: Run ML Classifier if available
        elif self.classifier and self.classifier.is_fitted:
            pred_cat, ml_conf, ml_probs = self.classifier.predict_single(raw_description, self.normalizer)
            category = pred_cat
            confidence = ml_conf
            source = "ml_classifier"
            prob_dist = ml_probs
            explanation = f"Classified by machine learning model with {confidence*100:.1f}% confidence."

            # Do not trust "Transfers" for a payee that does not look like a person
            if category == "Transfers" and self.payee_looks_like_person(raw_description) is False:
                confidence = min(confidence, self.UNVERIFIED_TRANSFER_CONFIDENCE)
                explanation = (
                    "The model guessed a transfer, but the payee does not look like a person's name, "
                    "so it needs a human check."
                )

        # Step 4: Fallback heuristic if no ML model fitted
        else:
            if default_cat:
                category = default_cat
                confidence = norm_conf
                source = "heuristic_lookup"
                explanation = f"Heuristic match for merchant '{merchant_display}'."
            else:
                category = "Other"
                confidence = 0.40
                source = "fallback"
                explanation = "Insufficient signals for automated categorization."

        # Step 5: Confidence Evaluation & Needs Review Flag
        if confidence >= self.high_threshold:
            confidence_level = "high"
            needs_review = False
        elif confidence >= self.medium_threshold:
            confidence_level = "medium"
            needs_review = False
        else:
            confidence_level = "low"
            needs_review = True
            predicted_hint = category
            category = "Uncategorized"
            explanation = f"Low AI confidence ({confidence*100:.1f}%, predicted '{predicted_hint}'). Marked as Uncategorized for user review."

        # Special overrides for explicit salary/transfer indicators
        upper_desc = raw_description.upper()
        if "SALARY" in upper_desc or "PAYROLL" in upper_desc:
            category = "Income"
            confidence = 0.99
            confidence_level = "high"
            needs_review = False
            source = "rule_override"
        elif "ATM WDL" in upper_desc or "CASH WDL" in upper_desc or "NFS WDL" in upper_desc:
            category = "Cash Withdrawal"
            confidence = 0.99
            confidence_level = "high"
            needs_review = False
            source = "rule_override"

        return {
            "raw_description": raw_description,
            "merchant": merchant_display,
            "normalized_merchant": merchant_key,
            "category": category,
            "confidence": round(confidence, 4),
            "confidence_level": confidence_level,
            "confidence_percentage": f"{confidence * 100:.1f}%",
            "source": source,
            "needs_review": needs_review,
            "probabilities": prob_dist,
            "explanation": explanation
        }
