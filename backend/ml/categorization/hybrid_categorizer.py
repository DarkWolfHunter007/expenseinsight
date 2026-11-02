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
    KEYWORD_CONFIDENCE = 0.72

    # Payment handles that only businesses have: static/dynamic QR codes, Google Pay for Business,
    # payment gateways.
    _BUSINESS_SIGNAL = re.compile(
        r"STATICQR|\bDQR\d*|OKBIZ|PAYTMQR|BHARATPE|MSWIPE|\.PAYU|\bPAYU@|RZP@|RAZORPAY|QR\d*@", re.IGNORECASE
    )
    _MS_PREFIX = re.compile(r"UPI/(?:DR|CR)/\d*/M/S", re.IGNORECASE)

    # A clear business word in the payee suggests a category. Short words must match a whole token
    # ("CHIT" must not match the name CHITRA); words of 5+ letters match as a prefix because the bank
    # cuts payee names ("RESTAUR") and the PDF wraps them in the middle of a word ("BARBEC UE").
    _HINTS = {
        "Food": (
            {"CAFE", "TEA", "FOOD", "FOODS", "SWEETS", "HOTEL", "HOTELS", "BAKE", "BBQ", "MESS", "TIFFIN", "DINER"},
            ("BAKER", "RESTAUR", "KITCHEN", "COFFEE", "JUICE", "BARBEC", "BIRYANI", "CATERING"),
        ),
        "Fuel": ({"FUEL", "FUELS", "PETROL", "DIESEL"}, ("PETROL",)),
        "Healthcare": (
            {"CLINIC", "LAB", "LABS", "DENTAL", "OPTICAL", "OPTICALS"},
            ("MEDICAL", "PHARMA", "HOSPITAL", "OPTICAL", "DENTAL"),
        ),
        "Shopping": (
            {"STORE", "STORES", "SHOP", "SHOPS", "BOOK", "BOOKS", "PET", "PETS", "MOBILE", "MOBILES"},
            ("TEXTILE", "FASHION", "JEWEL", "STATION", "ELECTRON", "ELECTRIC", "HARDWARE", "COMPUTER", "XEROX", "FLOWER"),
        ),
        "Groceries": ({"MART", "SUPERMARKET"}, ("SUPER", "GROCER", "VEGETABL", "DAIRY", "MARKET")),
        "Travel": ({"CABS", "TAXI", "TOUR", "TOURS", "TRAVELS"}, ("TRAVEL", "MOTOR", "GARAGE")),
        "Personal Care": ({"SALON", "SPA", "GYM", "PARLOUR", "BEAUTY"}, ("FITNESS", "PARLOUR")),
    }
    # Business words that do not point to a category (the row goes to review instead)
    _OTHER_BUSINESS_WORDS = {
        "CHIT", "CHITS", "PAY", "LTD", "PVT", "TECH", "BAR", "CLOUD", "PLAY", "GOLD", "AGENCY", "AUTO", "HUT",
        "SIGN", "SIGNS",
    }
    _OTHER_BUSINESS_PREFIXES = (
        "ENTERPR", "SERVICE", "STUDIO", "TRADER", "TRADING", "FINANCE", "INSURANCE", "SOFTWARE", "SYSTEM",
        "SOLUTION", "CORPORAT", "PAYMENT", "RECHARGE", "WALLET", "SCHOOL", "COLLEGE", "ACADEMY", "INSTITUT",
        "ASSOCIAT", "SOCIETY", "TRUST", "ENTERTAIN", "PRINT",
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

    @staticmethod
    def _word_matches(word: str, exact: set, prefixes: tuple) -> bool:
        return word in exact or (len(word) >= 5 and word.startswith(prefixes))

    def payee_profile(self, raw_description: str) -> Optional[Dict[str, Any]]:
        """Judges a UPI payee: is it a business, and does a business word suggest a category?
        Returns None when the narration is not a UPI payment (there is no payee to judge)."""
        payee = MerchantNormalizer.extract_payee(raw_description)
        if payee is None:
            return None

        raw_tokens = payee.replace(".", " ").replace("/", " ").upper().split()
        # Wrapped lines leave fragments of the payment handle glued to the name ("KANNAN S99", "PM@");
        # a token that is only digits ("ICGAIFE 3") is a real code and stays as it is.
        tokens = [re.sub(r"[\d@]+$", "", tk) if re.search(r"[A-Z]", tk) else tk for tk in raw_tokens]

        # The PDF wraps lines in the middle of words ("ST ATICQR"), so also look with the spaces removed
        spaceless = re.sub(r"\s+", "", (raw_description or "").upper())
        business = bool(
            self._BUSINESS_SIGNAL.search(raw_description or "")
            or self._BUSINESS_SIGNAL.search(spaceless)
            or self._MS_PREFIX.search(raw_description or "")
            or not 1 <= len(tokens) <= 4
        )
        hint: Optional[str] = None
        brands = self._brand_words()

        # Single tokens, and neighbours joined together to undo a mid-word wrap ("BARBEC" + "UE")
        words = list(tokens) + ["".join(pair) for pair in zip(tokens, tokens[1:])]
        for word in words:
            if not word.isalpha():
                if word in tokens:
                    business = True  # a code such as "3" is not part of a personal name
                continue
            for category, (exact, prefixes) in self._HINTS.items():
                if self._word_matches(word, exact, prefixes):
                    business = True
                    hint = hint or category
            if self._word_matches(word, self._OTHER_BUSINESS_WORDS, self._OTHER_BUSINESS_PREFIXES):
                business = True
            if word in brands and word in tokens:
                business = True

        return {"payee": payee, "business": business, "hint": hint}

    def payee_looks_like_person(self, raw_description: str) -> Optional[bool]:
        """True/False for a UPI narration, None when there is no UPI payee to judge."""
        profile = self.payee_profile(raw_description)
        if profile is None:
            return None
        return not profile["business"]

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

            # A payee that does not look like a person is not trusted as a transfer
            profile = self.payee_profile(raw_description)
            if profile and profile["business"]:
                if profile["hint"]:
                    # A clear business word ("BAKERY", "FUELS", "MEDICAL") names the category
                    category = profile["hint"]
                    confidence = self.KEYWORD_CONFIDENCE
                    source = "payee_keyword"
                    explanation = (
                        f"The payee '{profile['payee']}' contains a business word that points to "
                        f"{category}; please check it if it looks wrong."
                    )
                elif category == "Transfers":
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
