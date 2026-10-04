# ExpenseInsight — Persistent Storage Implementation Checklist

This checklist tracks every requirement from the **Persistent User Identity & Storage Implementation** specification.

---

## 1. Database Identity & Ownership (Phase 2)
- [ ] Stable User ID (UUIDv4) that never changes across restarts, logins, logouts, email casing, or devices.
- [ ] Email is an identity identifier, but NEVER used as the internal foreign key.
- [ ] Consistent email normalization: trim whitespace, lowercase, NOCASE uniqueness.
- [ ] Existing financial records retain original `user_id`.
- [ ] Foreign keys prevent accidental cross-user access with cascade on account deletion.
- [ ] Cross-user access strictly forbidden across all 5 user-owned entities:
  - `Statement`
  - `Transaction`
  - `CashExpense`
  - `CategoryCorrection`
  - `Forecast`

---

## 2. Persistent Session Storage (Phase 3)
- [ ] Persist minimum auth state in Flutter `SharedPreferences`:
  - `auth_token`
  - `user_id`
  - `user_email`
  - `is_guest`
- [ ] App start restores persisted session from local storage.
- [ ] Validates token with backend via `GET /auth/me`.
- [ ] Retrieves canonical user and initializes user context.
- [ ] Loads user-specific financial data.
- [ ] App restart preserves same user, same `user_id`, same records.
- [ ] Device restart preserves same identity and backend account.
- [ ] No new user generated during startup when session exists.
- [ ] No fallback to demo data when real user data exists.
- [ ] Handles expired, invalid, missing tokens, and deleted accounts safely.
- [ ] Distinguishes "session restoration failed (offline / network error)" from "this is a new user".
- [ ] Does not create new accounts when network is temporarily unavailable.

---

## 3. Email Identity (Phase 4)
- [ ] `POST /auth/identify` creates permanent user with stable UUID for new email.
- [ ] Issues JWT token with `sub: user.id`.
- [ ] Existing email retrieves existing user and loads existing financial data.
- [ ] Case-insensitivity (`User@example.com` == `user@example.com` == `USER@EXAMPLE.COM`).
- [ ] Whitespace normalization (`"  user@example.com  "`).
- [ ] Response contains `user_id`, `email`, `is_new_user`, `access_token`, `user`.
- [ ] No duplicate users created for same email.

---

## 4. Guest to Permanent User Migration (Phase 5)
- [ ] Case A: Guest enters NEW email -> guest upgraded in-place or records safely migrated with zero data loss.
- [ ] Case B: Guest enters EXISTING email -> guest records safely merged:
  - No duplicate transactions.
  - No orphaned records.
  - No records left attached to deleted guest.
  - Forecast regenerated from canonical merged data.
  - Atomic migration with rollback on failure.

---

## 5. User-Scoped Financial Operations (Phase 6)
- [ ] `GET /transactions` scoped strictly to `current_user.id`.
- [ ] `GET /transactions/{id}` returns 404 for another user's transaction.
- [ ] `PATCH /transactions/{id}/category` returns 404 for another user's transaction.
- [ ] `GET /cash-expenses` scoped strictly to `current_user.id`.
- [ ] `GET /cash-expenses/{id}` returns 404 for another user's cash expense.
- [ ] `PUT /cash-expenses/{id}` returns 404 for another user's cash expense.
- [ ] `DELETE /cash-expenses/{id}` returns 404 for another user's cash expense.
- [ ] `GET /statements` and `DELETE /statements` scoped to `current_user.id`.
- [ ] `GET /statements/{id}` returns 404 for another user's statement.
- [ ] `GET /forecast` generates and returns forecast scoped to `current_user.id`.
- [ ] `GET /analytics/*` (summary, monthly, categories, merchants) scoped to `current_user.id`.
- [ ] Demo fallback audited: invalid or expired tokens return 401 Unauthorized, never silently falling back to demo account.

---

## 6. Forecast Persistence & User Scoping (Phase 7)
- [ ] Forecasts belong to stable `user.id`.
- [ ] User A mutations never recalculate or mutate User B's forecast.
- [ ] No global/shared forecast state.
- [ ] After identity restoration, `ForecastProvider` requests forecast for restored user.

---

## 7. Flutter Provider Lifecycle & Account Switching (Phase 8)
- [ ] In-memory providers cleared on logout / account switch:
  - `TransactionProvider.clear()`
  - `CashExpenseProvider.clear()`
  - `ForecastProvider.clear()`
  - `AnalyticsProvider.clear()`
  - `StatementProvider.clear()`
- [ ] No provider retains data from previous user after account switching.
- [ ] Backend data remains intact when in-memory session is cleared.
- [ ] Reloads user-specific data upon new authentication.

---

## 8. Automated Integration & Isolation Tests (Phases 9–15)
- [ ] App restart integration test (Phase 9).
- [ ] Multi-device same-email simulation test (Phase 10).
- [ ] Account isolation test across all entities (Phase 11).
- [ ] Offline / network failure handling test (Phase 12).
- [ ] Logout and account switch test (Phase 13).
- [ ] Security audit verification for token validation and demo fallback (Phase 14).
- [ ] Full backend pytest test suite passing (Phase 15).
- [ ] Full Flutter test suite passing (Phase 15).
- [ ] Static analysis `flutter analyze` passing with 0 issues.

---

## 9. Machine-Readable Checklist (Phase 17)
- [ ] `PERSISTENT_STORAGE_CHECKLIST` dictionary defined in repository.
- [ ] Automated invariant test verifies checklist status.
