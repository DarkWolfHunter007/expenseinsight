import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InstallGuideDialog extends StatelessWidget {
  const InstallGuideDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const InstallGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.install_mobile_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Install ExpenseInsight',
                          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Standalone Web App (PWA)',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Install ExpenseInsight on your home screen for full-screen offline access, faster loading, and seamless PDF statement extraction.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // iOS Specific Steps
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_iphone_rounded, size: 18, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Text(
                          'On iPhone / iPad (Safari):',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _stepItem(
                      number: '1',
                      icon: Icons.ios_share_rounded,
                      text: 'Tap the Share button at the bottom of Safari.',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _stepItem(
                      number: '2',
                      icon: Icons.add_box_outlined,
                      text: "Scroll down and tap 'Add to Home Screen'.",
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _stepItem(
                      number: '3',
                      icon: Icons.check_circle_outline_rounded,
                      text: "Tap 'Add' in the top right corner to complete.",
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Android / Chrome Steps
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.android_rounded, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          'On Android / Chrome / Desktop:',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap the browser menu (⋮) and choose 'Install app' or 'Add to Home screen'.",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Got It', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepItem({
    required String number,
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF3B82F6),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
