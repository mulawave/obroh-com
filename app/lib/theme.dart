import 'package:flutter/material.dart';

class ObrohColors {
  static const Color obsidian950 = Color(0xFF080810);
  static const Color obsidian900 = Color(0xFF0E0E1A);
  static const Color obsidian800 = Color(0xFF161623);
  static const Color obsidian700 = Color(0xFF1F1F2E);

  // True metallic gold — not yellow
  static const Color gold200 = Color(0xFFE8D48A);
  static const Color gold300 = Color(0xFFD9BC65);
  static const Color gold400 = Color(0xFFCDA434); // Metallic gold
  static const Color gold500 = Color(0xFFB08820); // Rich deep gold
  static const Color gold600 = Color(0xFF8C6A10); // Antique gold

  static const Color foreground = Color(0xFFEDEBE6);
  static const Color foreground60 = Color(0x99EDEBE6);
  static const Color foreground40 = Color(0x66EDEBE6);
  static const Color foreground20 = Color(0x33EDEBE6);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);

  // Gradient shorthands
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold300, gold400, gold500],
  );

  static const goldBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold200, gold400, gold600],
  );
}

class ObrohTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ObrohColors.obsidian950,
      primaryColor: ObrohColors.gold400,
      colorScheme: const ColorScheme.dark(
        primary: ObrohColors.gold400,
        secondary: ObrohColors.gold500,
        surface: ObrohColors.obsidian900,
        error: ObrohColors.error,
        onPrimary: ObrohColors.obsidian950,
        onSecondary: ObrohColors.obsidian950,
        onSurface: ObrohColors.foreground,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ObrohColors.obsidian900,
        foregroundColor: ObrohColors.foreground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: ObrohColors.foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: ObrohColors.obsidian800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ObrohColors.gold400.withValues(alpha: 0.12)),
        ),
      ),
      // InputDecoration is overridden per-field via GoldTextField
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ObrohColors.obsidian800.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: ObrohColors.gold500.withValues(alpha: 0.25),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: ObrohColors.gold500.withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ObrohColors.gold400, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ObrohColors.error),
        ),
        labelStyle: const TextStyle(
          color: ObrohColors.gold400,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
        hintStyle: TextStyle(
          color: ObrohColors.foreground.withValues(alpha: 0.25),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ObrohColors.gold400,
          foregroundColor: ObrohColors.obsidian950,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ObrohColors.gold400,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ObrohColors.obsidian900,
        selectedItemColor: ObrohColors.gold400,
        unselectedItemColor: ObrohColors.foreground40,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      dividerTheme: DividerThemeData(
        color: ObrohColors.gold400.withValues(alpha: 0.12),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ObrohColors.obsidian800,
        contentTextStyle: const TextStyle(color: ObrohColors.foreground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
