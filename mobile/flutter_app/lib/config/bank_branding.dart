import 'package:flutter/material.dart';

class BankBrandingInfo {
  final String name;
  final String shortCode;
  final IconData icon;
  final Color primaryColor;
  final Color lightBackgroundColor;
  final Color darkBackgroundColor;
  final String tagline;

  const BankBrandingInfo({
    required this.name,
    required this.shortCode,
    required this.icon,
    required this.primaryColor,
    required this.lightBackgroundColor,
    required this.darkBackgroundColor,
    required this.tagline,
  });
}

class BankBranding {
  static const Map<String, BankBrandingInfo> _bankMap = {
    'hdfc': BankBrandingInfo(
      name: 'HDFC Bank',
      shortCode: 'HDFC',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF004C8F),
      lightBackgroundColor: Color(0xFFEBF3FB),
      darkBackgroundColor: Color(0xFF0D253F),
      tagline: 'We Understand Your World',
    ),
    'state bank': BankBrandingInfo(
      name: 'State Bank of India',
      shortCode: 'SBI',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF1C3F94),
      lightBackgroundColor: Color(0xFFEEF2FC),
      darkBackgroundColor: Color(0xFF0F1E4A),
      tagline: 'The Banker to Every Indian',
    ),
    'sbi': BankBrandingInfo(
      name: 'State Bank of India',
      shortCode: 'SBI',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF1C3F94),
      lightBackgroundColor: Color(0xFFEEF2FC),
      darkBackgroundColor: Color(0xFF0F1E4A),
      tagline: 'The Banker to Every Indian',
    ),
    'icici': BankBrandingInfo(
      name: 'ICICI Bank',
      shortCode: 'ICICI',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFBA2A16),
      lightBackgroundColor: Color(0xFFFDEEEB),
      darkBackgroundColor: Color(0xFF38120D),
      tagline: 'Hum Hai Na, Khayal Aapka',
    ),
    'axis': BankBrandingInfo(
      name: 'Axis Bank',
      shortCode: 'AXIS',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF97144D),
      lightBackgroundColor: Color(0xFFFBEBF1),
      darkBackgroundColor: Color(0xFF33071A),
      tagline: 'Badhti Ka Naam Zindagi',
    ),
    'kotak': BankBrandingInfo(
      name: 'Kotak Mahindra Bank',
      shortCode: 'KOTAK',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFED1C24),
      lightBackgroundColor: Color(0xFFFDE8E9),
      darkBackgroundColor: Color(0xFF3A0608),
      tagline: 'Let\'s Make Money Simple',
    ),
    'punjab national': BankBrandingInfo(
      name: 'Punjab National Bank',
      shortCode: 'PNB',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFA20000),
      lightBackgroundColor: Color(0xFFFDE8E8),
      darkBackgroundColor: Color(0xFF330000),
      tagline: 'The Name You Can Bank Upon',
    ),
    'pnb': BankBrandingInfo(
      name: 'Punjab National Bank',
      shortCode: 'PNB',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFA20000),
      lightBackgroundColor: Color(0xFFFDE8E8),
      darkBackgroundColor: Color(0xFF330000),
      tagline: 'The Name You Can Bank Upon',
    ),
    'bank of baroda': BankBrandingInfo(
      name: 'Bank of Baroda',
      shortCode: 'BOB',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFF26522),
      lightBackgroundColor: Color(0xFFFEF0E9),
      darkBackgroundColor: Color(0xFF3B1808),
      tagline: 'India\'s International Bank',
    ),
    'bob': BankBrandingInfo(
      name: 'Bank of Baroda',
      shortCode: 'BOB',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFF26522),
      lightBackgroundColor: Color(0xFFFEF0E9),
      darkBackgroundColor: Color(0xFF3B1808),
      tagline: 'India\'s International Bank',
    ),
    'canara': BankBrandingInfo(
      name: 'Canara Bank',
      shortCode: 'CANARA',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF0066B3),
      lightBackgroundColor: Color(0xFFEBF4FC),
      darkBackgroundColor: Color(0xFF00223D),
      tagline: 'Together We Can',
    ),
    'union bank': BankBrandingInfo(
      name: 'Union Bank of India',
      shortCode: 'UBI',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF004A99),
      lightBackgroundColor: Color(0xFFEBF2FA),
      darkBackgroundColor: Color(0xFF001933),
      tagline: 'Good People to Bank With',
    ),
    'indusind': BankBrandingInfo(
      name: 'IndusInd Bank',
      shortCode: 'INDUSIND',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF8B1D1D),
      lightBackgroundColor: Color(0xFFF9ECEC),
      darkBackgroundColor: Color(0xFF2E0909),
      tagline: 'We Care... Dil Se',
    ),
    'idfc': BankBrandingInfo(
      name: 'IDFC FIRST Bank',
      shortCode: 'IDFC',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF990000),
      lightBackgroundColor: Color(0xFFFCE8E8),
      darkBackgroundColor: Color(0xFF300000),
      tagline: 'Always You First',
    ),
    'yes bank': BankBrandingInfo(
      name: 'Yes Bank',
      shortCode: 'YES',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF0B308A),
      lightBackgroundColor: Color(0xFFECEFF8),
      darkBackgroundColor: Color(0xFF04102E),
      tagline: 'Experience Our Expertise',
    ),
    'federal': BankBrandingInfo(
      name: 'Federal Bank',
      shortCode: 'FEDERAL',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF003B70),
      lightBackgroundColor: Color(0xFFEBF0F6),
      darkBackgroundColor: Color(0xFF001426),
      tagline: 'Your Perfect Banking Partner',
    ),
    'standard chartered': BankBrandingInfo(
      name: 'Standard Chartered',
      shortCode: 'SCB',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF009A44),
      lightBackgroundColor: Color(0xFFEBF7F0),
      darkBackgroundColor: Color(0xFF002B13),
      tagline: 'Here for Good',
    ),
    'citibank': BankBrandingInfo(
      name: 'Citibank',
      shortCode: 'CITI',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF003B70),
      lightBackgroundColor: Color(0xFFEBF0F6),
      darkBackgroundColor: Color(0xFF001426),
      tagline: 'Citi Never Sleeps',
    ),
    'hsbc': BankBrandingInfo(
      name: 'HSBC Bank',
      shortCode: 'HSBC',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFDB0011),
      lightBackgroundColor: Color(0xFFFDE6E8),
      darkBackgroundColor: Color(0xFF330004),
      tagline: 'Opening Up a World of Opportunity',
    ),
  };

  static BankBrandingInfo fromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return _defaultBranding('Bank Statement');
    }
    final lower = name.toLowerCase().trim();
    if (lower.startsWith('multiple')) {
      return const BankBrandingInfo(
        name: 'Multiple Bank Statements',
        shortCode: 'MULTI',
        icon: Icons.account_balance_rounded,
        primaryColor: Color(0xFF3B82F6),
        lightBackgroundColor: Color(0xFFEFF6FF),
        darkBackgroundColor: Color(0xFF0F172A),
        tagline: 'Aggregated Bank Statements',
      );
    }
    if (lower.contains('cash')) {
      return const BankBrandingInfo(
        name: 'Cash & Liquid Expenses',
        shortCode: 'CASH',
        icon: Icons.payments_rounded,
        primaryColor: Color(0xFF10B981),
        lightBackgroundColor: Color(0xFFECFDF5),
        darkBackgroundColor: Color(0xFF064E3B),
        tagline: 'Cash Spending Ledger',
      );
    }
    for (final entry in _bankMap.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return _defaultBranding(name);
  }

  static BankBrandingInfo _defaultBranding(String rawName) {
    return BankBrandingInfo(
      name: rawName.isEmpty ? 'Bank Statement' : rawName,
      shortCode: 'BANK',
      icon: Icons.account_balance_rounded,
      primaryColor: const Color(0xFF10B981),
      lightBackgroundColor: const Color(0xFFE8F8F0),
      darkBackgroundColor: const Color(0xFF09291C),
      tagline: 'Verified Financial Statement',
    );
  }
}
