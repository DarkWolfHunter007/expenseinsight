import os
from typing import Any, Dict, List, Optional, Tuple, Union
import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.calibration import CalibratedClassifierCV
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import LinearSVC, SVC
from sklearn.pipeline import Pipeline
from sklearn.base import BaseEstimator, TransformerMixin
import joblib

try:
    from .text_cleaner import TextCleaner
    from .merchant_normalizer import MerchantNormalizer
except ImportError:
    from text_cleaner import TextCleaner
    from merchant_normalizer import MerchantNormalizer

class SentenceEmbeddingTransformer(BaseEstimator, TransformerMixin):
    """
    Sentence-Transformers embedding transformer (all-MiniLM-L6-v2)
    Conforming to the proposed methodology for deep text embeddings.
    """
    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        self.model_name = model_name
        self._model = None

    def fit(self, X, y=None):
        return self

    def transform(self, X):
        try:
            from sentence_transformers import SentenceTransformer
            if self._model is None:
                self._model = SentenceTransformer(self.model_name)
            return self._model.encode(list(X), show_progress_bar=False, convert_to_numpy=True)
        except Exception:
            raise RuntimeError("sentence-transformers not installed. Use TF-IDF vectorizer fallback.")

class ExpenseClassifier:
    """
    NLP & Machine Learning classifier for expense categorization.
    Supports Sentence-Transformers / TF-IDF + Calibrated LinearSVC (SVM) / Logistic Regression.
    """

    def __init__(self, model_type: str = "linear_svc", embedding_type: str = "tfidf", max_features: int = 5000):
        self.model_type = model_type
        self.embedding_type = embedding_type
        self.text_cleaner = TextCleaner()

        if embedding_type == "sentence_transformers":
            self.vectorizer = SentenceEmbeddingTransformer(model_name="all-MiniLM-L6-v2")
        else:
            self.vectorizer = TfidfVectorizer(
                ngram_range=(1, 3),
                analyzer="word",
                sublinear_tf=True,
                min_df=2,
                max_features=max_features,
                token_pattern=r'(?u)\b\w+\b'
            )

        if model_type in ("linear_svc", "svm"):
            base_svc = LinearSVC(C=1.0, max_iter=2000, random_state=42)
            self.classifier = CalibratedClassifierCV(estimator=base_svc, cv=3)
        elif model_type == "logistic_regression":
            base_clf = LogisticRegression(
                C=1.5,
                max_iter=1000,
                class_weight="balanced",
                random_state=42
            )
            self.classifier = base_clf
        elif model_type == "random_forest":
            self.classifier = RandomForestClassifier(
                n_estimators=100,
                max_depth=20,
                random_state=42,
                class_weight="balanced"
            )
        else:
            base_svc = LinearSVC(C=1.0, max_iter=2000, random_state=42)
            self.classifier = CalibratedClassifierCV(estimator=base_svc, cv=3)


        self.pipeline: Optional[Pipeline] = None
        self.classes_: Optional[np.ndarray] = None
        self.is_fitted: bool = False

    def _prepare_text(self, descriptions: List[str], normalizer: Optional[MerchantNormalizer] = None) -> List[str]:
        """Enriches raw transaction descriptions with cleaned text and normalized merchant tokens."""
        norm = normalizer or MerchantNormalizer()
        prepared = []
        for desc in descriptions:
            cleaned = self.text_cleaner.clean(desc)
            merchant_display, merchant_key, _, _ = norm.normalize(desc)
            # Combine cleaned description with normalized merchant to amplify key features
            enriched = f"{cleaned} {merchant_display.lower()} {merchant_key.replace('_', ' ')}"
            prepared.append(enriched.strip())
        return prepared

    def fit(self, descriptions: List[str], categories: List[str], normalizer: Optional[MerchantNormalizer] = None):
        """Fits vectorizer and classifier pipeline."""
        X_text = self._prepare_text(descriptions, normalizer)
        step_name = "embed" if self.embedding_type == "sentence_transformers" else "tfidf"
        self.pipeline = Pipeline([
            (step_name, self.vectorizer),
            ("clf", self.classifier)
        ])
        self.pipeline.fit(X_text, categories)
        self.classes_ = self.pipeline.classes_
        self.is_fitted = True
        return self

    def predict_proba(self, descriptions: List[str], normalizer: Optional[MerchantNormalizer] = None) -> np.ndarray:
        """Returns probability distribution across classes for each input description."""
        if not self.is_fitted or self.pipeline is None:
            raise ValueError("Classifier is not fitted. Train or load model first.")
        X_text = self._prepare_text(descriptions, normalizer)
        return self.pipeline.predict_proba(X_text)

    def predict_single(self, description: str, normalizer: Optional[MerchantNormalizer] = None) -> Tuple[str, float, Dict[str, float]]:
        """
        Predicts category, confidence, and full probability map for a single description.
        Returns:
            (predicted_category, confidence_score, probabilities_dict)
        """
        if not self.is_fitted or self.pipeline is None:
            raise ValueError("Classifier is not fitted.")

        probs = self.predict_proba([description], normalizer)[0]
        max_idx = int(np.argmax(probs))
        predicted_category = str(self.classes_[max_idx])
        confidence = float(probs[max_idx])

        prob_dict = {str(cat): round(float(p), 4) for cat, p in zip(self.classes_, probs)}
        # Sort probability dictionary descending
        prob_dict = dict(sorted(prob_dict.items(), key=lambda item: item[1], reverse=True))

        return predicted_category, confidence, prob_dict

    def save(self, filepath: str):
        """Saves pipeline and metadata to disk."""
        os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
        joblib.dump({
            "pipeline": self.pipeline,
            "classes": self.classes_,
            "model_type": self.model_type,
            "embedding_type": self.embedding_type,
            "is_fitted": self.is_fitted
        }, filepath)

    @classmethod
    def load(cls, filepath: str) -> "ExpenseClassifier":
        """Loads serialized model pipeline from disk."""
        data = joblib.load(filepath)
        instance = cls(
            model_type=data.get("model_type", "linear_svc"),
            embedding_type=data.get("embedding_type", "tfidf")
        )
        instance.pipeline = data["pipeline"]
        instance.classes_ = data["classes"]
        instance.is_fitted = data["is_fitted"]
        if instance.pipeline is not None:
            if "tfidf" in instance.pipeline.named_steps:
                instance.vectorizer = instance.pipeline.named_steps["tfidf"]
            elif "embed" in instance.pipeline.named_steps:
                instance.vectorizer = instance.pipeline.named_steps["embed"]
            if "clf" in instance.pipeline.named_steps:
                instance.classifier = instance.pipeline.named_steps["clf"]
        return instance

