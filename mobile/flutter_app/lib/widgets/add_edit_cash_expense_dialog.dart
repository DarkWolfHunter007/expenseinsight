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
    final desc = _descriptionController.text.trim();

    final cashProv = Provider.of<CashExpenseProvider>(context, listen: false);

    bool success;
    if (widget.expense != null) {
      success = await cashProv.updateCashExpense(
        id: widget.expense!.id,
        amount: parsedAmount,
        category: _selectedCategory,
        expenseDate: formattedDate,
        description: desc.isNotEmpty ? desc : null,
      );
    } else {
      success = await cashProv.createCashExpense(
        amount: parsedAmount,
        category: _selectedCategory,
        expenseDate: formattedDate,
        description: desc.isNotEmpty ? desc : null,
      );
    }

    if (!mounted) return;

    if (success) {
      // Immediately refresh unified analytics & forecast if present
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
                            child: const Icon(
                              Icons.payments_rounded,
                              color: Color(0xFF10B981),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              isEditing ? 'Edit Cash Expense' : 'Add Cash Expense',
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
                  'Record physical cash or out-of-bank spending to track your true total expenditure.',
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
                    hintText: 'e.g. Lunch, Auto fare, Snacks',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Type indicator (Cash)
                Row(
                  children: [
                    Text(
                      'Payment Type: ',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.money_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            'Cash',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
