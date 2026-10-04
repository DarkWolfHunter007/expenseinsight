import os
import sys
import uuid
import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from backend.app.main import app
from backend.app.database.session import SessionLocal
from backend.app.models.db_models import CashExpense, Forecast, Statement, Transaction, User

client = TestClient(app)


def test_new_email_creates_one_user():
    """Phase 14 Test 1: New email creates one user with stable UUID."""
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    res = client.post("/auth/identify", json={"email": email})
    assert res.status_code == 200
    data = res.json()
    assert data["email"] == email
    assert data["is_new_user"] is True
    assert "user_id" in data and len(data["user_id"]) > 0
    assert "access_token" in data and len(data["access_token"]) > 0
    assert data["user"]["is_guest"] is False

    # Verify exactly one user exists in DB
    db = SessionLocal()
    users = db.query(User).filter(User.email == email).all()
    assert len(users) == 1
    assert users[0].id == data["user_id"]
    db.close()


def test_same_email_returns_same_user():
    """Phase 14 Test 2: Same email returns same user with identical user_id."""
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    res1 = client.post("/auth/identify", json={"email": email})
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["is_new_user"] is True

    res2 = client.post("/auth/identify", json={"email": email})
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["is_new_user"] is False
    assert data2["user_id"] == data1["user_id"]
    assert data2["email"] == email


def test_email_matching_case_insensitive_and_whitespace_normalized():
    """
    Phase 14 Test 3 & 4:
    test@example.com then TEST@example.com then ' test@example.com '
    all resolve to the same user.
    """
    unique_name = f"identity_{uuid.uuid4().hex[:6]}"
    canon_email = f"{unique_name}@example.com"
    upper_email = f"{unique_name.upper()}@EXAMPLE.COM"
    padded_email = f"   {unique_name.capitalize()}@Example.Com   "

    res1 = client.post("/auth/identify", json={"email": canon_email})
    assert res1.status_code == 200
    user_id1 = res1.json()["user_id"]
    assert res1.json()["email"] == canon_email

    res2 = client.post("/auth/identify", json={"email": upper_email})
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["user_id"] == user_id1
    assert data2["email"] == canon_email
    assert data2["is_new_user"] is False

    res3 = client.post("/auth/identify", json={"email": padded_email})
    assert res3.status_code == 200
    data3 = res3.json()
    assert data3["user_id"] == user_id1
    assert data3["email"] == canon_email
    assert data3["is_new_user"] is False


def test_different_emails_create_different_users():
    """Phase 14 Test 5: Different emails create different users."""
    email_a = f"alice_{uuid.uuid4().hex[:8]}@example.com"
    email_b = f"bob_{uuid.uuid4().hex[:8]}@example.com"

    res_a = client.post("/auth/identify", json={"email": email_a})
    res_b = client.post("/auth/identify", json={"email": email_b})

    assert res_a.status_code == 200 and res_b.status_code == 200
    assert res_a.json()["user_id"] != res_b.json()["user_id"]


def test_cross_user_transaction_and_cash_expense_isolation():
    """Phase 14 Test 6 & 7: User A cannot access User B's transactions or cash expenses."""
    email_a = f"alice_{uuid.uuid4().hex[:8]}@example.com"
    email_b = f"bob_{uuid.uuid4().hex[:8]}@example.com"

    token_a = client.post("/auth/identify", json={"email": email_a}).json()["access_token"]
    token_b = client.post("/auth/identify", json={"email": email_b}).json()["access_token"]

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # User A creates a cash expense
    create_res = client.post(
        "/cash-expenses",
        json={
            "amount": 450.0,
            "category": "Food",
            "description": "User A secret expense",
            "expense_date": "2026-09-15",
            "payment_method": "cash"
        },
        headers=headers_a
    )
    assert create_res.status_code == 201
    expense_a_id = create_res.json()["id"]

    # User B lists cash expenses -> must be empty
    list_b = client.get("/cash-expenses", headers=headers_b)
    assert list_b.status_code == 200
    assert len(list_b.json()) == 0

    # User B lists transactions -> must be empty
    txns_b = client.get("/transactions", headers=headers_b)
    assert txns_b.status_code == 200
    assert len(txns_b.json()) == 0

    # User B tries to fetch User A's expense directly -> 404 Not Found
    get_res = client.get(f"/cash-expenses/{expense_a_id}", headers=headers_b)
    assert get_res.status_code == 404

    # User B tries to update User A's expense -> 404 Not Found
    update_res = client.put(
        f"/cash-expenses/{expense_a_id}",
        json={"amount": 999.0, "category": "Food"},
        headers=headers_b
    )
    assert update_res.status_code == 404

    # User B tries to delete User A's expense -> 404 Not Found
    delete_res = client.delete(f"/cash-expenses/{expense_a_id}", headers=headers_b)
    assert delete_res.status_code == 404


def test_cross_user_forecast_isolation():
    """Phase 14 Test 8 & 9: Forecast is strictly isolated and recalculated only for the mutator."""
    email_a = f"alice_{uuid.uuid4().hex[:8]}@example.com"
    email_b = f"bob_{uuid.uuid4().hex[:8]}@example.com"

    token_a = client.post("/auth/identify", json={"email": email_a}).json()["access_token"]
    token_b = client.post("/auth/identify", json={"email": email_b}).json()["access_token"]

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # User A adds several historical expenses
    for d, amt in [("2026-06-15", 3000.0), ("2026-07-15", 3500.0), ("2026-08-15", 4000.0), ("2026-09-15", 4500.0)]:
        client.post(
            "/cash-expenses",
            json={
                "amount": amt,
                "category": "Food",
                "description": f"Expense {d}",
                "expense_date": d,
                "payment_method": "upi"
            },
            headers=headers_a
        )

    user_a_id = client.get("/auth/me", headers=headers_a).json()["id"]
    user_b_id = client.get("/auth/me", headers=headers_b).json()["id"]

    # User A forecast
    forecast_a = client.get("/forecast", headers=headers_a).json()
    assert forecast_a["total_forecast"] > 0
    assert "Food" in forecast_a["category_forecasts"]

    # Verify database forecast ownership
    db = SessionLocal()
    forecasts_a_db = db.query(Forecast).filter(Forecast.user_id == user_a_id).all()
    assert len(forecasts_a_db) > 0
    forecasts_b_db = db.query(Forecast).filter(Forecast.user_id == user_b_id).all()
    assert len(forecasts_b_db) == 0
    db.close()

    # User B forecast
    forecast_b = client.get("/forecast", headers=headers_b).json()
    # User B has no expenses, so forecast is 0
    assert forecast_b["total_forecast"] == 0.0
    assert forecast_b["category_forecasts"] == {}

    # User A adds another expense -> User A forecast recalculates, User B untouched
    client.post(
        "/cash-expenses",
        json={
            "amount": 5000.0,
            "category": "Travel",
            "description": "Flight ticket",
            "expense_date": "2026-09-20",
            "payment_method": "bank"
        },
        headers=headers_a
    )

    forecast_b_after = client.get("/forecast", headers=headers_b).json()
    assert forecast_b_after["total_forecast"] == 0.0
    assert "Travel" not in forecast_b_after["category_forecasts"]


def test_session_restoration_via_token():
    """Phase 14 Test 10: Stored session token restores identical user identity."""
    email = f"session_{uuid.uuid4().hex[:8]}@example.com"
    id_res = client.post("/auth/identify", json={"email": email})
    data = id_res.json()
    user_id = data["user_id"]
    token = data["access_token"]

    # App restart simulation: Call GET /auth/me with the restored token
    me_res = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert me_data["id"] == user_id
    assert me_data["email"] == email


def test_guest_user_upgraded_in_place():
    """Phase 8 & 14: Guest user entering email upgrades their account in-place with zero data loss."""
    guest_res = client.post("/auth/guest")
    assert guest_res.status_code == 200
    guest_token = guest_res.json()["access_token"]
    guest_id = guest_res.json()["user"]["id"]
    guest_headers = {"Authorization": f"Bearer {guest_token}"}

    # Guest records a cash expense
    create_res = client.post(
        "/cash-expenses",
        json={
            "amount": 750.0,
            "category": "Groceries",
            "description": "Weekly market",
            "expense_date": "2026-09-25",
            "payment_method": "cash"
        },
        headers=guest_headers
    )
    assert create_res.status_code == 201
    expense_id = create_res.json()["id"]

    # Guest identifies with a new email
    new_email = f"upgraded_{uuid.uuid4().hex[:8]}@example.com"
    identify_res = client.post(
        "/auth/identify",
        json={"email": new_email},
        headers=guest_headers
    )
    assert identify_res.status_code == 200
    identified_data = identify_res.json()
    assert identified_data["user_id"] == guest_id  # In-place upgrade preserves user.id
    assert identified_data["email"] == new_email
    assert identified_data["user"]["is_guest"] is False

    # The cash expense is still accessible under new identity
    perm_headers = {"Authorization": f"Bearer {identified_data['access_token']}"}
    expense_res = client.get(f"/cash-expenses/{expense_id}", headers=perm_headers)
    assert expense_res.status_code == 200
    assert expense_res.json()["user_id"] == guest_id


def test_guest_migrates_data_to_existing_account():
    """Phase 8: Guest user identifying as an existing user merges data into the existing account."""
    existing_email = f"david_{uuid.uuid4().hex[:8]}@example.com"
    david_res = client.post("/auth/identify", json={"email": existing_email})
    david_id = david_res.json()["user_id"]

    # A guest session is started
    guest_res = client.post("/auth/guest")
    guest_token = guest_res.json()["access_token"]
    guest_headers = {"Authorization": f"Bearer {guest_token}"}

    # Guest records a cash expense
    create_res = client.post(
        "/cash-expenses",
        json={
            "amount": 1200.0,
            "category": "Electronics",
            "description": "Headphones",
            "expense_date": "2026-09-26",
            "payment_method": "upi"
        },
        headers=guest_headers
    )
    assert create_res.status_code == 201
    expense_id = create_res.json()["id"]

    # Guest now identifies as david
    merge_res = client.post(
        "/auth/identify",
        json={"email": existing_email},
        headers=guest_headers
    )
    assert merge_res.status_code == 200
    merge_data = merge_res.json()
    assert merge_data["user_id"] == david_id  # Returns David's ID
    assert merge_data["is_new_user"] is False

    # David now owns the expense created in the guest session
    david_headers = {"Authorization": f"Bearer {merge_data['access_token']}"}
    expense_check = client.get(f"/cash-expenses/{expense_id}", headers=david_headers)
    assert expense_check.status_code == 200
    assert expense_check.json()["user_id"] == david_id


def test_multi_device_retrieves_identical_data():
    """Phase 9: Multiple devices identifying with same email access identical financial data."""
    email = f"eve_{uuid.uuid4().hex[:8]}@example.com"

    # Device 1 identifies
    dev1_res = client.post("/auth/identify", json={"email": email})
    dev1_token = dev1_res.json()["access_token"]
    dev1_headers = {"Authorization": f"Bearer {dev1_token}"}

    # Device 1 adds expense
    client.post(
        "/cash-expenses",
        json={
            "amount": 1800.0,
            "category": "Shopping",
            "description": "Shoes",
            "expense_date": "2026-09-28",
            "payment_method": "bank"
        },
        headers=dev1_headers
    )

    # Device 2 identifies with same email
    dev2_res = client.post("/auth/identify", json={"email": email})
    dev2_token = dev2_res.json()["access_token"]
    dev2_headers = {"Authorization": f"Bearer {dev2_token}"}

    assert dev2_res.json()["user_id"] == dev1_res.json()["user_id"]

    # Device 2 retrieves expenses
    dev2_expenses = client.get("/cash-expenses", headers=dev2_headers).json()
    assert len(dev2_expenses) == 1
    assert dev2_expenses[0]["amount"] == 1800.0
    assert dev2_expenses[0]["category"] == "Shopping"


def test_negative_authorization_direct_statement_and_transaction_lookups():
    """Phase 10: Direct record lookups for foreign user records return 404."""
    email_a = f"alice_neg_{uuid.uuid4().hex[:8]}@example.com"
    email_b = f"bob_neg_{uuid.uuid4().hex[:8]}@example.com"

    token_a = client.post("/auth/identify", json={"email": email_a}).json()["access_token"]
    token_b = client.post("/auth/identify", json={"email": email_b}).json()["access_token"]

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # User A creates a transaction directly in DB for testing direct lookups
    db = SessionLocal()
    user_a = db.query(User).filter(User.email == email_a).first()
    stmt_a = Statement(
        user_id=user_a.id,
        file_name="alice_stmt.pdf",
        bank_name="HDFC",
        account_number="1234",
        statement_start="2026-01-01",
        statement_end="2026-01-31",
        processing_status="completed"
    )
    db.add(stmt_a)
    db.commit()
    db.refresh(stmt_a)

    txn_a = Transaction(
        user_id=user_a.id,
        statement_id=stmt_a.id,
        date="2026-01-15",
        raw_description="UPI/DR/SWIGGY/998877",
        amount=650.0,
        transaction_type="expense",
        category="Food",
        category_confidence=0.9,
        category_source="rules"
    )
    db.add(txn_a)
    db.commit()
    db.refresh(txn_a)
    stmt_a_id = stmt_a.id
    txn_a_id = txn_a.id
    db.close()

    # User B attempts to read User A's statement -> 404
    stmt_res = client.get(f"/statements/{stmt_a_id}", headers=headers_b)
    assert stmt_res.status_code == 404

    # User B attempts to read User A's statement status -> 404
    status_res = client.get(f"/statements/{stmt_a_id}/status", headers=headers_b)
    assert status_res.status_code == 404

    # User B attempts to read User A's transaction -> 404
    txn_res = client.get(f"/transactions/{txn_a_id}", headers=headers_b)
    assert txn_res.status_code == 404

    # User B attempts to update User A's transaction category -> 404
    update_res = client.patch(
        f"/transactions/{txn_a_id}/category",
        json={"category": "Groceries"},
        headers=headers_b
    )
    assert update_res.status_code == 404

    # User B attempts to delete User A's transaction -> 404
    del_res = client.delete(f"/transactions/{txn_a_id}", headers=headers_b)
    assert del_res.status_code == 404


def test_token_validation_and_rejections():
    """Phase 10 & 15: Invalid, expired, and non-existent user tokens return 401 Unauthorized."""
    import jwt
    from datetime import datetime, timedelta
    from backend.app.api.deps import SECRET_KEY, ALGORITHM

    # 1. Invalid signature / forged token
    forged_token = jwt.encode({"sub": "random-uuid-123"}, "wrong-secret-key-that-is-at-least-32-bytes-long!!!", algorithm="HS256")
    res1 = client.get("/auth/me", headers={"Authorization": f"Bearer {forged_token}"})
    assert res1.status_code == 401
    assert "Could not validate credentials" in res1.json()["detail"]

    # 2. Expired token
    expired_payload = {
        "sub": "some-user-id",
        "exp": datetime.utcnow() - timedelta(hours=1)
    }
    expired_token = jwt.encode(expired_payload, SECRET_KEY, algorithm=ALGORITHM)
    res2 = client.get("/auth/me", headers={"Authorization": f"Bearer {expired_token}"})
    assert res2.status_code == 401

    # 3. Valid token structure but user no longer exists in DB
    nonexistent_payload = {
        "sub": "non-existent-user-id-9999",
        "exp": datetime.utcnow() + timedelta(hours=1)
    }
    nonexistent_token = jwt.encode(nonexistent_payload, SECRET_KEY, algorithm=ALGORITHM)
    res3 = client.get("/auth/me", headers={"Authorization": f"Bearer {nonexistent_token}"})
    assert res3.status_code == 401
    assert "User not found" in res3.json()["detail"]


def test_machine_readable_checklist_verified():
    """Phase 17: Machine-readable PERSISTENT_STORAGE_CHECKLIST must be fully verified."""
    from backend.app.core.checklist import PERSISTENT_STORAGE_CHECKLIST

    assert len(PERSISTENT_STORAGE_CHECKLIST) >= 18
    for phase_key, item in PERSISTENT_STORAGE_CHECKLIST.items():
        assert "description" in item and len(item["description"]) > 0
        assert item.get("verified") is True, f"Checklist item {phase_key} is not verified!"

