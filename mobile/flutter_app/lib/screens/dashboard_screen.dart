import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/analytics_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/merchant_ranking_card.dart';
import '../widgets/monthly_trend_chart.dart';
import '../widgets/recurring_subscriptions_card.dart';
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
                onPressed: () {
                  analyticsProv.fetchAnalytics();
                  forecastProv.fetchForecast();
                  txnProv.fetchTransactions();
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Analytics',
              ),
            ],
          ),
          body: RefreshIndicator(
            color: const Color(0xFF10B981),
            onRefresh: () async {
              await analyticsProv.fetchAnalytics();
              await forecastProv.fetchForecast();
              await txnProv.fetchTransactions();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statement Period Badge
                  if (summary?.statementPeriod != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            'Period: ${summary!.statementPeriod}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${summary.totalTransactionsCount} txns',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),

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
                        childAspectRatio: isWide ? 1.4 : 1.3,
                        children: [
                          SpendingMetricCard(
                            title: 'Total Spent',
                            amount: summary?.totalExpense ?? 0.0,
                            subtitle: 'Historical 6-Month Total',
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
}
