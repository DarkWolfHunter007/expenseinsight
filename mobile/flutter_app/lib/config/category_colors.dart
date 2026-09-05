import 'package:flutter/material.dart';

class CategoryMeta {
  final String name;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const CategoryMeta({
    required this.name,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

class CategoryColors {
  static const Map<String, CategoryMeta> _categoryMap = {
    'Food': CategoryMeta(
      name: 'Food',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFF6B6B),
      backgroundColor: Color(0xFFFFECEC),
    ),
    'Groceries': CategoryMeta(
      name: 'Groceries',
      icon: Icons.shopping_basket_rounded,
      color: Color(0xFF20BF6B),
      backgroundColor: Color(0xFFE8F8F0),
    ),
    'Shopping': CategoryMeta(
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF4D96FF),
      backgroundColor: Color(0xFFEDF5FF),
    ),
    'Travel': CategoryMeta(
      name: 'Travel',
      icon: Icons.directions_car_rounded,
      color: Color(0xFFFF9F43),
      backgroundColor: Color(0xFFFFF4E8),
    ),
    'Bills': CategoryMeta(
      name: 'Bills',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF9C88FF),
      backgroundColor: Color(0xFFF3EFFF),
    ),
    'Entertainment': CategoryMeta(
      name: 'Entertainment',
      icon: Icons.movie_filter_rounded,
      color: Color(0xFFFF5252),
      backgroundColor: Color(0xFFFFEAEA),
    ),
    'Healthcare': CategoryMeta(
      name: 'Healthcare',
      icon: Icons.medical_services_rounded,
      color: Color(0xFF00D2D3),
      backgroundColor: Color(0xFFE6FAFA),
    ),
    'Fuel': CategoryMeta(
      name: 'Fuel',
      icon: Icons.local_gas_station_rounded,
      color: Color(0xFFFF793F),
      backgroundColor: Color(0xFFFFF0E8),
    ),
    'Rent': CategoryMeta(
      name: 'Rent',
      icon: Icons.home_rounded,
      color: Color(0xFF3867D6),
      backgroundColor: Color(0xFFEBF0FA),
    ),
    'Personal Care': CategoryMeta(
      name: 'Personal Care',
      icon: Icons.spa_rounded,
      color: Color(0xFFFC5C65),
      backgroundColor: Color(0xFFFFEEF0),
    ),
    'Education': CategoryMeta(
      name: 'Education',
      icon: Icons.school_rounded,
      color: Color(0xFF45AAF2),
      backgroundColor: Color(0xFFEDF7FD),
    ),
    'Insurance': CategoryMeta(
      name: 'Insurance',
      icon: Icons.shield_rounded,
      color: Color(0xFF26DE81),
      backgroundColor: Color(0xFFE9FCF2),
    ),
    'Investments': CategoryMeta(
      name: 'Investments',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF10AC84),
      backgroundColor: Color(0xFFE7F7F3),
    ),
    'Income': CategoryMeta(
      name: 'Income',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF2ED573),
      backgroundColor: Color(0xFFEAFBF1),
    ),
    'Transfers': CategoryMeta(
      name: 'Transfers',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFF747D8C),
      backgroundColor: Color(0xFFF1F2F6),
    ),
    'Cash Withdrawal': CategoryMeta(
      name: 'Cash Withdrawal',
      icon: Icons.atm_rounded,
      color: Color(0xFF57606F),
      backgroundColor: Color(0xFFEEF0F2),
    ),
    'Other': CategoryMeta(
      name: 'Other',
      icon: Icons.category_rounded,
      color: Color(0xFFA4B0BE),
      backgroundColor: Color(0xFFF1F2F6),
    ),
    'Uncategorized': CategoryMeta(
      name: 'Uncategorized',
      icon: Icons.help_outline_rounded,
      color: Color(0xFFFF4757),
      backgroundColor: Color(0xFFFFECEE),
    ),
  };

  static CategoryMeta getMeta(String? categoryName) {
    if (categoryName == null || categoryName.isEmpty) {
      return _categoryMap['Other']!;
    }
    // Case-insensitive lookup
    for (final entry in _categoryMap.entries) {
      if (entry.key.toLowerCase() == categoryName.toLowerCase()) {
        return entry.value;
      }
    }
    if (categoryName.toLowerCase() == 'uncertain') {
      return _categoryMap['Uncategorized']!;
    }
    return _categoryMap['Other']!;
  }

  static List<String> get allCategories => _categoryMap.keys.toList();
}
