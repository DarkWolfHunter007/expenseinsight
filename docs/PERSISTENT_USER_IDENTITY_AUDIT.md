# ExpenseInsight — Persistent User Identity & Multi-Tenant Data Isolation Audit

## Overview

This document specifies and verifies the persistent user identity system for ExpenseInsight.
It guarantees that user identity is stably anchored to email addresses, internal operations reference a unique `user.id` (UUID), cross-user data access is strictly prevented, and sessions persist seamlessly across application restarts without generating orphaned guest data.

---

## 1. Identity Architecture

### User Flow
```
User Enters Email (e.g. " Alice@example.com ")
       ↓
Email Normalized (trimmed + lowercased -> "alice@example.com")
       ↓
Database Lookup (NOCASE collation & func.lower)
       ↓
┌───────────────────────────────┴───────────────────────────────┐
│                                                               │
▼ (User Exists)                                                 ▼ (User Does Not Exist)
Retrieve Existing User                                          Check active ephemeral guest?
Check active ephemeral guest?                                   ├─ Yes: Upgrade guest user in-place
├─ Yes: Reassign records (Stmt/Txn/Cash/Correction)            │  (preserves user.id & all records)
│       Delete ephemeral guest, refresh forecast                └─ No: Create new User
└─ No: Issue session for existing user                                 (stable UUID user.id)
       ↓                                                               ↓
Issue JWT Access Token (sub: user.id, email: user.email)
       ↓
Client Persists Token, Email & UserId in SharedPreferences
       ↓
Subsequent Requests Derive Identity Exclusively from JWT Token
```

---

## 2. Phase 16 — Data Integrity & Ownership Enforcement Mapping

| Database Table | Ownership Column (`user_id`) | Foreign Key Target | Enforcement Points | Cross-User Isolation Verified |
| :--- | :--- | :--- | :--- | :--- |
| `users` | `id` (Primary Key) | Self (`UUIDv4`) | `/auth/me`, `/auth/identify` | Strict: Only current user can view their profile |
| `transactions` | `user_id` (Indexed) | `users.id` (CASCADE) | `GET /transactions`, `GET /transactions/{id}`, `PATCH /transactions/{id}/category` | Strict: Queries filter `Transaction.user_id == current_user.id` |
| `cash_expenses` | `user_id` (Indexed) | `users.id` (CASCADE) | `POST /cash-expenses`, `GET /cash-expenses`, `GET /cash-expenses/{id}`, `PUT /cash-expenses/{id}`, `DELETE /cash-expenses/{id}` | Strict: Direct ID lookup returns 404 if owned by another user |
| `statements` | `user_id` (Indexed) | `users.id` (CASCADE) | `POST /statements/upload`, `GET /statements`, `GET /statements/{id}`, `DELETE /statements` | Strict: Statement files and parsed records scoped to `Statement.user_id == current_user.id` |
| `forecasts` | `user_id` (Indexed) | `users.id` (CASCADE) | `GET /forecast`, `ForecastingService.generate_user_forecast` | Strict: Predictions computed only from `user_id` transactions; foreign forecasts untouched |
| `category_corrections` | `user_id` (Indexed) | `users.id` (CASCADE) | `PATCH /transactions/{id}/category` | Strict: ML fine-tuning corrections tied to creator `user_id` |

---

## 3. Phase 17 — Implementation Checklist

- [x] **Email identity implemented**: `POST /auth/identify` accepts `{ "email": "..." }` and returns stable identity + JWT.
- [x] **Email normalized**: Trimmed of surrounding whitespace and lowercased (`email.strip().lower()`).
- [x] **Email unique**: Enforced via SQLite/SQLAlchemy `NOCASE` collation and unique index.
- [x] **Stable user_id used internally**: Internal relationships reference `user.id` (UUID), never email.
- [x] **Existing user retrieved**: Same email returns existing `user.id` with `is_new_user = false`.
- [x] **New user created**: Unseen email creates new permanent record with `is_new_user = true`.
- [x] **Session persisted**: Stored in `SharedPreferences` (`auth_token`, `user_email`, `user_id`).
- [x] **Existing guest flow audited**: Ephemeral guest sessions are promoted in-place or merged cleanly without orphaned records.
- [x] **User-owned records scoped correctly**: All financial tables reference `user_id`.
- [x] **Cross-user access prevented**: Authenticated queries enforce `user_id == current_user.id`; ID lookups return 404 for foreign records.
- [x] **Forecast scoped to user**: Recalculations and predictions only use transactions owned by `current_user.id`.
- [x] **Transactions scoped to user**: Bank, UPI, and manual cash expenses scoped strictly to `current_user.id`.
- [x] **Cash expenses scoped to user**: CRUD operations reject cross-user access with 404.
- [x] **Statements scoped to user**: Uploads and listings isolated to `current_user.id`.
- [x] **Flutter identity restored after restart**: `AuthProvider.init()` checks saved token and invokes `/auth/me` to restore state without generating new guests.
- [x] **Backend tests pass**: 64/64 tests passing in `pytest` (including 10 new identity tests).
- [x] **Flutter tests pass**: 44/44 tests passing in `flutter test` (including identity & session tests).
- [x] **Flutter analyze passes**: 0 issues found in `flutter analyze`.
