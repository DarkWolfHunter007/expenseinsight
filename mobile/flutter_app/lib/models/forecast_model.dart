class CategoryForecastDetail {
  final double predictedAmount;
  final double lowerBound;
  final double upperBound;
  final double historicalRecentAvg;
  final double lastMonthSpent;
  final double trendPercentage;
  final int historicalMonths;

  CategoryForecastDetail({
    required this.predictedAmount,
    required this.lowerBound,
    required this.upperBound,
    required this.historicalRecentAvg,
    required this.lastMonthSpent,
    required this.trendPercentage,
    required this.historicalMonths,
  });

  factory CategoryForecastDetail.fromJson(Map<String, dynamic> json) {
    return CategoryForecastDetail(
      predictedAmount: (json['predicted_amount'] as num?)?.toDouble() ?? 0.0,
      lowerBound: (json['lower_bound'] as num?)?.toDouble() ?? 0.0,
      upperBound: (json['upper_bound'] as num?)?.toDouble() ?? 0.0,
      historicalRecentAvg: (json['historical_recent_avg'] as num?)?.toDouble() ?? 0.0,
      lastMonthSpent: (json['last_month_spent'] as num?)?.toDouble() ?? 0.0,
      trendPercentage: (json['trend_percentage'] as num?)?.toDouble() ?? 0.0,
      historicalMonths: json['historical_months'] ?? 0,
    );
  }
}

class ForecastModel {
  final String status;
  final String confidenceLevel;
  final String statusMessage;
  final int historicalMonthsCount;
  final double totalForecast;
  final double lowerBound;
  final double upperBound;
  final double next7DaysForecast;
  final double next30DaysForecast;
  final Map<String, CategoryForecastDetail> categoryForecasts;
  final String explanation;
  final List<String> explanationBullets;

  ForecastModel({
    required this.status,
    required this.confidenceLevel,
    required this.statusMessage,
    required this.historicalMonthsCount,
    required this.totalForecast,
    required this.lowerBound,
    required this.upperBound,
    required this.next7DaysForecast,
    required this.next30DaysForecast,
    required this.categoryForecasts,
    required this.explanation,
    required this.explanationBullets,
  });

  factory ForecastModel.fromJson(Map<String, dynamic> json) {
    final Map<String, CategoryForecastDetail> cats = {};
    if (json['category_forecasts'] != null) {
      (json['category_forecasts'] as Map<String, dynamic>).forEach((key, val) {
        cats[key] = CategoryForecastDetail.fromJson(val);
      });
    }

    return ForecastModel(
      status: json['status'] ?? 'unknown',
      confidenceLevel: json['confidence_level'] ?? 'medium',
      statusMessage: json['status_message'] ?? '',
      historicalMonthsCount: json['historical_months_count'] ?? 0,
      totalForecast: (json['total_forecast'] as num?)?.toDouble() ?? 0.0,
      lowerBound: (json['lower_bound'] as num?)?.toDouble() ?? 0.0,
      upperBound: (json['upper_bound'] as num?)?.toDouble() ?? 0.0,
      next7DaysForecast: (json['next_7_days_forecast'] as num?)?.toDouble() ?? 0.0,
      next30DaysForecast: (json['next_30_days_forecast'] as num?)?.toDouble() ?? 0.0,
      categoryForecasts: cats,
      explanation: json['explanation'] ?? '',
      explanationBullets: (json['explanation_bullets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
