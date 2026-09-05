import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/model_provider.dart';

class ModelBenchmarkScreen extends StatelessWidget {
  const ModelBenchmarkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ML Model & Academic Evaluation'),
        actions: [
          IconButton(
            onPressed: () => Provider.of<ModelProvider>(context, listen: false).fetchMetrics(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Model Metrics',
          ),
        ],
      ),
      body: Consumer<ModelProvider>(
        builder: (context, provider, child) {
          final metrics = provider.metrics;

          if (provider.isLoading && metrics == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }

          if (metrics == null) {
            return const Center(child: Text('Metrics not available'));
          }

          final comparison = metrics.comparisonExperiment;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Model Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.psychology_rounded, color: Color(0xFF10B981), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metrics.modelName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'v${metrics.version} • Evaluated on ${metrics.sampleCount} multi-bank samples',
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Algorithm Pipeline: ${metrics.algorithm}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Metrics Grid (PRD Section 39)
                Text(
                  'Academic Evaluation Metrics (Holdout Test 15%)',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  children: [
                    _metricCard('Accuracy', metrics.accuracyPercentage, 'Overall correct', const Color(0xFF10B981), isDark),
                    _metricCard('Macro F1 Score', metrics.macroF1.toStringAsFixed(4), 'Balanced category F1', const Color(0xFF3B82F6), isDark),
                    _metricCard('Macro Precision', metrics.macroPrecision.toStringAsFixed(4), 'Precision across classes', const Color(0xFF8B5CF6), isDark),
                    _metricCard('Macro Recall', metrics.macroRecall.toStringAsFixed(4), 'Coverage across classes', const Color(0xFFEC4899), isDark),
                  ],
                ),
                const SizedBox(height: 24),

                // Model Comparison Matrix (PRD Section 41)
                Text(
                  'Ablation & Model Architecture Comparison',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Benchmarking candidate NLP and ML classifiers',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                if (comparison != null)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: comparison.entries.map((e) {
                        final data = e.value as Map<String, dynamic>;
                        final isWinner = e.key.contains('Logistic');

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isWinner ? Icons.emoji_events_rounded : Icons.candlestick_chart_rounded,
                                color: isWinner ? const Color(0xFFF59E0B) : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.key,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (isWinner)
                                      Text(
                                        'Selected Production Model',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    data['accuracy_percentage'] ?? '0%',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                  Text(
                                    'F1: ${((data["macro_f1"] ?? 0) as num).toStringAsFixed(4)}',
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 24),

                // Retrain Model Action Button
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continuous Learning Retraining',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Re-fit model weights incorporating user manual corrections from feedback loop.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: provider.isRetraining
                              ? null
                              : () async {
                                  final ok = await provider.retrainModel();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? 'Model successfully retrained!' : 'Failed to retrain model. Ensure backend is reachable.'),
                                        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          icon: provider.isRetraining
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(provider.isRetraining ? 'Retraining...' : 'Retrain ML Model Now'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metricCard(String label, String value, String desc, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
