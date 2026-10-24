import 'package:flutter/material.dart';

class FacebookTheme {
  // Facebook Brand Colors
  static const Color fbBlue = Color(0xFF1877F2);
  static const Color fbBlueDark = Color(0xFF145DBF);
  static const Color fbBlueLight = Color(0xFFE7F3FF);
  
  // Facebook Background & Surfaces
  static const Color fbBackground = Color(0xFFF0F2F5);
  static const Color fbCardSurface = Color(0xFFFFFFFF);
  static const Color fbCardBorder = Color(0xFFE4E6EB);
  static const Color fbDivider = Color(0xFFCED0D4);
  
  // Facebook Text Colors
  static const Color fbTextPrimary = Color(0xFF050505);
  static const Color fbTextSecondary = Color(0xFF65676B);
  static const Color fbTextSubdued = Color(0xFF8A8D91);
  
  // Facebook Accent & Status Badges
  static const Color fbGreen = Color(0xFF31A24C);
  static const Color fbRed = Color(0xFFFA383E);
  static const Color fbAmber = Color(0xFFF7B125);

  // Common Semantic Aliases for clean widget consumption
  static const Color primaryColor = fbBlue;
  static const Color primaryDark = fbBlueDark;
  static const Color primaryLight = fbBlueLight;
  static const Color scaffoldBg = fbBackground;
  static const Color cardBg = fbCardSurface;
  static const Color surfaceColor = fbBackground;
  static const Color borderColor = fbCardBorder;
  static const Color dividerColor = fbDivider;
  static const Color textPrimary = fbTextPrimary;
  static const Color textSecondary = fbTextSecondary;
  static const Color textSubdued = fbTextSubdued;
  static const Color successColor = fbGreen;
  static const Color errorColor = fbRed;
  static const Color warningColor = fbAmber;

  static ThemeData get themeData => lightTheme;
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: fbBlue,
        primary: fbBlue,
        surface: fbCardSurface,
      ),
      scaffoldBackgroundColor: fbBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: fbCardSurface,
        elevation: 0.5,
        shadowColor: Color(0x33000000),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: fbTextPrimary),
        titleTextStyle: TextStyle(
          color: fbBlue,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: fbCardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: fbCardBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: fbBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fbTextSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: fbCardBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
