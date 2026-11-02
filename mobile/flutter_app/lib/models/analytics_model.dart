class CategorySpendingItem {
  final String category;
  final double amount;
  final double percentage;
  final int transactionCount;
  final double bankAmount;
  final double cashAmount;

  CategorySpendingItem({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
    this.bankAmount = 0.0,
    this.cashAmount = 0.0,
  });

  factory CategorySpendingItem.fromJson(Map<String, dynamic> json) {
    return CategorySpendingItem(
      category: json['category'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] ?? 0,
      bankAmount: (json['bank_amount'] as num?)?.toDouble() ?? 0.0,
      cashAmount: (json['cash_amount'] as num?)?.toDouble() ?? 0.0,
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
  final double bankExpense;
  final double cashExpense;

  MonthlySpendingItem({
    required this.month,
    required this.monthName,
    required this.totalExpense,
    required this.totalIncome,
    required this.netSavings,
    required this.transactionCount,
    this.bankExpense = 0.0,
    this.cashExpense = 0.0,
  });

  factory MonthlySpendingItem.fromJson(Map<String, dynamic> json) {
    return MonthlySpendingItem(
      month: json['month'] ?? '',
      monthName: json['month_name'] ?? '',
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      netSavings: (json['net_savings'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] ?? 0,
      bankExpense: (json['bank_expense'] as num?)?.toDouble() ?? 0.0,
      cashExpense: (json['cash_expense'] as num?)?.toDouble() ?? 0.0,
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

class CategoryBudgetItem {
  final String category;
  final double limit;
  final double spent;
  final double remaining;
  final double usedPct;
  final String status; // on_track | warning | critical | exceeded

  CategoryBudgetItem({
    required this.category,
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.usedPct,
    required this.status,
  });

  factory CategoryBudgetItem.fromJson(Map<String, dynamic> json) {
    return CategoryBudgetItem(
      category: json['category'] ?? '',
      limit: (json['limit'] as num?)?.toDouble() ?? 0.0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
      usedPct: (json['used_pct'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'on_track',
    );
  }
}

class LastMonthRecap {
  final String month; // YYYY-MM
  final double spent;
  final double budget;
  final double difference; // positive = under budget
  final bool underBudget;

  LastMonthRecap({
    required this.month,
    required this.spent,
    required this.budget,
    required this.difference,
    required this.underBudget,
  });

  factory LastMonthRecap.fromJson(Map<String, dynamic> json) {
    return LastMonthRecap(
      month: json['month'] ?? '',
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      difference: (json['difference'] as num?)?.toDouble() ?? 0.0,
      underBudget: json['under_budget'] ?? true,
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
  final int statementCount;
  final List<CategorySpendingItem> categoriesBreakdown;
  final List<MerchantSpendingItem> topMerchants;
  final List<RecurringExpenseItem> recurringExpenses;
  final double bankSpending;
  final double cashSpending;
  final double totalSpending;
  final double bankMoneyOut;
  final double bankMoneyIn;
  final double transfersOut;
  final double transfersIn;
  final double otherMoneyOut;
  final double netCashFlow;
  final String thisMonthLabel;
  final double monthlyBudget;
  final String? budgetMonth;
  final double budgetSpent;
  final double budgetRemaining;
  final double budgetUsedPct;
  final String budgetStatus; // none | on_track | warning | critical | exceeded
  final String budgetMode; // auto | manual
  final int daysLeftInMonth;
  final double safeToSpendToday;
  final List<CategoryBudgetItem> categoryBudgets;
  final LastMonthRecap? lastMonthRecap;

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
    this.statementCount = 0,
    required this.categoriesBreakdown,
    required this.topMerchants,
    required this.recurringExpenses,
    this.bankSpending = 0.0,
    this.cashSpending = 0.0,
    this.totalSpending = 0.0,
    this.bankMoneyOut = 0.0,
    this.bankMoneyIn = 0.0,
    this.transfersOut = 0.0,
    this.transfersIn = 0.0,
    this.otherMoneyOut = 0.0,
    this.netCashFlow = 0.0,
    this.thisMonthLabel = '',
    this.monthlyBudget = 0.0,
    this.budgetMonth,
    this.budgetSpent = 0.0,
    this.budgetRemaining = 0.0,
    this.budgetUsedPct = 0.0,
    this.budgetStatus = 'none',
    this.budgetMode = 'auto',
    this.daysLeftInMonth = 0,
    this.safeToSpendToday = 0.0,
    this.categoryBudgets = const [],
    this.lastMonthRecap,
  });

  factory AnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    final exp = (json['total_expense'] as num?)?.toDouble() ?? 0.0;
    return AnalyticsSummaryModel(
      totalExpense: exp,
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
      statementCount: json['statement_count'] ??
          (json['bank_name'] != null && json['bank_name'] != 'No Statements Ingested' && json['bank_name'] != 'Bank Statement' ? 1 : 0),
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
      bankSpending: (json['bank_spending'] as num?)?.toDouble() ?? 0.0,
      cashSpending: (json['cash_spending'] as num?)?.toDouble() ?? 0.0,
      totalSpending: (json['total_spending'] as num?)?.toDouble() ?? exp,
      bankMoneyOut: (json['bank_money_out'] as num?)?.toDouble() ?? 0.0,
      bankMoneyIn: (json['bank_money_in'] as num?)?.toDouble() ?? 0.0,
      transfersOut: (json['transfers_out'] as num?)?.toDouble() ?? 0.0,
      transfersIn: (json['transfers_in'] as num?)?.toDouble() ?? 0.0,
      otherMoneyOut: (json['other_money_out'] as num?)?.toDouble() ?? 0.0,
      netCashFlow: (json['net_cash_flow'] as num?)?.toDouble() ?? 0.0,
      thisMonthLabel: json['this_month_label'] ?? '',
      monthlyBudget: (json['monthly_budget'] as num?)?.toDouble() ?? 0.0,
      budgetMonth: json['budget_month'],
      budgetSpent: (json['budget_spent'] as num?)?.toDouble() ?? 0.0,
      budgetRemaining: (json['budget_remaining'] as num?)?.toDouble() ?? 0.0,
      budgetUsedPct: (json['budget_used_pct'] as num?)?.toDouble() ?? 0.0,
      budgetStatus: json['budget_status'] ?? 'none',
      budgetMode: json['budget_mode'] ?? 'auto',
      daysLeftInMonth: json['days_left_in_month'] ?? 0,
      safeToSpendToday: (json['safe_to_spend_today'] as num?)?.toDouble() ?? 0.0,
      categoryBudgets: (json['category_budgets'] as List<dynamic>?)
              ?.map((e) => CategoryBudgetItem.fromJson(e))
              .toList() ??
          [],
      lastMonthRecap: json['last_month_recap'] != null ? LastMonthRecap.fromJson(json['last_month_recap']) : null,
    );
  }
}
