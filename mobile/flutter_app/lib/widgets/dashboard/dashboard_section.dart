import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// An open dashboard section: a small numbered label and the content, with no enclosing card.
class DashboardSection extends StatelessWidget {
  final String number;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const DashboardSection({
    super.key,
    required this.number,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number  —  ${title.toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

/// A big number with a small label above it and an optional caption below, used across the sections.
class StatFigure extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final double size;

  const StatFigure({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: size,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
        ],
      ],
    );
  }
}
