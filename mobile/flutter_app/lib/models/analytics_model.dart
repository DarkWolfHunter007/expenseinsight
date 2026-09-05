class CategorySpendingItem {
  final String category;
  final double amount;
  final double percentage;
  final int transactionCount;

  CategorySpendingItem({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
  });

  factory CategorySpendingItem.fromJson(Map<String, dynamic> json) {
    return CategorySpendingItem(
      category: json['category'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] ?? 0,
    );
  }
}

class MonthlySpendingItem {
  final String month;
  final String monthName;
  final double totalExpense;
  final double totalIncome;
  final double netSavings;
  final int transactionCount;

  MonthlySpendingItem({
    required this.month,
    required this.monthName,
    required this.totalExpense,
    required this.totalIncome,
    required this.netSavings,
    required this.transactionCount,
  });

  factory MonthlySpendingItem.fromJson(Map<String, dynamic> json) {
    return MonthlySpendingItem(
      month: json['month'] ?? '',
      monthName: json['month_name'] ?? '',
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      netSavings: (json['net_savings'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] ?? 0,
    );
  }
}

class MerchantSpendingItem {
  final String merchant;
  final String canonicalName;
  final String category;
  final double totalAmount;
  final int transactionCount;
  final double percentageOfTotal;

  MerchantSpendingItem({
    required this.merchant,
    required this.canonicalName,
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentageOfTotal,
  });

  factory MerchantSpendingItem.fromJson(Map<String, dynamic> json) {
    return MerchantSpendingItem(
      merchant: json['merchant'] ?? '',
      canonicalName: json['canonical_name'] ?? '',
      category: json['category'] ?? 'Other',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] ?? 0,
      percentageOfTotal: (json['percentage_of_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RecurringExpenseItem {
  final String merchant;
  final String category;
  final double averageAmount;
  final String frequency;
  final String lastPaymentDate;
  final int occurrences;

  RecurringExpenseItem({
    required this.merchant,
    required this.category,
    required this.averageAmount,
    required this.frequency,
    required this.lastPaymentDate,
    required this.occurrences,
  });

  factory RecurringExpenseItem.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseItem(
      merchant: json['merchant'] ?? '',
      category: json['category'] ?? 'Other',
      averageAmount: (json['average_amount'] as num?)?.toDouble() ?? 0.0,
      frequency: json['frequency'] ?? 'Monthly',
      lastPaymentDate: json['last_payment_date'] ?? '',
      occurrences: json['occurrences'] ?? 0,
    );
  }
}

class AnalyticsSummaryModel {
  final double totalExpense;
  final double totalIncome;
  final double totalTransfers;
  final double netSavings;
  final double thisMonthSpent;
  final double previousMonthSpent;
  final double monthOverMonthChangePct;
  final double averageDailySpend;
  final int totalTransactionsCount;
  final String? statementPeriod;
  final String bankName;
  final List<CategorySpendingItem> categoriesBreakdown;
  final List<MerchantSpendingItem> topMerchants;
  final List<RecurringExpenseItem> recurringExpenses;

  AnalyticsSummaryModel({
    required this.totalExpense,
    required this.totalIncome,
    required this.totalTransfers,
    required this.netSavings,
    required this.thisMonthSpent,
    required this.previousMonthSpent,
    required this.monthOverMonthChangePct,
    required this.averageDailySpend,
    required this.totalTransactionsCount,
    this.statementPeriod,
    this.bankName = 'Bank Statement',
    required this.categoriesBreakdown,
    required this.topMerchants,
    required this.recurringExpenses,
  });

  factory AnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummaryModel(
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalTransfers: (json['total_transfers'] as num?)?.toDouble() ?? 0.0,
      netSavings: (json['net_savings'] as num?)?.toDouble() ?? 0.0,
      thisMonthSpent: (json['this_month_spent'] as num?)?.toDouble() ?? 0.0,
      previousMonthSpent: (json['previous_month_spent'] as num?)?.toDouble() ?? 0.0,
      monthOverMonthChangePct: (json['month_over_month_change_pct'] as num?)?.toDouble() ?? 0.0,
      averageDailySpend: (json['average_daily_spend'] as num?)?.toDouble() ?? 0.0,
      totalTransactionsCount: json['total_transactions_count'] ?? 0,
      statementPeriod: json['statement_period'],
      bankName: json['bank_name'] ?? 'Bank Statement',
      categoriesBreakdown: (json['categories_breakdown'] as List<dynamic>?)
              ?.map((e) => CategorySpendingItem.fromJson(e))
              .toList() ??
          [],
      topMerchants: (json['top_merchants'] as List<dynamic>?)
              ?.map((e) => MerchantSpendingItem.fromJson(e))
              .toList() ??
          [],
      recurringExpenses: (json['recurring_expenses'] as List<dynamic>?)
              ?.map((e) => RecurringExpenseItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}
