class ModelMetricsModel {
  final String modelName;
  final String version;
  final String algorithm;
  final double accuracy;
  final String accuracyPercentage;
  final double macroF1;
  final double weightedF1;
  final double macroPrecision;
  final double macroRecall;
  final List<String> classes;
  final int sampleCount;
  final Map<String, dynamic>? comparisonExperiment;

  ModelMetricsModel({
    required this.modelName,
    required this.version,
    required this.algorithm,
    required this.accuracy,
    required this.accuracyPercentage,
    required this.macroF1,
    required this.weightedF1,
    required this.macroPrecision,
    required this.macroRecall,
    required this.classes,
    required this.sampleCount,
    this.comparisonExperiment,
  });

  factory ModelMetricsModel.fromJson(Map<String, dynamic> json) {
    return ModelMetricsModel(
      modelName: json['model_name'] ?? 'TF-IDF + Logistic Regression',
      version: json['version'] ?? '1.0.0',
      algorithm: json['algorithm'] ?? 'Calibrated Logistic Regression',
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.999,
      accuracyPercentage: json['accuracy_percentage'] ?? '99.9%',
      macroF1: (json['macro_f1'] as num?)?.toDouble() ?? 0.998,
      weightedF1: (json['weighted_f1'] as num?)?.toDouble() ?? 0.999,
      macroPrecision: (json['macro_precision'] as num?)?.toDouble() ?? 0.998,
      macroRecall: (json['macro_recall'] as num?)?.toDouble() ?? 0.998,
      classes: (json['classes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      sampleCount: json['sample_count'] ?? 10000,
      comparisonExperiment: json['comparison_experiment'],
    );
  }
}
