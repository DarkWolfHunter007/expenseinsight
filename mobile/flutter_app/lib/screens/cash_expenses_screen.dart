import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/category_colors.dart';
import '../models/cash_expense_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/cash_expense_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/add_edit_cash_expense_dialog.dart';

class CashExpensesScreen extends StatefulWidget {
  const CashExpensesScreen({super.key});

  @override
  State<CashExpensesScreen> createState() => _CashExpensesScreenState();
}

class _CashExpensesScreenState extends State<CashExpensesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CashExpenseProvider>(context, listen: false).fetchCashExpenses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteExpense(BuildContext context, CashExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cash Expense'),
        content: Text(
          'Are you sure you want to delete this ₹${expense.amount.toStringAsFixed(2)} ${expense.category} expense? This will immediately update your total personal spending analytics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final cashProv = Provider.of<CashExpenseProvider>(context, listen: false);
      final analyticsProv = Provider.of<AnalyticsProvider>(context, listen: false);
      final forecastProv = Provider.of<ForecastProvider>(context, listen: false);
      TransactionProvider? txProv;
      try {
        txProv = Provider.of<TransactionProvider>(context, listen: false);
      } catch (_) {}

      final success = await cashProv.deleteCashExpense(expense.id);
      if (success) {
        analyticsProv.fetchAnalytics();
        forecastProv.fetchForecast();
        txProv?.fetchTransactions();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cash expense deleted successfully.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CashExpenseProvider>(
      builder: (context, provider, child) {
        final expenses = provider.cashExpenses;
        final allCats = ['All', ...CategoryColors.allCategories];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Cash Expenses'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'Add Cash Expense',
                onPressed: () => AddEditCashExpenseDialog.show(context),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort Expenses',
                onSelected: (val) {
                  final parts = val.split(':');
                  provider.setSorting(parts[0], parts[1]);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'expense_date:desc', child: Text('Date: Newest first')),
                  const PopupMenuItem(value: 'expense_date:asc', child: Text('Date: Oldest first')),
                  const PopupMenuItem(value: 'amount:desc', child: Text('Amount: Highest first')),
                  const PopupMenuItem(value: 'amount:asc', child: Text('Amount: Lowest first')),
                  const PopupMenuItem(value: 'category:asc', child: Text('Category: A-Z')),
                ],
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
          body: Column(
            children: [
              // Summary Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF064E3B), const Color(0xFF047857)]
                        : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recorded Cash Spending',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${provider.totalCashSpending.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF064E3B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${expenses.length} item${expenses.length == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search cash expense note or category...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    provider.setSearchQuery(val);
                  },
                ),
              ),

              // Category Filter Chips
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: allCats.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final cat = allCats[i];
                    final isSelected = (provider.selectedCategory == null && cat == 'All') ||
                        provider.selectedCategory == cat;
                    return FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        provider.setCategoryFilter(cat == 'All' ? null : cat);
                      },
                      selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF10B981),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Expense List or Empty State
              Expanded(
                child: provider.isLoading && expenses.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                    : expenses.isEmpty
                        ? _buildEmptyState(context, isDark)
                        : RefreshIndicator(
                            color: const Color(0xFF10B981),
                            onRefresh: () async {
                              await provider.fetchCashExpenses();
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
                              itemCount: expenses.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final item = expenses[i];
                                return _buildExpenseTile(context, item, isDark);
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_outlined,
                size: 48,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No cash expenses recorded yet.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track cash spending here so your total spending reflects both bank and physical cash expenses.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => AddEditCashExpenseDialog.show(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Cash Expense', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTile(BuildContext context, CashExpenseModel item, bool isDark) {
    final meta = CategoryColors.getMeta(item.category);
    DateTime? dt;
    try {
      dt = DateTime.parse(item.expenseDate);
    } catch (_) {}
    final formattedDate = dt != null ? DateFormat('dd MMM yyyy').format(dt) : item.expenseDate;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: meta.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(meta.icon, color: meta.color, size: 22),
        ),
        title: Row(
          children: [
            Text(
              item.category,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Cash',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF059669),
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.description!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              formattedDate,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${item.amount.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (val) {
                if (val == 'edit') {
                  AddEditCashExpenseDialog.show(context, expense: item);
                } else if (val == 'delete') {
                  _deleteExpense(context, item);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
