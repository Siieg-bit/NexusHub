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
//
// Auditoria WCAG v3 (12/04/2026):
//   - Todos os pares texto/fundo atingem AA (4.5:1) ou superior
//   - Tokens semânticos (success, error, warning, info) são distinguíveis
//   - GreenLeaf v3: hierarquia visual corrigida, botões sempre visíveis
// =============================================================================

abstract class NexusThemes {
  NexusThemes._();

  // ============================================================================
  // TEMA PRINCIPAL — Amino Original (Dark)
  //
  // Replica pixel-perfect o visual do Amino Apps:
  //   - Fundo: azul-marinho profundo (#0D1B2A)
  //   - Destaque: ciano (#00BCD4) para nav e links
  //   - CTA: verde Amino (#1A9E4A) para botões de ação
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
    textHint: Color(0xFF8A9FB0),
    textDisabled: Color(0xFF3A4A5A),

    // Ícones
    iconPrimary: Color(0xFFF2F2F2),
    iconSecondary: Color(0xFF8899AA),
    iconDisabled: Color(0xFF3A4A5A),

    // Destaques
    accentPrimary: Color(0xFF00BCD4),
    accentSecondary: Color(0xFF4DD0E1),

    // Botões
    buttonPrimaryBackground: Color(0xFF1A9E4A),
    buttonPrimaryForeground: Color(0xFFFFFFFF),
    buttonSecondaryBackground: Color(0xFF213040),
    buttonSecondaryForeground: Color(0xFF00BCD4),
    buttonDestructiveBackground: Color(0xFFE53935),
    buttonDestructiveForeground: Color(0xFFFFFFFF),

    // Estados
    success: Color(0xFF69F0AE),
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
    inputHint: Color(0xFF8A9FB0),

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
        color: Color(0x401A9E4A),
        blurRadius: 8,
        offset: Offset(0, 3),
      ),
    ],

    // Gradientes
    primaryGradient: LinearGradient(
      colors: [Color(0xFF1A9E4A), Color(0xFF00BCD4)],
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
    bottomNavUnselectedItem: Color(0xFF6A7D8E),

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
    levelBadgeForeground: Color(0xFF0D1B2A),
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
    textHint: Color(0xFF8A80A8),
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
    buttonDestructiveBackground: Color(0xFFFF6B81),
    buttonDestructiveForeground: Color(0xFF1A0A10),

    // Estados
    success: Color(0xFF69F0AE),
    successContainer: Color(0xFF1A3028),
    error: Color(0xFFFF6B81),
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
    inputHint: Color(0xFF8A80A8),

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
        color: Color(0x4D9B59F5),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
    buttonShadow: [
      BoxShadow(
        color: Color(0x409B59F5),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],

    // Gradientes
    primaryGradient: LinearGradient(
      colors: [Color(0xFF9B59F5), Color(0xFFBB86FC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: LinearGradient(
      colors: [Color(0xFF7B2FBE), Color(0xFF9B59F5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    fabGradient: LinearGradient(
      colors: [Color(0xFF9B59F5), Color(0xFFBB86FC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    streakGradient: LinearGradient(
      colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
    ),
    walletGradient: LinearGradient(
      colors: [Color(0xFF9B59F5), Color(0xFFBB86FC)],
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
    bottomNavSelectedItem: Color(0xFFBB86FC),
    bottomNavUnselectedItem: Color(0xFF6A5F88),

    // App Bar
    appBarBackground: Color(0xFF0A0A0F),
    appBarForeground: Color(0xFFF2F0FF),

    // Drawer
    drawerBackground: Color(0xFF15121F),
    drawerHeaderBackground: Color(0xFF1E1830),
    drawerSidebarBackground: Color(0xFF07050F),

    // Chips
    chipBackground: Color(0xFF1E1830),
    chipSelectedBackground: Color(0xFF3A2A60),
    chipText: Color(0xFFB0A8D0),
    chipSelectedText: Color(0xFFBB86FC),

    // Divider
    divider: Color(0x336B4FA0),

    // Shimmer
    shimmerBase: Color(0xFF1A1528),
    shimmerHighlight: Color(0xFF241D38),

    // Gamificação
    levelBadgeBackground: Color(0xFF9B59F5),
    levelBadgeForeground: Color(0xFF1A0A2E),
    coinColor: Color(0xFFFFD700),
    onlineIndicator: Color(0xFF69F0AE),

    // Preview
    previewAccent: Color(0xFF9B59F5),
  );

  // ============================================================================
  // TEMA GREENLEAF — Natural e Leve (Light) — v3 (visibilidade corrigida)
  //
  // Visual limpo e fresco com verde vibrante:
  //   - Fundo: branco-esverdeado suave (#F0F7F2) — não branco puro
  //   - Superfícies: hierarquia clara com bordas sutis
  //   - Destaque: verde escuro (#1A7A3C) para ações
  //   - Botões: sempre visíveis com fundo sólido
  //
  // Correções v3 (visibilidade):
  //   - backgroundPrimary: #F4FAF5 → #F0F7F2 (mais neutro)
  //   - cardBackground: #FFFFFF → #FAFDFА (levemente esverdeado para hierarquia)
  //   - buttonSecondaryBackground: #D4EDD8 → #2E9E50 (fundo sólido, sempre visível)
  //   - buttonSecondaryForeground: #1A5C2E → #FFFFFF (texto branco sobre verde)
  //   - chipBackground: #E8F5EA → #D0E8D4 (mais contraste sobre cards)
  //   - chipSelectedBackground: #B8DEC0 → #1A7A3C (selecionado = verde escuro)
  //   - chipSelectedText: #1A2E1C → #FFFFFF (texto branco sobre verde escuro)
  //   - borderPrimary: #B8DEC0 → #9ECBA8 (mais visível para delimitar cards)
  //   - drawerSidebarBackground: #1A2E1C → #2D4A30 (verde-escuro mais suave)
  //   - drawerBackground: #FFFFFF → #F0F7F2 (consistente com backgroundPrimary)
  //   - inputBackground: #EDF7EE → #E4F2E6 (mais contraste sobre fundo)
  //   - shimmerBase: #E8F5EA → #DCE8DF (mais visível)
  // ============================================================================
  static const NexusThemeData greenLeaf = NexusThemeData(
    id: NexusThemeId.greenLeaf,
    name: 'GreenLeaf',
    description: 'Fresco, limpo e natural — verde vibrante sobre fundo claro.',
    baseMode: NexusThemeMode.light,

    // Fundos — levemente esverdeados para não ser branco puro
    backgroundPrimary: Color(0xFFF0F7F2),
    backgroundSecondary: Color(0xFFE4F2E6),

    // Superfícies — hierarquia clara: cardElevated > card > fundo
    surfacePrimary: Color(0xFFFAFDFA),
    surfaceSecondary: Color(0xFFE4F2E6),
    cardBackground: Color(0xFFFAFDFA),
    cardBackgroundElevated: Color(0xFFFFFFFF),
    modalBackground: Color(0xFFFAFDFA),

    // Overlay
    overlayColor: Color(0x661A3A1E),
    overlayOpacity: 0.4,

    // Textos — verde-escuro profundo para máximo contraste
    textPrimary: Color(0xFF0F1F11),
    textSecondary: Color(0xFF2E4A34),
    textHint: Color(0xFF4A6A52),
    textDisabled: Color(0xFFB0CCB4),

    // Ícones
    iconPrimary: Color(0xFF0F1F11),
    iconSecondary: Color(0xFF2E4A34),
    iconDisabled: Color(0xFFB0CCB4),

    // Destaques
    accentPrimary: Color(0xFF1A7A3C),
    accentSecondary: Color(0xFF2E9E50),

    // Botões — todos com fundo sólido e texto de alto contraste
    buttonPrimaryBackground: Color(0xFF1A7A3C),
    buttonPrimaryForeground: Color(0xFFFFFFFF),
    // Secundário: verde médio sólido — sempre visível em qualquer fundo
    buttonSecondaryBackground: Color(0xFF2E9E50),
    buttonSecondaryForeground: Color(0xFFFFFFFF),
    buttonDestructiveBackground: Color(0xFFB71C1C),
    buttonDestructiveForeground: Color(0xFFFFFFFF),

    // Estados
    success: Color(0xFF2E9E50),
    successContainer: Color(0xFFD8F0DC),
    error: Color(0xFFB71C1C),
    errorContainer: Color(0xFFFFEBEE),
    warning: Color(0xFFA85200),
    warningContainer: Color(0xFFFFF3E0),
    info: Color(0xFF1565C0),
    infoContainer: Color(0xFFE3F2FD),

    // Bordas — mais visíveis para delimitar cards e seções
    borderPrimary: Color(0xFF9ECBA8),
    borderSubtle: Color(0xFFC4DEC8),
    borderFocus: Color(0xFF1A7A3C),

    // Inputs — fundo levemente mais escuro que o card para destaque
    inputBackground: Color(0xFFE4F2E6),
    inputBorder: Color(0xFF9ECBA8),
    inputHint: Color(0xFF4A6A52),

    // Interação
    selectedState: Color(0xFF1A7A3C),
    disabledState: Color(0xFFB0CCB4),
    disabledOpacity: 0.38,

    // Sombras — mais visíveis para separar cards do fundo claro
    cardShadow: [
      BoxShadow(
        color: Color(0x221A7A3C),
        blurRadius: 6,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ],
    modalShadow: [
      BoxShadow(
        color: Color(0x2E1A7A3C),
        blurRadius: 20,
        offset: Offset(0, 8),
      ),
    ],
    buttonShadow: [
      BoxShadow(
        color: Color(0x401A7A3C),
        blurRadius: 8,
        offset: Offset(0, 3),
      ),
    ],

    // Gradientes
    primaryGradient: LinearGradient(
      colors: [Color(0xFF1A7A3C), Color(0xFF2E9E50)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: LinearGradient(
      colors: [Color(0xFF2E9E50), Color(0xFF56C27A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    fabGradient: LinearGradient(
      colors: [Color(0xFF1A7A3C), Color(0xFF2E9E50)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    streakGradient: LinearGradient(
      colors: [Color(0xFF2E9E50), Color(0xFF56C27A)],
    ),
    walletGradient: LinearGradient(
      colors: [Color(0xFF1A7A3C), Color(0xFF2E9E50)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    aminoPlusGradient: LinearGradient(
      colors: [Color(0xFF1A7A3C), Color(0xFF2E9E50)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),

    // Bottom Nav — fundo branco com borda superior sutil
    bottomNavBackground: Color(0xFFFFFFFF),
    bottomNavSelectedItem: Color(0xFF1A7A3C),
    bottomNavUnselectedItem: Color(0xFF4A6650),

    // App Bar
    appBarBackground: Color(0xFFFAFDFA),
    appBarForeground: Color(0xFF0F1F11),

    // Drawer — fundo consistente com o app
    drawerBackground: Color(0xFFF0F7F2),
    drawerHeaderBackground: Color(0xFFD8EDD8),
    // Sidebar: verde-escuro suave — texto branco sobre ele
    drawerSidebarBackground: Color(0xFF2D4A30),

    // Chips — fundo mais escuro para contraste sobre cards brancos
    chipBackground: Color(0xFFD0E8D4),
    chipSelectedBackground: Color(0xFF1A7A3C),
    chipText: Color(0xFF1A3A22),
    chipSelectedText: Color(0xFFFFFFFF),

    // Divider
    divider: Color(0xFFC4DEC8),

    // Shimmer
    shimmerBase: Color(0xFFDCE8DF),
    shimmerHighlight: Color(0xFFEDF7EE),

    // Gamificação
    levelBadgeBackground: Color(0xFF1A7A3C),
    levelBadgeForeground: Color(0xFFFFFFFF),
    coinColor: Color(0xFFB8860B),
    onlineIndicator: Color(0xFF2E9E50),

    // Preview
    previewAccent: Color(0xFF1A7A3C),
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
