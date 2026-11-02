"""
Re-runs the merchant normalizer and categorizer over transactions that are already stored, so an
improved classifier also fixes old statements without uploading them again.

Rows the user categorized themselves (manual_user, learned_feedback) are never touched.

    python tools/recategorize.py --email you@example.com            # dry run: only shows what would change
    python tools/recategorize.py --email you@example.com --apply    # writes, after backing up the database

Stop the backend first when applying (docker compose stop backend) and start it again afterwards.
"""
import argparse
import collections
import os
import shutil
import sqlite3
import sys
import warnings

warnings.filterwarnings("ignore")
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.ml.categorization.classifier import ExpenseClassifier  # noqa: E402
from backend.ml.categorization.hybrid_categorizer import HybridCategorizer  # noqa: E402
from backend.ml.preprocessing.merchant_normalizer import MerchantNormalizer  # noqa: E402

PROTECTED_SOURCES = ("manual_user", "learned_feedback")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", required=True, help="account whose transactions are re-categorized")
    parser.add_argument("--db", default="data/expenseinsight.db")
    parser.add_argument("--model", default="backend/ml/models/expense_classifier.joblib")
    parser.add_argument("--apply", action="store_true", help="write the changes (default is a dry run)")
    args = parser.parse_args()

    categorizer = HybridCategorizer(
        classifier=ExpenseClassifier.load(args.model), normalizer=MerchantNormalizer()
    )
    db = sqlite3.connect(args.db)
    db.row_factory = sqlite3.Row
    user = db.execute("select id from users where email = ? collate nocase", (args.email,)).fetchone()
    if not user:
        sys.exit(f"No account with email {args.email}")

    rows = db.execute(
        "select id, raw_description, amount, transaction_type, category, needs_review, category_source "
        "from transactions where user_id = ?", (user["id"],)
    ).fetchall()

    changes = []
    for row in rows:
        if row["category_source"] in PROTECTED_SOURCES:
            continue
        result = categorizer.categorize_transaction(row["raw_description"], row["amount"], row["transaction_type"])
        if result["category"] != row["category"] or bool(row["needs_review"]) != bool(result["needs_review"]):
            changes.append((row, result))

    summary = collections.Counter(f"{row['category']} -> {res['category']}" for row, res in changes)
    print(f"{len(rows)} transactions checked, {len(changes)} would change:")
    for change, count in summary.most_common():
        print(f"  {count:4}  {change}")

    if not args.apply:
        print("\nDry run only. Add --apply to write these changes.")
        return

    backup = args.db + ".bak-before-recategorize"
    shutil.copy(args.db, backup)
    for row, res in changes:
        db.execute(
            "update transactions set category=?, category_confidence=?, category_source=?, needs_review=?, "
            "merchant=?, normalized_merchant=?, clean_description=? where id=?",
            (res["category"], res["confidence"], res["source"], int(res["needs_review"]),
             res["merchant"], res["normalized_merchant"], res["normalized_merchant"], row["id"]),
        )
    db.commit()
    print(f"\nApplied {len(changes)} changes. Backup: {backup}")


if __name__ == "__main__":
    main()
