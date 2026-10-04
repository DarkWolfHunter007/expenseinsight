import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/install_guide_dialog.dart';
import '../widgets/server_settings_dialog.dart';
import 'cash_expenses_screen.dart';
import 'model_benchmark_screen.dart';
import 'onboarding_screen.dart';
import 'upload_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Options'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final isIdentified = auth.isAuthenticated && !auth.user!.isGuest;
              final emailText = isIdentified
                  ? auth.user!.email
                  : (auth.isAuthenticated ? 'Guest User (Demo)' : 'Not Identified');

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                      child: Icon(
                        isIdentified ? Icons.person_rounded : Icons.person_outline_rounded,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIdentified ? 'Persistent Identity' : 'Session Identity',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            emailText,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await auth.logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                            (route) => false,
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        isIdentified ? 'Switch' : 'Identify',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildSectionHeader('Data Ingestion & Records'),
          const SizedBox(height: 8),
          _buildMenuCard(
            context,
            icon: Icons.cloud_upload_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: 'Ingest Bank Statement PDF',
            subtitle: 'Upload e-statements to parse and categorize transactions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadScreen()),
              );
            },
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildMenuCard(
            context,
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Cash Expenses Ledger',
            subtitle: 'Review, edit, and audit recorded cash expenses',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashExpensesScreen()),
              );
            },
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('AI & Intelligence'),
          const SizedBox(height: 8),
          _buildMenuCard(
            context,
            icon: Icons.psychology_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'AI Model & Benchmark',
            subtitle: 'Accuracy metrics, model latency, and confidence scoring',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelBenchmarkScreen()),
              );
            },
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('System & Settings'),
          const SizedBox(height: 8),
          _buildMenuCard(
            context,
            icon: Icons.cloud_outlined,
            iconColor: const Color(0xFF0EA5E9),
            title: 'Server Connection',
            subtitle: 'Configure backend API host, port, and network status',
            onTap: () => ServerSettingsDialog.show(context),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildMenuCard(
            context,
            icon: Icons.install_mobile_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Install App (PWA)',
            subtitle: 'Add ExpenseInsight to your home screen for quick access',
            onTap: () => InstallGuideDialog.show(context),
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'ExpenseInsight v1.0.0\nAI-Powered Personal Financial Intelligence',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
