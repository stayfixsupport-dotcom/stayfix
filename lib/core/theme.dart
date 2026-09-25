import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SfColors {
  // ── Brand Gold Tokens ──────────────────────────────────────────
  static const Color gold = Color(0xFFD6A85A);
  static const Color goldDark = Color(0xFFB8863B);
  static const Color goldLight = Color(0xFFE8C27A);
  static const Color goldMuted = Color(0x33D6A85A);

  // ── Dark Mode Colors ───────────────────────────────────────────
  static const Color darkBgBase = Color(0xFF070707);
  static const Color darkBgSurface = Color(0xFF111111);
  static const Color darkBgCard = Color(0xFF18181B);
  static const Color darkBgField = Color(0xFF222225);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xB3FFFFFF);
  static const Color darkTextMuted = Color(0x80FFFFFF);
  static const Color darkBorder = Color(0x33D6A85A);

  // ── Light Mode (White Mode) Colors ─────────────────────────────
  static const Color lightBgBase = Color(0xFFF8F9FA);
  static const Color lightBgSurface = Color(0xFFFFFFFF);
  static const Color lightBgCard = Color(0xFFFFFFFF);
  static const Color lightBgField = Color(0xFFF1F3F5);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextMuted = Color(0xFF6B7280);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightCardShadow = Color(0x0F000000);

  // ── Status Colors ──────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}

class AppTheme {
  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SfColors.darkBgBase,
      primaryColor: SfColors.gold,
      colorScheme: const ColorScheme.dark(
        primary: SfColors.gold,
        secondary: SfColors.goldLight,
        surface: SfColors.darkBgSurface,
        onSurface: SfColors.darkTextPrimary,
        error: SfColors.danger,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).apply(
        bodyColor: SfColors.darkTextPrimary,
        displayColor: SfColors.darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: SfColors.darkBgCard,
        elevation: 0.0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: SfColors.darkBorder, width: 1.0),
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SfColors.darkBgBase,
        foregroundColor: SfColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SfColors.darkBgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SfColors.darkBgField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SfColors.gold, width: 1.5), // blue
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SfColors.lightBgBase,
      primaryColor: SfColors.goldDark,
      colorScheme: const ColorScheme.light(
        primary: SfColors.goldDark,
        secondary: SfColors.gold,
        surface: SfColors.lightBgSurface,
        onSurface: SfColors.lightTextPrimary,
        error: SfColors.danger,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).apply(
        bodyColor: SfColors.lightTextPrimary,
        displayColor: SfColors.lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: SfColors.lightBgCard,
        elevation: 2.0,
        margin: EdgeInsets.zero,
        shadowColor: SfColors.lightCardShadow,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: SfColors.lightBorder, width: 1.0),
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SfColors.lightBgSurface,
        foregroundColor: SfColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SfColors.lightBgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SfColors.lightBgField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SfColors.goldDark, width: 1.5),
        ),
      ),
    );
  }
}
