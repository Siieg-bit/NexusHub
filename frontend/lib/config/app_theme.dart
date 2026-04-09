import 'package:flutter/material.dart';
import '../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// google_fonts removido — usando fonte local PlusJakartaSans de assets/fonts/

/// Tema visual do NexusHub — réplica pixel-perfect do Amino Apps.
/// Cores extraídas diretamente de screenshots do Amino original.
/// Fundo azul-marinho profundo (#0D1B2A), destaque ciano (#00BCD4),
/// verde apenas para CTAs (Check In, Join), rosa para FAB de criação.
class AppTheme {
  AppTheme._();

  // ============================================================================
  // CORES PRIMÁRIAS — AMINO ORIGINAL (pixel-perfect)
  // ============================================================================

  /// Verde Amino — usado APENAS para botões CTA (CHECK IN, Join, Entrar)
  static const Color primaryColor = Color(0xFF2DBE60); // amino-green (CTA only)
  static const Color primaryLight = Color(0xFF5CD882);
  static const Color primaryDark = Color(0xFF1E9B4A);

  /// Ciano/Teal — cor de destaque principal (nav ativa, links, destaques)
  static const Color accentColor =
      Color(0xFF00BCD4); // amino-cyan (destaque principal)
  static const Color accentLight = Color(0xFF4DD0E1);

  /// Rosa/Pink — cor do FAB de criação dentro de comunidades
  static const Color fabPink = Color(0xFFE91E63); // amino-pink (FAB criar post)
  static const Color fabPinkLight = Color(0xFFFF5C8D);

  // ============================================================================
  // CORES AMINO EXTRAS (do app original)
  // ============================================================================

  static const Color aminoPurple = Color(0xFF7C3AED); // amino-purple
  static const Color aminoMagenta = Color(0xFFE040FB); // amino-magenta
  static const Color aminoOrange = Color(0xFFFF9800); // amino-orange
  static const Color aminoYellow = Color(0xFFFFD54F); // amino-yellow
  static const Color aminoBlue = Color(0xFF2979FF); // amino-blue
  static const Color aminoRed = Color(0xFFE53935); // amino-red
  static const Color aminoCyan = Color(0xFF00BCD4); // amino-cyan (check-in)
  static const Color aminoPink = Color(0xFFE91E63); // amino-pink (FAB)

  // ============================================================================
  // CORES DE FUNDO — DARK THEME (padrão do Amino original)
  // Amino usa azul-marinho profundo, NÃO roxo-índigo, NÃO preto puro
  // ============================================================================

  static const Color scaffoldBg = Color(0xFF0D1B2A); // azul-marinho profundo
  static const Color surfaceColor =
      Color(0xFF1B2838); // card/surface azul escuro
  static const Color cardColor = Color(0xFF213040); // card azul-marinho médio
  static const Color cardColorLight = Color(0xFF2A3A4E); // hover/elevated card
  static const Color bottomNavBg =
      Color(0xFF0A1628); // nav bar azul-marinho mais escuro
  static const Color dividerColor =
      Color(0xFF2A3A50); // borda azul-marinho sutil

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
  // CORES DE TEXTO — DARK THEME
  // Amino usa cinza-azulado, NÃO arroxeado
  // ============================================================================

  static const Color textPrimary = Color(0xFFF2F2F2); // branco suave
  static const Color textSecondary =
      Color(0xFF8899AA); // cinza-azulado (não arroxeado)
  static const Color textHint = Color(0xFF5A6A7A); // hint cinza-azulado

  // ============================================================================
  // CORES DE TEXTO — LIGHT THEME
  // ============================================================================

  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF666680);
  static const Color textHintLight = Color(0xFF9999AA);

  // ============================================================================
  // CORES DE STATUS
  // ============================================================================

  static const Color successColor = Color(0xFF2DBE60); // verde Amino
  static const Color errorColor = Color(0xFFE53935); // amino-red
  static const Color warningColor = Color(0xFFFF9800); // amino-orange
  static const Color infoColor = Color(0xFF2979FF); // amino-blue
  static const Color onlineColor = Color(0xFF2DBE60); // verde Amino
  static const Color offlineColor = Color(0xFF636E72);

  // ============================================================================
  // CORES DE BADGES (do Amino original)
  // ============================================================================

  static const Color badgeLeader = Color(0xFF2DBE60);
  static const Color badgeCurator = Color(0xFFE040FB);
  static const Color badgeVerified = Color(0xFFE040FB);
  static const Color badgeStaff = Color(0xFFE040FB);
  static const Color badgeAge = Color(0xFF9C27B0);

  // ============================================================================
  // CORES DE NÍVEL / GAMIFICAÇÃO
  // ============================================================================

  static const List<Color> levelColors = [
    Color(0xFF636E72), // Nível 1-2
    Color(0xFF2DBE60), // Nível 3-4 (verde Amino)
    Color(0xFF2979FF), // Nível 5-6 (azul Amino)
    Color(0xFF7C3AED), // Nível 7-8 (roxo Amino)
    Color(0xFFE53935), // Nível 9-10 (vermelho Amino)
    Color(0xFFFF9800), // Nível 11-14 (laranja Amino)
    Color(0xFFFF6B6B), // Nível 15-17
    Color(0xFFE040FB), // Nível 18-19 (magenta Amino)
    Color(0xFFFFD700), // Nível 20+
  ];

  /// Gradiente do level badge (estilo Amino: azul)
  static const Color levelBadgeBg = Color(0xFF1565C0);
  static const Color levelBadgeFg = Color(0xFF42A5F5);
  static const Color levelBadgeNum = Color(0xFF0D47A1);

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
  // CORES ESPECIAIS — WALLET / STORE (Amino original)
  // ============================================================================

  static const Color walletHeaderBg =
      Color(0xFF4FC3F7); // azul celeste da carteira
  static const Color walletHeaderDark = Color(0xFF29B6F6);
  static const Color aminoPlusBannerStart =
      Color(0xFFFF9800); // gradiente laranja
  static const Color aminoPlusBannerEnd = Color(0xFFFFB74D);
  static const Color coinGold = Color(0xFFFFD700); // moeda dourada

  // ============================================================================
  // GRADIENTES AMINO
  // ============================================================================

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2DBE60), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente do FAB rosa de criação (dentro de comunidades)
  static const LinearGradient fabGradient = LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFFFF5C8D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient streakGradient = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
  );

  static const LinearGradient coinsGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
  );

  static const LinearGradient levelGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient = LinearGradient(
    colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient aminoPlusGradient = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: s.plusJakartaSans,
            color: textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold),
        displayMedium: TextStyle(
            color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(
            color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(
            color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(
            color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(
            color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        labelLarge: TextStyle(
            color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: textSecondary, fontSize: 12),
        labelSmall: TextStyle(color: textHint, fontSize: 10),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bottomNavBg,
        selectedItemColor: Colors.white,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        hintStyle: const TextStyle(color: textHint),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: dividerColor, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentColor, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: const BorderSide(color: accentColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColorLight,
        selectedColor: accentColor.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme:
          const DividerThemeData(color: dividerColor, thickness: 0.5, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: fabPink,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
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
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: s.plusJakartaSans,
            color: textPrimaryLight,
            fontSize: 32,
            fontWeight: FontWeight.bold),
        displayMedium: TextStyle(
            color: textPrimaryLight, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(
            color: textPrimaryLight, fontSize: 24, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(
            color: textPrimaryLight, fontSize: 22, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(
            color: textPrimaryLight, fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(
            color: textPrimaryLight, fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: textPrimaryLight, fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: textPrimaryLight, fontSize: 14, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(
            color: textSecondaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimaryLight, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimaryLight, fontSize: 14),
        bodySmall: TextStyle(color: textSecondaryLight, fontSize: 12),
        labelLarge: TextStyle(
            color: textPrimaryLight, fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: textSecondaryLight, fontSize: 12),
        labelSmall: TextStyle(color: textHintLight, fontSize: 10),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColorLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
            color: textPrimaryLight, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bottomNavBgLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textHintLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColorLt,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColorLtAlt,
        hintStyle: const TextStyle(color: textHintLight),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: dividerColorLight, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentColor, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: const BorderSide(color: accentColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColorLtAlt,
        selectedColor: accentColor.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: textPrimaryLight, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(
          color: dividerColorLight, thickness: 0.5, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColorLight,
        contentTextStyle: const TextStyle(color: textPrimaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColorLight,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondaryLight,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }
}

/// Extension em BuildContext para acessar cores theme-aware.
///
/// Em vez de usar `AppTheme.scaffoldBg` (sempre dark), use `context.scaffoldBg`
/// que retorna a cor correta baseada no tema atual (dark ou light).
///
/// Exemplo:
/// ```dart
/// // ANTES (hardcoded dark):
/// backgroundColor: AppTheme.scaffoldBg,
///
/// // DEPOIS (theme-aware):
/// backgroundColor: context.scaffoldBg,
/// ```
extension NexusColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Fundos ──
  Color get scaffoldBg =>
      _isDark ? AppTheme.scaffoldBg : AppTheme.scaffoldBgLight;
  Color get surfaceColor =>
      _isDark ? AppTheme.surfaceColor : AppTheme.surfaceColorLight;
  Color get cardBg => _isDark ? AppTheme.cardColor : AppTheme.cardColorLt;
  Color get cardBgAlt =>
      _isDark ? AppTheme.cardColorLight : AppTheme.cardColorLtAlt;
  Color get bottomNavBg =>
      _isDark ? AppTheme.bottomNavBg : AppTheme.bottomNavBgLight;
  Color get dividerClr =>
      _isDark ? AppTheme.dividerColor : AppTheme.dividerColorLight;

  // ── Textos ──
  Color get textPrimary =>
      _isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
  Color get textSecondary =>
      _isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
  Color get textHint => _isDark ? AppTheme.textHint : AppTheme.textHintLight;
}
