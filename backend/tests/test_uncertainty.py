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


@pytest.mark.parametrize("payee,category", [
    ("NEW CITY BAKE", "Food"),
    ("ASOK BAKE", "Food"),
    ("HOTEL SAGAR", "Food"),
    ("BARBEC UE", "Food"),            # the PDF wrapped the word in the middle
    ("SREE MEDICAL", "Healthcare"),
    ("KANNAN FUEL", "Fuel"),
    ("ANN FUELS", "Fuel"),            # plural
    ("PC BOOK H", "Shopping"),
    ("SMB FASHION TEXTILE", "Shopping"),
    ("PET MATTE", "Shopping"),
])
def test_a_clear_business_word_names_the_category(categorizer, payee, category):
    result = categorizer.categorize_transaction(_upi(payee), 500.0, "expense")
    assert result["category"] == category
    assert result["source"] == "payee_keyword"
    assert result["needs_review"] is False


@pytest.mark.parametrize("payee", ["SREE CHIT", "ICGAIFE 3", "GOOGLE CL"])
def test_business_like_payees_without_a_category_go_to_review(categorizer, payee):
    result = categorizer.categorize_transaction(_upi(payee), 500.0, "expense")
    assert result["needs_review"] is True
    assert result["category"] == "Uncategorized"
    assert result["confidence"] < 0.60


def test_ms_prefix_means_a_business():
    cat = HybridCategorizer(classifier=OverconfidentTransferModel(), normalizer=MerchantNormalizer())
    result = cat.categorize_transaction("UPI/DR/624001/M/S.SOU TH/ICIC/**1@ICICI/PAID VIA", 1365.0, "expense")
    assert result["needs_review"] is True


@pytest.mark.parametrize("tail", ["**89611@SBIPAY/ST ATICQR", "**STATICQR.ROYAL@YBL", "**DQR01@YBL", "**16072@OKBIZAXIS", "**.RZP@RXAIRTEL"])
def test_business_payment_handles_are_a_business_signal(categorizer, tail):
    raw = f"UPI/DR/611111111111/ROYAL STR/UTIB/{tail}/PAID VIA"
    result = categorizer.categorize_transaction(raw, 72.0, "expense")
    assert result["needs_review"] is True


def test_non_upi_descriptions_are_left_to_the_model(categorizer):
    result = categorizer.categorize_transaction("NEFT CR-CNRB1234567890-SOME ONE", 500.0, "expense")
    assert result["category"] == "Transfers"
    assert result["needs_review"] is False


def test_known_merchants_never_reach_the_model(categorizer):
    result = categorizer.categorize_transaction(_upi("SWIGGY IN"), 300.0, "expense")
    assert result["category"] == "Food"
    assert result["source"] == "merchant_kb"


# ---------- merchant matching only looks at the payee ----------

def test_a_stray_vi_in_the_reference_hash_is_not_vodafone_idea():
    raw = "UPI/CR/623203359632/LEKSHM Y S/CNRB/**07775@SUPERYES/ PAID VIA//SMY24072706184KXQ6TD VI18V96YN3PUUOD"
    _, key, category, _ = MerchantNormalizer().normalize(raw)
    assert key == "lekshm_y_s"
    assert category is None


def test_a_shop_address_is_not_matched_against_merchant_names():
    raw = "UPI/DR/661296549375/MARGIN FR/UTIB/**16072@OKBIZAXIS/P AID VIA//SMY2412171555NRLIPZCU NRUPATUNGA ROAD BANGALORE"
    _, key, category, _ = MerchantNormalizer().normalize(raw)
    assert key != "metro_rail"
    assert category is None


def test_a_short_alias_does_not_fuzzy_match_an_unrelated_payee():
    raw = "UPI/DR/661181493370/MALABA R B/YESB/**98885@YBL/PAID VIA"
    _, key, _, _ = MerchantNormalizer().normalize(raw)
    assert key != "h&m"


def test_the_same_person_paid_from_two_banks_is_one_merchant():
    n = MerchantNormalizer()
    first = n.normalize("UPI/DR/1/GOKUL KRI/CNRB/**1@OKSBI/UPI")[1]
    second = n.normalize("UPI/DR/2/GOKUL KRI/UTIB/**2@OKAXIS/UPI")[1]
    assert first == second == "gokul_kri"


def test_the_bank_code_is_not_part_of_the_merchant_name():
    assert MerchantNormalizer().normalize("UPI/DR/3/ANN FUELS/YESB/**5@YBL/UPI")[1] == "ann_fuels"


def test_non_upi_narrations_are_still_matched_on_the_whole_text():
    _, key, category, _ = MerchantNormalizer().normalize("POS 48392 AMAZON SELLER SERVICES")
    assert key == "amazon"


def test_one_shared_word_is_not_a_fuzzy_match():
    n = MerchantNormalizer()
    for payee in ("GOOGLE IN", "GOOGLE PL", "GOOGLE CL"):
        merchant, _, _, _ = n.normalize(f"UPI/DR/1/{payee}/UTIB/**1@X/UPI")
        assert merchant != "YouTube Premium", payee


def test_a_typo_in_a_known_merchant_still_matches():
    _, key, category, _ = MerchantNormalizer().normalize("UPI/DR/1/SWIGGI/UTIB/**1@X/UPI")
    assert key == "swiggy"
    assert category == "Food"
