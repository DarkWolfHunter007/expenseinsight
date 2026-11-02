import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/category_colors.dart';
import '../../models/analytics_model.dart';
import '../../utils/money.dart';
import 'dashboard_section.dart';

/// Where the money goes, as a ranked list of bars: the largest category first, so the comparison needs
/// no reading of a pie or donut.
class CategoryRankingSection extends StatelessWidget {
  final List<CategorySpendingItem> categories;
  final int maxRows;

  const CategoryRankingSection({super.key, required this.categories, this.maxRows = 8});

  @override
  Widget build(BuildContext context) {
    final sorted = [...categories]..sort((a, b) => b.amount.compareTo(a.amount));
    final shown = sorted.take(maxRows).toList();
    final hidden = sorted.length - shown.length;
    final largest = shown.isEmpty ? 1.0 : shown.first.amount.clamp(1.0, double.infinity);

    return DashboardSection(
      number: '04',
      title: 'Where your money goes',
      subtitle: 'Purchases and bills by category',
      child: shown.isEmpty
          ? Text('No spending categories yet.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]))
          : Column(
              children: [
                for (final item in shown) _row(context, item, largest),
                if (hidden > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('+ $hidden more', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _row(BuildContext context, CategorySpendingItem item, double largest) {
    final meta = CategoryColors.getMeta(item.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(meta.icon, size: 14, color: meta.color),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Text(
              item.category,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.amount / largest).clamp(0.0, 1.0),
                minHeight: 8,
                color: meta.color,
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 78,
            child: Text(
              rupees(item.amount),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${item.percentage.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}
