import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/analytics_provider.dart';
import '../providers/cash_expense_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/add_edit_cash_expense_dialog.dart';
import '../widgets/bank_statement_header.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/install_guide_dialog.dart';
import '../widgets/merchant_ranking_card.dart';
import '../widgets/monthly_trend_chart.dart';
import '../widgets/recurring_subscriptions_card.dart';
import '../widgets/server_settings_dialog.dart';
import '../widgets/spending_metric_card.dart';
import 'review_uncertain_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer3<AnalyticsProvider, ForecastProvider, TransactionProvider>(
      builder: (context, analyticsProv, forecastProv, txnProv, child) {
        final summary = analyticsProv.summary;
        final forecast = forecastProv.forecast;
        final uncertainCount = txnProv.uncertainTransactions.length;

        if (analyticsProv.isLoading && summary == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('ExpenseInsight'),
            actions: [
              IconButton(
                onPressed: () => AddEditCashExpenseDialog.show(context),
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981)),
                tooltip: 'Add Cash Expense',
              ),
              IconButton(
                onPressed: () => InstallGuideDialog.show(context),
                icon: const Icon(Icons.install_mobile_rounded),
                tooltip: 'Install App (PWA)',
              ),
              IconButton(
                onPressed: () => ServerSettingsDialog.show(context),
                icon: const Icon(Icons.cloud_outlined),
                tooltip: 'Server Connection',
              ),
              IconButton(
                onPressed: () {
                  analyticsProv.fetchAnalytics();
                  forecastProv.fetchForecast();
                  txnProv.fetchTransactions();
                  Provider.of<CashExpenseProvider>(context, listen: false).fetchCashExpenses();
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Analytics',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => AddEditCashExpenseDialog.show(context),
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Cash Expense', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: RefreshIndicator(
            color: const Color(0xFF10B981),
            onRefresh: () async {
              await analyticsProv.fetchAnalytics();
              await forecastProv.fetchForecast();
              await txnProv.fetchTransactions();
              if (context.mounted) {
                await Provider.of<CashExpenseProvider>(context, listen: false).fetchCashExpenses();
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic Bank Statement Hero Header
                  BankStatementHeader(
                    bankName: summary?.bankName ?? 'Bank Statement',
                    statementPeriod: summary?.statementPeriod,
                    transactionCount: summary?.totalTransactionsCount ?? 0,
                  ),
                  const SizedBox(height: 16),

                  // Spending Sources Breakdown Card (PRD Section 15: Bank vs Cash vs Total)
                  _buildSpendingSourcesBreakdown(context, summary, isDark),
                  const SizedBox(height: 16),

                  // Uncertain Transactions Alert Banner (PRD Section 20)
                  if (uncertainCount > 0) ...[
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReviewUncertainScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$uncertainCount Uncertain Transaction${uncertainCount > 1 ? "s" : ""}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF991B1B),
                                    ),
                                  ),
                                  Text(
                                    'AI categorized with low confidence. Tap to review.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF991B1B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Top Metric Cards Grid (PRD Section 32)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      return GridView.count(
                        crossAxisCount: isWide ? 4 : 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: isWide ? 1.35 : 1.1,
                        children: [
                          SpendingMetricCard(
                            title: 'Total Spent',
                            amount: summary?.totalExpense ?? 0.0,
                            subtitle: (summary != null && summary.cashSpending > 0)
                                ? 'Bank: ₹${summary.bankSpending.toStringAsFixed(0)} • Cash: ₹${summary.cashSpending.toStringAsFixed(0)}'
                                : 'Bank + Cash Combined',
                            icon: Icons.account_balance_wallet_rounded,
                            accentColor: const Color(0xFFEF4444),
                          ),
                          SpendingMetricCard(
                            title: 'This Month',
                            amount: summary?.thisMonthSpent ?? 0.0,
                            trendPercentage: summary?.monthOverMonthChangePct,
                            icon: Icons.calendar_today_rounded,
                            accentColor: const Color(0xFF3B82F6),
                          ),
                          SpendingMetricCard(
                            title: 'Next Month Forecast',
                            amount: forecast?.totalForecast ?? (summary?.thisMonthSpent ?? 0.0),
                            subtitle: 'AI Statistical Estimate',
                            icon: Icons.auto_awesome_rounded,
                            accentColor: const Color(0xFF8B5CF6),
                          ),
                          SpendingMetricCard(
                            title: 'Net Savings',
                            amount: summary?.netSavings ?? 0.0,
                            subtitle: 'Income minus Expenses',
                            icon: Icons.savings_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Spending by Category Donut Chart
                  _sectionHeader('Spending by Category', 'Category-wise distribution'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: CategoryDonutChart(
                      categories: summary?.categoriesBreakdown ?? [],
                      totalExpense: summary?.totalExpense ?? 0.0,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Monthly Spending Trend Line Chart
                  _sectionHeader('Monthly Spending Trend', 'Chronological income and expense breakdown'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: MonthlyTrendChart(
                      monthlyData: analyticsProv.monthlySpending,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Top Merchants Card
                  _sectionHeader('Top Spending Merchants', 'Normalized merchant rankings'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: MerchantRankingCard(
                      merchants: summary?.topMerchants ?? [],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recurring Subscriptions Card
                  _sectionHeader('Recurring Subscriptions & Bills', 'Detected monthly repeating cycles'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: RecurringSubscriptionsCard(
                      recurringItems: summary?.recurringExpenses ?? [],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSpendingSourcesBreakdown(BuildContext context, dynamic summary, bool isDark) {
    final bankSpent = (summary?.bankSpending as num?)?.toDouble() ?? 0.0;
    final cashSpent = (summary?.cashSpending as num?)?.toDouble() ?? 0.0;
    final totalSpent = (summary?.totalExpense as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pie_chart_outline_rounded, size: 18, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Real Spending Sources',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => AddEditCashExpenseDialog.show(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Cash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Total Spending
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Spending',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${totalSpent.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bank Spending
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 12, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 4),
                          Text(
                            'Bank',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${bankSpent.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Cash Spending
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_rounded, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            'Cash',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${cashSpent.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
