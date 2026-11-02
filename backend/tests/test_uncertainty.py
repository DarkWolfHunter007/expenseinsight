import pytest

from backend.ml.categorization.hybrid_categorizer import HybridCategorizer
from backend.ml.preprocessing.merchant_normalizer import MerchantNormalizer

UPI_TAIL = "/YESB/**X1@YBL/UPI//AXI3A7AF781"


class OverconfidentTransferModel:
    """Stand-in for the trained model, which calls every unfamiliar UPI payee a transfer at ~99%."""
    is_fitted = True

    def predict_single(self, raw_description, normalizer):
        return "Transfers", 0.99, {"Transfers": 0.99}


@pytest.fixture(scope="module")
def categorizer():
    return HybridCategorizer(classifier=OverconfidentTransferModel(), normalizer=MerchantNormalizer())


def _upi(payee):
    return f"UPI/DR/611111111111/{payee}{UPI_TAIL}"


# ---------- names broken by a mid-word wrap or cut at 9 characters ----------

@pytest.mark.parametrize("raw,key", [
    ("UPI/DR/102156053610/FLIPKAR T /HDFC/**.PAYU@HDFCBANK/U PI TRAN//HDFC4BFC", "flipkart"),
    (_upi("SWIGGY IN"), "swiggy"),
    (_upi("ZOMATO LI"), "zomato"),
])
def test_wrapped_or_cut_payee_names_still_match_the_known_merchant(raw, key):
    _, normalized, category, confidence = MerchantNormalizer().normalize(raw)
    assert normalized == key
    assert category is not None
    assert confidence >= 0.88


def test_a_person_name_does_not_match_a_merchant_by_accident():
    for name in ("CHITRA SUN", "ASHOK MEN", "BINDU NAI", "ELSA GEORG"):
        _, _, category, confidence = MerchantNormalizer().normalize(_upi(name))
        assert category is None or confidence < 0.88, name


# ---------- an unfamiliar payee that is not a person goes to review ----------

@pytest.mark.parametrize("payee", [
    "RAHUL SHARM", "ABHIN AN", "CHITRA SUN", "PAYAL K", "KANNAN S99", "GAYATV PM@", "ELSA GEORG",
])
def test_person_like_payees_stay_transfers(categorizer, payee):
    result = categorizer.categorize_transaction(_upi(payee), 500.0, "expense")
    assert result["category"] == "Transfers"
    assert result["needs_review"] is False


@pytest.mark.parametrize("payee", [
    "NEW CITY BAKE", "SREE MEDICAL", "KANNAN FUEL", "HOTEL SAGAR", "SREE CHIT",
    "ICGAIFE 3", "PC BOOK H", "GOOGLE CL",
])
def test_business_like_payees_are_not_trusted_as_transfers(categorizer, payee):
    result = categorizer.categorize_transaction(_upi(payee), 500.0, "expense")
    assert result["needs_review"] is True
    assert result["category"] == "Uncategorized"
    assert result["confidence"] < 0.60


def test_non_upi_descriptions_are_left_to_the_model(categorizer):
    result = categorizer.categorize_transaction("NEFT CR-CNRB1234567890-SOME ONE", 500.0, "expense")
    assert result["category"] == "Transfers"
    assert result["needs_review"] is False


def test_known_merchants_never_reach_the_model(categorizer):
    result = categorizer.categorize_transaction(_upi("SWIGGY IN"), 300.0, "expense")
    assert result["category"] == "Food"
    assert result["source"] == "merchant_kb"
