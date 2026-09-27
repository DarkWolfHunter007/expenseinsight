class TransactionModel {
  final String id;
  final String userId;
  final String? statementId;
  final String date;
  final String rawDescription;
  final String? cleanDescription;
  final String merchant;
  final String normalizedMerchant;
  final double amount;
  final String currency;
  final String transactionType; // expense, income, transfer, cash_withdrawal
  final String crDr; // DR or CR
  final double? balance;
  final String? referenceNumber;
  final String category;
  final double categoryConfidence;
  final String categorySource;
  final bool needsReview;
  final bool isDuplicate;
  final DateTime createdAt;
  final String sourceType; // 'bank' or 'cash'

  TransactionModel({
    required this.id,
    required this.userId,
    this.statementId,
    required this.date,
    required this.rawDescription,
    this.cleanDescription,
    required this.merchant,
    required this.normalizedMerchant,
    required this.amount,
    required this.currency,
    required this.transactionType,
    required this.crDr,
    this.balance,
    this.referenceNumber,
    required this.category,
    required this.categoryConfidence,
    required this.categorySource,
    required this.needsReview,
    required this.isDuplicate,
    required this.createdAt,
    this.sourceType = 'bank',
  });

  bool get isCash => sourceType == 'cash' || transactionType == 'cash_expense';
  bool get isExpense => (crDr == 'DR' && transactionType != 'transfer') || isCash;
  bool get isIncome => crDr == 'CR' || transactionType == 'income';
  bool get isTransfer => transactionType == 'transfer' || transactionType == 'cash_withdrawal';

  String get confidenceLevel {
    if (isCash) return 'Cash';
    if (categoryConfidence >= 0.85) return 'High';
    if (categoryConfidence >= 0.60) return 'Medium';
    return 'Low';
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      statementId: json['statement_id'],
      date: json['date'] ?? '',
      rawDescription: json['raw_description'] ?? '',
      cleanDescription: json['clean_description'],
      merchant: json['merchant'] ?? 'Unknown',
      normalizedMerchant: json['normalized_merchant'] ?? 'unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
      transactionType: json['transaction_type'] ?? 'expense',
      crDr: json['cr_dr'] ?? 'DR',
      balance: (json['balance'] as num?)?.toDouble(),
      referenceNumber: json['reference_number'],
      category: json['category'] ?? 'Uncategorized',
      categoryConfidence: (json['category_confidence'] as num?)?.toDouble() ?? 0.0,
      categorySource: json['category_source'] ?? 'ml',
      needsReview: json['needs_review'] ?? false,
      isDuplicate: json['is_duplicate'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      sourceType: json['source_type'] ?? (json['transaction_type'] == 'cash_expense' ? 'cash' : 'bank'),
    );
  }
}

class UncertainReviewModel {
  final String transactionId;
  final String merchant;
  final String rawDescription;
  final double amount;
  final String date;
  final String predictedCategory;
  final double confidence;
  final String confidencePercentage;
  final List<String> suggestedCategories;

  UncertainReviewModel({
    required this.transactionId,
    required this.merchant,
    required this.rawDescription,
    required this.amount,
    required this.date,
    required this.predictedCategory,
    required this.confidence,
    required this.confidencePercentage,
    required this.suggestedCategories,
  });

  factory UncertainReviewModel.fromJson(Map<String, dynamic> json) {
    return UncertainReviewModel(
      transactionId: json['transaction_id'] ?? '',
      merchant: json['merchant'] ?? 'Unknown',
      rawDescription: json['raw_description'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] ?? '',
      predictedCategory: json['predicted_category'] ?? 'Other',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      confidencePercentage: json['confidence_percentage'] ?? '0%',
      suggestedCategories: (json['suggested_categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
