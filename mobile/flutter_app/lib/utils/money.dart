import 'package:intl/intl.dart';

final NumberFormat _indian = NumberFormat.decimalPattern('en_IN');

/// Whole rupees with Indian digit grouping: 16343.82 -> "₹16,344", -1677.82 -> "-₹1,678".
String rupees(double value) => '${value < 0 ? '-' : ''}₹${_indian.format(value.abs().round())}';
