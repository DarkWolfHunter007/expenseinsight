class CashExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String expenseDate;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CashExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.description,
    required this.createdAt,
    this.updatedAt,
  });

  factory CashExpenseModel.fromJson(Map<String, dynamic> json) {
    return CashExpenseModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? '',
      expenseDate: json['expense_date'] ?? '',
      description: json['description'],
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
