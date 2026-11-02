# ExpenseInsight: Handoff

Read this first if you are picking the project up (a person or a fresh AI session). It says what the
project is, where it stands, what is known to be wrong, and what to do next. Everything here was
checked against the code or against a running app unless it says "unverified".

- Running it: [STARTUP.md](STARTUP.md) (Docker, Windows and Mac, Cloudflare sharing)
- Product background: [README.md](README.md), [ExpenseInsight_PRD.md](ExpenseInsight_PRD.md)
- Checking the app against ChatGPT: [docs/CHATGPT_VERIFICATION.md](docs/CHATGPT_VERIFICATION.md)

---

## 1. What it is

A privacy-first personal-finance **web app** for Indian bank statements. You upload a bank-statement
PDF (Canara, HDFC, SBI, ICICI, Axis, Kotak formats are handled), and it extracts the transactions,
works out the merchant, categorizes each one, and shows spending, a monthly budget with alerts, and a
next-month forecast. Cash expenses can be added by hand.

- **Backend:** FastAPI + SQLAlchemy + SQLite, PyMuPDF for PDFs, scikit-learn for categorization,
  statsmodels (ARIMA) for the forecast.
- **Frontend:** Flutter, built for the **web only** (an installable PWA). No native iOS/macOS/Windows build.
- **Run:** Docker Compose. Nginx serves the site and proxies the API, all on **port 3000**.
- **Login:** passwordless, by email. Every request needs a bearer token.

## 2. State at handoff

| | |
|---|---|
| Branch | `main`, working tree clean |
| Pushed? | **No. Several commits are ahead of `origin/main`** (last pushed: `6b7bfa2`). Ask the owner before pushing. |
| Tests | Backend `pytest backend/tests` (165 passed at handoff), Flutter `flutter test` (76 passed at handoff), `flutter analyze` clean |
| Docker | Running and healthy with the latest code: `http://localhost:3000` |
| In progress | Nothing half-edited. The four problems the audit found (old section 6) are **fixed and deployed**. |

Recent commits (newest first): web bundle rebuild, ChatGPT comparison tool, "Money in and out" dashboard
card, backend money-out fields, notification settings, categorization fix, share-script fixes,
`STARTUP.md`, the merge of the earlier code-review commit.

## 3. Repository map

```
backend/app/
  main.py                      app + router registration; create_all() builds the tables
  api/deps.py                  auth: a valid token is REQUIRED (no shared demo user); JWT secret from env
  api/endpoints/               auth, statements, transactions, cash_expenses, analytics, forecast,
                               model, budget
  services/
    pdf_extractor.py           PDF -> text + bank detection + period
    transaction_parser.py      text -> transactions (block parser for passbooks; balance chain decides CR/DR)
    statement_processor.py     the 7-stage upload pipeline (applies the user's learned rules)
    analytics_service.py       summary, budget (_compute_budget), money in/out, categories
    forecasting_service.py     feeds the forecaster with bank + cash spending
    accounting.py              what counts as spending / income / transfer
  models/db_models.py          tables incl. budget_settings, merchant_category_rules
backend/ml/
  preprocessing/merchant_normalizer.py   merchant knowledge base + matching layers
  preprocessing/text_cleaner.py
  categorization/hybrid_categorizer.py   KB match -> ML model -> person-vs-business rule -> review flag
  forecasting/forecaster.py              ARIMA per category, sums the categories
mobile/flutter_app/
  lib/providers/               state (analytics, budget, transactions, cash, forecast, ...)
  lib/screens/                 dashboard, budget_settings, transactions, upload, ...
  lib/widgets/                 budget_card, budget_banners, money_flow_card, notification_settings_card, ...
  lib/services/                api_service, budget_notification_service (+ web/stub notification files)
  build/web/                   the BUILT site. It is tracked in git and is what Docker serves.
  nginx.conf                   proxies /api,/auth,/statements,... to the backend (add new API prefixes here!)
tools/                         synthetic_statement.py, recategorize.py, compare_with_chatgpt.py
docs/                          CHATGPT_VERIFICATION.md and older audit notes
```

## 4. Definitions the app uses (so the numbers are not a surprise)

- **Money out / in (bank):** every debit / credit on the statement. Matches the PDF's own withdrawals and
  deposits, and `opening + in - out = closing` reconciles. Shown in the dashboard's "Money in and out" card.
- **Spending:** debits that are purchases, bills or fees. It **excludes payments to people ("Transfers")
  and ATM cash**. So the dashboard's "Total spending" is much smaller than money out. This is by design
  but confusing (see section 6).
- **Income:** credits that are not transfers from people.
- **Direction of each row** comes from the running balance, not from the column.
- **Monthly budget (automatic):** personal spending / days from the first to the last spending
  transaction x 30.4375. A manual monthly limit overrides it, and category limits can be set.
  Levels: on track, warning at 80%, critical at 90%, exceeded above 100%.
  "Safe to spend today" = remaining / days left in the month (never below 0).
  The dashboard range stretches to cash entries dated after the statement ends.
- **Forecast:** per category, then summed. 3+ complete months: ARIMA. Exactly 2: `0.65 x latest + 0.35 x previous`.
  1: repeat with +/-25%. Months with no spending count as 0. Months the data only part covers are left out
  **only while 3 or more complete months remain** (this matters, see section 6).
- **Learned corrections:** changing a category with "apply to future" saves a per-user merchant rule
  (`merchant_category_rules`) that later uploads use.
- **Notifications:** browser notifications, first time each level is reached in a month. They need the
  browser's permission; the Budget & Alerts screen shows the status and a test button.

## 5. How things were verified (reuse this)

1. **Independent PDF check:** read the PDF, decide CR/DR with the balance chain, and confirm
   `opening + deposits - withdrawals = closing balance`. This is the arbiter when two readings disagree.
2. **Synthetic statements:** `python tools/synthetic_statement.py --out <dir>` makes a Canara-style PDF
   plus a ground-truth JSON (it found a real parser bug).
3. **ChatGPT cross-check:** `docs/CHATGPT_VERIFICATION.md` + `tools/compare_with_chatgpt.py`.
   Treat ChatGPT as a second opinion, not ground truth (it makes arithmetic and classification mistakes).
4. **Result of the last audit (a real 98-row Canara statement):** extraction was perfect (98/98 rows,
   amounts, dates, directions, balances; money in/out reconcile to the closing balance). The weak part
   is **classification**, listed next.

## 6. What the audit found, and what was done

An independent audit of a real 98-row Canara statement (extraction was perfect) found four real problems.
All four are fixed, covered by tests, and deployed:

1. **Wrong merchants.** Matching read the whole narration, so a stray "vi" in a reference hash became
   Vodafone Idea, an address became Metro Rail, and a short alias ("h and m") fuzzy-matched anything.
   Fixed in `merchant_normalizer.py`: match on the **payee only** (`extract_payee`), no substring match on
   aliases under 3 letters, fuzzy match only aliases of 6+ letters and by whole-string similarity
   (`fuzz.ratio`, because `token_set_ratio` made "google in" match "google youtube"), and a truncated-name
   key is only added when the cut ends inside a second word. The merchant key no longer contains the bank code.
2. **Person-vs-business rule gaps** (`hybrid_categorizer.payee_profile`): handles plurals (`FUELS`),
   words broken by a wrap (`BARBEC UE`), the `M/S` prefix, business payment handles (`STATICQR`, `DQR`,
   `OKBIZ`, ...) even when the PDF breaks them with a space, and gives keyword category hints
   (bakery/hotel -> Food, fuel -> Fuel, medical -> Healthcare, textile/book/pet -> Shopping, ...) at medium
   confidence. A business with no hint goes to the review list.
3. **Forecast over-weighting a thin month** (`forecaster.py`): a month with at least 85% of its days
   covered counts as complete; with a short history a partial month under 50% coverage is dropped.
4. **Dashboard calculations:** "Net Savings" is replaced by **Net cash flow** (money in - money out - cash
   spending, which equals the real change in the account); "This Month" is labelled with its month; the
   Total spending card says what it excludes.

Known limit that remains: a small business with a person-like name (for example a restaurant called
"ZAM ZAM") cannot be told apart from a person and stays a transfer.

### Backlog / limitations (lower priority)

- Refund credits count as income (they should reduce spending).
- Recurring-bill detection only accepts 20-35 day gaps, so a bimonthly bill is missed.
- `POST /model/retrain` does not retrain anything in Docker (`OFFLINE_TRAINING_MODE`); it saves feedback
  and says so. Real retraining is an offline script (`ml_training/`).
- The ML model is overconfident on unfamiliar payees (trained largely on synthetic data); the review rule
  in `hybrid_categorizer` is a patch, not a recalibration.
- Browser notifications only fire while the app is open; there is no server push.
- `/auth/identify` is passwordless: anyone who knows an email can open that account. Put Cloudflare
  Access in front before sharing publicly (see `STARTUP.md`).
- Stored transactions keep the categories they were given at upload. After changing the categorizer,
  stop the backend, run `python tools/recategorize.py --email <email>` (dry run) and add `--apply`
  to update old rows. It writes a timestamped backup of the database first and never touches rows the
  user categorized. (Earlier versions reused one backup name, so repeated runs overwrote it.)

## 6b. Dashboard and Activity Centre

The dashboard is an "open canvas" (numbered sections, no stacked banners) and notifications live in a per-user
Activity Centre (bell in the app bar). Design, rules, API and limitations: `docs/ACTIVITY_CENTRE.md`.
Tests at this point: 186 backend, 105 Flutter.

## 7. Things that will trip you up

- **Docker Desktop must be running.** The error `dockerDesktopLinuxEngine ... cannot find the file`
  means it is not. A stray Flutter dev server on port 3000 will shadow the Docker site.
- **`build/web` is committed and is what Docker serves.** After any Flutter change:
  `cd mobile/flutter_app && flutter build web --release`, then `docker compose up --build -d`, then
  commit the rebuilt bundle. Browsers cache: hard refresh (Ctrl+Shift+R) after a rebuild.
- **New API path?** Add its prefix to `nginx.conf`, or the site returns HTML instead of JSON.
- **Two databases exist:** `data/expenseinsight.db` is the one Docker uses; a `expenseinsight.db` in the
  project root comes from running the backend locally. Both are git-ignored and hold real data. Never commit them.
- **Never commit personal data.** The repo is public. `.env` (the JWT secret) is git-ignored.
- **Flutter web is a canvas,** so the page text is not searchable; check screens by screenshot.
- **Windows quoting:** passing multi-line Python or Dart through a shell heredoc corrupts backslashes and
  null bytes. Write a script file and run it instead.
- A brand-new Cloudflare quick-tunnel link takes 10-60 seconds to start working; that is on Cloudflare's side.

## 8. Commands

```bash
docker compose up --build -d          # build and start (site + API on http://localhost:3000)
docker compose ps                     # both containers Up, backend healthy
.venv/Scripts/python -m pytest backend/tests -q        # backend tests (Windows venv path)
cd mobile/flutter_app && flutter analyze && flutter test
cd mobile/flutter_app && flutter build web --release   # then rebuild Docker, then commit build/web
python tools/recategorize.py --email you@example.com   # dry run; add --apply to write
python share_live.py                                   # public Cloudflare link + QR (port 3000)
```

## 9. Open decisions for the owner

1. Push the local commits to GitHub `main`?
2. Should a payee that cannot be told apart from a person (for example a small restaurant) go to the
   review list (more reviewing for the user) or stay a transfer (some spending missed)? Today it stays
   a transfer.
