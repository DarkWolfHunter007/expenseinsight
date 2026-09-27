class CashExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String expenseDate;
  final String? description;
  final String paymentMethod; // 'bank', 'upi', 'cash'
  final DateTime createdAt;
  final DateTime? updatedAt;

  CashExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.description,
    this.paymentMethod = 'cash',
    required this.createdAt,
    this.updatedAt,
  });

  factory CashExpenseModel.fromJson(Map<String, dynamic> json) {
    final rawDesc = json['description'] as String?;
    String? cleanDesc = rawDesc;
    String method = (json['payment_method'] as String?)?.toLowerCase() ?? 'cash';
    if (rawDesc != null) {
      for (final pfx in ['[Bank] ', '[Bank]', '[UPI] ', '[UPI]', '[Cash] ', '[Cash]']) {
        if (rawDesc.startsWith(pfx)) {
          if (pfx.contains('Bank')) method = 'bank';
          if (pfx.contains('UPI')) method = 'upi';
          if (pfx.contains('Cash')) method = 'cash';
          cleanDesc = rawDesc.substring(pfx.length).trim();
          if (cleanDesc.isEmpty) cleanDesc = null;
          break;
        }
      }
    }

    return CashExpenseModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? '',
      expenseDate: json['expense_date'] ?? '',
      description: cleanDesc,
      paymentMethod: method,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'expense_date': expenseDate,
      'payment_method': paymentMethod,
      if (description != null && description!.isNotEmpty) 'description': description,
    };
  }

  CashExpenseModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? expenseDate,
    String? description,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      expenseDate: expenseDate ?? this.expenseDate,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
