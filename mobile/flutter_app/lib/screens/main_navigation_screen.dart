import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import 'cash_expenses_screen.dart';
import 'dashboard_screen.dart';
import 'forecast_screen.dart';
import 'model_benchmark_screen.dart';
import 'transactions_screen.dart';
import 'upload_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    CashExpensesScreen(),
    UploadScreen(),
    TransactionsScreen(),
    ForecastScreen(),
    ModelBenchmarkScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final uncertainCount = Provider.of<TransactionProvider>(context).uncertainTransactions.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // Desktop / Web Navigation Rail Layout
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
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
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          );
        }

        // Mobile Bottom Navigation Bar Layout
        return Scaffold(
          body: _screens[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: _selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: [
              const NavigationRequest(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Overview',
              ),
              const NavigationRequest(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Cash',
              ),
              const NavigationRequest(
                icon: Icon(Icons.cloud_upload_outlined),
                selectedIcon: Icon(Icons.cloud_upload_rounded),
                label: 'Upload',
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
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: 'Forecast',
              ),
              const NavigationRequest(
                icon: Icon(Icons.psychology_outlined),
                selectedIcon: Icon(Icons.psychology_rounded),
                label: 'AI Model',
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
