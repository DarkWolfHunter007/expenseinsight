import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/statement_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/model_provider.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;

  void _startGuestDemo() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final stmtProv = Provider.of<StatementProvider>(context, listen: false);
    final txnProv = Provider.of<TransactionProvider>(context, listen: false);
    final analyticsProv = Provider.of<AnalyticsProvider>(context, listen: false);
    final forecastProv = Provider.of<ForecastProvider>(context, listen: false);
    final modelProv = Provider.of<ModelProvider>(context, listen: false);

    await auth.loginGuest();
    await stmtProv.seedSampleStatement(bank: 'HDFC Bank');
    await txnProv.fetchTransactions();
    await analyticsProv.fetchAnalytics();
    await forecastProv.fetchForecast();
    await modelProv.fetchMetrics();

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / App Icon Badge
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'ExpenseInsight',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Intelligent Financial Intelligence from Bank Statements',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Feature Cards
                  _featureCard(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'Automated PDF Parsing',
                    desc: 'Upload 6-month statements. Extracts transactions & balances automatically.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _featureCard(
                    icon: Icons.storefront_rounded,
                    title: 'Merchant Normalization',
                    desc: 'Cleans UPI/POS clutter into canonical merchant names like Swiggy & Uber.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _featureCard(
                    icon: Icons.psychology_rounded,
                    title: 'ML Expense Categorization',
                    desc: 'TF-IDF NLP model with confidence scores & uncertainty review deck.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _featureCard(
                    icon: Icons.query_stats_rounded,
                    title: 'Predictive Forecasting',
                    desc: 'Time-series forecasting with statistical confidence intervals.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 36),

                  // Action Buttons
                  if (_isLoading)
                    const CircularProgressIndicator(color: Color(0xFF10B981))
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startGuestDemo(),
                        icon: const Icon(Icons.flash_on_rounded, size: 20),
                        label: const Text('Launch 1-Click Demo (HDFC 6-Mo)'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Continue to Dashboard'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
              color: const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
