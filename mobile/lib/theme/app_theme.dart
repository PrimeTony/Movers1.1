import 'package:flutter/material.dart';

class AppTheme {
  static const Color pureBlack = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF141414);
  static const Color surfaceDark = Color(0xFF141414);
  static const Color surfaceElevated = Color(0xFF212121);
  static const Color borderSubtle = Color(0xFF2E2E2E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textTertiary = Color(0xFF666666);
  static const Color statusGreen = Color(0xFF2ECC71);
  static const Color accentLime = Color(0xFFCDFF00);
  static const Color starGold = Color(0xFFFFD700);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: pureBlack,
      cardColor: darkSurface,
      dividerColor: borderSubtle,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: textPrimary,
        onPrimary: pureBlack,
        surface: darkSurface,
        onSurface: textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: pureBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

