# ExpenseInsight --- Detailed Product Requirements Document (PRD)

**Version:** 1.0\
**Status:** MVP / Academic Project\
**Product:** ExpenseInsight\
**Platform:** Flutter mobile application + backend API + ML/NLP
services\
**Primary Use Case:** Automatically extract, normalize, categorize,
analyze, and forecast personal expenses from bank-statement PDFs.

------------------------------------------------------------------------

## 1. Product Overview

ExpenseInsight is an intelligent personal-finance application that
converts bank-statement PDFs into structured financial data and
transforms that data into useful spending insights.

The user uploads one or more bank statements, ideally covering
approximately six months. The system extracts transaction information
from the PDFs, converts the raw statement content into structured
transactions, normalizes inconsistent merchant descriptions, categorizes
expenses using NLP and machine learning, identifies transactions whose
category is uncertain, and generates historical spending analytics and
future expense forecasts.

The product is based on the project concept of combining:

1.  Transaction data collection
2.  Data preprocessing
3.  NLP-based expense categorization
4.  Transaction storage
5.  Spending analytics
6.  Expense forecasting
7.  Interactive visualization

The original project methodology proposes preprocessing transaction
descriptions, using TF-IDF for feature extraction, supervised machine
learning for categories such as Food, Shopping, Travel, Bills, and
Entertainment, and forecasting future expenses from historical spending
patterns.

This PRD expands that concept into a complete real-world application
architecture.

------------------------------------------------------------------------

# 2. Problem Statement

Bank statements contain valuable financial information, but the
information is often difficult to use directly.

A typical statement may contain descriptions such as:

``` text
UPI/3249820192/SWIGGY
UPI-P2M-RAHUL-RAZORPAY
POS 48392 AMAZON SELLER
NEFT/ABC ELECTRICITY LTD
UPI/987231/UBER INDIA
```

The same merchant can also appear in multiple forms:

``` text
SWIGGY
SWIGGY LIMITED
UPI/SWIGGY/123123
SWIGGY*ORDER
SWIGGY INSTAMART
```

A user should not have to manually clean or categorize every
transaction.

ExpenseInsight solves this by creating a pipeline:

``` text
Bank Statement PDF
        ↓
PDF Extraction / OCR
        ↓
Raw Statement Text
        ↓
Transaction Parsing
        ↓
Merchant Normalization
        ↓
NLP Preprocessing
        ↓
Expense Categorization
        ↓
Confidence Evaluation
        ↓
Human Review for Uncertain Transactions
        ↓
Structured Transaction Database
        ↓
Analytics
        ↓
Forecasting
        ↓
Flutter Dashboard
```

------------------------------------------------------------------------

# 3. Product Goals

## Primary Goals

### G1 --- Automated transaction extraction

Extract transaction records from bank-statement PDFs without requiring
manual data entry.

Each transaction should ideally contain:

-   Date
-   Description
-   Amount
-   Transaction type
-   Debit/credit indicator
-   Balance, when available
-   Bank/source
-   Statement period
-   Raw extracted text
-   Parsed merchant
-   Normalized merchant
-   Category
-   Category confidence

### G2 --- Merchant normalization

Create a normalization layer that converts inconsistent transaction
descriptions into a consistent merchant representation.

Example:

``` text
UPI/3249820192/SWIGGY
        ↓
SWIGGY
```

``` text
POS/AMAZON SELLER/48392
        ↓
AMAZON
```

``` text
UPI/987231/UBER INDIA
        ↓
UBER
```

This layer should run before final category prediction.

### G3 --- Automated expense categorization

Automatically classify transactions into meaningful categories such as:

-   Food
-   Shopping
-   Travel
-   Bills
-   Entertainment

Additional categories may be supported:

-   Healthcare
-   Education
-   Groceries
-   Fuel
-   Rent
-   Subscriptions
-   Personal Care
-   Insurance
-   Investments
-   Transfers
-   Cash Withdrawal
-   Other
-   Uncategorized

The initial academic evaluation should use a controlled category set so
that model performance can be measured consistently.

### G4 --- Handle uncertain transactions

The system must not pretend that every prediction is correct.

When confidence is low, the system should mark the transaction for
review.

Example:

``` text
ABC ENTERPRISES
₹2,400

Predicted category:
Shopping

Confidence:
51%

[ Food ] [ Shopping ] [ Bills ] [ Travel ] [ Other ]
```

The user correction should be stored as feedback.

### G5 --- Spending analytics

Calculate:

-   Total spending
-   Monthly spending
-   Category-wise spending
-   Average daily spending
-   Spending by transaction type
-   Highest-spending categories
-   Merchant-level spending
-   Monthly category trends
-   Recurring expenses

### G6 --- Expense forecasting

Use historical transactions to estimate future expenses.

The first target should be:

-   Next 7 days
-   Next 30 days
-   Next month

The system may later support:

-   60-day forecast
-   90-day forecast

Forecasting must be presented as an estimate rather than a guaranteed
outcome.

------------------------------------------------------------------------

# 4. Non-Goals for the MVP

The MVP should NOT attempt to:

-   Directly access bank accounts
-   Initiate payments
-   Transfer money
-   Store banking passwords
-   Act as a banking application
-   Guarantee financial outcomes
-   Provide regulated financial advice
-   Automatically make investment decisions
-   Build a full accounting system
-   Support every bank statement format from day one

The first version should focus on:

**PDF → transactions → categorization → analytics → forecast.**

------------------------------------------------------------------------

# 5. Target Users

## Primary User

A person who wants to understand their spending without manually
entering every transaction.

Example:

> A user has six months of bank statements and wants to know where their
> money went and how much they are likely to spend next month.

## Academic User

The project evaluator should be able to see:

-   NLP processing
-   ML classification
-   Data normalization
-   Database design
-   Forecasting
-   Visualization
-   Model evaluation

------------------------------------------------------------------------

# 6. Core User Journey

``` text
Open App
   ↓
Create Account / Continue
   ↓
Upload Bank Statement
   ↓
Select Statement Period
   ↓
Processing
   ↓
Transactions Extracted
   ↓
Merchant Normalization
   ↓
AI Categorization
   ↓
Uncertain Transactions Review
   ↓
Dashboard Generated
   ↓
Historical Analysis
   ↓
Future Expense Forecast
```

------------------------------------------------------------------------

# 7. Flutter Application

## 7.1 Onboarding

The onboarding should explain:

> Upload your bank statement and ExpenseInsight will organize your
> transactions and show you where your money is going.

Actions:

-   Get Started
-   Sign In
-   Continue

------------------------------------------------------------------------

# 8. Statement Upload

## Requirements

The application should support:

-   PDF upload
-   Multiple PDF upload
-   Six-month statement upload
-   File validation
-   Upload progress
-   Processing status

Example:

``` text
Upload Statements

January 2026.pdf     ✓
February 2026.pdf   ✓
March 2026.pdf      ✓
April 2026.pdf      ✓
May 2026.pdf        ✓
June 2026.pdf       ✓

[ Analyze Statements ]
```

The application should ideally allow a single six-month PDF as well.

------------------------------------------------------------------------

# 9. PDF Processing Pipeline

The backend should first determine whether the PDF contains selectable
text.

## Case A --- Text-based PDF

Use a PDF text extraction library.

Pipeline:

``` text
PDF
 ↓
Text Extraction
 ↓
Page Text
 ↓
Transaction Parser
```

## Case B --- Scanned PDF

Use OCR.

Pipeline:

``` text
PDF
 ↓
Render Pages
 ↓
OCR
 ↓
Extracted Text
 ↓
Transaction Parser
```

The system should retain the original PDF and raw extracted text
separately where appropriate.

------------------------------------------------------------------------

# 10. Transaction Parsing

The parser converts raw statement text into structured records.

Example raw data:

``` text
15/01/2026
UPI/3249820192/SWIGGY
487.00
42,850.00
```

Parsed representation:

``` json
{
  "date": "2026-01-15",
  "description": "UPI/3249820192/SWIGGY",
  "amount": 487.00,
  "type": "debit",
  "balance": 42850.00
}
```

The parser must be designed so that bank-specific formats can be added
later.

------------------------------------------------------------------------

# 11. Transaction Schema

Each normalized transaction should contain at least:

``` json
{
  "id": "uuid",
  "user_id": "uuid",
  "statement_id": "uuid",
  "date": "2026-01-15",
  "raw_description": "UPI/3249820192/SWIGGY",
  "clean_description": "SWIGGY",
  "merchant": "Swiggy",
  "normalized_merchant": "swiggy",
  "amount": 487.00,
  "currency": "INR",
  "transaction_type": "debit",
  "category": "food",
  "category_confidence": 0.974,
  "category_source": "ml",
  "needs_review": false
}
```

------------------------------------------------------------------------

# 12. Merchant Normalization Layer

## Purpose

The merchant normalization layer is one of the key additions to the
project.

Bank transaction descriptions contain noise:

-   UPI identifiers
-   Reference numbers
-   Transaction IDs
-   Dates
-   Account numbers
-   Payment gateway identifiers
-   POS identifiers
-   Bank-specific prefixes
-   Random alphanumeric strings

The normalization layer attempts to isolate the meaningful merchant
information.

## Example

Input:

``` text
UPI/3249820192/SWIGGY/ORDER123
```

Output:

``` text
Merchant:
Swiggy
```

Input:

``` text
POS 48392 AMAZON SELLER
```

Output:

``` text
Merchant:
Amazon
```

Input:

``` text
NEFT/ABC ELECTRICITY LTD/98732
```

Output:

``` text
Merchant:
ABC Electricity
```

## Normalization stages

``` text
Raw Description
      ↓
Lowercase
      ↓
Remove transaction IDs
      ↓
Remove reference numbers
      ↓
Remove known banking prefixes
      ↓
Remove unnecessary symbols
      ↓
Detect merchant tokens
      ↓
Canonical merchant name
```

------------------------------------------------------------------------

# 13. Merchant Normalization Strategy

The normalization engine should use multiple techniques rather than one
rule.

## Layer 1 --- Regex cleaning

Remove:

-   Long numeric IDs
-   Reference numbers
-   UPI identifiers
-   Special characters
-   Known statement prefixes

## Layer 2 --- Known merchant dictionary

Maintain a merchant alias table.

Example:

``` text
swiggy
swiggy india
swiggy limited
swiggy instamart
swiggy order
```

→

``` text
Swiggy
```

## Layer 3 --- Similarity matching

Use string similarity or embeddings to determine whether two
descriptions probably refer to the same merchant.

Example:

``` text
AMZN
AMAZON
AMAZON SELLER
AMAZON PAY
```

The system may determine that these are related, but it should avoid
blindly merging entities when the evidence is weak.

## Layer 4 --- User correction

If the system repeatedly gets a merchant wrong, the user can correct the
normalized merchant.

That correction becomes persistent data.

------------------------------------------------------------------------

# 14. Merchant Database

Create a merchant normalization table.

``` text
merchants
--------------------------------
id
canonical_name
aliases
default_category
confidence
created_at
updated_at
```

Example:

``` text
canonical_name: Swiggy
aliases:
    SWIGGY
    SWIGGY INDIA
    SWIGGY ORDER
    SWIGGY INSTAMART

default_category:
Food
```

The system should distinguish between:

-   Merchant identity
-   Default category
-   Actual transaction category

This is important because the same merchant can sometimes represent
different kinds of spending.

------------------------------------------------------------------------

# 15. NLP Preprocessing

After normalization, transaction text should be prepared for the ML
model.

Steps:

``` text
Raw description
       ↓
Lowercase
       ↓
Remove noise
       ↓
Tokenization
       ↓
Optional stop-word removal
       ↓
Normalize merchant
       ↓
Feature extraction
```

The original project specifically proposes preprocessing, tokenization,
and TF-IDF feature extraction. These remain part of the baseline
implementation.

------------------------------------------------------------------------

# 16. Feature Representation

The system should support experimentation with multiple representations.

## Baseline

``` text
TF-IDF
```

Recommended baseline classifier:

``` text
TF-IDF
   ↓
Logistic Regression
   ↓
Category
```

## Advanced Experiment

Evaluate semantic embeddings:

``` text
Transaction text
       ↓
Sentence embedding
       ↓
Classifier
       ↓
Category
```

## Hybrid Experiment

Potential final model:

``` text
                    Transaction
                         ↓
                 Normalization
                         ↓
             ┌───────────┴───────────┐
             ↓                       ↓
           TF-IDF               Embedding
             ↓                       ↓
             └───────────┬───────────┘
                         ↓
                    Classifier
                         ↓
               Category + Confidence
```

The final model should be selected using measured validation performance
rather than assuming that embeddings are automatically superior.

------------------------------------------------------------------------

# 17. Expense Categories

## Core Categories

``` text
Food
Shopping
Travel
Bills
Entertainment
```

## Extended Categories

``` text
Groceries
Fuel
Healthcare
Education
Rent
Insurance
Subscriptions
Personal Care
Transfers
Cash Withdrawal
Investment
Other
Uncategorized
```

The core categories should remain stable for academic model evaluation.

------------------------------------------------------------------------

# 18. Category Prediction

For every transaction:

``` text
Transaction
    ↓
Preprocessing
    ↓
Feature extraction
    ↓
ML model
    ↓
Probability distribution
```

Example:

``` json
{
  "food": 0.974,
  "shopping": 0.012,
  "travel": 0.005,
  "bills": 0.006,
  "entertainment": 0.003
}
```

Final result:

``` text
Food
97.4%
```

------------------------------------------------------------------------

# 19. Confidence and Uncertainty

Confidence should be a first-class field in the database.

Suggested logic:

``` text
>= 85%
High confidence
Automatically accept

60%–84%
Medium confidence
Accept but make correction easy

< 60%
Low confidence
Require / strongly recommend user review
```

These thresholds should be configurable and evaluated against validation
data.

The system must not represent model probability as certainty.

------------------------------------------------------------------------

# 20. "Help Me Categorize This" Feature

This is a key user-facing feature for uncertain transactions.

When the model does not know the category:

``` text
We couldn't confidently categorize this transaction.

Merchant:
ABC ENTERPRISES

Amount:
₹2,400

What was this expense?

[ Food ]
[ Shopping ]
[ Travel ]
[ Bills ]
[ Entertainment ]
[ Other ]
```

The user selects a category.

The correction is stored.

------------------------------------------------------------------------

# 21. AI Categorization Prompt

If an LLM is used as an auxiliary classification or explanation layer,
it should receive normalized transaction information rather than the
entire bank statement.

Example prompt:

``` text
You are an expense categorization assistant.

Classify the following financial transaction into exactly one category.

Categories:
- Food
- Shopping
- Travel
- Bills
- Entertainment
- Groceries
- Fuel
- Healthcare
- Education
- Rent
- Insurance
- Subscription
- Personal Care
- Other
- Uncategorized

Transaction:
Merchant: {merchant}
Description: {clean_description}
Amount: {amount}
Date: {date}

If the category cannot be determined reliably, return:
"Uncategorized"

Return JSON only:

{
  "category": "...",
  "confidence": 0.0,
  "reason": "short explanation"
}
```

The LLM should not be treated as the only source of truth if the
academic implementation is based on supervised ML. It can be an
auxiliary layer for difficult or low-confidence cases.

------------------------------------------------------------------------

# 22. Hybrid Categorization Architecture

A strong production-oriented approach is:

``` text
Transaction
     ↓
Merchant normalization
     ↓
Known merchant lookup
     │
     ├── Strong match → category
     │
     └── No strong match
             ↓
        ML classifier
             ↓
        Confidence check
             │
       ┌─────┴─────┐
       ↓           ↓
    High          Low
confidence      confidence
       ↓           ↓
    Accept       Review / LLM
```

This reduces unnecessary model calls and gives the system a fallback
path.

------------------------------------------------------------------------

# 23. User Feedback Learning

Every correction should be saved.

``` text
Prediction:
ABC ENTERPRISES → Shopping

User:
Changes → Bills

Stored:
merchant = ABC ENTERPRISES
correct_category = Bills
```

Future transactions containing the same normalized merchant can use this
learned association.

For the academic project, model retraining can happen manually or
periodically rather than after every single correction.

------------------------------------------------------------------------

# 24. Database Design

## users

``` text
id
email
created_at
```

## statements

``` text
id
user_id
file_name
bank_name
statement_start
statement_end
processing_status
created_at
```

## transactions

``` text
id
user_id
statement_id
date
raw_description
clean_description
merchant
normalized_merchant
amount
currency
transaction_type
balance
category
category_confidence
category_source
needs_review
created_at
```

## merchants

``` text
id
canonical_name
aliases
default_category
created_at
updated_at
```

## category_corrections

``` text
id
transaction_id
user_id
old_category
new_category
created_at
```

## forecasts

``` text
id
user_id
forecast_date
category
predicted_amount
lower_bound
upper_bound
model_version
created_at
```

## model_versions

``` text
id
model_name
version
algorithm
features
accuracy
precision
recall
f1_score
created_at
```

------------------------------------------------------------------------

# 25. Analytics Engine

Once transactions are categorized, the analytics service should
generate:

## Total spending

``` text
Total debit transactions
```

## Monthly spending

``` text
January    ₹18,420
February   ₹21,200
March      ₹19,840
April      ₹23,100
May        ₹20,500
June       ₹24,200
```

## Category spending

``` text
Food             ₹12,400
Shopping          ₹8,200
Bills             ₹6,100
Travel            ₹4,500
Entertainment     ₹2,300
```

## Category percentage

``` text
Food          37%
Shopping      24%
Bills         18%
Travel        13%
Entertainment  8%
```

## Merchant spending

``` text
Swiggy      ₹4,820
Amazon      ₹3,200
Uber        ₹2,100
Netflix       ₹649
```

------------------------------------------------------------------------

# 26. Recurring Expense Detection

The system can identify repeated transactions.

Examples:

``` text
Netflix
₹649
Every month
```

``` text
Electricity
₹1,850
Approximately every 30 days
```

Recurring expenses can improve forecasting.

This should be considered an enhancement if time is limited.

------------------------------------------------------------------------

# 27. Forecasting System

The forecasting engine receives historical categorized spending.

Input:

``` text
Month       Food
January     3200
February    3500
March       3100
April       3800
May         3600
June        3900
```

Output:

``` text
Next month forecast:
₹3,700
```

------------------------------------------------------------------------

# 28. Forecast Targets

The system should support:

### Short-term

``` text
Next 7 days
```

### Monthly

``` text
Next 30 days
```

### Category-wise

``` text
Food
Shopping
Travel
Bills
Entertainment
```

The main academic output should be:

**Expected spending for the next month.**

------------------------------------------------------------------------

# 29. Forecasting Model Strategy

Start simple.

Potential baseline:

``` text
Historical average
```

Then evaluate time-series approaches such as:

``` text
Moving Average
Exponential Smoothing
ARIMA
```

The exact model should be selected based on validation results and the
amount of historical data available.

Six months of user data is relatively limited, so the system should
avoid claiming high forecasting certainty.

A minimum-history rule should be implemented.

Example:

``` text
< 3 months:
Insufficient history

3–5 months:
Low-confidence forecast

>= 6 months:
Forecast available
```

The thresholds should be configurable.

------------------------------------------------------------------------

# 30. Forecast Output

The dashboard should display:

``` text
Next Month Forecast

Food
₹3,700

Shopping
₹2,350

Travel
₹1,450

Bills
₹2,600

Entertainment
₹900

────────────────

Expected Total
₹11,000
```

The application should clearly label these values as estimates.

------------------------------------------------------------------------

# 31. Forecast Explanation

The application should show why a forecast was generated.

Example:

``` text
Expected Food spending: ₹3,700

Based on:
• Average recent food spending
• Recent monthly trend
• Recurring food transactions
• Six months of available history
```

The explanation should be based on actual model inputs and not
fabricated.

------------------------------------------------------------------------

# 32. Dashboard

The main dashboard should contain:

``` text
ExpenseInsight

Total Spent
₹42,850

This Month
₹7,420

Predicted Next Month
₹8,150
```

Then:

``` text
Spending by Category
[Pie / Donut Chart]
```

``` text
Monthly Spending
[Line Chart]
```

``` text
Forecast
[Historical + predicted chart]
```

``` text
Top Merchants
1. Swiggy
2. Amazon
3. Uber
```

------------------------------------------------------------------------

# 33. Transaction Review Screen

Users should be able to:

-   View transactions
-   Search transactions
-   Filter by category
-   Filter by date
-   Sort by amount
-   Correct categories
-   See confidence
-   See original description
-   See normalized merchant

Example:

``` text
Swiggy

Original:
UPI/3249820192/SWIGGY/ORDER123

Normalized:
Swiggy

Amount:
₹487

Category:
Food

Confidence:
97.4%
```

------------------------------------------------------------------------

# 34. Processing Status

PDF analysis may take time.

Show:

``` text
Analyzing statement...

✓ Reading PDF
✓ Extracting transactions
✓ Cleaning transaction descriptions
✓ Normalizing merchants
✓ Categorizing transactions
● Building spending analysis
○ Generating forecast
```

------------------------------------------------------------------------

# 35. Backend Architecture

Recommended:

``` text
Flutter
   │
   ▼
REST API
   │
   ▼
FastAPI
   │
   ├── PDF Processing Service
   ├── Transaction Parser
   ├── Merchant Normalizer
   ├── NLP Service
   ├── ML Categorizer
   ├── Analytics Engine
   └── Forecasting Engine
            │
            ▼
        PostgreSQL
```

------------------------------------------------------------------------

# 36. Recommended Technology Stack

## Mobile

``` text
Flutter
Dart
```

## Backend

``` text
Python
FastAPI
```

## Data processing

``` text
Python
pandas
numpy
```

## PDF

Use a suitable PDF extraction library for text-based documents.

## OCR

Use an OCR engine for scanned statements.

## NLP / ML

``` text
scikit-learn
TF-IDF
Logistic Regression
```

Potential advanced experiments:

``` text
Sentence Transformers
XGBoost
LightGBM
```

## Forecasting

Potential options:

``` text
statsmodels
ARIMA
Exponential Smoothing
```

## Database

``` text
PostgreSQL
```

## Deployment

Potential architecture:

``` text
Flutter App
     ↓
Cloud-hosted FastAPI
     ↓
PostgreSQL
```

------------------------------------------------------------------------

# 37. API Requirements

## Authentication

``` http
POST /auth/register
POST /auth/login
GET /auth/me
```

## Statements

``` http
POST /statements/upload
GET /statements
GET /statements/{id}
GET /statements/{id}/status
```

## Transactions

``` http
GET /transactions
GET /transactions/{id}
PATCH /transactions/{id}/category
```

## Analytics

``` http
GET /analytics/summary
GET /analytics/monthly
GET /analytics/categories
GET /analytics/merchants
```

## Forecast

``` http
GET /forecast
GET /forecast/category/{category}
```

## Model

``` http
POST /model/retrain
GET /model/status
GET /model/metrics
```

------------------------------------------------------------------------

# 38. Security and Privacy

Bank statements contain highly sensitive financial information.

The system should:

-   Encrypt data in transit
-   Use authenticated API requests
-   Avoid logging raw transaction descriptions unnecessarily
-   Avoid exposing uploaded PDFs publicly
-   Restrict each user to their own transactions
-   Secure stored documents
-   Delete uploaded statements when the user requests deletion
-   Avoid storing banking passwords or credentials
-   Minimize data sent to third-party AI services

If an external LLM is used, only the minimum transaction information
necessary for categorization should be sent.

------------------------------------------------------------------------

# 39. Model Evaluation

The ML system must be evaluated quantitatively.

Dataset split:

``` text
Training: 70%
Validation: 15%
Testing: 15%
```

Metrics:

``` text
Accuracy
Precision
Recall
F1-score
Confusion Matrix
```

For imbalanced categories, macro F1-score should receive particular
attention.

------------------------------------------------------------------------

# 40. Forecast Evaluation

Forecasting should be evaluated using appropriate error metrics.

Potential metrics:

``` text
MAE
RMSE
MAPE
```

Example:

``` text
Actual:
₹10,000

Predicted:
₹9,400

Absolute error:
₹600
```

The project should compare the chosen forecasting model against a simple
baseline.

------------------------------------------------------------------------

# 41. Model Comparison Experiment

A strong academic implementation should compare approaches.

Example:

``` text
                    Accuracy    F1
TF-IDF + Logistic     87%      0.85
Embedding + LR        91%      0.90
Hybrid                93%      0.92
```

These numbers are examples only. They must NOT be claimed in the final
project until actually measured.

The final model should be selected based on experimental results.

------------------------------------------------------------------------

# 42. Handling Unseen Merchants

This is an important requirement.

Example:

``` text
Unknown merchant:
XYZ SERVICES PVT LTD
```

The system should:

1.  Normalize the description.
2.  Search known merchant aliases.
3.  Run the ML classifier.
4.  Calculate confidence.
5.  If uncertain, request user input.
6.  Store the correction.
7.  Use the correction in future predictions.

This is preferable to a rigid:

``` text
"SWIGGY" → Food
```

keyword-only system.

------------------------------------------------------------------------

# 43. Duplicate Transaction Detection

The parser should attempt to detect duplicate records caused by:

-   Overlapping statements
-   Re-uploaded PDFs
-   Duplicate pages
-   Statement generation errors

Potential duplicate key:

``` text
date
amount
normalized merchant
transaction type
reference number
```

The system should flag suspicious duplicates instead of silently
deleting them.

------------------------------------------------------------------------

# 44. Credit vs Debit Handling

Only actual expenses should normally contribute to spending analytics.

For example:

``` text
Salary credit → income
UPI payment → expense
Bank transfer received → income
Cash withdrawal → expense / cash movement
Credit card payment → potentially transfer rather than new expense
```

The MVP should explicitly distinguish:

``` text
Income
Expense
Transfer
Unknown
```

This prevents inflated spending totals.

------------------------------------------------------------------------

# 45. Credit Card Consideration

If credit-card statements are supported later, the system must avoid
double-counting.

Example:

``` text
Credit card purchase:
₹2,000 → Expense

Credit card bill payment:
₹2,000 → Transfer / Settlement
```

Both must not be counted as ₹4,000 of spending.

This should be treated as an important future enhancement.

------------------------------------------------------------------------

# 46. Error Handling

Possible failures:

### PDF cannot be read

``` text
We couldn't read this PDF.
Try uploading a text-based statement or a clearer scanned document.
```

### Transactions cannot be detected

``` text
We found the statement but could not reliably identify transactions.
```

### Category uncertain

``` text
We need your help categorizing this transaction.
```

### Forecast unavailable

``` text
Not enough historical data to generate a reliable forecast.
```

------------------------------------------------------------------------

# 47. Functional Requirements

## FR-01

The user must be able to upload a bank statement PDF.

## FR-02

The system must extract transaction records from the PDF.

## FR-03

The system must support OCR for scanned statements.

## FR-04

The system must normalize transaction descriptions.

## FR-05

The system must identify merchants where possible.

## FR-06

The system must categorize expenses automatically.

## FR-07

The system must store category confidence.

## FR-08

The system must identify low-confidence transactions.

## FR-09

The user must be able to correct a category.

## FR-10

The correction must be stored.

## FR-11

The system must generate category-wise spending analysis.

## FR-12

The system must generate monthly spending analysis.

## FR-13

The system must generate future spending predictions when enough data
exists.

## FR-14

The dashboard must display historical and predicted spending.

## FR-15

The system must distinguish income, expense, and transfers where
possible.

------------------------------------------------------------------------

# 48. Non-Functional Requirements

## Performance

A typical six-month statement should be processed within a reasonable
time depending on PDF size and OCR requirements.

## Reliability

Parsing failures must not result in silently incorrect transactions.

## Scalability

The backend should support multiple users and multiple statements.

## Security

Financial information must be protected using authenticated and
encrypted communication.

## Explainability

Users should be able to see:

-   Original description
-   Normalized merchant
-   Category
-   Confidence
-   Reason for review

------------------------------------------------------------------------

# 49. MVP Scope

The first working version should contain:

``` text
✓ Flutter application
✓ PDF upload
✓ PDF text extraction
✓ Transaction parsing
✓ Merchant normalization
✓ Transaction database
✓ TF-IDF categorization
✓ Confidence score
✓ Manual correction
✓ Spending dashboard
✓ Monthly analysis
✓ Next-month forecast
```

Do not add every advanced feature before this pipeline works.

------------------------------------------------------------------------

# 50. Phase 2

After MVP:

``` text
OCR
Multiple bank formats
Embedding-based classification
Hybrid categorization
Recurring expense detection
Better merchant matching
Income detection
Transfer detection
```

------------------------------------------------------------------------

# 51. Phase 3

Advanced features:

``` text
Personalized model
Automatic retraining
Budget recommendations
Anomaly detection
60/90-day forecasting
Natural-language financial assistant
```

These features are outside the essential scope of the initial
implementation.

------------------------------------------------------------------------

# 52. Example End-to-End Scenario

User uploads:

``` text
Jan-Jun-2026-bank-statement.pdf
```

System extracts:

``` text
1. UPI/123/SWIGGY       ₹450
2. POS/AMAZON/123       ₹1,299
3. UPI/UBER/998         ₹280
4. NEFT/ELECTRICITY     ₹1,850
5. UPI/NETFLIX          ₹649
```

Merchant normalization:

``` text
SWIGGY
AMAZON
UBER
ABC ELECTRICITY
NETFLIX
```

Categorization:

``` text
SWIGGY          → Food           97%
AMAZON          → Shopping       94%
UBER            → Travel         98%
ELECTRICITY     → Bills          99%
NETFLIX         → Entertainment  96%
```

Analytics:

``` text
Food             ₹12,400
Shopping          ₹8,200
Travel            ₹4,500
Bills             ₹6,100
Entertainment     ₹2,300
```

Forecast:

``` text
Next month expected spending:
₹11,000
```

Dashboard:

``` text
┌─────────────────────────────────┐
│ Total Spending                  │
│ ₹42,850                         │
├─────────────────────────────────┤
│ This Month                      │
│ ₹7,420                          │
├─────────────────────────────────┤
│ Forecast                        │
│ ₹8,150                          │
└─────────────────────────────────┘
```

------------------------------------------------------------------------

# 53. Recommended Project Structure

``` text
expenseinsight/
│
├── mobile/
│   └── flutter_app/
│
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── models/
│   │   ├── services/
│   │   ├── database/
│   │   └── main.py
│   │
│   └── requirements.txt
│
├── ml/
│   ├── datasets/
│   ├── preprocessing/
│   ├── categorization/
│   ├── forecasting/
│   ├── evaluation/
│   └── models/
│
├── scripts/
│   ├── train_classifier.py
│   ├── evaluate_classifier.py
│   └── evaluate_forecaster.py
│
├── docs/
│   └── PRD.md
│
└── README.md
```

------------------------------------------------------------------------

# 54. Success Criteria

The project is considered successful when a user can:

``` text
Upload a six-month bank statement
        ↓
Receive structured transactions
        ↓
See normalized merchants
        ↓
Receive automatic categories
        ↓
Review uncertain transactions
        ↓
See spending analytics
        ↓
Receive a next-month expense forecast
```

The academic implementation should additionally demonstrate measurable
ML performance and forecasting performance.

------------------------------------------------------------------------

# 55. Key Product Principle

The system should prioritize **data quality before intelligence**.

The correct order is:

``` text
Reliable PDF extraction
        ↓
Reliable transaction parsing
        ↓
Reliable merchant normalization
        ↓
Reliable categorization
        ↓
Reliable analytics
        ↓
Reliable forecasting
```

A sophisticated forecasting model cannot compensate for incorrectly
extracted transactions.

Likewise, an advanced embedding model cannot compensate for poor
transaction normalization.

Therefore, the merchant normalization and transaction parsing layers
should receive significant implementation attention.

------------------------------------------------------------------------

# 56. Final Product Vision

ExpenseInsight should ultimately feel less like a spreadsheet and more
like an automated financial intelligence system.

The user's job should be:

``` text
Upload statement
```

The application's job should be:

``` text
Read it
↓
Understand it
↓
Clean it
↓
Normalize it
↓
Categorize it
↓
Ask the user only when uncertain
↓
Learn from corrections
↓
Analyze spending
↓
Predict future expenses
↓
Explain the results
```

The central innovation is not merely displaying charts.

It is building an end-to-end pipeline that transforms unstructured
bank-statement information into structured, categorized, explainable,
and forward-looking financial insights.
