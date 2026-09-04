import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/category_colors.dart';
import '../models/analytics_model.dart';

class MerchantRankingCard extends StatelessWidget {
  final List<MerchantSpendingItem> merchants;

  const MerchantRankingCard({super.key, required this.merchants});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (merchants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No merchant spending data available',
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black45),
        ),
      );
    }

    final topItems = merchants.take(5).toList();

    return Column(
      children: topItems.map((item) {
        final meta = CategoryColors.getMeta(item.category);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: meta.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.merchant,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${item.transactionCount} transactions • ${item.category}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(item.totalAmount),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (item.percentageOfTotal / 100.0).clamp(0.01, 1.0),
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(meta.color),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
