import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../widgets/add_edit_cash_expense_dialog.dart';
import 'cash_expenses_screen.dart';
import 'dashboard_screen.dart';
import 'forecast_screen.dart';
import 'model_benchmark_screen.dart';
import 'more_screen.dart';
import 'transactions_screen.dart';
import 'upload_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _desktopSelectedIndex = 0;
  int _mobileSelectedIndex = 0; // 0: Overview, 1: Transactions, 2: Forecast, 3: More

  final List<Widget> _desktopScreens = const [
    DashboardScreen(),
    CashExpensesScreen(),
    UploadScreen(),
    TransactionsScreen(),
    ForecastScreen(),
    ModelBenchmarkScreen(),
  ];

  final List<Widget> _mobileScreens = const [
    DashboardScreen(),
    TransactionsScreen(),
    ForecastScreen(),
    MoreScreen(),
  ];

  int _mobileIndexToNav(int index) {
    switch (index) {
      case 0:
        return 0; // Overview
      case 1:
        return 1; // Transactions
      case 2:
        return 3; // Forecast
      case 3:
        return 4; // More
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uncertainCount = Provider.of<TransactionProvider>(context).uncertainTransactions.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // Desktop / Web Navigation Rail Layout (Preserved 100%)
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _desktopSelectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _desktopSelectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: Text('Dashboard'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.payments_outlined),
                      selectedIcon: Icon(Icons.payments_rounded),
                      label: Text('Cash Expenses'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.cloud_upload_outlined),
                      selectedIcon: Icon(Icons.cloud_upload_rounded),
                      label: Text('Ingest PDF'),
                    ),
                    NavigationRailDestination(
                      icon: Badge(
                        isLabelVisible: uncertainCount > 0,
                        label: Text('$uncertainCount'),
                        child: const Icon(Icons.receipt_long_outlined),
                      ),
                      selectedIcon: const Icon(Icons.receipt_long_rounded),
                      label: Text('Transactions'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome_rounded),
                      label: Text('Forecast'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.psychology_outlined),
                      selectedIcon: Icon(Icons.psychology_rounded),
                      label: Text('AI Benchmark'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _desktopScreens[_desktopSelectedIndex]),
              ],
            ),
          );
        }

        // Mobile Bottom Navigation Bar Layout (Rebalanced Hierarchy)
        return Scaffold(
          body: _mobileScreens[_mobileSelectedIndex],
          bottomNavigationBar: NavigationBar(
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: _mobileIndexToNav(_mobileSelectedIndex),
            onDestinationSelected: (int navIndex) {
              if (navIndex == 2) {
                // Unified Add Expense action
                AddEditCashExpenseDialog.show(context);
                return;
              }
              setState(() {
                if (navIndex == 0) {
                  _mobileSelectedIndex = 0;
                } else if (navIndex == 1) {
                  _mobileSelectedIndex = 1;
                } else if (navIndex == 3) {
                  _mobileSelectedIndex = 2;
                } else if (navIndex == 4) {
                  _mobileSelectedIndex = 3;
                }
              });
            },
            destinations: [
              const NavigationRequest(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Overview',
              ),
              NavigationRequest(
                icon: Badge(
                  isLabelVisible: uncertainCount > 0,
                  label: Text('$uncertainCount'),
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                selectedIcon: const Icon(Icons.receipt_long_rounded),
                label: 'Transactions',
              ),
              const NavigationRequest(
                icon: Icon(Icons.add_circle_outline_rounded, size: 28),
                selectedIcon: Icon(Icons.add_circle_rounded, size: 28),
                label: 'Add',
              ),
              const NavigationRequest(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: 'Forecast',
              ),
              const NavigationRequest(
                icon: Icon(Icons.more_horiz_outlined),
                selectedIcon: Icon(Icons.more_horiz_rounded),
                label: 'More',
              ),
            ],
          ),
        );
      },
    );
  }
}

class NavigationRequest extends NavigationDestination {
  const NavigationRequest({
    super.key,
    required super.icon,
    super.selectedIcon,
    required super.label,
    super.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationDestination(
      key: key,
      icon: icon,
      selectedIcon: selectedIcon,
      label: '',
      tooltip: tooltip ?? label,
    );
  }
}
