# Checking ExpenseInsight against ChatGPT

The idea: ChatGPT reads the same bank statement PDF on its own, using the same definitions as the app,
and gives its answer in a fixed format. A script then compares that answer with what the app stored and
calculated. If they agree on every row and every total, the extraction and the calculations are right.
Where they disagree, the report shows exactly which rows or totals differ, so you can see who is wrong.

## How to run a check

1. Open ChatGPT (use a model that can read PDFs and run Python, such as GPT-4o or newer with the
   file tools turned on).
2. Attach the **same PDF** you uploaded to the app.
3. Copy everything inside the box under **"The prompt"** below and paste it as your message.
4. ChatGPT answers with one block of JSON. Save it as a file, for example `chatgpt_answer.json`
   (copy the JSON, or use the download link if ChatGPT offers one).
5. In the project folder, run:

```bash
python tools/compare_with_chatgpt.py --email YOUR_EMAIL --chatgpt chatgpt_answer.json
```

The app must be running (`docker compose up -d`), and `YOUR_EMAIL` is the email you signed in with.
Add `--report report.md` to also save the result as a file. If the account has more than one
statement, add `--statement "part of the file name"` to compare just one.

## What the script checks

| Check | What it tells you |
|---|---|
| ChatGPT's own consistency | Its rows chain from the opening balance to the closing balance, and its stated totals match its own rows. If not, ChatGPT made a mistake and its answer cannot be trusted. |
| Extraction | Every row in the PDF exists in the app with the same date, amount, debit/credit and balance. Nothing missing, nothing extra. |
| Totals recalculated from rows | Money out, money in, spending, transfers and cash withdrawals, calculated the same way for both sides. |
| The app's dashboard numbers | The numbers the dashboard shows (from the app's own summary) against ChatGPT's totals. This tests the app's calculations, not just its reading of the PDF. |
| Categories | How often ChatGPT and the app choose the same category. Categories are partly a judgement call, so differences are listed for you to read, not counted as failures. |

The first four are hard checks: they must match to the paisa. Categories are an agreement rate.

---

## The prompt

Copy from the line below to the end of the box.

````text
You are helping me verify a personal finance app called ExpenseInsight. I have attached a bank
statement PDF. Read it yourself, independently, and give me the data in an exact format so I can compare
it with what the app produced. Accuracy matters far more than speed. Do not guess and do not skip rows.

## 1. What the app does (so you use the same definitions)

ExpenseInsight reads Indian bank-statement PDFs (Canara, HDFC, SBI, ICICI, Axis, Kotak). For every
transaction row it stores: date, narration, debit or credit, amount, running balance and a category.
It then calculates totals using these exact rules:

- MONEY OUT = every debit (withdrawal) row. This should equal the "total withdrawals" of the statement.
- MONEY IN = every credit (deposit) row. This should equal the "total deposits" of the statement.
- TRANSFERS = money sent to or received from another PERSON (person-to-person UPI or bank transfers).
  These are neutral movements, NOT spending and NOT income.
- CASH WITHDRAWALS = ATM or cash withdrawals. These are NOT spending (the money becomes cash).
- SPENDING = debits that are not transfers and not cash withdrawals (purchases, bills, food, travel,
  subscriptions, bank charges and so on).
- INCOME = credits that are not transfers (salary, interest, refunds, other business credits).

## 2. Step by step

1. Read EVERY page of the PDF, every transaction row. Do not stop at the first pages.
2. For each row capture: date, the full narration text (join wrapped lines with a single space), whether
   it is a DEBIT (DR, money left the account) or CREDIT (CR, money came in), the amount, and the running
   balance after the row.
   - The PDF often prints only one amount column value per row plus the balance. Decide DR or CR from the
     running balance: if the balance went DOWN versus the previous row it is a DR, if UP it is a CR.
   - Narrations wrap over several lines and may contain date fragments such as "24/09/2025 09:08:00".
     Those are part of the narration, NOT separate transactions. A new transaction starts at a row date
     (for example 24-09-2025) that has its own amount and balance.
   - Rows may be slightly out of date order. Keep them in the order they appear in the PDF.
3. USE PYTHON (the code tool) for all arithmetic. Do not add numbers in your head. Specifically:
   a. Check the chain: opening_balance + CR - DR equals the next balance for every row. List any row where
      it does not.
   b. Count the rows.
   c. Compute all totals in section 4 with code from your own rows.
4. Classify every row into exactly one category from this list (use these exact spellings):
   Food, Groceries, Shopping, Travel, Fuel, Bills, Entertainment, Healthcare, Rent, Education, Insurance,
   Investments, Income, Transfers, Cash Withdrawal, Other, Uncategorized
   Rules:
   - Payment to or from a PERSON by UPI or bank transfer -> Transfers.
   - ATM / cash withdrawal -> Cash Withdrawal.
   - Salary, interest credited by the bank, refunds from a shop or app -> Income.
   - Bank charges, SMS charges, phone, electricity, internet, insurance premiums -> Bills.
   - Restaurants, food delivery, cafes -> Food. Supermarkets and grocery -> Groceries.
   - Online shopping and retail -> Shopping. Bus, metro, taxi, trains, flights -> Travel. Petrol -> Fuel.
   - Streaming, games, subscriptions -> Entertainment. Chemists, hospitals -> Healthcare.
   - Banks cut the payee name to about 9 characters and the PDF may split a word across lines, so
     "FLIPKAR T" is Flipkart (Shopping) and "KERALA ST" next to tiny bus-fare amounts is a state bus
     corporation (Travel).
   - If you genuinely cannot tell whether a payee is a person or a business, use Uncategorized and set
     "uncertain": true for that row. Never invent a category.

## 3. Output format

Reply with ONE JSON object in a single code block, and nothing else before or after it. If you can
create a downloadable file, also attach it as chatgpt_answer.json. Use exactly these field names.
Amounts are plain numbers with two decimals, no currency signs and no commas.

{
  "statement": {
    "bank": "Canara Bank",
    "account_masked": "XXXXXXXX0000",
    "period_start": "YYYY-MM-DD",
    "period_end": "YYYY-MM-DD",
    "page_count": 0,
    "opening_balance": 0.00,
    "closing_balance": 0.00,
    "row_count": 0
  },
  "transactions": [
    {
      "n": 1,
      "date": "YYYY-MM-DD",
      "description": "full narration on one line",
      "type": "DR",
      "amount": 0.00,
      "balance": 0.00,
      "category": "Food",
      "uncertain": false
    }
  ],
  "totals": {
    "money_out": 0.00,
    "money_in": 0.00,
    "spending": 0.00,
    "transfers_out": 0.00,
    "transfers_in": 0.00,
    "cash_withdrawals": 0.00,
    "income": 0.00
  },
  "spending_by_month": { "YYYY-MM": 0.00 },
  "spending_by_category": { "Food": 0.00 },
  "checks": {
    "balance_chain_ok": true,
    "rows_where_chain_breaks": [],
    "closing_balance_equals_opening_plus_money_in_minus_money_out": true
  },
  "notes": "anything unclear, ambiguous or that you were unsure about"
}

## 4. Totals, defined precisely

- money_out        = sum of amount over rows with type DR
- money_in         = sum of amount over rows with type CR
- transfers_out    = sum of amount over rows with type DR and category Transfers
- transfers_in     = sum of amount over rows with type CR and category Transfers
- cash_withdrawals = sum of amount over rows with type DR and category Cash Withdrawal
- spending         = money_out - transfers_out - cash_withdrawals
- income           = money_in - transfers_in
- spending_by_month and spending_by_category: only the rows that count as spending (DR, not Transfers,
  not Cash Withdrawal), grouped by the calendar month of the row date and by category.

## 5. Before you answer

Re-run your code on the final list and make sure: row_count equals the number of items in
"transactions"; the balance chain check was computed by code, not by eye; every total in "totals" comes
from code run on exactly the rows you are returning. If the chain breaks anywhere, say which rows in
"checks" and "notes" instead of hiding it. If any page was unreadable, say so in "notes".
````

---

## Reading the result

- **Everything matches (rows and totals):** the app read the PDF correctly and its totals are right.
- **ChatGPT's own checks fail:** ChatGPT made an arithmetic or reading error. Ask it to fix the listed
  rows and run the comparison again. Do not blame the app yet.
- **Rows differ:** the report lists rows only the app has, rows only ChatGPT has, and rows whose balance
  differs. Check those rows against the PDF by eye.
- **Only categories differ:** usually a judgement call (for example a payee that could be a person or a
  small shop). Decide which side is right. If the app is wrong, correct it once in the app with
  "apply to future" turned on, and it remembers.
- **Money out is different on the dashboard but not in the report:** the dashboard's "Total spending"
  deliberately leaves out transfers and cash withdrawals. Compare it with ChatGPT's `spending`, and the
  "Money in and out" card with `money_out` and `money_in`.
