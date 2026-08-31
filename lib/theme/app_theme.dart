import 'package:flutter/material.dart';

/// Curated colors matching the MEASURA royal blue tape measure brand identity.
class AppColors {
  // Brand Blues
  static const primaryBlue = Color(0xFF0B4FD8);
  static const primaryDark = Color(0xFF062B75);
  static const deepNavy = Color(0xFF0F172A);
  static const slateNavy = Color(0xFF1E293B);

  // Background & Surfaces
  static const background = Color(0xFFF8FAFD);
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const cardFill = Color(0xFFF1F5F9);
  static const surfaceSubtle = Color(0xFFE2E8F0);

  // Accents & States
  static const selectedBlue = Color(0xFF0B4FD8);
  static const selectedBlueLight = Color(0xFFDBEAFE);
  static const borderLight = Color(0xFFCBD5E1);

  // Status
  static const passGreen = Color(0xFF10B981);
  static const failRed = Color(0xFFEF4444);

  // Backwards compatibility aliases
  static const cream = background;
  static const navy = deepNavy;
}

ThemeData buildAppTheme() {
  const primary = AppColors.primaryBlue;

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      surface: AppColors.background,
      surfaceContainerHighest: AppColors.cardFill,
      onSurface: AppColors.deepNavy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceWhite,
      foregroundColor: AppColors.deepNavy,
      elevation: 0,
      scrolledUnderElevation: 1.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.deepNavy,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: AppColors.deepNavy,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        color: AppColors.deepNavy,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyLarge: TextStyle(color: AppColors.deepNavy, fontSize: 15),
      bodyMedium: TextStyle(color: AppColors.slateNavy, fontSize: 14),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepNavy,
        side: const BorderSide(color: AppColors.borderLight, width: 1.2),
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: AppColors.primaryBlue.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceWhite,
      labelStyle: const TextStyle(color: AppColors.slateNavy, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
