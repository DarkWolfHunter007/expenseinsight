import 'package:flutter/material.dart';

/// Colors and wording for each budget tier.
class BudgetTier {
  final Color accent;
  final Color fill;
  final IconData icon;

  const BudgetTier(this.accent, this.fill, this.icon);

  static BudgetTier of(String status) {
    switch (status) {
      case 'exceeded':
        return const BudgetTier(Color(0xFFEF4444), Color(0xFF7F1D1D), Icons.warning_amber_rounded);
      case 'critical':
        return const BudgetTier(Color(0xFFF97316), Color(0xFF7C2D12), Icons.priority_high_rounded);
      case 'warning':
        return const BudgetTier(Color(0xFFF59E0B), Color(0xFF78350F), Icons.error_outline_rounded);
      default:
        return const BudgetTier(Color(0xFF10B981), Color(0xFF064E3B), Icons.check_circle_outline_rounded);
    }
  }
}
