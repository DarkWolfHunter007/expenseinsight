import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/category_colors.dart';
import '../../models/forecast_model.dart';
import '../../utils/money.dart';
import 'dashboard_section.dart';

/// The forecast, with the reasons for it. It never shows a confident number when the history is short:
/// below three complete months it is labelled a rough estimate and says how many months it is based on.
class IntelligenceSection extends StatelessWidget {
  final ForecastModel? forecast;
  final VoidCallback? onOpenForecast;

  const IntelligenceSection({super.key, required this.forecast, this.onOpenForecast});

  static const _purple = Color(0xFF8B5CF6);

  /// True when there is a usable forecast at all.
  static bool hasForecast(ForecastModel? f) => f != null && f.status != 'insufficient_data' && f.historicalMonthsCount > 0;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    return DashboardSection(
      number: '05',
      title: 'ExpenseInsight intelligence',
      subtitle: 'Next-month spending forecast',
      trailing: onOpenForecast == null
          ? null
          : TextButton(onPressed: onOpenForecast, child: const Text('Full forecast')),
      child: hasForecast(f) ? _content(context, f!) : _empty(),
    );
  }

  Widget _empty() => Text(
        'Not enough history for a forecast yet. Upload a statement or add a few expenses and this will fill in.',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
      );

  Widget _content(BuildContext context, ForecastModel f) {
    final months = f.historicalMonthsCount;
    final rough = months < 3;
    final categories = f.categoryForecasts.entries.where((e) => e.value.predictedAmount > 0).toList()
      ..sort((a, b) => b.value.predictedAmount.compareTo(a.value.predictedAmount));
    final top = categories.take(4).toList();
    final largest = top.isEmpty ? 1.0 : top.first.value.predictedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(rupees(f.totalForecast),
                style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: _purple)),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (rough ? const Color(0xFFF59E0B) : _purple).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rough ? 'Rough estimate' : '${f.confidenceLevel} confidence',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rough ? const Color(0xFFF59E0B) : _purple,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Likely between ${rupees(f.lowerBound)} and ${rupees(f.upperBound)}, based on '
          '$months complete month${months == 1 ? '' : 's'} of spending.',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
        ),
        if (rough) ...[
          const SizedBox(height: 6),
          Text(
            months == 1
                ? 'With one month of history the forecast repeats that month and the range is wide. Treat it as a guide.'
                : 'With under three months of history the forecast is only a guide.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF59E0B)),
          ),
        ],
        if (top.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('What it expects, by category',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
          const SizedBox(height: 8),
          for (final entry in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(entry.key, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (entry.value.predictedAmount / largest).clamp(0.0, 1.0),
                        minHeight: 6,
                        color: CategoryColors.getMeta(entry.key).color,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    child: Text(rupees(entry.value.predictedAmount),
                        textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text('How this is calculated', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in f.explanationBullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('•  $line', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
