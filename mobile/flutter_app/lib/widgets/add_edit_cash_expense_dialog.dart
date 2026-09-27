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

/// Unified Manual Expense Entry Dialog (Bank or Cash)
/// Allows recording expenses from both Cash and Bank payment sources.
typedef AddExpenseDialog = AddEditCashExpenseDialog;

class AddEditCashExpenseDialog extends StatefulWidget {
  final CashExpenseModel? expense;

  const AddEditCashExpenseDialog({super.key, this.expense});

  static Future<bool?> show(BuildContext context, {CashExpenseModel? expense}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddEditCashExpenseDialog(expense: expense),
    );
  }

  @override
  State<AddEditCashExpenseDialog> createState() => _AddEditCashExpenseDialogState();
}

class _AddEditCashExpenseDialogState extends State<AddEditCashExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late DateTime _selectedDate;
  String _paymentSource = 'Cash'; // 'Cash' | 'Bank'
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final exp = widget.expense;
    _amountController = TextEditingController(
      text: exp != null ? exp.amount.toStringAsFixed(2) : '',
    );
    _descriptionController = TextEditingController(
      text: exp?.description ?? '',
    );

    final availableCategories = CategoryColors.allCategories;
    if (exp != null && availableCategories.contains(exp.category)) {
      _selectedCategory = exp.category;
    } else {
      _selectedCategory = availableCategories.isNotEmpty ? availableCategories.first : 'Food';
    }

    if (exp != null) {
      final method = exp.paymentMethod.toLowerCase();
      if (method == 'bank') {
        _paymentSource = 'Bank';
      } else if (method == 'upi') {
        _paymentSource = 'UPI';
      } else {
        _paymentSource = 'Cash';
      }
    } else {
      _paymentSource = 'Cash';
    }

    if (exp != null && exp.expenseDate.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(exp.expenseDate);
      } catch (_) {
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid positive amount.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final rawDesc = _descriptionController.text.trim();
    final finalDesc = rawDesc.isNotEmpty ? rawDesc : null;
    final paymentMethod = _paymentSource.toLowerCase();

    final cashProv = Provider.of<CashExpenseProvider>(context, listen: false);

    bool success;
    if (widget.expense != null) {
      success = await cashProv.updateCashExpense(
        id: widget.expense!.id,
        amount: parsedAmount,
        category: _selectedCategory,
        expenseDate: formattedDate,
        description: finalDesc,
        paymentMethod: paymentMethod,
      );
    } else {
      success = await cashProv.createCashExpense(
        amount: parsedAmount,
        category: _selectedCategory,
        expenseDate: formattedDate,
        description: finalDesc,
        paymentMethod: paymentMethod,
      );
    }

    if (!mounted) return;

    if (success) {
      // Immediately refresh unified analytics & forecast & transactions
      try {
        Provider.of<AnalyticsProvider>(context, listen: false).fetchAnalytics();
      } catch (_) {}
      try {
        Provider.of<ForecastProvider>(context, listen: false).fetchForecast();
      } catch (_) {}
      try {
        Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();
      } catch (_) {}
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = cashProv.errorMessage ?? 'Operation failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.expense != null;
    final categories = CategoryColors.allCategories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.add_card_rounded,
                              color: const Color(0xFF10B981),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              isEditing ? 'Edit Expense' : 'Add Expense',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Record manual spending to keep your financial intelligence and forecasts complete.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Payment Source Selector (PRD Phase 5)
                Text(
                  'Payment Source *',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Cash Option
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _paymentSource = 'Cash'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: _paymentSource == 'Cash'
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _paymentSource == 'Cash'
                                  ? const Color(0xFF10B981)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: _paymentSource == 'Cash' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_rounded,
                                size: 15,
                                color: _paymentSource == 'Cash' ? const Color(0xFF10B981) : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Cash',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _paymentSource == 'Cash'
                                        ? const Color(0xFF10B981)
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // UPI Option
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _paymentSource = 'UPI'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: _paymentSource == 'UPI'
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _paymentSource == 'UPI'
                                  ? const Color(0xFF8B5CF6)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: _paymentSource == 'UPI' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                size: 15,
                                color: _paymentSource == 'UPI' ? const Color(0xFF8B5CF6) : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'UPI',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _paymentSource == 'UPI'
                                        ? const Color(0xFF8B5CF6)
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Bank Option
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _paymentSource = 'Bank'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: _paymentSource == 'Bank'
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _paymentSource == 'Bank'
                                  ? const Color(0xFF3B82F6)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: _paymentSource == 'Bank' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_rounded,
                                size: 15,
                                color: _paymentSource == 'Bank' ? const Color(0xFF3B82F6) : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Bank',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _paymentSource == 'Bank'
                                        ? const Color(0xFF3B82F6)
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount Field
                Text(
                  'Amount *',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                    hintText: '0.00',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Amount is required.';
                    }
                    final numVal = double.tryParse(val.trim());
                    if (numVal == null) {
                      return 'Enter a valid numeric amount.';
                    }
                    if (numVal <= 0) {
                      return 'Amount must be greater than zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date Field
                Text(
                  'Date *',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMMM yyyy').format(_selectedDate),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF10B981)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category Field
                Text(
                  'Category *',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: categories.map((cat) {
                    final meta = CategoryColors.getMeta(cat);
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(meta.icon, size: 18, color: meta.color),
                          const SizedBox(width: 8),
                          Text(cat, style: GoogleFonts.inter(fontSize: 14)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Description Field
                Text(
                  'Description / Note (Optional)',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLength: 255,
                  decoration: InputDecoration(
                    hintText: 'e.g. Lunch, Auto fare, Grocery',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: Text('Cancel', style: GoogleFonts.inter()),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Add Expense',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
