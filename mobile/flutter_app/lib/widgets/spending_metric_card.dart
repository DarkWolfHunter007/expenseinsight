import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SpendingMetricCard extends StatelessWidget {
  final String title;
  final double amount;
  final String? subtitle;
  final double? trendPercentage;
  final IconData icon;
  final Color accentColor;
  final bool isCurrency;

  const SpendingMetricCard({
    super.key,
    required this.title,
    required this.amount,
    this.subtitle,
    this.trendPercentage,
    required this.icon,
    required this.accentColor,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isCurrency ? currencyFormat.format(amount) : amount.toStringAsFixed(0),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          if (trendPercentage != null)
            Row(
              children: [
                Icon(
                  trendPercentage! >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 14,
                  color: trendPercentage! >= 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  '${trendPercentage! >= 0 ? "+" : ""}${trendPercentage!.toStringAsFixed(1)}% vs last month',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: trendPercentage! >= 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ],
            )
          else if (subtitle != null)
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }
}
