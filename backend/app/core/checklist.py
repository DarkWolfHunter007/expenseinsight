"""
backend/app/core/checklist.py

Machine-readable verification checklist for Persistent User Identity & Storage.
Mandated by Phase 17 of the Persistent User Identity specification.
"""

PERSISTENT_STORAGE_CHECKLIST = {
    "PHASE_1_DB_SCHEMA_AUDIT": {
        "description": "User schema supports stable UUIDv4 user.id, email with NOCASE uniqueness, created_at, updated_at.",
        "verified": True,
    },
    "PHASE_2_USER_ID_ANCHOR": {
        "description": "All financial models (Transaction, CashExpense, Statement, Forecast, CategoryCorrection) reference stable internal user.id as foreign key.",
        "verified": True,
    },
    "PHASE_3_RETRIEVAL_VS_CREATION": {
        "description": "POST /auth/identify checks if normalized email exists. If yes, retrieves user without creating duplicate; if no, creates new user or upgrades guest.",
        "verified": True,
    },
    "PHASE_4_CASE_INSENSITIVE_EMAIL": {
        "description": "Email matching is case-insensitive (e.g., User@Example.com matches user@example.com).",
        "verified": True,
    },
    "PHASE_5_EMAIL_NORMALIZATION": {
        "description": "Emails are trimmed of whitespace and converted to lowercase before lookup/storage.",
        "verified": True,
    },
    "PHASE_6_GUEST_UPGRADE": {
        "description": "Guest users are upgraded in-place or atomically migrated to existing user accounts without data loss.",
        "verified": True,
    },
    "PHASE_7_MULTI_DEVICE_PERSISTENCE": {
        "description": "Identifying with the same email from different devices/sessions retrieves the exact same user_id and data.",
        "verified": True,
    },
    "PHASE_8_OFFLINE_AND_APP_RESTART": {
        "description": "App restarts and offline states restore cached user session without creating new guest accounts.",
        "verified": True,
    },
    "PHASE_9_CROSS_USER_DATA_ISOLATION": {
        "description": "User A cannot see User B's transactions, cash expenses, statements, or forecasts.",
        "verified": True,
    },
    "PHASE_10_NEGATIVE_AUTHORIZATION": {
        "description": "Direct record lookups for foreign user records return 404 or authorization error. Expired/invalid tokens reject with 401.",
        "verified": True,
    },
    "PHASE_11_BACKEND_TESTS": {
        "description": "Automated test suite covers new user creation, existing user retrieval, email normalization, guest upgrade, multi-device, and data isolation.",
        "verified": True,
    },
    "PHASE_12_FLUTTER_SESSION_MANAGEMENT": {
        "description": "Flutter stores user_id, email, token in SharedPreferences and clears in-memory provider state on logout or identity switch.",
        "verified": True,
    },
    "PHASE_13_UI_FLOW_VERIFICATION": {
        "description": "UI provides identify-yourself onboarding screen and account switcher in Settings/More.",
        "verified": True,
    },
    "PHASE_14_AUTOMATED_TEST_STRATEGY": {
        "description": "Full automated test suites pass across backend (pytest) and mobile (flutter test).",
        "verified": True,
    },
    "PHASE_15_SECURITY_AND_PRIVACY": {
        "description": "No plain-text passwords stored; Bearer tokens strictly validated with 401 on invalid/expired/non-existent user tokens.",
        "verified": True,
    },
    "PHASE_16_FAILURE_MODES": {
        "description": "DB rollbacks protect guest migration, offline startup safely falls back to cached credentials without creating duplicate accounts.",
        "verified": True,
    },
    "PHASE_17_VERIFICATION_CHECKLIST": {
        "description": "In-repo verification checklist exists in docs/PERSISTENT_STORAGE_IMPLEMENTATION_CHECKLIST.md and backend/app/core/checklist.py.",
        "verified": True,
    },
    "PHASE_18_AUDIT_DOCUMENTATION": {
        "description": "All execution steps, tests, and architectural guarantees documented.",
        "verified": True,
    },
}
