import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/category_colors.dart';
import '../models/analytics_model.dart';

class RecurringSubscriptionsCard extends StatelessWidget {
  final List<RecurringExpenseItem> recurringItems;

  const RecurringSubscriptionsCard({super.key, required this.recurringItems});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (recurringItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No recurring subscriptions detected',
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black45),
        ),
      );
    }

    return Column(
      children: recurringItems.map((item) {
        final meta = CategoryColors.getMeta(item.category);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: meta.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(meta.icon, color: meta.color, size: 18),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      '${item.frequency} • ${item.occurrences} recorded billing cycles',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '~${currencyFormat.format(item.averageAmount)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    'per cycle',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
