# ExpenseInsight — Persistent Storage Implementation Checklist

This checklist tracks every requirement from the **Persistent User Identity & Storage Implementation** specification.

---

## 1. Database Identity & Ownership (Phase 2)
- [x] Stable User ID (UUIDv4) that never changes across restarts, logins, logouts, email casing, or devices.
- [x] Email is an identity identifier, but NEVER used as the internal foreign key.
- [x] Consistent email normalization: trim whitespace, lowercase, NOCASE uniqueness.
- [x] Existing financial records retain original `user_id`.
- [x] Foreign keys prevent accidental cross-user access with cascade on account deletion.
- [x] Cross-user access strictly forbidden across all 5 user-owned entities:
  - `Statement`
  - `Transaction`
  - `CashExpense`
  - `CategoryCorrection`
  - `Forecast`

---

## 2. Persistent Session Storage (Phase 3)
- [x] Persist minimum auth state in Flutter `SharedPreferences`:
  - `auth_token`
  - `user_id`
  - `user_email`
  - `is_guest`
- [x] App start restores persisted session from local storage.
- [x] Validates token with backend via `GET /auth/me`.
- [x] Retrieves canonical user and initializes user context.
- [x] Loads user-specific financial data.
- [x] App restart preserves same user, same `user_id`, same records.
- [x] Device restart preserves same identity and backend account.
- [x] No new user generated during startup when session exists.
- [x] No fallback to demo data when real user data exists.
- [x] Handles expired, invalid, missing tokens, and deleted accounts safely.
- [x] Distinguishes "session restoration failed (offline / network error)" from "this is a new user".
- [x] Does not create new accounts when network is temporarily unavailable.

---

## 3. Email Identity (Phase 4)
- [x] `POST /auth/identify` creates permanent user with stable UUID for new email.
- [x] Issues JWT token with `sub: user.id`.
- [x] Existing email retrieves existing user and loads existing financial data.
- [x] Case-insensitivity (`User@example.com` == `user@example.com` == `USER@EXAMPLE.COM`).
- [x] Whitespace normalization (`"  user@example.com  "`).
- [x] Response contains `user_id`, `email`, `is_new_user`, `access_token`, `user`.
- [x] No duplicate users created for same email.

---

## 4. Guest to Permanent User Migration (Phase 5)
- [x] Case A: Guest enters NEW email -> guest upgraded in-place or records safely migrated with zero data loss.
- [x] Case B: Guest enters EXISTING email -> guest records safely merged:
  - No duplicate transactions.
  - No orphaned records.
  - No records left attached to deleted guest.
  - Forecast regenerated from canonical merged data.
  - Atomic migration with rollback on failure.

---

## 5. User-Scoped Financial Operations (Phase 6)
- [x] `GET /transactions` scoped strictly to `current_user.id`.
- [x] `GET /transactions/{id}` returns 404 for another user's transaction.
- [x] `PATCH /transactions/{id}/category` returns 404 for another user's transaction.
- [x] `GET /cash-expenses` scoped strictly to `current_user.id`.
- [x] `GET /cash-expenses/{id}` returns 404 for another user's cash expense.
- [x] `PUT /cash-expenses/{id}` returns 404 for another user's cash expense.
- [x] `DELETE /cash-expenses/{id}` returns 404 for another user's cash expense.
- [x] `GET /statements` and `DELETE /statements` scoped to `current_user.id`.
- [x] `GET /statements/{id}` returns 404 for another user's statement.
- [x] `GET /forecast` generates and returns forecast scoped to `current_user.id`.
- [x] `GET /analytics/*` (summary, monthly, categories, merchants) scoped to `current_user.id`.
- [x] Demo fallback audited: invalid or expired tokens return 401 Unauthorized, never silently falling back to demo account.

---

## 6. Forecast Persistence & User Scoping (Phase 7)
- [x] Forecasts belong to stable `user.id`.
- [x] User A mutations never recalculate or mutate User B's forecast.
- [x] No global/shared forecast state.
- [x] After identity restoration, `ForecastProvider` requests forecast for restored user.

---

## 7. Flutter Provider Lifecycle & Account Switching (Phase 8)
- [x] In-memory providers cleared on logout / account switch:
  - `TransactionProvider.clear()`
  - `CashExpenseProvider.clear()`
  - `ForecastProvider.clear()`
  - `AnalyticsProvider.clear()`
  - `StatementProvider.clear()`
- [x] No provider retains data from previous user after account switching.
- [x] Backend data remains intact when in-memory session is cleared.
- [x] Reloads user-specific data upon new authentication.

---

## 8. Automated Integration & Isolation Tests (Phases 9–15)
- [x] App restart integration test (Phase 9).
- [x] Multi-device same-email simulation test (Phase 10).
- [x] Account isolation test across all entities (Phase 11).
- [x] Offline / network failure handling test (Phase 12).
- [x] Logout and account switch test (Phase 13).
- [x] Security audit verification for token validation and demo fallback (Phase 14).
- [x] Full backend pytest test suite passing (Phase 15): 67 passed, 0 failed.
- [x] Full Flutter test suite passing (Phase 15): 49 passed, 0 failed.
- [x] Static analysis `flutter analyze` passing with 0 issues.

---

## 9. Machine-Readable Checklist (Phase 17)
- [x] `PERSISTENT_STORAGE_CHECKLIST` dictionary defined in repository (`backend/app/core/checklist.py`).
- [x] Automated invariant test verifies checklist status (`backend/tests/test_user_identity.py::test_machine_readable_checklist_verified`).
