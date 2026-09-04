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
            explanation += " Category marked for user review due to low confidence."

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
