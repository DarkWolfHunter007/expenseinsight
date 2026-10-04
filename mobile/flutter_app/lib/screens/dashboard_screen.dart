import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/category_colors.dart';
import '../models/analytics_model.dart';
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
import 'upload_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onOpenForecast;
  final VoidCallback? onOpenTransactions;

  const DashboardScreen({
    super.key,
    this.onOpenForecast,
    this.onOpenTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer3<AnalyticsProvider, ForecastProvider, TransactionProvider>(
      builder: (context, analyticsProv, forecastProv, txnProv, child) {
        final summary = analyticsProv.summary;
        final forecast = forecastProv.forecast;
        final uncertainCount = txnProv.uncertainTransactions.length;
        final recentTransactions = txnProv.transactions.take(4).toList();

        if (forecastProv.isStale && !forecastProv.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            forecastProv.fetchForecast();
          });
        }

        if (analyticsProv.isLoading && summary == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            ),
          );
        }

        if (analyticsProv.errorMessage != null && summary == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('ExpenseInsight')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load analytics',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      analyticsProv.errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        analyticsProv.fetchAnalytics();
                        forecastProv.fetchForecast();
                        txnProv.fetchTransactions();
                        Provider.of<CashExpenseProvider>(context, listen: false).fetchCashExpenses();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;

            if (isDesktop) {
              return _buildDesktopDashboard(
                context,
                summary,
                forecast,
                uncertainCount,
                recentTransactions,
                analyticsProv,
                forecastProv,
                txnProv,
                isDark,
              );
            }

            return _buildMobileDashboard(
              context,
              summary,
              forecast,
              uncertainCount,
              recentTransactions,
              analyticsProv,
              forecastProv,
              txnProv,
              isDark,
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MOBILE DASHBOARD: Personal Money Manager UX
  // ==========================================
  Widget _buildMobileDashboard(
    BuildContext context,
    AnalyticsSummaryModel? summary,
    ForecastModel? forecast,
    int uncertainCount,
    List<TransactionModel> recentTransactions,
    AnalyticsProvider analyticsProv,
    ForecastProvider forecastProv,
    TransactionProvider txnProv,
    bool isDark,
  ) {
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
            onPressed: () {
              analyticsProv.fetchAnalytics();
              forecastProv.fetchForecast();
              txnProv.fetchTransactions();
              Provider.of<CashExpenseProvider>(context, listen: false).fetchCashExpenses();
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
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
              // 0. Active Bank Statement Context (Compact)
              CompactStatementContextCard(
                bankName: summary?.bankName ?? 'Bank Statement',
                statementPeriod: summary?.statementPeriod,
                transactionCount: summary?.totalTransactionsCount ?? 0,
                statementCount: summary?.statementCount ?? 0,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 1. Spending Overview (Total Spending with subtle Bank vs Cash indicators)
              _buildMobileSpendingOverview(context, summary, isDark),
              const SizedBox(height: 16),

              // 2. Uncertain Transactions Alert Banner (if needed)
              if (uncertainCount > 0) ...[
                _buildUncertainAlertBanner(context, uncertainCount),
                const SizedBox(height: 16),
              ],

              // 3. AI Forecast Hero Card (Differentiator)
              _buildForecastHeroCard(context, forecast, summary, isDark),
              const SizedBox(height: 20),

              // 4. Category Spending Insights Summary
              _buildMobileSpendingInsights(context, summary, isDark),
              const SizedBox(height: 20),

              // 5. Recent Transactions Feed
              _buildRecentTransactionsSection(context, recentTransactions, isDark),
              const SizedBox(height: 20),

              // 6. Quick Action: + Add Expense Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => AddEditCashExpenseDialog.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('+ Add Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DESKTOP DASHBOARD: Analytical Workstation
  // ==========================================
  Widget _buildDesktopDashboard(
    BuildContext context,
    AnalyticsSummaryModel? summary,
    ForecastModel? forecast,
    int uncertainCount,
    List<TransactionModel> recentTransactions,
    AnalyticsProvider analyticsProv,
    ForecastProvider forecastProv,
    TransactionProvider txnProv,
    bool isDark,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ExpenseInsight Dashboard'),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BankStatementHeader(
                bankName: summary?.bankName ?? 'Bank Statement',
                statementPeriod: summary?.statementPeriod,
                transactionCount: summary?.totalTransactionsCount ?? 0,
              ),
              const SizedBox(height: 16),
              _buildMobileSpendingOverview(context, summary, isDark),
              const SizedBox(height: 16),
              if (uncertainCount > 0) ...[
                _buildUncertainAlertBanner(context, uncertainCount),
                const SizedBox(height: 16),
              ],
              _buildForecastHeroCard(context, forecast, summary, isDark),
              const SizedBox(height: 20),
              // Metric Cards Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                children: [
                  SpendingMetricCard(
                    title: 'This Month',
                    amount: summary?.thisMonthSpent ?? 0.0,
                    trendPercentage: summary?.monthOverMonthChangePct,
                    icon: Icons.calendar_today_rounded,
                    accentColor: const Color(0xFF3B82F6),
                  ),
                  SpendingMetricCard(
                    title: 'Net Savings',
                    amount: summary?.netSavings ?? 0.0,
                    subtitle: 'Income minus Expenses',
                    icon: Icons.savings_rounded,
                    accentColor: const Color(0xFF10B981),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Category Donut Chart
              _sectionHeader('Spending by Category', 'Category-wise distribution across all sources'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: CategoryDonutChart(
                  categories: summary?.categoriesBreakdown ?? [],
                  totalExpense: summary?.totalExpense ?? 0.0,
                ),
              ),
              const SizedBox(height: 24),
              // Monthly Spending Trend
              _sectionHeader('Monthly Spending Trend', 'Chronological income and expense breakdown'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: MonthlyTrendChart(monthlyData: analyticsProv.monthlySpending),
              ),
              const SizedBox(height: 24),
              // Top Merchants
              _sectionHeader('Top Spending Merchants', 'Normalized merchant rankings'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: MerchantRankingCard(merchants: summary?.topMerchants ?? []),
              ),
              const SizedBox(height: 24),
              // Recurring Subscriptions
              _sectionHeader('Recurring Subscriptions & Bills', 'Detected monthly repeating cycles'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: RecurringSubscriptionsCard(recurringItems: summary?.recurringExpenses ?? []),
              ),
              const SizedBox(height: 24),
              _buildRecentTransactionsSection(context, recentTransactions, isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // COMPONENT: Mobile Spending Overview Card
  // ==========================================
  Widget _buildMobileSpendingOverview(BuildContext context, AnalyticsSummaryModel? summary, bool isDark) {
    final bankSpent = summary?.bankSpending ?? 0.0;
    final cashSpent = summary?.cashSpending ?? 0.0;
    final totalSpent = summary?.totalExpense ?? 0.0;
    final period = summary?.statementPeriod ?? 'Total Personal Spending';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL SPENDING',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.9,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      period,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹${totalSpent.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          // Clean, subtle source tags
          Wrap(
            spacing: 10,
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

  // ==========================================
  // COMPONENT: AI Forecast Hero Card
  // ==========================================
  Widget _buildForecastHeroCard(BuildContext context, ForecastModel? forecast, AnalyticsSummaryModel? summary, bool isDark) {
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
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (onOpenForecast != null) {
            onOpenForecast!();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForecastScreen()),
            );
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.12 : 0.06),
                const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.08 : 0.03),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                            maxLines: 1,
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
                      confidence,
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
                        Text(
                          'Expected spending based on your history',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
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

  // ==========================================
  // COMPONENT: Mobile Spending Insights
  // ==========================================
  Widget _buildMobileSpendingInsights(BuildContext context, AnalyticsSummaryModel? summary, bool isDark) {
    final categories = summary?.categoriesBreakdown ?? [];
    final totalSpent = summary?.totalExpense ?? 0.0;
    final topCategories = categories.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
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
                      'SPENDING INSIGHTS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.9,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Top categories this period',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (topCategories.isEmpty)
            Text(
              'No category data available yet.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            )
          else
            ...topCategories.map((cat) {
              final meta = CategoryColors.getMeta(cat.category);
              final pct = totalSpent > 0 ? (cat.amount / totalSpent) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: meta.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(meta.icon, size: 14, color: meta.color),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cat.category,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '₹${cat.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        color: meta.color,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: Recent Transactions Section
  // ==========================================
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
                    'RECENT TRANSACTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.9,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Latest spending across bank & cash',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                if (onOpenTransactions != null) {
                  onOpenTransactions!();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                  );
                }
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

  // ==========================================
  // COMPONENT: Uncertain Alert Banner
  // ==========================================
  Widget _buildUncertainAlertBanner(BuildContext context, int uncertainCount) {
    return InkWell(
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
