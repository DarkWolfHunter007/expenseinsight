import random
import re
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import pandas as pd
import numpy as np

# Seed for reproducibility
random.seed(42)
np.random.seed(42)

CATEGORY_TEMPLATES: Dict[str, Dict] = {
    "Food": {
        "merchants": [
            "SWIGGY", "ZOMATO", "MCDONALDS", "DOMINOS PIZZA", "KFC", "STARBUCKS", "SUBWAY", 
            "BURGER KING", "PIZZA HUT", "CHAI POINT", "CHAAYOS", "HALDIRAMS", "SARAVANAA BHAVAN",
            "BARBEQUE NATION", "WOW MOMO", "BASKIN ROBBINS", "NATURAL ICE CREAM", "THEOBROMA",
            "CAFE COFFEE DAY", "THIRD WAVE COFFEE", "BLUE TOKAI", "PUNJABI DHABA", "UDUPI RESTAURANT"
        ],
        "keywords": ["FOOD", "RESTAURANT", "CAFE", "DINE", "BAKERY", "KITCHEN", "EATERY", "SNACKS", "BIRAYNI", "PIZZA", "BURGER", "SWEETS"],
        "amount_range": (80, 2500),
        "type": "expense"
    },
    "Groceries": {
        "merchants": [
            "ZEPTO", "BIGBASKET", "BLINKIT", "DMART", "RELIANCE SMART", "SMART BAZAAR", "NATURES BASKET",
            "MORE SUPERMARKET", "SPENCERS", "JIOMART", "RATNADEEP", "LOCAL KIRANA STORE", "VEGETABLE VENDOR",
            "ORGANIC INDIA", "COUNTRY DELIGHT", "MILK BASKET"
        ],
        "keywords": ["GROCERY", "SUPERMARKET", "KIRANA", "MART", "PROVISIONS", "ORGANIC", "FRESH VEGETABLES", "FRUITS", "DAIRY MILK"],
        "amount_range": (150, 6500),
        "type": "expense"
    },
    "Shopping": {
        "merchants": [
            "AMAZON", "AMAZON SELLER", "FLIPKART", "MYNTRA", "AJIO", "NYKAA", "ZARA", "H&M", "MEESHO",
            "DECATHLON", "IKEA", "CROMA", "RELIANCE DIGITAL", "LIFESTYLE", "SHOPPERS STOP", "WESTSIDE",
            "UNIQLO", "PUMA STORE", "NIKE", "ADIDAS", "MAX FASHION", "PANTALOONS", "HAMLEYS"
        ],
        "keywords": ["SHOPPING", "RETAIL", "APPAREL", "CLOTHING", "ELECTRONICS", "FASHION", "STORE", "FOOTWEAR", "MALL", "BOUTIQUE"],
        "amount_range": (300, 25000),
        "type": "expense"
    },
    "Travel": {
        "merchants": [
            "UBER INDIA", "OLA CABS", "RAPIDO", "MAKEMYTRIP", "CLEARTRIP", "IRCTC", "INDIGO AIRLINES",
            "AIR INDIA", "REDBUS", "GOIBIBO", "EASEMYTRIP", "DMRC METRO", "BMRC METRO", "FASTAG RECHARGE",
            "AUTO RICKSHAW", "TAXI SERVICE", "PARKING FEE", "TOLL PLAZA"
        ],
        "keywords": ["CAB", "RIDE", "TRAVEL", "FLIGHT", "TICKET", "METRO", "BUS", "TRIP", "AIRWAYS", "TOLL", "FASTAG", "HOTEL BOOKING"],
        "amount_range": (40, 18000),
        "type": "expense"
    },
    "Bills": {
        "merchants": [
            "AIRTEL PREPAID", "AIRTEL BROADBAND", "JIO FIBER", "JIO RECHARGE", "VODAFONE IDEA", "BESCOM ELECTRICITY",
            "TATA POWER", "ADANI ELECTRICITY", "ACT FIBERNET", "MAHANAGAR GAS", "IGL GAS", "BWSSB WATER",
            "TATA PLAY DTH", "DISH TV", "SUN DIRECT", "MUNICIPAL CORP TAX", "PROPERTY TAX", "MAINTENANCE BILL"
        ],
        "keywords": ["BILL", "ELECTRICITY", "POWER", "BROADBAND", "INTERNET", "DTH", "WATER BILL", "GAS UTILITY", "RECHARGE", "TELECOM"],
        "amount_range": (199, 8500),
        "type": "expense"
    },
    "Entertainment": {
        "merchants": [
            "NETFLIX", "SPOTIFY", "AMAZON PRIME", "DISNEY HOTSTAR", "BOOKMYSHOW", "PVR CINEMAS", "INOX LEISURE",
            "YOUTUBE PREMIUM", "SONYLIV", "ZEE5", "APPLE SERVICES", "PLAYSTATION NETWORK", "STEAM GAMES",
            "CINEPOLIS", "SMASH GAMING", "CONCERT PASS", "STANDUP COMEDY"
        ],
        "keywords": ["CINEMA", "MOVIES", "THEATRE", "SUBSCRIPTION", "STREAMING", "MUSIC", "GAMES", "ENTERTAINMENT", "SHOW TICKETS"],
        "amount_range": (149, 3500),
        "type": "expense"
    },
    "Healthcare": {
        "merchants": [
            "APOLLO PHARMACY", "TATA 1MG", "PHARMEASY", "PRACTO", "MEDPLUS", "DR LAL PATHLABS", "METROPOLIS",
            "FORTIS HOSPITAL", "MANIPAL HOSPITAL", "MAX HEALTHCARE", "CLINIC CONSULTATION", "DENTAL CARE", "EYE CLINIC"
        ],
        "keywords": ["PHARMACY", "MEDICINE", "HOSPITAL", "CLINIC", "DIAGNOSTICS", "LAB TEST", "HEALTHCARE", "DOCTOR", "SURGERY"],
        "amount_range": (120, 15000),
        "type": "expense"
    },
    "Fuel": {
        "merchants": [
            "INDIAN OIL", "HPCL PETROL", "BPCL FUEL", "SHELL PETROL PUMP", "RELIANCE PETROLEUM", "CNG STATION",
            "AUTO GAS", "HP AUTO CARE", "SPEED PETROL", "XTRAPOWER IOCL"
        ],
        "keywords": ["PETROL", "DIESEL", "FUEL", "GAS STATION", "PETROL PUMP", "IOCL", "BPCL", "HPCL", "CNG"],
        "amount_range": (200, 6000),
        "type": "expense"
    },
    "Rent": {
        "merchants": [
            "NOBROKER RENT", "MYGATE MAINTENANCE", "HOUSE OWNER RENT", "FLAT RENT", "RENTOMOJO", "NESTAWAY",
            "SOCIETY MAINTENANCE", "PG ACCOMMODATION"
        ],
        "keywords": ["RENT", "HOUSE RENT", "MAINTENANCE", "PG RENT", "LANDLORD", "SECURITY DEPOSIT", "FLAT MAINTENANCE"],
        "amount_range": (5000, 65000),
        "type": "expense"
    },
    "Personal Care": {
        "merchants": [
            "URBAN COMPANY", "NATURALS SALON", "LOREAL SALON", "TONI & GUY", "VLCC", "KAYA SKIN CLINIC",
            "GYM MEMBERSHIP", "CULT FIT", "FITNESS FIRST", "SPA TREATMENT"
        ],
        "keywords": ["SALON", "SPA", "HAIRCUT", "BEAUTY", "GROOMING", "FITNESS", "GYM", "PERSONAL CARE", "WORKOUT"],
        "amount_range": (250, 7500),
        "type": "expense"
    },
    "Education": {
        "merchants": [
            "COURSERA", "UDEMY", "UPGRAD", "SCALER ACADEMY", "UNACADEMY", "BYJUS", "SCHOOL FEES",
            "COLLEGE TUITION", "BOOK STORE", "KINDLE BOOKS", "EDX", "CAMPUS FEE"
        ],
        "keywords": ["COURSE", "EDUCATION", "FEES", "TUITION", "ACADEMY", "LEARNING", "BOOKS", "SCHOOL", "COLLEGE", "EXAM FEE"],
        "amount_range": (499, 45000),
        "type": "expense"
    },
    "Insurance": {
        "merchants": [
            "LIC INDIA", "HDFC ERGO", "ICICI LOMBARD", "STAR HEALTH INSURANCE", "POLICYBAZAAR", "ACKO INSURANCE",
            "MAX LIFE INSURANCE", "TATA AIG", "CARE HEALTH INSURANCE"
        ],
        "keywords": ["INSURANCE", "PREMIUM", "LIFE INSURANCE", "HEALTH INSURANCE", "VEHICLE INSURANCE", "POLICY PREMIUM"],
        "amount_range": (1500, 35000),
        "type": "expense"
    },
    "Investments": {
        "merchants": [
            "ZERODHA BROKING", "GROWW INVEST", "UPSTOX", "ANGEL ONE", "CAMS MUTUAL FUND", "KFINTECH",
            "NATIONAL PENSION SYSTEM", "GOLD INVEST", "SMALLCASE", "INDMONEY"
        ],
        "keywords": ["INVESTMENT", "MUTUAL FUND", "BROKING", "STOCKS", "SIP", "EQUITY", "DEPOSIT", "NPS", "SHARES"],
        "amount_range": (1000, 75000),
        "type": "transfer"
    },
    "Income": {
        "merchants": [
            "INFOSYS SALARY", "TCS SALARY", "WIPRO PAYROLL", "ACCENTURE SALARY", "GOOGLE INDIA SALARY",
            "MICROSOFT SALARY", "SALARY CREDIT FOR MONTH", "INTEREST CREDIT SB", "FIXED DEPOSIT INTEREST",
            "DIVIDEND CREDIT NEFT", "FREELANCE PAYMENT", "CLIENT REMITTANCE"
        ],
        "keywords": ["SALARY", "PAYROLL", "INTEREST CREDIT", "DIVIDEND", "STIPEND", "BONUS", "REFUND CREDIT", "CASHBACK CREDIT"],
        "amount_range": (5000, 350000),
        "type": "income"
    },
    "Transfers": {
        "merchants": [
            "TRANSFER TO SELF", "TPT TO SISTER", "FUND TRANSFER FRIEND", "SENT MONEY TO BROTHER",
            "UPI TRANSFER TO PARENTS", "NEFT TRANSFER FAMILY", "GPAY TO ROOMMATE", "PHONEPE SETTLEMENT"
        ],
        "keywords": ["TRANSFER", "SELF TRANSFER", "SENT MONEY", "UPI TO", "P2P TRANSFER", "FAMILY SUPPORT"],
        "amount_range": (200, 40000),
        "type": "transfer"
    },
    "Cash Withdrawal": {
        "merchants": [
            "ATM CASH WDL", "NFS ATM WITHDRAWAL", "HDFC ATM WDL", "SBI ATM CASH", "ICICI ATM WDL", "AXIS ATM WDL"
        ],
        "keywords": ["ATM WDL", "CASH WITHDRAWAL", "ATM CASH", "NFS WDL", "SELF WDL"],
        "amount_range": (500, 20000),
        "type": "transfer"
    }
}

UPI_HANDLES = ["@okaxis", "@okhdfcbank", "@okicici", "@oksbi", "@paytm", "@ybl", "@axl", "@ibl", "@ptaxis", "@upi"]
BANKS = ["HDFC Bank", "State Bank of India", "ICICI Bank", "Axis Bank", "Kotak Mahindra Bank"]

def generate_noisy_description(merchant: str, keyword: str, channel: str) -> str:
    """Generates realistic noisy bank statement strings."""
    ref_no = random.randint(100000000000, 999999999999)
    upi_ref = random.randint(100000, 999999)
    handle = random.choice(UPI_HANDLES)
    merchant_slug = merchant.replace(" ", "").lower()

    if channel == "UPI":
        templates = [
            f"UPI/{ref_no}/{merchant}/paytm",
            f"UPI/{merchant}/{upi_ref}/{merchant_slug}{handle}",
            f"UPI-P2M-{ref_no}-{merchant}-RAZORPAY",
            f"UPI/P2M/{ref_no}/{merchant}/{merchant_slug}{handle}/Payment",
            f"UPI-{merchant}-{ref_no}@{merchant_slug}",
            f"UPI/DR/{ref_no}/{merchant}/NA/Payment for order",
            f"UPI/{upi_ref}/{merchant}/BILLDESK/{ref_no}"
        ]
        return random.choice(templates)
    elif channel == "POS":
        templates = [
            f"POS {random.randint(10000, 99999)} {merchant} BANGALORE IN",
            f"POS/{merchant}/{random.randint(1000, 9999)}/MUMBAI",
            f"POS 00{random.randint(1000, 9999)} {merchant} DELHI",
            f"POS DEBIT - {merchant} HYDERABAD",
            f"POS/ECOM/{merchant}/{ref_no}"
        ]
        return random.choice(templates)
    elif channel == "NEFT":
        templates = [
            f"NEFT/{ref_no}/{merchant}/NET BANKING",
            f"NEFT-N{ref_no}-{merchant}-PAYMENT",
            f"NEFT/BIL/{ref_no}/{merchant} LTD",
            f"NEFT CR-{merchant}-{ref_no}"
        ]
        return random.choice(templates)
    elif channel == "IMPS":
        templates = [
            f"IMPS/{ref_no}/{merchant}/{random.randint(1000, 9999)}",
            f"IMPS-P2A-{ref_no}-{merchant}-BILL",
            f"IMPS/P2M/{ref_no}/{merchant}"
        ]
        return random.choice(templates)
    elif channel == "ACH":
        templates = [
            f"ACH/DR/{merchant}/{ref_no}",
            f"ACH/{merchant}/MTHLY/000{random.randint(100, 999)}",
            f"NACH/DR/{merchant}/MANDATE/{ref_no}"
        ]
        return random.choice(templates)
    else:
        # Direct clean or lightly prefixed
        return f"{channel}/{merchant}/{ref_no}"


def generate_synthetic_transactions(num_records: int = 8000, start_date: datetime = None) -> pd.DataFrame:
    """Generates synthetic labeled transactions dataframe."""
    if start_date is None:
        start_date = datetime(2026, 1, 1)

    records = []
    channels = ["UPI", "UPI", "UPI", "POS", "POS", "NEFT", "IMPS", "ACH", "BIL", "ECOM"]
    categories = list(CATEGORY_TEMPLATES.keys())
    
    # Weight probabilities roughly reflecting real-world distribution
    category_weights = [
        0.22,  # Food
        0.14,  # Groceries
        0.13,  # Shopping
        0.11,  # Travel
        0.09,  # Bills
        0.06,  # Entertainment
        0.04,  # Healthcare
        0.05,  # Fuel
        0.02,  # Rent
        0.03,  # Personal Care
        0.02,  # Education
        0.02,  # Insurance
        0.03,  # Investments
        0.02,  # Income
        0.015, # Transfers
        0.005  # Cash Withdrawal
    ]

    running_balance = 75000.0

    for i in range(num_records):
        cat = random.choices(categories, weights=category_weights, k=1)[0]
        cat_data = CATEGORY_TEMPLATES[cat]
        merchant = random.choice(cat_data["merchants"])
        keyword = random.choice(cat_data["keywords"])
        channel = random.choice(channels)
        
        # Determine transaction type
        txn_type = cat_data["type"]
        is_income = (txn_type == "income")
        
        # Calculate amount with realistic noise
        min_amt, max_amt = cat_data["amount_range"]
        amount = round(random.uniform(min_amt, max_amt), 2)
        
        # Date within a 180 day period (6 months)
        days_offset = random.randint(0, 180)
        txn_date = (start_date + timedelta(days=days_offset)).strftime("%Y-%m-%d")
        
        raw_desc = generate_noisy_description(merchant, keyword, channel)
        
        if is_income:
            running_balance += amount
            cr_dr = "CR"
        else:
            running_balance -= amount
            if running_balance < 1000:
                running_balance = 50000.0  # replenish
            cr_dr = "DR"

        records.append({
            "id": f"txn_{i+1:06d}",
            "date": txn_date,
            "raw_description": raw_desc,
            "merchant_ground_truth": merchant.title(),
            "category": cat,
            "amount": amount,
            "transaction_type": txn_type,
            "cr_dr": cr_dr,
            "balance": round(running_balance, 2),
            "bank": random.choice(BANKS)
        })

    df = pd.DataFrame(records)
    # Sort chronologically
    df["date_dt"] = pd.to_datetime(df["date"])
    df = df.sort_values(by="date_dt").reset_index(drop=True)
    df = df.drop(columns=["date_dt"])
    return df


def split_dataset(df: pd.DataFrame, train_ratio=0.70, val_ratio=0.15, test_ratio=0.15) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Splits into train (70%), validation (15%), test (15%) stratified by category."""
    from sklearn.model_selection import train_test_split

    train_val, test = train_test_split(df, test_size=test_ratio, random_state=42, stratify=df["category"])
    val_adjusted_ratio = val_ratio / (train_ratio + val_ratio)
    train, val = train_test_split(train_val, test_size=val_adjusted_ratio, random_state=42, stratify=train_val["category"])
    
    return train.reset_index(drop=True), val.reset_index(drop=True), test.reset_index(drop=True)


if __name__ == "__main__":
    df = generate_synthetic_transactions(8000)
    train, val, test = split_dataset(df)
    print(f"Generated {len(df)} transactions.")
    print(f"Train: {len(train)}, Val: {len(val)}, Test: {len(test)}")
    print("Category distribution in Train:")
    print(train["category"].value_counts())
