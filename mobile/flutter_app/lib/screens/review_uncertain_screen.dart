import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/category_colors.dart';
import '../models/transaction_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/transaction_provider.dart';

class ReviewUncertainScreen extends StatefulWidget {
  const ReviewUncertainScreen({super.key});

  @override
  State<ReviewUncertainScreen> createState() => _ReviewUncertainScreenState();
}

class _ReviewUncertainScreenState extends State<ReviewUncertainScreen> {
  bool _applyToFuture = true;
  String? _selectedCategory;
  String? _lastItemTxnId;

  void _onCategoryConfirmed(UncertainReviewModel item, String chosenCategory) async {
    final txnProv = Provider.of<TransactionProvider>(context, listen: false);
    await txnProv.updateCategory(item.transactionId, chosenCategory, applyToFuture: _applyToFuture);

    // Refresh analytics and forecast with the updated category
    if (mounted) {
      Provider.of<AnalyticsProvider>(context, listen: false).fetchAnalytics();
      Provider.of<ForecastProvider>(context, listen: false).fetchForecast();
    }

    if (mounted) {
      setState(() {
        _selectedCategory = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Categorized '${item.merchant}' as '$chosenCategory'"),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Me Categorize This'),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          final items = provider.uncertainTransactions;

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD1FAE5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 64,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'All Caught Up!',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All statement transactions are confidently categorized. No low-confidence transactions left to review.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            );
          }

          final currentItem = items.first;

          // Reset or initialize default selection to Uncategorized when reviewing a new item
          if (_lastItemTxnId != currentItem.transactionId) {
            _lastItemTxnId = currentItem.transactionId;
            _selectedCategory = 'Uncategorized';
          }

          final activeCategory = _selectedCategory ?? 'Uncategorized';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stepper index
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining to review: ${items.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Low AI Confidence (${currentItem.confidencePercentage})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Review Card (PRD Section 20)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.help_outline_rounded, color: Color(0xFFEF4444), size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Uncertain Category Review",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Current category defaulted to Uncategorized. Pick the correct category below.',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Merchant Name
                      Text(
                        'Merchant:',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        currentItem.merchant,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Amount & Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount:',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                currencyFormat.format(currentItem.amount),
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Date:',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                currentItem.date,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Raw Statement Description
                      Text(
                        'Statement Narration:',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentItem.rawDescription,
                          style: GoogleFonts.robotoMono(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Question Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Category:',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CategoryColors.getMeta(activeCategory).backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CategoryColors.getMeta(activeCategory).icon,
                                  size: 13,
                                  color: CategoryColors.getMeta(activeCategory).color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Selected: $activeCategory',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: CategoryColors.getMeta(activeCategory).color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Selectable Category Pills with Tick Mark
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: CategoryColors.allCategories.map((cat) {
                          final meta = CategoryColors.getMeta(cat);
                          final isSelected = activeCategory.toLowerCase() == cat.toLowerCase();

                          return ChoiceChip(
                            showCheckmark: true,
                            checkmarkColor: isSelected ? Colors.white : meta.color,
                            avatar: isSelected
                                ? null
                                : Icon(meta.icon, size: 14, color: meta.color),
                            label: Text(cat),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            ),
                            selected: isSelected,
                            selectedColor: meta.color,
                            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected
                                    ? meta.color
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Apply to future toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Apply to similar future transactions',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Learns merchant association for automated future classification',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                        value: _applyToFuture,
                        onChanged: (val) {
                          setState(() {
                            _applyToFuture = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _onCategoryConfirmed(currentItem, 'Uncategorized'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Keep Uncategorized'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _onCategoryConfirmed(currentItem, activeCategory),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Confirm Category'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
