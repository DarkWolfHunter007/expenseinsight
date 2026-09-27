import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/bank_branding.dart';

class BankStatementHeader extends StatelessWidget {
  final String bankName;
  final String? statementPeriod;
  final int transactionCount;
  final String? accountNumber;

  const BankStatementHeader({
    super.key,
    required this.bankName,
    this.statementPeriod,
    required this.transactionCount,
    this.accountNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final branding = BankBranding.fromName(bankName);

    final cardBg = isDark
        ? branding.darkBackgroundColor.withValues(alpha: 0.6)
        : branding.lightBackgroundColor.withValues(alpha: 0.7);

    final borderColor = isDark
        ? branding.primaryColor.withValues(alpha: 0.3)
        : branding.primaryColor.withValues(alpha: 0.2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bank Icon & Code Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: branding.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: branding.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    branding.shortCode.length > 5
                        ? branding.shortCode.substring(0, 5)
                        : branding.shortCode,
                    style: GoogleFonts.poppins(
                      fontSize: branding.shortCode.length > 4 ? 9.5 : (branding.shortCode.length > 3 ? 10.5 : 12.0),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bank Name Heading & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            branding.name.endsWith('Bank') || branding.name.endsWith('Statement')
                                ? '${branding.name} Statement'
                                : '${branding.name} Bank Statement',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      branding.tagline,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Verified Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'Analyzed',
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
          ),
          const SizedBox(height: 12),
          // Info Pills (Period & Transaction Count & Account Number)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (statementPeriod != null && statementPeriod!.isNotEmpty)
                _buildInfoPill(
                  context,
                  icon: Icons.date_range_rounded,
                  label: statementPeriod!,
                  isDark: isDark,
                  primaryColor: branding.primaryColor,
                ),
              _buildInfoPill(
                context,
                icon: Icons.receipt_long_rounded,
                label: '$transactionCount transactions',
                isDark: isDark,
                primaryColor: branding.primaryColor,
              ),
              if (accountNumber != null && accountNumber!.isNotEmpty && accountNumber != 'N/A')
                _buildInfoPill(
                  context,
                  icon: Icons.credit_card_rounded,
                  label: 'A/C: $accountNumber',
                  isDark: isDark,
                  primaryColor: branding.primaryColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: primaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact Statement Context Card for Mobile Home
/// Clearly indicates the active statement(s), bank branding, period, and transaction count.
class CompactStatementContextCard extends StatelessWidget {
  final String bankName;
  final String? statementPeriod;
  final int transactionCount;
  final int statementCount;
  final VoidCallback? onTap;

  const CompactStatementContextCard({
    super.key,
    required this.bankName,
    this.statementPeriod,
    required this.transactionCount,
    this.statementCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMultiBank = bankName.toLowerCase().trim().startsWith('multiple');
    final branding = isMultiBank
        ? BankBranding.fromName('multiple')
        : BankBranding.fromName(bankName);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final period = statementPeriod ?? 'Active Statement Period';
    final hasNoData = statementCount == 0 && transactionCount == 0;

    String titleText;
    if (hasNoData) {
      titleText = 'No Statements Ingested';
    } else if (isMultiBank) {
      titleText = 'Multiple Bank Statements';
    } else {
      titleText = branding.name;
    }

    String subtitleText;
    if (hasNoData) {
      subtitleText = 'Upload a statement to begin';
    } else if (statementCount > 1) {
      subtitleText = '$statementCount statements · $transactionCount transactions';
    } else {
      subtitleText = '$period · $transactionCount transactions';
    }

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Compact Bank Logo Chip
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: hasNoData
                      ? Colors.grey.withValues(alpha: 0.15)
                      : branding.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: hasNoData
                      ? Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.grey[400])
                      : Text(
                          branding.shortCode.length > 5
                              ? branding.shortCode.substring(0, 5)
                              : branding.shortCode,
                          style: GoogleFonts.poppins(
                            fontSize: branding.shortCode.length > 4 ? 8.5 : 10,
                            fontWeight: FontWeight.w800,
                            color: branding.primaryColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              // Bank Name and Period/Transaction Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
