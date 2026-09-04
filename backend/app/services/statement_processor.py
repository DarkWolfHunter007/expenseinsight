import os
import sys
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..")))

from ml.categorization.classifier import ExpenseClassifier
from ml.categorization.hybrid_categorizer import HybridCategorizer
from ml.preprocessing.merchant_normalizer import MerchantNormalizer
from .pdf_extractor import PDFExtractor
from .transaction_parser import TransactionParser
from .forecasting_service import ForecastingService
from ..models.db_models import Statement, Transaction, CategoryCorrection

class StatementProcessor:
    """
    End-to-End Bank Statement Processing Pipeline conforming to PRD Sections 9, 10, 12, 18, 34.
    """

    def __init__(self, db: Session, model_path: Optional[str] = None):
        self.db = db
        self.pdf_extractor = PDFExtractor()
        self.parser = TransactionParser()

        # Load ML Classifier and Normalizer
        if model_path is None:
            model_path = os.path.abspath(
                os.path.join(os.path.dirname(__file__), "..", "..", "..", "ml", "models", "expense_classifier.joblib")
            )

        classifier = None
        if os.path.exists(model_path):
            try:
                classifier = ExpenseClassifier.load(model_path)
            except Exception as e:
                print(f"Notice: could not load ML classifier: {e}")

        # Load user corrections from DB for layer 4
        corrections = self.db.query(CategoryCorrection).all()
        custom_dict = {c.old_category: c.new_category for c in corrections}
        
        self.normalizer = MerchantNormalizer(custom_corrections=custom_dict)
        self.hybrid_categorizer = HybridCategorizer(classifier=classifier, normalizer=self.normalizer)
        self.forecasting_service = ForecastingService(db=self.db)

    def process_statement(self, statement_id: str, file_path_or_bytes: Any) -> Dict[str, Any]:
        """
        Executes the 7-stage statement ingestion and intelligence pipeline.
        """
        stmt = self.db.query(Statement).filter(Statement.id == statement_id).first()
        if not stmt:
            raise ValueError(f"Statement {statement_id} not found in database.")

        try:
            # Step 1: Reading PDF
            stmt.processing_status = "processing"
            stmt.processing_step = "Reading PDF document"
            stmt.processing_progress = 0.15
            self.db.commit()

            extraction_result = self.pdf_extractor.extract_from_file_or_bytes(file_path_or_bytes)
            stmt.bank_name = extraction_result.get("detected_bank") or stmt.bank_name
            stmt.account_number = extraction_result.get("account_number") or stmt.account_number
            stmt.statement_start = extraction_result.get("statement_period_start") or stmt.statement_start
            stmt.statement_end = extraction_result.get("statement_period_end") or stmt.statement_end
            self.db.commit()

            # Step 2: Extracting transactions
            stmt.processing_step = "Extracting transactions"
            stmt.processing_progress = 0.35
            self.db.commit()

            raw_txns = self.parser.parse(extraction_result)
            if not raw_txns:
                raise ValueError("Could not extract any transaction records from statement.")

            # Step 3, 4, 5: Cleaning, Normalizing, Categorizing
            stmt.processing_step = "Normalizing merchants & AI Categorization"
            stmt.processing_progress = 0.65
            self.db.commit()

            processed_transactions = []
            for item in raw_txns:
                raw_desc = item["raw_description"]
                amt = item["amount"]
                txn_type = item["transaction_type"]

                # Run Hybrid Categorization
                cat_res = self.hybrid_categorizer.categorize_transaction(
                    raw_description=raw_desc,
                    amount=amt,
                    transaction_type=txn_type
                )

                txn = Transaction(
                    user_id=stmt.user_id,
                    statement_id=stmt.id,
                    date=item["date"],
                    raw_description=raw_desc,
                    clean_description=cat_res.get("normalized_merchant"),
                    merchant=cat_res.get("merchant"),
                    normalized_merchant=cat_res.get("normalized_merchant"),
                    amount=amt,
                    currency=item.get("currency", "INR"),
                    transaction_type=txn_type,
                    cr_dr=item.get("cr_dr", "DR"),
                    balance=item.get("balance"),
                    reference_number=item.get("reference_number"),
                    category=cat_res.get("category", "Uncategorized"),
                    category_confidence=cat_res.get("confidence", 0.0),
                    category_source=cat_res.get("source", "ml"),
                    needs_review=cat_res.get("needs_review", False),
                    is_duplicate=item.get("is_duplicate", False)
                )
                self.db.add(txn)
                processed_transactions.append(txn)

            stmt.total_transactions = len(processed_transactions)
            self.db.commit()

            # Step 6: Building spending analysis
            stmt.processing_step = "Building spending analysis"
            stmt.processing_progress = 0.85
            self.db.commit()

            # Step 7: Generating forecast
            stmt.processing_step = "Generating expense forecast"
            stmt.processing_progress = 0.95
            self.db.commit()

            self.forecasting_service.generate_user_forecast(user_id=stmt.user_id, persist=True)

            # Complete!
            stmt.processing_status = "completed"
            stmt.processing_step = "Completed"
            stmt.processing_progress = 1.0
            self.db.commit()

            return {
                "status": "success",
                "statement_id": stmt.id,
                "bank_name": stmt.bank_name,
                "total_transactions": len(processed_transactions),
                "period": f"{stmt.statement_start} to {stmt.statement_end}"
            }

        except Exception as e:
            stmt.processing_status = "failed"
            stmt.processing_step = f"Failed: {str(e)}"
            self.db.commit()
            raise e
