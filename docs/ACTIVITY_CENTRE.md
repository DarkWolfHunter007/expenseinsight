# Financial Activity Centre and dashboard notifications

## What was there before

- Three stacked banners above the budget card: month recap, safe-to-spend and a red "uncertain transactions" banner.
  Dismissal was held in browser storage only, so it was shared between accounts on the same browser.
- Budget alerts were browser notifications only (`BudgetNotificationService`), with no history inside the app.
- Nothing was stored per user on the server, so there was nothing to review later.

## What it is now

| Piece | Where |
|---|---|
| Table `notifications` (unique `user_id` + `dedupe_key`) | `backend/app/models/db_models.py` |
| Rules and lifecycle | `backend/app/services/notification_service.py` |
| API | `backend/app/api/endpoints/notifications.py` |
| State | `lib/providers/notification_provider.dart` |
| Bell, screen, row | `lib/widgets/notification_bell.dart`, `lib/screens/activity_centre_screen.dart` |
| Destinations | `lib/utils/notification_actions.dart` |
| Inline budget status, daily and monthly dismissal | `lib/widgets/budget_card.dart` |
| Always-visible review list | `lib/widgets/dashboard/review_section.dart` |

Types: `month_recap`, `safe_to_spend`, `budget_warning`, `budget_critical`, `budget_exceeded`,
`uncertain_transaction`, `transaction_success`, `statement_upload`, `system`.
Groups for the filters: Budget, Transactions, System.

## Lifecycle rules

- **Dedupe**: each record has a `dedupe_key`; `create_once` is idempotent, so refreshing never duplicates.
  Budget levels: `budget|YYYY-MM|scope|status` (once per month, scope and level). Recap: `recap|YYYY-MM`.
  Safe to spend: `safe|YYYY-MM-DD`, updated in place through the day.
- **Review queue**: one live record `uncertain|live`. Its count follows `Transaction.needs_review`; it is resolved only
  when the count reaches 0, never by reading or dismissing it. Reading it does not clear the dashboard list.
- **Read, dismissed, resolved are separate.** Opening the screen changes nothing. Dismissed and resolved items are
  hidden unless "Show earlier notifications" is on.
- **Per account.** Every query filters on the authenticated user. Guest to account merge moves budget settings and
  learned merchant rules and deletes the guest's notifications.
- **Dashboard dismissals** (client, per account): safe-to-spend hides for the day, recap hides for that month.
  Browser-notification choices are now scoped per account too.

## API (new; nothing existing changed)

| Method | Path | Purpose |
|---|---|---|
| GET | `/notifications?group=&include_dismissed=&limit=` | feed with `unread_count` and per-group `counts` |
| POST | `/notifications/sync` | record whatever is newly due; idempotent |
| POST | `/notifications/read-all` | mark a group read |
| POST | `/notifications/{id}/read` `/unread` `/dismiss` `/restore` | single-item actions |

Nginx must proxy the `notifications` prefix (added to `mobile/flutter_app/nginx.conf`).

## Removed or replaced

`widgets/budget_banners.dart` (SafeToSpendBanner, MonthRecapBanner) and the red uncertain banner were replaced by the
inline budget card and `ReviewSection`. The whole-card close button was removed: the budget card is core information.
`BudgetNotificationService`, the planner and the settings card are kept.

## Limitations

- Server-side sync is triggered by the client (after the dashboard loads, and by cash-expense and statement hooks).
  Nothing is recorded while the app is closed, and there is no push to a closed browser.
- The backend uses the server's date (UTC in Docker). For a user in India the "day" for safe-to-spend rolls over at
  05:30 local time. The budget maths already behaved this way.
- Guest notifications are dropped when a guest signs up (the data they describe is migrated and re-derived on the next sync).
- Browser notifications still need the user to opt in, and may be blocked by the browser.

## Tests

Backend: `backend/tests/test_notifications.py` (dedupe, status transitions, read/unread, dismiss, isolation between
users, uncertain counts, migration). Flutter: `test/activity_centre_test.dart` (provider, destinations, relative time,
bell, screen, narrow width), `test/budget_card_test.dart`, `test/budget_alerts_test.dart`,
`test/notification_settings_test.dart`.
