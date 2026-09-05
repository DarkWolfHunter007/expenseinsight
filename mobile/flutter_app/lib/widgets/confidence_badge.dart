import 'package:flutter/material.dart';

class ConfidenceBadge extends StatelessWidget {
  final double confidence;
  final bool needsReview;

  const ConfidenceBadge({
    super.key,
    required this.confidence,
    this.needsReview = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;
    String label;
    IconData icon;

    if (needsReview || confidence < 0.60) {
      color = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFEE2E2);
      label = '${(confidence * 100).toStringAsFixed(0)}% Review';
      icon = Icons.error_outline_rounded;
    } else if (confidence < 0.85) {
      color = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFEF3C7);
      label = '${(confidence * 100).toStringAsFixed(0)}%';
      icon = Icons.info_outline_rounded;
    } else {
      color = const Color(0xFF10B981);
      bgColor = const Color(0xFFD1FAE5);
      label = '${(confidence * 100).toStringAsFixed(0)}%';
      icon = Icons.verified_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
