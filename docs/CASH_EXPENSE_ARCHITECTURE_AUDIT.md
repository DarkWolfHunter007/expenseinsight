# Cash / Liquid Money Expense Tracking: Architecture Audit Report

## 1. Executive Summary
ExpenseInsight is an intelligent personal finance system analyzing user expenses from bank statement PDFs. This audit evaluates the codebase to integrate **Cash / Liquid Money Expense Tracking**, enabling users to manually record day-to-day cash expenses that do not originate from bank statements.

The system will maintain a strict architectural separation:
- `BANK_TRANSACTION`: Ingested from bank statements via the automated PDF pipeline.
- `CASH_EXPENSE`: Manually entered out-of-bank cash spending belonging to the authenticated user.
- `TOTAL_PERSONAL_SPENDING`: The unified aggregation of both sources across arbitrary reporting periods.

---

## 2. Current Architecture Review

### 2.1 Database Architecture (`backend/app/models/db_models.py`, `backend/app/database/session.py`)
- **ORM & Engine**: SQLAlchemy with SQLite (`sqlite:///./expenseinsight.db`). Connection event hook activates `PRAGMA foreign_keys=ON`.
- **Entities**:
  - `User`: Primary key UUID string (`id`), email, hashed password, guest flag. Has `cascade="all, delete-orphan"` relationships to `Statement`, `Transaction`, `CategoryCorrection`, `Forecast`.
  - `Statement`: Belongs to `User`. Tracks PDF file path, bank name, date range (`statement_start`, `statement_end`), status, progress. Deleting a statement cascade-deletes its transactions.
  - `Transaction`: Belongs to `User` and optionally `Statement`. Stores `date` (YYYY-MM-DD), `amount` (Float), `currency` (INR), `transaction_type` (expense/income/transfer), `cr_dr` (DR/CR), `category`, `merchant`, `normalized_merchant`.
  - `CategoryCorrection`: Stores user category corrections.
  - `Forecast`: Stores ARIMA/exponential smoothing forecasted amounts per category.
  - `Merchant`: Knowledge base lookup for merchants.

### 2.2 API Architecture (`backend/app/api/`)
- FastAPI application structured with routers:
  - `/api/v1` and root prefixes: `/auth`, `/statements`, `/transactions`, `/analytics`, `/forecast`, `/model`.
  - Dependency injection via `get_db` and `get_current_user` (Bearer JWT auth).
  - Pydantic v2 schemas (`backend/app/models/schemas.py`) for request/response serialization with `from_attributes=True`.

### 2.3 Analytics Architecture (`backend/app/services/analytics_service.py`)
- `AnalyticsService`:
  - `_get_user_transactions_df`: Loads user's bank transactions into a Pandas DataFrame, parses dates to `datetime`.
  - `get_summary`: Calculates `total_expense`, `total_income`, `total_transfers`, `net_savings`, `this_month_spent`, `previous_month_spent`, `month_over_month_change_pct`, `average_daily_spend`, `statement_period`, category breakdown, top merchants, and recurring expenses.
  - `get_monthly_spending`: Groups expenses and income by month (`year_month`).
  - `get_category_spending`: Aggregates debits by `category`, calculating total amount and percentage.
  - `get_merchant_spending`: Ranks top merchants by total expenditure.
  - `get_recurring_expenses`: Identifies periodic/subscription debits.

### 2.4 Forecasting Architecture (`backend/app/services/forecasting_service.py`, `backend/ml/forecasting/forecaster.py`)
- `ForecastingService`: Gathers transaction dicts (`date`, `amount`, `category`, `transaction_type`, `cr_dr`) and invokes `ExpenseForecaster`.
- `ExpenseForecaster`: Prepares a monthly pivot matrix (`year_month` x `category`) of expenses. Computes next-month forecasts and 90% confidence bounds using ARIMA or weighted smoothing.

### 2.5 Flutter Architecture (`mobile/flutter_app/`)
- **State Management**: Provider pattern (`ChangeNotifierProvider` in `MultiProvider`).
- **Services**: `ApiService` singleton with HTTP client, Bearer token header injection, fallback to `MockDataService`.
- **Models**: `TransactionModel`, `AnalyticsSummaryModel`, `MonthlySpendingItem`, `CategorySpendingItem`, `ForecastModel`.
- **UI Screens**:
  - `MainNavigationScreen`: Responsive layout with `NavigationRail` (desktop/web) and `NavigationBar` (mobile).
  - `DashboardScreen`: Bank statement header, metric cards grid, category donut chart, monthly trend chart, top merchants card.
  - `TransactionsScreen`: Transaction search, category filter chips, sort options, transaction list.
  - `UploadScreen`: Drag & drop PDF ingestion.
  - `ForecastScreen`: Forecast visualization and category projections.

### 2.6 Category & Date Filtering Conventions
- **Categories**: Standard category list (`Food`, `Shopping`, `Travel`, `Bills`, `Entertainment`, `Groceries`, `Fuel`, `Healthcare`, `Rent`, `Personal Care`, `Education`, `Investments`, `Other`, `Uncategorized`).
- **Dates**: Stored as standard ISO date strings `YYYY-MM-DD`. Financial calculations group by `expense_date` rather than creation audit timestamps.

---

## 3. Integration Plan & System Design

### 3.1 Domain Model (`CashExpense`)
```text
Table: cash_expenses
- id: String(36), PK (UUID)
- user_id: String(36), FK(users.id, ON DELETE CASCADE), indexed
- amount: Float (positive decimal value > 0)
- category: String(50), indexed
- description: String(255), nullable
- expense_date: String(20), indexed (YYYY-MM-DD)
- created_at: DateTime (UTC)
- updated_at: DateTime (UTC)
```
- Direct relationship with `User`: `user.cash_expenses`.
- Independent of `Statement`: Deleting bank statements preserves cash expenses intact.
- Deleting `User` cascades to delete all cash expenses.

### 3.2 API Layer (`/cash-expenses`)
- `POST /cash-expenses`: Create a cash expense (validates amount > 0, non-empty category, valid date YYYY-MM-DD).
- `GET /cash-expenses`: List authenticated user's cash expenses with optional date range (`start_date`, `end_date`), `category`, `search`, and pagination.
- `GET /cash-expenses/{id}`: Retrieve single cash expense (enforces user ownership).
- `PUT /cash-expenses/{id}`: Update amount, category, date, or description.
- `DELETE /cash-expenses/{id}`: Delete cash expense.

### 3.3 Analytics Integration
- Combine `Bank Transactions` and `Cash Expenses` based on `expense_date`:
  - `total_expense` = `bank_spending` + `cash_spending`.
  - Expose distinct fields: `bank_spending`, `cash_spending`, `total_spending` in `AnalyticsSummaryResponse`.
  - `categories_breakdown`: Combines bank debit spending + cash spending per category with recalculated percentages.
  - `monthly_spending`: Groups cash expenses by month using `expense_date` and adds them to monthly debits.
  - Top merchants remain bank-only as cash transactions do not have normalized merchant entities.
  - Date boundary checks: When statements define an analytics period (`start_date` to `end_date`), only cash expenses within `[start_date, end_date]` are aggregated.

### 3.4 Forecasting Integration
- `ForecastingService` appends cash expenses as expense dicts (`date=expense_date`, `amount=c.amount`, `category=c.category`, `transaction_type="expense"`, `cr_dr="DR"`).
- The forecaster aggregates monthly totals combining both streams, projecting future personal spending accurately.

### 3.5 Flutter Client Integration
- Model: `CashExpenseModel`.
- API Service: `createCashExpense`, `getCashExpenses`, `updateCashExpense`, `deleteCashExpense`.
- Provider: `CashExpenseProvider` with reactive state.
- UI:
  - Form: `AddCashExpenseDialog` / modal with Amount, Date, Category dropdown, Description.
  - History: Cash expenses tab or screen with date sorting, edit, delete with confirmation.
  - Dashboard: Spending cards showing Total Spending, Bank Transactions, Cash Expenses; Category and Monthly charts reflecting combined spending.

---

## 4. Potential Risks & Mitigations
1. **Date Range Contamination**: Cash expenses outside the selected statement period must not pollute statement-scoped analytics.
   *Mitigation*: Filter cash expenses strictly by `start_date <= expense_date <= end_date` whenever a date range applies.
2. **Statement Deletion Side-Effects**: Deleting a statement should not purge cash expenses.
   *Mitigation*: Foreign key references `users.id`, not `statements.id`.
3. **Floating Point Financial Precision**: Decimal addition errors.
   *Mitigation*: Round monetary amounts explicitly to 2 decimal places in calculations and API outputs.
4. **Offline / Mock Fallback in Flutter**: Flutter app supports mock mode when backend is unreachable.
   *Mitigation*: Provide mock cash expenses in `MockDataService` to ensure UI tests and offline development succeed gracefully.
