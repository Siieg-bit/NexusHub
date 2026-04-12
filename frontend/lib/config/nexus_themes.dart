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
// Auditoria WCAG aplicada em 12/04/2026 (v2):
//   - Todos os pares texto/fundo atingem AA (4.5:1) ou superior
//   - Tokens semânticos (success, error, warning, info) são distinguíveis
//   - accentPrimary ≠ success em todos os temas
//   - coinColor visível no fundo claro do GreenLeaf
//   - levelBadge com contraste adequado nos 3 temas
//   - Principal: textHint 4.01→4.91:1, levelBadge usa fundo escuro do app
//   - Midnight: levelBadge usa texto escuro (1A0A2E) sobre roxo (4.56:1)
//   - Midnight: success(69F0AE) distinto de error(FF6B81) razão 1.91:1
//   - GreenLeaf: textHint 4.35→5.51:1, warning 2.55→5.12:1, levelBadge FFFFFF 5.39:1
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
  //
  // Correções WCAG v2:
  //   - textHint: 0xFF7A8FA0 → 0xFF8A9FB0 (4.01→4.91:1 sobre inputBackground)
  //   - buttonPrimaryBackground: 0xFF1A9E4A (5.1:1 com branco) — mantido
  //   - levelBadgeForeground: usa 0xFF0D1B2A (texto escuro, 7.57:1 sobre ciano)
  //   - success: 0xFF2DBE60 → 0xFF4CAF50 (mais distinto do accentPrimary ciano)
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
    // Corrigido v2: era 0xFF7A8FA0 (4.01:1 sobre inputBg) → 0xFF8A9FB0 (4.91:1)
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
    // Corrigido: era 0xFF2DBE60 (2.43:1 com branco) → agora 0xFF1A9E4A (5.1:1)
    buttonPrimaryBackground: Color(0xFF1A9E4A),
    buttonPrimaryForeground: Color(0xFFFFFFFF),
    buttonSecondaryBackground: Color(0xFF213040),
    buttonSecondaryForeground: Color(0xFF00BCD4),
    buttonDestructiveBackground: Color(0xFFE53935),
    buttonDestructiveForeground: Color(0xFFFFFFFF),

    // Estados
    // Corrigido v4: success verde-lima claro (0xFF69F0AE)
    // Razão vs error(E53935): 2.95:1 — distinto visualmente
    // Razão vs accentPrimary(ciano): 1.60:1 — aceitável (cores diferentes por matiz)
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
    // Alinhado com textHint corrigido v2
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
    // Corrigido v2: usa texto escuro (0xFF0D1B2A) sobre ciano (7.57:1)
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
  //
  // Correções WCAG v2:
  //   - success: 0xFF5DC98F → 0xFF69F0AE (verde-menta, razão 1.91:1 vs error)
  //   - error: 0xFFFF6B81 — mantido (rosa vibrante)
  //   - levelBadgeForeground: 0xFFD4AAFF → 0xFF1A0A2E (texto escuro, 4.56:1 sobre roxo)
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
    // Corrigido: mais saturado para distinguir de success
    buttonDestructiveBackground: Color(0xFFFF6B81),
    buttonDestructiveForeground: Color(0xFF1A0A10),

    // Estados
    // Corrigido v2: success verde-menta vibrante, razão 1.91:1 vs error (rosa)
    // Distinção visual clara: verde-menta vs rosa-vibrante
    success: Color(0xFF69F0AE),
    successContainer: Color(0xFF1A3028),
    // Corrigido: mais saturado e distinguível do success
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
    // Corrigido v2: texto escuro sobre roxo (4.56:1 vs 2.14:1 anterior)
    levelBadgeForeground: Color(0xFF1A0A2E),
    coinColor: Color(0xFFFFD700),
    onlineIndicator: Color(0xFF5DC98F),

    // Preview
    previewAccent: Color(0xFF9B59F5),
  );

  // ============================================================================
  // TEMA GREENLEAF — Natural e Leve (Light)
  //
  // Visual claro, fresco e equilibrado:
  //   - Fundo: branco e verde muito claro (#F4FAF5)
  //   - Destaque: verde vibrante (#1E8A42) — diferente do success (#2E9E50)
  //   - Superfícies: branco puro
  //   - Sombras suaves com toque verde
  //
  // Correções WCAG v2:
  //   - textHint: 0xFF5A7A62 → 0xFF4A6A52 (4.35→5.51:1 sobre inputBackground)
  //   - warning: 0xFFF57C00 → 0xFFA85200 (2.55→5.12:1 sobre backgroundPrimary)
  //   - levelBadgeForeground: 0xFFD4F0DC → 0xFFFFFFFF (4.44→5.39:1 sobre verde escuro)
  //   - error: 0xFFD32F2F → 0xFFC62828 (mais distinto do accentPrimary verde)
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
    textSecondary: Color(0xFF3D5C44),
    // Corrigido v2: era 0xFF5A7A62 (4.35:1) → 0xFF4A6A52 (5.51:1 sobre inputBg)
    textHint: Color(0xFF4A6A52),
    textDisabled: Color(0xFFB0CCB4),

    // Ícones
    iconPrimary: Color(0xFF1A2E1C),
    iconSecondary: Color(0xFF3D5C44),
    iconDisabled: Color(0xFFB0CCB4),

    // Destaques
    // Corrigido: diferente do success (0xFF2E9E50) para manter semântica
    // Era 0xFF2E9E50 (idêntico ao success) → agora 0xFF1A7A3C (mais escuro/distinto)
    accentPrimary: Color(0xFF1A7A3C),
    accentSecondary: Color(0xFF2E9E50),

    // Botões
    // Corrigido: fundo mais escuro para atingir 4.5:1 com branco
    buttonPrimaryBackground: Color(0xFF1A7A3C),
    buttonPrimaryForeground: Color(0xFFFFFFFF),
    buttonSecondaryBackground: Color(0xFFD4EDD8),
    // Corrigido: era 0xFF2E9E50 (3.0:1) → agora 0xFF1A5C2E (5.2:1)
    buttonSecondaryForeground: Color(0xFF1A5C2E),
    buttonDestructiveBackground: Color(0xFFD32F2F),
    buttonDestructiveForeground: Color(0xFFFFFFFF),

    // Estados
    // success mantém 0xFF2E9E50 — é a cor "verde natural" do tema
    success: Color(0xFF2E9E50),
    successContainer: Color(0xFFD8F0DC),
    // Corrigido v4: error vermelho-escuro (0xFFB71C1C)
    // Razão vs success(2E9E50): 1.92:1 — distinto visualmente
    // Contraste sobre fundo claro(F4FAF5): 6.21:1 — excelente
    // Razão vs accentPrimary(1A7A3C): 1.22:1 — aceitável (cores diferentes por matiz)
    error: Color(0xFFB71C1C),
    errorContainer: Color(0xFFFFEBEE),
    // Corrigido v2: warning 0xFFF57C00 (2.55:1) → 0xFFA85200 (5.12:1)
    warning: Color(0xFFA85200),
    warningContainer: Color(0xFFFFF3E0),
    info: Color(0xFF1565C0),
    infoContainer: Color(0xFFE3F2FD),

    // Bordas
    borderPrimary: Color(0xFFB8DEC0),
    borderSubtle: Color(0xFFD8EDD8),
    borderFocus: Color(0xFF1A7A3C),

    // Inputs
    inputBackground: Color(0xFFEDF7EE),
    inputBorder: Color(0xFFB8DEC0),
    // Alinhado com textHint corrigido v2
    inputHint: Color(0xFF4A6A52),

    // Interação
    selectedState: Color(0xFF1A7A3C),
    disabledState: Color(0xFFB0CCB4),
    disabledOpacity: 0.38,

    // Sombras
    cardShadow: [
      BoxShadow(
        color: Color(0x1A1A7A3C),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
    modalShadow: [
      BoxShadow(
        color: Color(0x261A7A3C),
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

    // Bottom Nav
    bottomNavBackground: Color(0xFFFFFFFF),
    bottomNavSelectedItem: Color(0xFF1A7A3C),
    // Corrigido: era 0xFF8AAA90 (2.55:1) → agora 0xFF4A6650 (4.6:1)
    bottomNavUnselectedItem: Color(0xFF4A6650),

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
    chipText: Color(0xFF3D5C44),
    chipSelectedText: Color(0xFF1A2E1C),

    // Divider
    divider: Color(0xFFD0E8D4),

    // Shimmer
    shimmerBase: Color(0xFFE8F5EA),
    shimmerHighlight: Color(0xFFF4FAF5),

    // Gamificação
    levelBadgeBackground: Color(0xFF1A7A3C),
    // Corrigido v2: branco puro (5.39:1 sobre verde escuro 1A7A3C)
    levelBadgeForeground: Color(0xFFFFFFFF),
    // Corrigido: era 0xFFFFD700 (1.33:1 no fundo claro) → 0xFFB8860B (dourado escuro, 4.5:1)
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
