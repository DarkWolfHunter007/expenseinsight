import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF10B981); // Emerald Green
  static const Color primaryDark = Color(0xFF059669);
  static const Color primaryLight = Color(0xFFD1FAE5);

  static const Color secondaryColor = Color(0xFF6366F1); // Indigo
  static const Color accentColor = Color(0xFF3B82F6); // Blue

  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkCardSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkCardHighlight = Color(0xFF334155); // Slate 700

  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightCardSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  static const Color expenseRed = Color(0xFFEF4444);
  static const Color incomeGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: lightCardSurface,
      error: expenseRed,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryLight),
      headlineMedium: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimaryLight),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryLight),
      bodyLarge: GoogleFonts.inter(fontSize: 15, color: textPrimaryLight),
      bodyMedium: GoogleFonts.inter(fontSize: 13, color: textSecondaryLight),
    ),
    cardTheme: CardThemeData(
      color: lightCardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: lightBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimaryLight,
      ),
      iconTheme: const IconThemeData(color: textPrimaryLight),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: darkCardSurface,
      error: expenseRed,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryDark),
      headlineMedium: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimaryDark),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryDark),
      bodyLarge: GoogleFonts.inter(fontSize: 15, color: textPrimaryDark),
      bodyMedium: GoogleFonts.inter(fontSize: 13, color: textSecondaryDark),
    ),
    cardTheme: CardThemeData(
      color: darkCardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
      ),
      iconTheme: const IconThemeData(color: textPrimaryDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
