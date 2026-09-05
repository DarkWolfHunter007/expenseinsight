import re
from typing import Dict, List, Optional, Tuple
from rapidfuzz import fuzz, process
from .text_cleaner import TextCleaner

# Canonical Merchant Knowledge Base:
# Format: canonical_name: { "aliases": [...], "default_category": "food", "type": "expense" }
DEFAULT_MERCHANT_KB = {
    # Food & Dining
    "Swiggy": {
        "aliases": ["swiggy", "swiggy india", "swiggy instamart", "swiggy order", "bundl technologies", "swiggy dineout", "swiggy gourmet"],
        "default_category": "Food",
        "type": "expense"
    },
    "Zomato": {
        "aliases": ["zomato", "zomato media", "zomato limited", "zomato gold", "zomato order", "zomato feeding", "blinkit", "grofers"],
        "default_category": "Food",
        "type": "expense"
    },
    "McDonald's": {
        "aliases": ["mcdonalds", "mcdonald", "hardcastle restaurants", "mcd delivery", "mcdonald s"],
        "default_category": "Food",
        "type": "expense"
    },
    "Dominos": {
        "aliases": ["dominos", "dominos pizza", "jubilant foodworks", "domino", "jubilant food"],
        "default_category": "Food",
        "type": "expense"
    },
    "KFC": {
        "aliases": ["kfc", "kentucky fried chicken", "devyani international", "sapphire foods", "kfc india"],
        "default_category": "Food",
        "type": "expense"
    },
    "Starbucks": {
        "aliases": ["starbucks", "tata starbucks", "starbucks coffee"],
        "default_category": "Food",
        "type": "expense"
    },
    "Subway": {
        "aliases": ["subway", "subway sandwich", "subway club"],
        "default_category": "Food",
        "type": "expense"
    },
    "Burger King": {
        "aliases": ["burger king", "restaurant brands asia", "burger king india"],
        "default_category": "Food",
        "type": "expense"
    },
    "Pizza Hut": {
        "aliases": ["pizza hut", "yum brands", "pizza hut delivery"],
        "default_category": "Food",
        "type": "expense"
    },
    "Chai Point": {
        "aliases": ["chai point", "mountain trail foods"],
        "default_category": "Food",
        "type": "expense"
    },
    "Chaayos": {
        "aliases": ["chaayos", "sunshine teahouse"],
        "default_category": "Food",
        "type": "expense"
    },

    # Groceries
    "Zepto": {
        "aliases": ["zepto", "kiranakart", "zepto delivery"],
        "default_category": "Groceries",
        "type": "expense"
    },
    "BigBasket": {
        "aliases": ["bigbasket", "supermarket grocery supplies", "innovative retail", "bbnow", "bb daily"],
        "default_category": "Groceries",
        "type": "expense"
    },
    "D-Mart": {
        "aliases": ["dmart", "d mart", "avenue supermarts", "dmart ready"],
        "default_category": "Groceries",
        "type": "expense"
    },
    "Reliance Fresh": {
        "aliases": ["reliance fresh", "reliance retail", "reliance smart", "smart bazaar", "jiomart"],
        "default_category": "Groceries",
        "type": "expense"
    },
    "Nature's Basket": {
        "aliases": ["natures basket", "godrej natures basket"],
        "default_category": "Groceries",
        "type": "expense"
    },

    # Shopping & E-Commerce
    "Amazon": {
        "aliases": ["amazon", "amazon seller", "amazon in", "amazon pay", "amazon cloud", "amzn", "amzn mktp"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Flipkart": {
        "aliases": ["flipkart", "flipkart internet", "flipkart payments", "fkmp", "flipkart plus"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Myntra": {
        "aliases": ["myntra", "myntra designs", "myntra fashion"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Ajio": {
        "aliases": ["ajio", "reliance ajio", "ajio fashion"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Nykaa": {
        "aliases": ["nykaa", "fsn e commerce", "nykaa man", "nykaa fashion"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Zara": {
        "aliases": ["zara", "inditex", "zara fashion"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "H&M": {
        "aliases": ["h&m", "h and m", "hennes mauritz"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Meesho": {
        "aliases": ["meesho", "fashnear technologies"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Decathlon": {
        "aliases": ["decathlon", "decathlon sports", "decathlon india"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "IKEA": {
        "aliases": ["ikea", "ikea india", "ingka"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Croma": {
        "aliases": ["croma", "infiniti retail", "croma electronics"],
        "default_category": "Shopping",
        "type": "expense"
    },
    "Reliance Digital": {
        "aliases": ["reliance digital", "resq"],
        "default_category": "Shopping",
        "type": "expense"
    },

    # Travel & Commute
    "Uber": {
        "aliases": ["uber", "uber india", "uber bv", "uber trip", "uber rides", "uber eats"],
        "default_category": "Travel",
        "type": "expense"
    },
    "Ola": {
        "aliases": ["ola", "ola cabs", "ani technologies", "ola money", "ola ride"],
        "default_category": "Travel",
        "type": "expense"
    },
    "Rapido": {
        "aliases": ["rapido", "roppen transportation", "rapido bike"],
        "default_category": "Travel",
        "type": "expense"
    },
    "MakeMyTrip": {
        "aliases": ["makemytrip", "mmt", "makemytrip india"],
        "default_category": "Travel",
        "type": "expense"
    },
    "Cleartrip": {
        "aliases": ["cleartrip", "cleartrip pvt ltd"],
        "default_category": "Travel",
        "type": "expense"
    },
    "IRCTC": {
        "aliases": ["irctc", "indian railway", "irctc ticketing", "cris", "irctc app"],
        "default_category": "Travel",
        "type": "expense"
    },
    "IndiGo": {
        "aliases": ["indigo", "interglobe aviation", "indigo airlines", "goindigo"],
        "default_category": "Travel",
        "type": "expense"
    },
    "Air India": {
        "aliases": ["air india", "tata air india"],
        "default_category": "Travel",
        "type": "expense"
    },
    "RedBus": {
        "aliases": ["redbus", "ibibo group redbus", "redbus ticketing"],
        "default_category": "Travel",
        "type": "expense"
    },
    "Metro Rail": {
        "aliases": ["dmrc", "bmrc", "delhi metro", "bangalore metro", "mumbai metro", "metro recharge"],
        "default_category": "Travel",
        "type": "expense"
    },

    # Utilities & Bills
    "Airtel": {
        "aliases": ["airtel", "bharti airtel", "airtel dth", "airtel broadband", "airtel payment bank"],
        "default_category": "Bills",
        "type": "expense"
    },
    "Jio": {
        "aliases": ["jio", "reliance jio", "jio fiber", "jio recharge", "jio infocomm"],
        "default_category": "Bills",
        "type": "expense"
    },
    "Vodafone Idea": {
        "aliases": ["vi", "vodafone", "idea cellular", "vodafone idea"],
        "default_category": "Bills",
        "type": "expense"
    },
    "BESCOM": {
        "aliases": ["bescom", "bangalore electricity", "bescom online"],
        "default_category": "Bills",
        "type": "expense"
    },
    "Tata Power": {
        "aliases": ["tata power", "tata electricity"],
        "default_category": "Bills",
        "type": "expense"
    },
    "Adani Electricity": {
        "aliases": ["adani electricity", "adani energy"],
        "default_category": "Bills",
        "type": "expense"
    },
    "ACT Fibernet": {
        "aliases": ["act fibernet", "atria convergence technologies", "act broadband"],
        "default_category": "Bills",
        "type": "expense"
    },
    "Mahanagar Gas": {
        "aliases": ["mahanagar gas", "mgl gas", "igl gas", "indrapraprastha gas"],
        "default_category": "Bills",
        "type": "expense"
    },
    "BWSSB": {
        "aliases": ["bwssb", "water board", "bangalore water"],
        "default_category": "Bills",
        "type": "expense"
    },

    # Entertainment & Media
    "Netflix": {
        "aliases": ["netflix", "netflix entertainment", "netflix com"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "Spotify": {
        "aliases": ["spotify", "spotify india", "spotify ab", "spotify premium"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "Amazon Prime": {
        "aliases": ["amazon prime", "prime video", "prime member"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "Disney+ Hotstar": {
        "aliases": ["hotstar", "disney hotstar", "disney plus hotstar", "novi digital"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "BookMyShow": {
        "aliases": ["bookmyshow", "bigtree entertainment", "bms ticket"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "PVR INOX": {
        "aliases": ["pvr", "pvr cinemas", "inox", "inox leisure", "pvr inox"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "YouTube Premium": {
        "aliases": ["youtube premium", "google youtube", "yt premium"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "SonyLIV": {
        "aliases": ["sonyliv", "sony pictures networks", "culver max"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "Zee5": {
        "aliases": ["zee5", "zee entertainment"],
        "default_category": "Entertainment",
        "type": "expense"
    },
    "Apple Services": {
        "aliases": ["apple com bill", "apple media", "itunes", "icloud", "apple music"],
        "default_category": "Entertainment",
        "type": "expense"
    },

    # Healthcare & Pharmacy
    "Apollo Pharmacy": {
        "aliases": ["apollo pharmacy", "apollo hospitals", "apollo 247", "apollo health"],
        "default_category": "Healthcare",
        "type": "expense"
    },
    "Tata 1mg": {
        "aliases": ["1mg", "tata 1mg", "1mg technologies"],
        "default_category": "Healthcare",
        "type": "expense"
    },
    "PharmEasy": {
        "aliases": ["pharmeasy", "api holdings", "pharmeasy medicines"],
        "default_category": "Healthcare",
        "type": "expense"
    },
    "Practo": {
        "aliases": ["practo", "practo technologies", "practo care"],
        "default_category": "Healthcare",
        "type": "expense"
    },
    "MedPlus": {
        "aliases": ["medplus", "medplus pharmacy", "optival health"],
        "default_category": "Healthcare",
        "type": "expense"
    },
    "Dr Lal PathLabs": {
        "aliases": ["dr lal pathlabs", "lal pathlabs", "lal path"],
        "default_category": "Healthcare",
        "type": "expense"
    },

    # Fuel
    "Indian Oil": {
        "aliases": ["ioc", "indian oil", "iocl", "indian oil corp"],
        "default_category": "Fuel",
        "type": "expense"
    },
    "HPCL": {
        "aliases": ["hpcl", "hindustan petroleum", "hp petrol", "hp auto care"],
        "default_category": "Fuel",
        "type": "expense"
    },
    "BPCL": {
        "aliases": ["bpcl", "bharat petroleum", "speed petrol"],
        "default_category": "Fuel",
        "type": "expense"
    },
    "Shell": {
        "aliases": ["shell", "shell petrol", "shell india"],
        "default_category": "Fuel",
        "type": "expense"
    },

    # Rent & Housing
    "NoBroker": {
        "aliases": ["nobroker", "nobroker technologies", "nobroker rent", "nobroker pay"],
        "default_category": "Rent",
        "type": "expense"
    },
    "MyGate": {
        "aliases": ["mygate", "vivish technologies", "mygate maintenance"],
        "default_category": "Rent",
        "type": "expense"
    },
    "House Rent": {
        "aliases": ["house rent", "owner rent", "flat rent", "monthly rent", "landlord rent"],
        "default_category": "Rent",
        "type": "expense"
    },

    # Investments & Trading
    "Zerodha": {
        "aliases": ["zerodha", "zerodha broking", "rainmatter"],
        "default_category": "Investments",
        "type": "transfer"
    },
    "Groww": {
        "aliases": ["groww", "nextbillion technology", "groww invest"],
        "default_category": "Investments",
        "type": "transfer"
    },
    "Upstox": {
        "aliases": ["upstox", "rksv securities"],
        "default_category": "Investments",
        "type": "transfer"
    },
    "Mutual Fund": {
        "aliases": ["cams", "kfintech", "uti mutual fund", "hdfc mutual fund", "sbi mutual fund", "icici prudential mutual fund", "nippon mutual fund"],
        "default_category": "Investments",
        "type": "transfer"
    },

    # Income Keywords / Senders
    "Salary": {
        "aliases": ["salary credit", "sal credit", "monthly salary", "payroll", "infosys salary", "tcs salary", "wipro salary", "accenture salary", "google salary", "microsoft salary", "amazon salary"],
        "default_category": "Income",
        "type": "income"
    },
    "Interest Earned": {
        "aliases": ["interest credit", "sb interest", "savings interest", "fd interest", "interest paid"],
        "default_category": "Income",
        "type": "income"
    },
    "Dividend": {
        "aliases": ["dividend credit", "ach dividend", "neft dividend"],
        "default_category": "Income",
        "type": "income"
    },

    # Cash & Transfers
    "Cash Withdrawal": {
        "aliases": ["atm wdl", "atm withdrawal", "nfs wdl", "cash wdl", "atm cash", "self withdrawal"],
        "default_category": "Cash Withdrawal",
        "type": "transfer"
    },
    "Self Transfer": {
        "aliases": ["fund transfer to self", "self transfer", "transfer to own account", "tpt self", "inter account transfer"],
        "default_category": "Transfers",
        "type": "transfer"
    }
}


class MerchantNormalizer:
    """
    Multi-layer merchant normalization engine conforming to PRD Sections 12-14.
    """

    def __init__(self, custom_corrections: Optional[Dict[str, str]] = None):
        self.text_cleaner = TextCleaner()
        self.kb = DEFAULT_MERCHANT_KB
        self.custom_corrections = custom_corrections or {}

        # Build reverse lookup index for fast exact matching
        self._alias_to_canonical: Dict[str, str] = {}
        self._all_aliases: List[str] = []

        for canonical, data in self.kb.items():
            for alias in data["aliases"]:
                alias_clean = self.text_cleaner.clean(alias)
                if alias_clean:
                    self._alias_to_canonical[alias_clean] = canonical
                    self._all_aliases.append(alias_clean)

    def add_user_correction(self, raw_or_cleaned_merchant: str, canonical_name: str, category: Optional[str] = None):
        """Layer 4: Persistent user feedback correction."""
        clean_key = self.text_cleaner.clean(raw_or_or_str := raw_or_cleaned_merchant)
        if clean_key:
            self.custom_corrections[clean_key] = canonical_name
            self._alias_to_canonical[clean_key] = canonical_name
            if clean_key not in self._all_aliases:
                self._all_aliases.append(clean_key)

    def normalize(self, raw_description: str) -> Tuple[str, str, Optional[str], float]:
        """
        Normalizes raw transaction description.
        Returns:
            (display_merchant, normalized_merchant_key, default_category, match_confidence)
        """
        if not raw_description:
            return ("Unknown Merchant", "unknown", None, 0.0)

        cleaned_text = self.text_cleaner.clean(raw_description)
        if not cleaned_text:
            return ("Unknown Merchant", "unknown", None, 0.0)

        # Layer 4: Check user corrections first
        if cleaned_text in self.custom_corrections:
            canonical = self.custom_corrections[cleaned_text]
            default_cat = self.kb.get(canonical, {}).get("default_category")
            return (canonical, canonical.lower().replace(" ", "_"), default_cat, 1.0)

        # Layer 2: Exact Substring / Alias Matching
        # Check if entire cleaned string matches an alias
        if cleaned_text in self._alias_to_canonical:
            canonical = self._alias_to_canonical[cleaned_text]
            default_cat = self.kb.get(canonical, {}).get("default_category")
            return (canonical, canonical.lower().replace(" ", "_"), default_cat, 0.98)

        # Check if any known alias exists as a standalone token or substring inside the cleaned text
        for alias, canonical in self._alias_to_canonical.items():
            # Check for word boundary substring match
            if re.search(r'\b' + re.escape(alias) + r'\b', cleaned_text):
                default_cat = self.kb.get(canonical, {}).get("default_category")
                return (canonical, canonical.lower().replace(" ", "_"), default_cat, 0.95)

        # Layer 3: Fuzzy similarity matching using RapidFuzz
        if self._all_aliases:
            best_match = process.extractOne(
                cleaned_text,
                self._all_aliases,
                scorer=fuzz.token_set_ratio,
                score_cutoff=75.0
            )
            if best_match:
                matched_alias, score, _ = best_match
                canonical = self._alias_to_canonical[matched_alias]
                default_cat = self.kb.get(canonical, {}).get("default_category")
                confidence = round(score / 100.0, 2)
                if confidence >= 0.85:
                    return (canonical, canonical.lower().replace(" ", "_"), default_cat, confidence)
                elif confidence >= 0.70:
                    return (canonical, canonical.lower().replace(" ", "_"), default_cat, confidence * 0.9)

        # Layer 1 Fallback: Format cleaned tokens nicely as merchant name
        tokens = cleaned_text.split()
        if tokens:
            # Pick first 1-3 prominent words
            clean_name = " ".join(tokens[:3]).title()
            norm_key = "_".join(tokens[:3])
            return (clean_name, norm_key, None, 0.40)

        return ("Unknown Merchant", "unknown", None, 0.0)
