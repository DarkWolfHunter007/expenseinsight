import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/transaction_model.dart';
import '../../utils/money.dart';
import 'dashboard_section.dart';

/// Transactions waiting for a human decision. It is always visible, shows the exact count and links to the
/// review screen. It does not go away because a notification was read: only reviewing the transactions
/// empties it.
class ReviewSection extends StatelessWidget {
  final List<UncertainReviewModel> items;
  final VoidCallback onReview;

  const ReviewSection({super.key, required this.items, required this.onReview});

  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    return DashboardSection(
      number: '06',
      title: 'Needs your review',
      subtitle: count == 0 ? null : '$count pending',
      trailing: count == 0 ? null : TextButton(onPressed: onReview, child: const Text('Review all')),
      child: count == 0
          ? Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Nothing needs your review.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400])),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The AI was not confident about ${count == 1 ? 'this transaction' : 'these'}. '
                  'Confirm the category so ${count == 1 ? 'it counts' : 'they count'} correctly in your spending.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                ),
                const SizedBox(height: 10),
                for (final item in items.take(3))
                  InkWell(
                    onTap: onReview,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.merchant, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(
                                  'Low confidence (${item.confidencePercentage}), guessed ${item.predictedCategory}  ·  ${item.date}',
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          Text(rupees(item.amount), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                if (count > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('+ ${count - 3} more', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                  ),
              ],
            ),
    );
  }
}
