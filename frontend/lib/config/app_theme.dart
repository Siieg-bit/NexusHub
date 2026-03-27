import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema visual do aplicativo, inspirado no design do Amino
/// com cores vibrantes e interface moderna. Suporta Dark e Light mode.
class AppTheme {
  AppTheme._();

  // ============================================================================
  // CORES PRIMÁRIAS (compartilhadas entre temas)
  // ============================================================================

  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color primaryDark = Color(0xFF4834D4);
  static const Color accentColor = Color(0xFF00CEC9);
  static const Color accentLight = Color(0xFF81ECEC);

  // ============================================================================
  // CORES DE FUNDO — DARK THEME
  // ============================================================================

  static const Color scaffoldBg = Color(0xFF0D0D0D);
  static const Color surfaceColor = Color(0xFF1A1A2E);
  static const Color cardColor = Color(0xFF16213E);
  static const Color cardColorLight = Color(0xFF1E2A4A);
  static const Color bottomNavBg = Color(0xFF0F0F23);
  static const Color dividerColor = Color(0xFF2D2D44);

  // ============================================================================
  // CORES DE FUNDO — LIGHT THEME
  // ============================================================================

  static const Color scaffoldBgLight = Color(0xFFF5F5F8);
  static const Color surfaceColorLight = Color(0xFFFFFFFF);
  static const Color cardColorLt = Color(0xFFFFFFFF);
  static const Color cardColorLtAlt = Color(0xFFF0F0F5);
  static const Color bottomNavBgLight = Color(0xFFFFFFFF);
  static const Color dividerColorLight = Color(0xFFE0E0E8);

  // ============================================================================
  // CORES DE TEXTO
  // ============================================================================

  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textHint = Color(0xFF666666);

  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF666680);
  static const Color textHintLight = Color(0xFF9999AA);

  // ============================================================================
  // CORES DE STATUS
  // ============================================================================

  static const Color successColor = Color(0xFF00B894);
  static const Color errorColor = Color(0xFFE17055);
  static const Color warningColor = Color(0xFFFDCB6E);
  static const Color infoColor = Color(0xFF74B9FF);
  static const Color onlineColor = Color(0xFF55EFC4);
  static const Color offlineColor = Color(0xFF636E72);

  // ============================================================================
  // CORES DE NÍVEL / GAMIFICAÇÃO
  // ============================================================================

  static const List<Color> levelColors = [
    Color(0xFF636E72), // Nível 1-2
    Color(0xFF00B894), // Nível 3-4
    Color(0xFF0984E3), // Nível 5-6
    Color(0xFF6C5CE7), // Nível 7-8
    Color(0xFFE17055), // Nível 9-10
    Color(0xFFFDCB6E), // Nível 11-14
    Color(0xFFFF6B6B), // Nível 15-17
    Color(0xFFE84393), // Nível 18-19
    Color(0xFFFFD700), // Nível 20+
  ];

  static Color getLevelColor(int level) {
    if (level <= 2) return levelColors[0];
    if (level <= 4) return levelColors[1];
    if (level <= 6) return levelColors[2];
    if (level <= 8) return levelColors[3];
    if (level <= 10) return levelColors[4];
    if (level <= 14) return levelColors[5];
    if (level <= 17) return levelColors[6];
    if (level <= 19) return levelColors[7];
    return levelColors[8];
  }

  // ============================================================================
  // DARK THEME
  // ============================================================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
          bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
          bodySmall: TextStyle(color: textSecondary, fontSize: 12),
          labelLarge: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: textSecondary, fontSize: 12),
          labelSmall: TextStyle(color: textHint, fontSize: 10),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bottomNavBg,
        selectedItemColor: primaryColor,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        hintStyle: const TextStyle(color: textHint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: dividerColor, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColorLight,
        selectedColor: primaryColor.withOpacity(0.3),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 0.5, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }

  // ============================================================================
  // LIGHT THEME
  // ============================================================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBgLight,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColorLight,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: textPrimaryLight, fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: textPrimaryLight, fontSize: 28, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(color: textPrimaryLight, fontSize: 24, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: textPrimaryLight, fontSize: 22, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(color: textPrimaryLight, fontSize: 20, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: textPrimaryLight, fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: textPrimaryLight, fontSize: 16, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: textPrimaryLight, fontSize: 14, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: textPrimaryLight, fontSize: 16),
          bodyMedium: TextStyle(color: textPrimaryLight, fontSize: 14),
          bodySmall: TextStyle(color: textSecondaryLight, fontSize: 12),
          labelLarge: TextStyle(color: textPrimaryLight, fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: textSecondaryLight, fontSize: 12),
          labelSmall: TextStyle(color: textHintLight, fontSize: 10),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColorLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(color: textPrimaryLight, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bottomNavBgLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textHintLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardTheme(
        color: cardColorLt,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColorLtAlt,
        hintStyle: const TextStyle(color: textHintLight),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: dividerColorLight, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColorLtAlt,
        selectedColor: primaryColor.withOpacity(0.15),
        labelStyle: const TextStyle(color: textPrimaryLight, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: dividerColorLight, thickness: 0.5, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColorLight,
        contentTextStyle: const TextStyle(color: textPrimaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondaryLight,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}
