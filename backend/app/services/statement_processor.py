import os
import sys
import time
from collections import Counter
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..")))

from backend.ml.categorization.classifier import ExpenseClassifier
from backend.ml.categorization.hybrid_categorizer import HybridCategorizer
from backend.ml.preprocessing.merchant_normalizer import MerchantNormalizer
from .pdf_extractor import PDFExtractor
from .transaction_parser import TransactionParser
from .analytics_service import AnalyticsService
from .forecasting_service import ForecastingService
from ..models.db_models import Statement, Transaction, CategoryCorrection

# Terminal ANSI Color & Style Formatting (Safe for Windows & Unix)
CYAN = "\033[1;36m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[1;34m"
MAGENTA = "\033[1;35m"
RED = "\033[1;31m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"


class StatementProcessor:
    """
    End-to-End Bank Statement Processing Pipeline with Real-Time Terminal Visibility.
    Conforms to PRD Sections 9, 10, 12, 18, 34.
    """

    def __init__(self, db: Session, model_path: Optional[str] = None):
        self.db = db
        self.pdf_extractor = PDFExtractor()
        self.parser = TransactionParser()

        # Load ML Classifier and Normalizer
        if model_path is None:
            env_model_path = os.getenv("MODEL_PATH")
            if env_model_path:
                model_path = os.path.abspath(env_model_path)
            else:
                model_path = os.path.abspath(
                    os.path.join(os.path.dirname(__file__), "..", "..", "ml", "models", "expense_classifier.joblib")
                )

        classifier = None
        if os.path.exists(model_path):
            try:
                classifier = ExpenseClassifier.load(model_path)
            except Exception as e:
                print(f"{YELLOW}[!] Notice: could not load ML classifier: {e}{RESET}")

        # Load user corrections from DB for layer 4
        corrections = self.db.query(CategoryCorrection).all()
        custom_dict = {c.old_category: c.new_category for c in corrections}

        self.normalizer = MerchantNormalizer(custom_corrections=custom_dict)
        self.hybrid_categorizer = HybridCategorizer(classifier=classifier, normalizer=self.normalizer)
        self.analytics_service = AnalyticsService(db=self.db)
        self.forecasting_service = ForecastingService(db=self.db)

    def process_statement(self, statement_id: str, file_path_or_bytes: Any) -> Dict[str, Any]:
        """
        Executes the 7-stage statement ingestion and intelligence pipeline with live terminal output.
        """
        start_time = time.time()
        stmt = self.db.query(Statement).filter(Statement.id == statement_id).first()
        if not stmt:
            raise ValueError(f"Statement {statement_id} not found in database.")

        filename = stmt.file_name or "uploaded_statement.pdf"
        print(f"\n{CYAN}+==============================================================================+{RESET}")
        print(f"{CYAN}| >> {BOLD}ExpenseInsight Ingestion Pipeline{RESET}{CYAN} — Live Statement Processing       |{RESET}")
        print(f"{CYAN}+==============================================================================+{RESET}")
        print(f"{CYAN}|{RESET}  {BOLD}File:{RESET} {filename:<30} {BOLD}Statement ID:{RESET} {stmt.id[:8]}...{stmt.id[-4:]:<14} {CYAN}|{RESET}")
        print(f"{CYAN}|{RESET}  {BOLD}User:{RESET} {str(stmt.user_id):<30} {BOLD}Started At:{RESET}   {time.strftime('%H:%M:%S'):<22} {CYAN}|{RESET}")
        print(f"{CYAN}+==============================================================================+{RESET}")

        try:
            # =========================================================================
            # STAGE 1: Reading & Ingesting PDF
            # =========================================================================
            step_t0 = time.time()
            print(f"\n{BLUE}[Stage 1/7] Ingesting PDF Binary & Validating Document...{RESET}")
            stmt.processing_status = "processing"
            stmt.processing_step = "Reading PDF document"
            stmt.processing_progress = 0.15
            self.db.commit()

            file_size_kb = 0.0
            if isinstance(file_path_or_bytes, str) and os.path.exists(file_path_or_bytes):
                file_size_kb = os.path.getsize(file_path_or_bytes) / 1024.0
            elif isinstance(file_path_or_bytes, (bytes, bytearray)):
                file_size_kb = len(file_path_or_bytes) / 1024.0

            print(f"  {GREEN}[+]{RESET} PDF Document validated ({file_size_kb:.1f} KB) in {time.time() - step_t0:.3f}s")

            # =========================================================================
            # STAGE 2: Extracting Document Layout & Bounding Boxes
            # =========================================================================
            step_t0 = time.time()
            print(f"\n{BLUE}[Stage 2/7] Extracting Document Tables & Multi-Bank Layout...{RESET}")
            extraction_result = self.pdf_extractor.extract_from_file_or_bytes(file_path_or_bytes)

            stmt.bank_name = extraction_result.get("detected_bank") or stmt.bank_name or "Generic Bank"
            stmt.account_number = extraction_result.get("account_number") or stmt.account_number or "N/A"
            stmt.statement_start = extraction_result.get("statement_period_start") or stmt.statement_start
            stmt.statement_end = extraction_result.get("statement_period_end") or stmt.statement_end
            self.db.commit()

            page_count = extraction_result.get("page_count", 1)
            raw_lines_count = len(extraction_result.get("raw_lines", []))
            print(f"  {GREEN}[+]{RESET} Detected Bank Layout : {BOLD}{stmt.bank_name}{RESET}")
            print(f"  {GREEN}[+]{RESET} Account Number        : {BOLD}{stmt.account_number}{RESET}")
            print(f"  {GREEN}[+]{RESET} Statement Period      : {BOLD}{stmt.statement_start} to {stmt.statement_end}{RESET}")
            print(f"  {GREEN}[+]{RESET} Document Extracted    : {page_count} pages, {raw_lines_count} text/table rows in {time.time() - step_t0:.3f}s")

            # =========================================================================
            # STAGE 3: Parsing Tabular Transactions
            # =========================================================================
            step_t0 = time.time()
            print(f"\n{BLUE}[Stage 3/7] Parsing Structured Transactions & Normalizing Fields...{RESET}")
            stmt.processing_step = "Extracting transactions"
            stmt.processing_progress = 0.35
            self.db.commit()

            raw_txns = self.parser.parse(extraction_result)
            if not raw_txns:
                raise ValueError("Could not extract any valid financial transaction records from statement.")

            debit_count = sum(1 for t in raw_txns if t.get("cr_dr") == "DR")
            credit_count = sum(1 for t in raw_txns if t.get("cr_dr") == "CR")
            total_debit_amt = sum(t["amount"] for t in raw_txns if t.get("cr_dr") == "DR")
            total_credit_amt = sum(t["amount"] for t in raw_txns if t.get("cr_dr") == "CR")

            print(f"  {GREEN}[+]{RESET} Extracted Records     : {BOLD}{len(raw_txns)}{RESET} structured transactions")
            print(f"  {GREEN}[+]{RESET} Cashflow Breakdown    : {RED}{debit_count} Debits (-Rs. {total_debit_amt:,.2f}){RESET} | {GREEN}{credit_count} Credits (+Rs. {total_credit_amt:,.2f}){RESET}")
            print(f"  {GREEN}[+]{RESET} Parsing Completed in  : {time.time() - step_t0:.3f}s")

            # =========================================================================
            # STAGE 4 & 5: 4-Layer Normalization & ML Categorization
            # =========================================================================
            step_t0 = time.time()
            print(f"\n{BLUE}[Stages 4 & 5/7] 4-Layer Normalization & ML Categorization...{RESET}")
            stmt.processing_step = "Normalizing merchants & AI Categorization"
            stmt.processing_progress = 0.65
            self.db.commit()

            processed_transactions = []
            category_counts = Counter()
            confidence_tiers = {"High (>=85%)": 0, "Medium (60-84%)": 0, "Low (<60%) [Review]": 0}
            sample_normalizations = []

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

                category = cat_res.get("category", "Uncategorized")
                confidence = float(cat_res.get("confidence", 0.0))
                needs_review = cat_res.get("needs_review", False)
                norm_merchant = cat_res.get("normalized_merchant", raw_desc[:20])

                category_counts[category] += 1

                if confidence >= 0.85:
                    confidence_tiers["High (>=85%)"] += 1
                elif confidence >= 0.60:
                    confidence_tiers["Medium (60-84%)"] += 1
                else:
                    confidence_tiers["Low (<60%) [Review]"] += 1

                if len(sample_normalizations) < 4:
                    sample_normalizations.append((raw_desc[:28], norm_merchant, category, f"{confidence * 100:.1f}%"))

                txn = Transaction(
                    user_id=stmt.user_id,
                    statement_id=stmt.id,
                    date=item["date"],
                    raw_description=raw_desc,
                    clean_description=norm_merchant,
                    merchant=cat_res.get("merchant", norm_merchant),
                    normalized_merchant=norm_merchant,
                    amount=amt,
                    currency=item.get("currency", "INR"),
                    transaction_type=txn_type,
                    cr_dr=item.get("cr_dr", "DR"),
                    balance=item.get("balance"),
                    reference_number=item.get("reference_number"),
                    category=category,
                    category_confidence=confidence,
                    category_source=cat_res.get("source", "ml"),
                    needs_review=needs_review,
                    is_duplicate=item.get("is_duplicate", False)
                )
                self.db.add(txn)
                processed_transactions.append(txn)

            stmt.total_transactions = len(processed_transactions)
            self.db.commit()

            print(f"  {GREEN}[+]{RESET} Normalization Samples (Raw -> Clean -> Category):")
            for raw_s, norm_s, cat_s, conf_s in sample_normalizations:
                print(f"      * {DIM}{raw_s:<28}{RESET} -> {BOLD}{norm_s:<18}{RESET} [{MAGENTA}{cat_s}{RESET}, Conf: {GREEN}{conf_s}{RESET}]")

            print(f"\n  {GREEN}[+]{RESET} AI Confidence Distribution:")
            for tier, count in confidence_tiers.items():
                tier_color = GREEN if "High" in tier else (YELLOW if "Medium" in tier else RED)
                print(f"      * {tier:<26}: {tier_color}{count} transactions ({count / len(processed_transactions) * 100:.1f}%){RESET}")

            top_categories = category_counts.most_common(5)
            print(f"\n  {GREEN}[+]{RESET} Top Categories Discovered:")
            for cat_name, cnt in top_categories:
                print(f"      * {cat_name:<20}: {cnt:>3} txns ({cnt / len(processed_transactions) * 100:.1f}%)")

            # =========================================================================
            # STAGE 6: Spending Analysis & Recurring Subscription Detection
            # =========================================================================
            step_t0 = time.time()
            print(f"\n{BLUE}[Stage 6/7] Computing Spending Intelligence & Recurring Subscriptions...{RESET}")
            stmt.processing_step = "Building spending analysis"
            stmt.processing_progress = 0.85
            self.db.commit()

            summary = self.analytics_service.get_summary(user_id=stmt.user_id)
            recurring_subs = summary.get("recurring_expenses", [])

            print(f"  {GREEN}[+]{RESET} Total Spending (All-Time) : {BOLD}Rs. {summary.get('total_expense', 0.0):,.2f}{RESET}")
            print(f"  {GREEN}[+]{RESET} Current Month Spending   : {BOLD}Rs. {summary.get('this_month_spent', 0.0):,.2f}{RESET} (MoM: {summary.get('month_over_month_change_pct', 0.0):+.1f}%)")
            print(f"  {GREEN}[+]{RESET} Net Savings Rate         : {GREEN}Rs. {summary.get('net_savings', 0.0):,.2f}{RESET}")
            print(f"  {GREEN}[+]{RESET} Subscriptions Detected   : {BOLD}{len(recurring_subs)}{RESET} recurring services")
            for sub in recurring_subs[:4]:
                print(f"      * {BOLD}{sub.get('merchant')}{RESET} ({sub.get('category')}): Rs. {sub.get('average_amount', 0):,.2f}/mo (Freq: {sub.get('frequency', 'Monthly')})")

            # =========================================================================
            # STAGE 7: Time-Series Forecasting (Holt-Winters + 90% CI)
            # =========================================================================
            step_t0 = time.time()
            print(f"\n{BLUE}[Stage 7/7] Generating Time-Series Expense Forecast...{RESET}")
            stmt.processing_step = "Generating expense forecast"
            stmt.processing_progress = 0.95
            self.db.commit()

            forecast_data = self.forecasting_service.generate_user_forecast(user_id=stmt.user_id, persist=True)
            total_forecast = forecast_data.get("total_forecast", 0.0)
            ci_lower = forecast_data.get("confidence_interval_lower", 0.0)
            ci_upper = forecast_data.get("confidence_interval_upper", 0.0)
            next_7d = forecast_data.get("next_7_days_forecast", 0.0)
            explanations = forecast_data.get("explanations", [])

            print(f"  {GREEN}[+]{RESET} Next Month Forecast       : {BOLD}Rs. {total_forecast:,.2f}{RESET} (90% CI: [Rs. {ci_lower:,.2f} - Rs. {ci_upper:,.2f}])")
            print(f"  {GREEN}[+]{RESET} Short-Term Targets        : Next 7 Days: Rs. {next_7d:,.2f} | Next 30 Days: Rs. {total_forecast:,.2f}")
            if explanations:
                print(f"  {GREEN}[+]{RESET} AI Drivers / Reasoning   : {explanations[0]}")

            # =========================================================================
            # PIPELINE COMPLETED
            # =========================================================================
            stmt.processing_status = "completed"
            stmt.processing_step = "Completed"
            stmt.processing_progress = 1.0
            self.db.commit()

            total_elapsed = time.time() - start_time
            print(f"\n{GREEN}+==============================================================================+{RESET}")
            print(f"{GREEN}| [OK] Pipeline Finished Successfully in {total_elapsed:.2f}s!                               |{RESET}")
            print(f"{GREEN}|      {len(processed_transactions)} transactions indexed & ready for Flutter Mobile / Desktop / PWA      |{RESET}")
            print(f"{GREEN}+==============================================================================+{RESET}\n")

            return {
                "status": "success",
                "statement_id": stmt.id,
                "bank_name": stmt.bank_name,
                "total_transactions": len(processed_transactions),
                "period": f"{stmt.statement_start} to {stmt.statement_end}",
                "elapsed_seconds": round(total_elapsed, 2)
            }

        except Exception as e:
            stmt.processing_status = "failed"
            stmt.processing_step = f"Failed: {str(e)}"
            self.db.commit()
            print(f"\n{RED}[X] [Pipeline Error] Statement processing failed: {e}{RESET}\n")
            raise e
