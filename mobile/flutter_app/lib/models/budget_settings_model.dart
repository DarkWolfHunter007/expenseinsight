class BudgetSettingsModel {
  final bool autoLimits;
  final double? monthlyLimit;
  final Map<String, double> categoryLimits;

  const BudgetSettingsModel({
    this.autoLimits = true,
    this.monthlyLimit,
    this.categoryLimits = const {},
  });

  factory BudgetSettingsModel.fromJson(Map<String, dynamic> json) {
    final limits = <String, double>{};
    (json['category_limits'] as Map<String, dynamic>?)?.forEach((key, value) {
      limits[key] = (value as num).toDouble();
    });
    return BudgetSettingsModel(
      autoLimits: json['auto_limits'] ?? true,
      monthlyLimit: (json['monthly_limit'] as num?)?.toDouble(),
      categoryLimits: limits,
    );
  }

  Map<String, dynamic> toJson() => {
        'auto_limits': autoLimits,
        'monthly_limit': monthlyLimit,
        'category_limits': categoryLimits,
      };
}
