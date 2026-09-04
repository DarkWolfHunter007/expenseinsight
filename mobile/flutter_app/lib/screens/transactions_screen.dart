import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/category_colors.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        final transactions = provider.transactions;
        final allCats = ['All', ...CategoryColors.allCategories];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transactions'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort Transactions',
                onSelected: (val) {
                  final parts = val.split(':');
                  provider.setSorting(parts[0], parts[1]);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'date:desc', child: Text('Date: Newest first')),
                  const PopupMenuItem(value: 'date:asc', child: Text('Date: Oldest first')),
                  const PopupMenuItem(value: 'amount:desc', child: Text('Amount: Highest first')),
                  const PopupMenuItem(value: 'amount:asc', child: Text('Amount: Lowest first')),
                  const PopupMenuItem(value: 'merchant:asc', child: Text('Merchant: A-Z')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Search and Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search merchant or description...',
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
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final cat = allCats[i];
                    final isSelected = provider.selectedCategory.toLowerCase() == cat.toLowerCase();
                    final meta = cat != 'All' ? CategoryColors.getMeta(cat) : null;

                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      avatar: meta != null
                          ? Icon(meta.icon, size: 14, color: isSelected ? Colors.white : meta.color)
                          : null,
                      selectedColor: const Color(0xFF10B981),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          provider.setCategoryFilter(cat);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Review Filter Toggle & Count Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${transactions.length} Transactions',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    FilterChip(
                      label: const Text('Uncertain Only'),
                      selected: provider.needsReviewOnly,
                      selectedColor: const Color(0xFFFEE2E2),
                      checkmarkColor: const Color(0xFFEF4444),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: provider.needsReviewOnly ? const Color(0xFFEF4444) : Colors.grey,
                      ),
                      onSelected: (val) {
                        provider.setNeedsReviewOnly(val);
                      },
                    ),
                  ],
                ),
              ),

              // Transaction List
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                    : transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions match filters',
                                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: transactions.length,
                            itemBuilder: (ctx, i) {
                              return TransactionTile(transaction: transactions[i]);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
