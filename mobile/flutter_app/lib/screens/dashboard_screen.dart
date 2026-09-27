import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/forecast_model.dart';
import '../models/transaction_model.dart';
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
import '../widgets/transaction_tile.dart';
import 'forecast_screen.dart';
import 'review_uncertain_screen.dart';
import 'transactions_screen.dart';

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
        final recentTransactions = txnProv.transactions.take(4).toList();

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
                tooltip: 'Add Expense',
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
            label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w600)),
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

                  // 1. Current Spending Summary & Sources
                  _buildSpendingSourcesSummary(context, summary, isDark),
                  const SizedBox(height: 16),

                  // 2. Uncertain Transactions Alert Banner
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

                  // 3. AI Forecast Intelligence Hero Card
                  _buildForecastHeroCard(context, forecast, summary, isDark),
                  const SizedBox(height: 16),

                  // 4. Secondary Metric Cards (This Month & Net Savings)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Expanded(
                            child: SpendingMetricCard(
                              title: 'This Month',
                              amount: summary?.thisMonthSpent ?? 0.0,
                              trendPercentage: summary?.monthOverMonthChangePct,
                              icon: Icons.calendar_today_rounded,
                              accentColor: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SpendingMetricCard(
                              title: 'Net Savings',
                              amount: summary?.netSavings ?? 0.0,
                              subtitle: 'Income minus Expenses',
                              icon: Icons.savings_rounded,
                              accentColor: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 5. Recent Transactions Section
                  _buildRecentTransactionsSection(context, recentTransactions, isDark),
                  const SizedBox(height: 24),

                  // 6. Spending by Category Donut Chart
                  _sectionHeader('Spending by Category', 'Category-wise distribution across all sources'),
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

                  // 7. Monthly Spending Trend Line Chart
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

                  // 8. Top Spending Merchants
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

                  // 9. Recurring Subscriptions Card
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

  Widget _buildSpendingSourcesSummary(BuildContext context, dynamic summary, bool isDark) {
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
              Expanded(
                child: Text(
                  'Total Spending',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                ),
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
                label: const Text('Add Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${totalSpent.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          // Subtle payment source breakdown row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_rounded, size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Text(
                      'Bank: ₹${bankSpent.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Cash: ₹${cashSpent.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecastHeroCard(BuildContext context, ForecastModel? forecast, dynamic summary, bool isDark) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final predictedAmount = forecast?.totalForecast ?? (summary?.thisMonthSpent ?? 0.0);
    final confidence = forecast?.confidenceLevel ?? 'Moderate';

    Color confidenceColor;
    if (confidence.toLowerCase().contains('high')) {
      confidenceColor = const Color(0xFF10B981);
    } else if (confidence.toLowerCase().contains('mod')) {
      confidenceColor = const Color(0xFFF59E0B);
    } else {
      confidenceColor = const Color(0xFF8B5CF6);
    }

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ForecastScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.12 : 0.05),
                const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.08 : 0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF8B5CF6)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'AI FORECAST',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$confidence Confidence',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: confidenceColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Month Prediction',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(predictedAmount),
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explore',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF8B5CF6)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection(
    BuildContext context,
    List<TransactionModel> transactions,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Latest verified spending records',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                );
              },
              child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Center(
              child: Text(
                'No transactions recorded yet.\nIngest a statement or tap + Add Expense.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        else
          ...transactions.map((t) => TransactionTile(transaction: t)),
      ],
    );
  }
}
