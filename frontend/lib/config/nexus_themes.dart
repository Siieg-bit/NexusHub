import 'package:flutter/material.dart';
import 'nexus_theme_data.dart';

// =============================================================================
// NexusThemes — Catálogo oficial de temas do NexusHub
//
// Cada tema é uma instância `const` de NexusThemeData com todos os tokens
// preenchidos. Para adicionar um novo tema, instancie NexusThemeData com
// os valores desejados e registre-o em [all].
//
// Temas disponíveis:
//   1. principal  — Amino original (Azul-marinho + Ciano/Verde, dark)
//   2. midnight   — Premium noturno (Roxo + Preto profundo, dark)
//   3. greenLeaf  — Natural e leve (Verde + Branco, light)
// =============================================================================

abstract class NexusThemes {
  NexusThemes._();

  // ============================================================================
  // TEMA PRINCIPAL — Amino Original (Dark)
  //
  // Replica pixel-perfect o visual do Amino Apps:
  //   - Fundo: azul-marinho profundo (#0D1B2A)
  //   - Destaque: ciano (#00BCD4) para nav e links
  //   - CTA: verde Amino (#2DBE60) para botões de ação
  //   - FAB: rosa (#E91E63) para criar posts
  // ============================================================================
  static const NexusThemeData principal = NexusThemeData(
    id: NexusThemeId.principal,
    name: 'Principal',
    description: 'O visual original do NexusHub — azul-marinho e ciano.',
    baseMode: NexusThemeMode.dark,

    // Fundos
    backgroundPrimary: Color(0xFF0D1B2A),
    backgroundSecondary: Color(0xFF0A1628),

    // Superfícies
    surfacePrimary: Color(0xFF1B2838),
    surfaceSecondary: Color(0xFF213040),
    cardBackground: Color(0xFF213040),
    cardBackgroundElevated: Color(0xFF2A3A4E),
    modalBackground: Color(0xFF1B2838),

    // Overlay
    overlayColor: Color(0xCC000000),
    overlayOpacity: 0.8,

    // Textos
    textPrimary: Color(0xFFF2F2F2),
    textSecondary: Color(0xFF8899AA),
    textHint: Color(0xFF5A6A7A),
    textDisabled: Color(0xFF3A4A5A),

    // Ícones
    iconPrimary: Color(0xFFF2F2F2),
    iconSecondary: Color(0xFF8899AA),
    iconDisabled: Color(0xFF3A4A5A),

    // Destaques
    accentPrimary: Color(0xFF00BCD4),
    accentSecondary: Color(0xFF4DD0E1),

    // Botões
    buttonPrimaryBackground: Color(0xFF2DBE60),
    buttonPrimaryForeground: Color(0xFFFFFFFF),
    buttonSecondaryBackground: Color(0xFF213040),
    buttonSecondaryForeground: Color(0xFF00BCD4),
    buttonDestructiveBackground: Color(0xFFE53935),
    buttonDestructiveForeground: Color(0xFFFFFFFF),

    // Estados
    success: Color(0xFF2DBE60),
    successContainer: Color(0xFF1A3A2A),
    error: Color(0xFFE53935),
    errorContainer: Color(0xFF3A1A1A),
    warning: Color(0xFFFF9800),
    warningContainer: Color(0xFF3A2A10),
    info: Color(0xFF2979FF),
    infoContainer: Color(0xFF1A2A3A),

    // Bordas
    borderPrimary: Color(0xFF2A3A50),
    borderSubtle: Color(0xFF1E2E40),
    borderFocus: Color(0xFF00BCD4),

    // Inputs
    inputBackground: Color(0xFF213040),
    inputBorder: Color(0xFF2A3A50),
    inputHint: Color(0xFF5A6A7A),

    // Interação
    selectedState: Color(0xFF00BCD4),
    disabledState: Color(0xFF2A3A50),
    disabledOpacity: 0.38,

    // Sombras
    cardShadow: [
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
    modalShadow: [
      BoxShadow(
        color: Color(0x4D000000),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
    buttonShadow: [
      BoxShadow(
        color: Color(0x402DBE60),
        blurRadius: 8,
        offset: Offset(0, 3),
      ),
    ],

    // Gradientes
    primaryGradient: LinearGradient(
      colors: [Color(0xFF2DBE60), Color(0xFF00BCD4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: LinearGradient(
      colors: [Color(0xFF00BCD4), Color(0xFF4DD0E1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    fabGradient: LinearGradient(
      colors: [Color(0xFFE91E63), Color(0xFFFF5C8D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    streakGradient: LinearGradient(
      colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
    ),
    walletGradient: LinearGradient(
      colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    aminoPlusGradient: LinearGradient(
      colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),

    // Bottom Nav
    bottomNavBackground: Color(0xFF0A1628),
    bottomNavSelectedItem: Color(0xFFFFFFFF),
    bottomNavUnselectedItem: Color(0xFF5A6A7A),

    // App Bar
    appBarBackground: Color(0xFF0D1B2A),
    appBarForeground: Color(0xFFF2F2F2),

    // Drawer
    drawerBackground: Color(0xFF1B2838),
    drawerHeaderBackground: Color(0xFF213040),
    drawerSidebarBackground: Color(0xFF000000),

    // Chips
    chipBackground: Color(0xFF213040),
    chipSelectedBackground: Color(0xFF1A3A4A),
    chipText: Color(0xFF8899AA),
    chipSelectedText: Color(0xFF00BCD4),

    // Divider
    divider: Color(0xFF2A3A50),

    // Shimmer
    shimmerBase: Color(0xFF213040),
    shimmerHighlight: Color(0xFF2A3A4E),

    // Gamificação
    levelBadgeBackground: Color(0xFF1565C0),
    levelBadgeForeground: Color(0xFF42A5F5),
    coinColor: Color(0xFFFFD700),
    onlineIndicator: Color(0xFF2DBE60),

    // Preview
    previewAccent: Color(0xFF00BCD4),
  );

  // ============================================================================
  // TEMA MIDNIGHT — Premium Noturno (Dark)
  //
  // Visual escuro e premium com roxo vivo:
  //   - Fundo: preto profundo (#0A0A0F)
  //   - Destaque: roxo (#9B59F5) vibrante
  //   - Superfícies: roxo-escuro translúcido
  //   - Sombras com glow roxo
  // ============================================================================
  static const NexusThemeData midnight = NexusThemeData(
    id: NexusThemeId.midnight,
    name: 'Midnight',
    description: 'Escuro, premium e noturno — roxo vibrante sobre o preto.',
    baseMode: NexusThemeMode.dark,

    // Fundos
    backgroundPrimary: Color(0xFF0A0A0F),
    backgroundSecondary: Color(0xFF0E0C18),

    // Superfícies
    surfacePrimary: Color(0xFF15121F),
    surfaceSecondary: Color(0xFF1E1830),
    cardBackground: Color(0xFF1A1528),
    cardBackgroundElevated: Color(0xFF241D38),
    modalBackground: Color(0xFF1E1830),

    // Overlay
    overlayColor: Color(0xB3100D1A),
    overlayOpacity: 0.7,

    // Textos
    textPrimary: Color(0xFFF2F0FF),
    textSecondary: Color(0xFFB0A8D0),
    textHint: Color(0xFF6A6080),
    textDisabled: Color(0xFF3A3050),

    // Ícones
    iconPrimary: Color(0xFFF2F0FF),
    iconSecondary: Color(0xFFB0A8D0),
    iconDisabled: Color(0xFF3A3050),

    // Destaques
    accentPrimary: Color(0xFF9B59F5),
    accentSecondary: Color(0xFFBB86FC),

    // Botões
    buttonPrimaryBackground: Color(0xFF9B59F5),
    buttonPrimaryForeground: Color(0xFFFFFFFF),
    buttonSecondaryBackground: Color(0xFF2A1F45),
    buttonSecondaryForeground: Color(0xFFBB86FC),
    buttonDestructiveBackground: Color(0xFFCF6679),
    buttonDestructiveForeground: Color(0xFFFFFFFF),

    // Estados
    success: Color(0xFF4CAF82),
    successContainer: Color(0xFF1A3028),
    error: Color(0xFFCF6679),
    errorContainer: Color(0xFF3A1A22),
    warning: Color(0xFFFFB74D),
    warningContainer: Color(0xFF3A2A10),
    info: Color(0xFF7986CB),
    infoContainer: Color(0xFF1A1E38),

    // Bordas
    borderPrimary: Color(0x556B4FA0),
    borderSubtle: Color(0x2A6B4FA0),
    borderFocus: Color(0xFF9B59F5),

    // Inputs
    inputBackground: Color(0xFF1A1528),
    inputBorder: Color(0x556B4FA0),
    inputHint: Color(0xFF6A6080),

    // Interação
    selectedState: Color(0xFF9B59F5),
    disabledState: Color(0xFF3A3050),
    disabledOpacity: 0.38,

    // Sombras — glow roxo característico do Midnight
    cardShadow: [
      BoxShadow(
        color: Color(0x339B59F5),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
    modalShadow: [
      BoxShadow(
        color: Color(0x669B59F5),
        blurRadius: 28,
        offset: Offset(0, 8),
      ),
    ],
    buttonShadow: [
      BoxShadow(
        color: Color(0x809B59F5),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],

    // Gradientes
    primaryGradient: LinearGradient(
      colors: [Color(0xFF9B59F5), Color(0xFF6A1FD4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: LinearGradient(
      colors: [Color(0xFFBB86FC), Color(0xFF9B59F5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    fabGradient: LinearGradient(
      colors: [Color(0xFF9B59F5), Color(0xFFBB86FC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    streakGradient: LinearGradient(
      colors: [Color(0xFFBB86FC), Color(0xFF9B59F5)],
    ),
    walletGradient: LinearGradient(
      colors: [Color(0xFF9B59F5), Color(0xFF6A1FD4)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    aminoPlusGradient: LinearGradient(
      colors: [Color(0xFF9B59F5), Color(0xFFBB86FC)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),

    // Bottom Nav
    bottomNavBackground: Color(0xFF0A0A0F),
    bottomNavSelectedItem: Color(0xFF9B59F5),
    bottomNavUnselectedItem: Color(0xFF6A6080),

    // App Bar
    appBarBackground: Color(0xFF0A0A0F),
    appBarForeground: Color(0xFFF2F0FF),

    // Drawer
    drawerBackground: Color(0xFF12101A),
    drawerHeaderBackground: Color(0xFF1E1830),
    drawerSidebarBackground: Color(0xFF050408),

    // Chips
    chipBackground: Color(0xFF1E1830),
    chipSelectedBackground: Color(0xFF3A2060),
    chipText: Color(0xFFB0A8D0),
    chipSelectedText: Color(0xFFBB86FC),

    // Divider
    divider: Color(0x2A6B4FA0),

    // Shimmer
    shimmerBase: Color(0xFF1A1528),
    shimmerHighlight: Color(0xFF2A2040),

    // Gamificação
    levelBadgeBackground: Color(0xFF6A1FD4),
    levelBadgeForeground: Color(0xFFBB86FC),
    coinColor: Color(0xFFFFD700),
    onlineIndicator: Color(0xFF4CAF82),

    // Preview
    previewAccent: Color(0xFF9B59F5),
  );

  // ============================================================================
  // TEMA GREENLEAF — Natural e Leve (Light)
  //
  // Visual claro, fresco e equilibrado:
  //   - Fundo: branco e verde muito claro (#F4FAF5)
  //   - Destaque: verde vibrante (#2E9E50)
  //   - Superfícies: branco puro
  //   - Sombras suaves com toque verde
  // ============================================================================
  static const NexusThemeData greenLeaf = NexusThemeData(
    id: NexusThemeId.greenLeaf,
    name: 'GreenLeaf',
    description: 'Fresco, limpo e natural — verde vibrante sobre fundo claro.',
    baseMode: NexusThemeMode.light,

    // Fundos
    backgroundPrimary: Color(0xFFF4FAF5),
    backgroundSecondary: Color(0xFFE8F5EA),

    // Superfícies
    surfacePrimary: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFEDF7EE),
    cardBackground: Color(0xFFFFFFFF),
    cardBackgroundElevated: Color(0xFFF0F9F1),
    modalBackground: Color(0xFFFFFFFF),

    // Overlay
    overlayColor: Color(0x661A3A1E),
    overlayOpacity: 0.4,

    // Textos
    textPrimary: Color(0xFF1A2E1C),
    textSecondary: Color(0xFF4A6650),
    textHint: Color(0xFF8AAA90),
    textDisabled: Color(0xFFB0CCB4),

    // Ícones
    iconPrimary: Color(0xFF1A2E1C),
    iconSecondary: Color(0xFF4A6650),
    iconDisabled: Color(0xFFB0CCB4),

    // Destaques
    accentPrimary: Color(0xFF2E9E50),
    accentSecondary: Color(0xFF56C27A),

    // Botões
    buttonPrimaryBackground: Color(0xFF2E9E50),
    buttonPrimaryForeground: Color(0xFFFFFFFF),
    buttonSecondaryBackground: Color(0xFFE0F5E4),
    buttonSecondaryForeground: Color(0xFF2E9E50),
    buttonDestructiveBackground: Color(0xFFD32F2F),
    buttonDestructiveForeground: Color(0xFFFFFFFF),

    // Estados
    success: Color(0xFF2E9E50),
    successContainer: Color(0xFFD8F0DC),
    error: Color(0xFFD32F2F),
    errorContainer: Color(0xFFFFEBEE),
    warning: Color(0xFFF57C00),
    warningContainer: Color(0xFFFFF3E0),
    info: Color(0xFF1976D2),
    infoContainer: Color(0xFFE3F2FD),

    // Bordas
    borderPrimary: Color(0xFFB8DEC0),
    borderSubtle: Color(0xFFD8EDD8),
    borderFocus: Color(0xFF2E9E50),

    // Inputs
    inputBackground: Color(0xFFEDF7EE),
    inputBorder: Color(0xFFB8DEC0),
    inputHint: Color(0xFF8AAA90),

    // Interação
    selectedState: Color(0xFF2E9E50),
    disabledState: Color(0xFFB0CCB4),
    disabledOpacity: 0.38,

    // Sombras
    cardShadow: [
      BoxShadow(
        color: Color(0x1A2E9E50),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
    modalShadow: [
      BoxShadow(
        color: Color(0x262E9E50),
        blurRadius: 20,
        offset: Offset(0, 8),
      ),
    ],
    buttonShadow: [
      BoxShadow(
        color: Color(0x402E9E50),
        blurRadius: 8,
        offset: Offset(0, 3),
      ),
    ],

    // Gradientes
    primaryGradient: LinearGradient(
      colors: [Color(0xFF2E9E50), Color(0xFF56C27A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: LinearGradient(
      colors: [Color(0xFF56C27A), Color(0xFF2E9E50)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    fabGradient: LinearGradient(
      colors: [Color(0xFF2E9E50), Color(0xFF1B7A38)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    streakGradient: LinearGradient(
      colors: [Color(0xFF56C27A), Color(0xFF2E9E50)],
    ),
    walletGradient: LinearGradient(
      colors: [Color(0xFF56C27A), Color(0xFF2E9E50)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    aminoPlusGradient: LinearGradient(
      colors: [Color(0xFF2E9E50), Color(0xFF56C27A)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),

    // Bottom Nav
    bottomNavBackground: Color(0xFFFFFFFF),
    bottomNavSelectedItem: Color(0xFF2E9E50),
    bottomNavUnselectedItem: Color(0xFF8AAA90),

    // App Bar
    appBarBackground: Color(0xFFFFFFFF),
    appBarForeground: Color(0xFF1A2E1C),

    // Drawer
    drawerBackground: Color(0xFFFFFFFF),
    drawerHeaderBackground: Color(0xFFE8F5EA),
    drawerSidebarBackground: Color(0xFF1A2E1C),

    // Chips
    chipBackground: Color(0xFFE8F5EA),
    chipSelectedBackground: Color(0xFFB8DEC0),
    chipText: Color(0xFF4A6650),
    chipSelectedText: Color(0xFF1A2E1C),

    // Divider
    divider: Color(0xFFD0E8D4),

    // Shimmer
    shimmerBase: Color(0xFFE8F5EA),
    shimmerHighlight: Color(0xFFF4FAF5),

    // Gamificação
    levelBadgeBackground: Color(0xFF1B7A38),
    levelBadgeForeground: Color(0xFF56C27A),
    coinColor: Color(0xFFFFD700),
    onlineIndicator: Color(0xFF2E9E50),

    // Preview
    previewAccent: Color(0xFF2E9E50),
  );

  // ============================================================================
  // Catálogo e utilitários
  // ============================================================================

  /// Lista completa de temas disponíveis (na ordem de exibição na UI).
  static const List<NexusThemeData> all = [
    principal,
    midnight,
    greenLeaf,
  ];

  /// Retorna um tema pelo seu [NexusThemeId].
  /// Retorna [principal] como fallback se o id não for encontrado.
  static NexusThemeData byId(NexusThemeId id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => principal,
    );
  }
}
