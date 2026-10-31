import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/category_colors.dart';
import '../models/budget_settings_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/budget_provider.dart';
import '../services/budget_notification_service.dart';

class _LimitRow {
  String category;
  final TextEditingController amount;

  _LimitRow(this.category, String initial) : amount = TextEditingController(text: initial);
}

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _monthlyController = TextEditingController();
  final List<_LimitRow> _rows = [];
  final _notifications = BudgetNotificationService.instance;

  bool _auto = true;
  bool _notificationsOn = false;
  bool _ready = false;
  String? _error;

  // Categories that can sensibly have a spending limit (income and transfers are not spending).
  static final _limitCategories = CategoryColors.allCategories
      .where((c) => !const {'Income', 'Transfers', 'Investments', 'Uncategorized'}.contains(c))
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _monthlyController.dispose();
    for (final row in _rows) {
      row.amount.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<BudgetProvider>();
    await provider.fetchSettings();
    final enabled = await _notifications.isEnabled();
    if (!mounted) return;
    final s = provider.settings;
    setState(() {
      _auto = s.autoLimits;
      _monthlyController.text = s.monthlyLimit != null ? s.monthlyLimit!.toStringAsFixed(0) : '';
      _rows
        ..clear()
        ..addAll(s.categoryLimits.entries.map((e) => _LimitRow(e.key, e.value.toStringAsFixed(0))));
      _notificationsOn = enabled && _notifications.permission == 'granted';
      _ready = true;
    });
  }

  double? _parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[₹,\s]'), '');
    return cleaned.isEmpty ? null : double.tryParse(cleaned);
  }

  Future<void> _save() async {
    final monthlyText = _monthlyController.text;
    final monthly = _parse(monthlyText);
    if (monthlyText.trim().isNotEmpty && (monthly == null || monthly < 0)) {
      setState(() => _error = 'Enter the monthly limit as a number, for example 8000.');
      return;
    }

    final limits = <String, double>{};
    for (final row in _rows) {
      final text = row.amount.text;
      if (text.trim().isEmpty) continue;
      final amount = _parse(text);
      if (amount == null || amount < 0) {
        setState(() => _error = 'Enter the ${row.category} limit as a number.');
        return;
      }
      if (amount > 0) limits[row.category] = amount;
    }
    if (!_auto && (monthly == null || monthly == 0) && limits.isEmpty) {
      setState(() => _error = 'Set a monthly limit or at least one category limit, or switch automatic limits back on.');
      return;
    }
    setState(() => _error = null);

    final budget = context.read<BudgetProvider>();
    final analytics = context.read<AnalyticsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await budget.save(BudgetSettingsModel(
      autoLimits: _auto,
      monthlyLimit: monthly != null && monthly > 0 ? monthly : null,
      categoryLimits: limits,
    ));
    if (!mounted) return;
    if (ok) {
      await analytics.fetchAnalytics();
      messenger.showSnackBar(const SnackBar(content: Text('Budget settings saved')));
      navigator.pop();
    } else {
      setState(() => _error = budget.errorMessage ?? 'Could not save. Please try again.');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final result = await _notifications.setEnabled(value);
    if (!mounted) return;
    setState(() => _notificationsOn = result);
    if (value && !result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications are blocked. Allow them for this site in your browser settings.')),
      );
    } else if (result) {
      _notifications.sendTest();
    }
  }

  void _addRow() {
    final used = _rows.map((r) => r.category).toSet();
    final next = _limitCategories.firstWhere((c) => !used.contains(c), orElse: () => '');
    if (next.isEmpty) return;
    setState(() => _rows.add(_LimitRow(next, '')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saving = context.watch<BudgetProvider>().isSaving;
    final summary = context.watch<AnalyticsProvider>().summary;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget & Alerts')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (summary != null && summary.budgetStatus != 'none')
                  _card(
                    isDark,
                    child: Row(
                      children: [
                        const Icon(Icons.savings_rounded, color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Current monthly budget: ₹${summary.monthlyBudget.toStringAsFixed(0)} '
                            '(${summary.budgetMode == 'manual' ? 'set by you' : 'automatic'})',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                _header('Monthly limit'),
                _card(
                  isDark,
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _auto,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (v) => setState(() => _auto = v),
                        title: Text('Set limits automatically',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _auto
                              ? 'Uses your average monthly spending from your uploaded statement.'
                              : 'Only the limits you set below are used.',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _monthlyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Monthly limit (optional)',
                          prefixText: '₹ ',
                          helperText: _auto
                              ? 'Leave empty to use the automatic amount. A number here replaces it.'
                              : 'The most you want to spend in a month.',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                _header('Category limits'),
                _card(
                  isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _auto
                            ? 'Automatic limits cover your main categories. Add a limit here to override one.'
                            : 'Pre-approve how much each category can spend per month.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      for (final row in _rows) _rowEditor(row),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _rows.length >= _limitCategories.length ? null : _addRow,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add category limit'),
                        ),
                      ),
                    ],
                  ),
                ),
                _header('Alerts'),
                _card(
                  isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: const [
                          _TierChip('80%  warning', Color(0xFFF59E0B)),
                          _TierChip('90%  critical', Color(0xFFF97316)),
                          _TierChip('over 100%  exceeded', Color(0xFFEF4444)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _notificationsOn,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: _notifications.supported ? _toggleNotifications : null,
                        title: Text('Browser notifications',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _notifications.supported
                              ? 'Get a notification the first time you reach each level in a month.'
                              : 'Not available in this browser or app.',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444))),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _rowEditor(_LimitRow row) {
    final used = _rows.where((r) => r != row).map((r) => r.category).toSet();
    final options = _limitCategories.where((c) => c == row.category || !used.contains(c)).toList();
    if (!options.contains(row.category)) options.add(row.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<String>(
              initialValue: row.category,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: [for (final c in options) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => row.category = v ?? row.category),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: TextField(
              controller: row.amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '₹ ', border: OutlineInputBorder(), isDense: true),
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _rows.remove(row);
              row.amount.dispose();
            }),
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.grey),
        ),
      );

  Widget _card(bool isDark, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: child,
      );
}

class _TierChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TierChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
