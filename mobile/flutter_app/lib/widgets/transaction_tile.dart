import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/category_colors.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'confidence_badge.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionTile({super.key, required this.transaction});

  void _showCategoryChangeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool applyToFuture = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Change Category',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Merchant: ${transaction.merchant} (${transaction.amount.toStringAsFixed(0)} INR)',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CategoryColors.allCategories.map((cat) {
                      final meta = CategoryColors.getMeta(cat);
                      final isSelected = (transaction.needsReview && (cat == 'Uncategorized' || cat == 'Other')) ||
                          transaction.category.toLowerCase() == cat.toLowerCase();

                      return ChoiceChip(
                        showCheckmark: true,
                        checkmarkColor: isSelected ? Colors.white : meta.color,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(meta.icon, size: 14, color: isSelected ? Colors.white : meta.color),
                            const SizedBox(width: 6),
                            Text(cat),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: meta.color,
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            Provider.of<TransactionProvider>(context, listen: false)
                                .updateCategory(transaction.id, cat, applyToFuture: applyToFuture);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Updated '$cat' for ${transaction.merchant}"),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
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
                    value: applyToFuture,
                    onChanged: (val) {
                      setModalState(() {
                        applyToFuture = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final meta = CategoryColors.getMeta(transaction.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    DateTime? txnDate = DateTime.tryParse(transaction.date);
    final formattedDate = txnDate != null ? DateFormat('MMM dd, yyyy').format(txnDate) : transaction.date;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: transaction.needsReview
                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: transaction.needsReview ? 1.5 : 1.0,
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: meta.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, color: meta.color, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  transaction.merchant,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${transaction.crDr == "DR" ? "-" : "+"}${currencyFormat.format(transaction.amount)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: transaction.crDr == "CR"
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(
                  formattedDate,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    transaction.category,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: meta.color,
                    ),
                  ),
                ),
                if (transaction.isCash) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_rounded, size: 10, color: Color(0xFF10B981)),
                        const SizedBox(width: 3),
                        Text(
                          'Cash',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                ConfidenceBadge(
                  confidence: transaction.categoryConfidence,
                  needsReview: transaction.needsReview,
                  isCash: transaction.isCash,
                ),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (transaction.isCash) ...[
                    _detailRow('Payment Source:', 'Cash / Liquid Money', isDark),
                    const SizedBox(height: 6),
                    _detailRow('Description / Note:', transaction.rawDescription, isDark),
                    const SizedBox(height: 6),
                    _detailRow('Entry Mode:', 'Manually Recorded', isDark),
                  ] else ...[
                    _detailRow('Raw Statement Text:', transaction.rawDescription, isDark),
                    const SizedBox(height: 6),
                    _detailRow('Normalized Merchant:', transaction.normalizedMerchant, isDark),
                    const SizedBox(height: 6),
                    _detailRow('Classification Source:', transaction.categorySource.toUpperCase(), isDark),
                    if (transaction.balance != null) ...[
                      const SizedBox(height: 6),
                      _detailRow('Account Balance:', currencyFormat.format(transaction.balance!), isDark),
                    ],
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCategoryChangeDialog(context),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Change Category'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _detailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
