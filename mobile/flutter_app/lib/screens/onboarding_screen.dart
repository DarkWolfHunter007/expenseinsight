import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cash_expense_provider.dart';
import '../providers/statement_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/model_provider.dart';
import '../widgets/server_settings_dialog.dart';
import 'main_navigation_screen.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _continueWithEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _localError = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _localError = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.identifyWithEmail(email);

    if (!mounted) return;

    if (success) {
      final stmtProv = Provider.of<StatementProvider>(context, listen: false);
      final txnProv = Provider.of<TransactionProvider>(context, listen: false);
      final cashProv = Provider.of<CashExpenseProvider>(context, listen: false);
      final analyticsProv = Provider.of<AnalyticsProvider>(context, listen: false);
      final forecastProv = Provider.of<ForecastProvider>(context, listen: false);

      await Future.wait([
        stmtProv.fetchStatements(),
        txnProv.fetchTransactions(),
        cashProv.fetchCashExpenses(),
        analyticsProv.fetchAnalytics(),
        forecastProv.fetchForecast(),
      ]);

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _localError = auth.errorMessage ?? 'Failed to identify user. Please try again.';
      });
    }
  }

  void _startGuestDemo() async {
    setState(() {
      _isLoading = true;
      _localError = null;
    });
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ServerSettingsDialog.show(context),
            icon: const Icon(Icons.cloud_outlined),
            tooltip: 'Server Connection Settings',
          ),
        ],
      ),
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
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
                  const SizedBox(height: 24),

                  // Email Identity Section (Primary Action)
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      final isIdentified = auth.isAuthenticated && !auth.user!.isGuest;
                      if (isIdentified && _emailController.text.isEmpty) {
                        _emailController.text = auth.user!.email;
                      }

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isIdentified
                                  ? 'Active Session Identified'
                                  : 'Enter your email to continue',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isIdentified
                                  ? 'Identified as ${auth.user!.email}. Continue to restore your data or enter a new email.'
                                  : 'Identify yourself to persist your transactions, statements, and AI predictions.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('email_identity_input'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _continueWithEmail(),
                              decoration: InputDecoration(
                                hintText: 'name@example.com',
                                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            if (_localError != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _localError!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFFEF4444),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                              key: const Key('continue_with_email_button'),
                              onPressed: _isLoading ? null : () => _continueWithEmail(),
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: Text(_isLoading ? 'Identifying...' : 'Continue with Email'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR EXPLORE DEMO',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('guest_demo_button'),
                      onPressed: _isLoading ? null : () => _startGuestDemo(),
                      icon: const Icon(Icons.flash_on_rounded, size: 18),
                      label: const Text('Launch 1-Click Demo (HDFC 6-Mo)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Feature Cards
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'CORE CAPABILITIES',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                    ],
                  ),
                  const SizedBox(height: 16),
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
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
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
