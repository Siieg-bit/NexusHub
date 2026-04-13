import 'package:flutter/material.dart';

// =============================================================================
// NexusThemeData — Interface central de Design Tokens do NexusHub
//
// Define TODOS os tokens visuais usados pelo app. Cada tema concreto
// (Principal, Midnight, GreenLeaf) implementa esta interface com seus
// próprios valores de cor, gradiente e sombra.
//
// Princípios:
//  - Tokens semânticos: os nomes descrevem o USO, não a cor em si.
//    Ex: "accentPrimary" em vez de "cyan" ou "green".
//  - Cobertura total: todos os elementos visuais do app têm um token.
//  - Compatibilidade: `toMaterialTheme()` gera ThemeData para widgets nativos.
//  - Imutabilidade: todos os tokens são `final` e o objeto é `const`.
// =============================================================================

/// Identificador único de cada tema disponível no app.
enum NexusThemeId {
  principal,
  midnight,
  greenLeaf,
  /// Tema criado dinamicamente pelo admin via bubble-admin.
  /// Identificado pelo campo [NexusThemeData.remoteSlug].
  remote,
}

/// Modo base do tema (claro ou escuro).
enum NexusThemeMode {
  light,
  dark,
}

/// Contrato de tokens visuais do NexusHub.
///
/// Todos os temas concretos devem implementar esta classe.
/// Acesse via `ref.watch(nexusThemeProvider)` ou `context.nexusTheme`.
class NexusThemeData {
  // ── Identidade ─────────────────────────────────────────────────────────────

  /// Identificador único do tema.
  final NexusThemeId id;

  /// Slug único do tema remoto (ex: "ocean_blue").
  /// Não nulo apenas quando [id] == [NexusThemeId.remote].
  final String? remoteSlug;

  /// Nome legível do tema (ex: "Principal", "Midnight").
  final String name;

  /// Descrição curta exibida na tela de seleção.
  final String? description;

  /// Define se o tema é claro ou escuro (afeta SystemUiOverlayStyle).
  final NexusThemeMode baseMode;

  // ── Fundos ─────────────────────────────────────────────────────────────────

  /// Fundo principal do Scaffold.
  final Color backgroundPrimary;

  /// Fundo secundário (ex: seções alternadas, headers).
  final Color backgroundSecondary;

  // ── Superfícies ────────────────────────────────────────────────────────────

  /// Superfície principal (ex: modais, bottom sheets).
  final Color surfacePrimary;

  /// Superfície secundária (ex: inputs, chips, itens de lista).
  final Color surfaceSecondary;

  /// Fundo de cards.
  final Color cardBackground;

  /// Fundo de cards elevados (hover, pressed).
  final Color cardBackgroundElevated;

  /// Fundo de modais e dialogs.
  final Color modalBackground;

  // ── Overlay ────────────────────────────────────────────────────────────────

  /// Cor do overlay escuro (ex: drawer, dialogs).
  final Color overlayColor;

  /// Opacidade padrão do overlay.
  final double overlayOpacity;

  // ── Textos ─────────────────────────────────────────────────────────────────

  /// Texto principal (títulos, conteúdo).
  final Color textPrimary;

  /// Texto secundário (subtítulos, metadados).
  final Color textSecondary;

  /// Texto de dica / placeholder.
  final Color textHint;

  /// Texto desativado.
  final Color textDisabled;

  // ── Ícones ─────────────────────────────────────────────────────────────────

  /// Ícone principal.
  final Color iconPrimary;

  /// Ícone secundário.
  final Color iconSecondary;

  /// Ícone desativado.
  final Color iconDisabled;

  // ── Destaques (Accent) ─────────────────────────────────────────────────────

  /// Cor de destaque principal (nav ativa, links, seleção).
  final Color accentPrimary;

  /// Cor de destaque secundária (variação mais clara ou complementar).
  final Color accentSecondary;

  // ── Botões ─────────────────────────────────────────────────────────────────

  /// Fundo do botão primário (CTA principal).
  final Color buttonPrimaryBackground;

  /// Texto/ícone do botão primário.
  final Color buttonPrimaryForeground;

  /// Fundo do botão secundário (outlined/ghost).
  final Color buttonSecondaryBackground;

  /// Texto/ícone do botão secundário.
  final Color buttonSecondaryForeground;

  /// Fundo do botão destrutivo (ex: banir, deletar).
  final Color buttonDestructiveBackground;

  /// Texto/ícone do botão destrutivo.
  final Color buttonDestructiveForeground;

  // ── Estados Semânticos ─────────────────────────────────────────────────────

  /// Cor de sucesso (ex: check-in, join, confirmação).
  final Color success;

  /// Fundo do container de sucesso.
  final Color successContainer;

  /// Cor de erro (ex: formulários, alertas críticos).
  final Color error;

  /// Fundo do container de erro.
  final Color errorContainer;

  /// Cor de aviso (ex: strikes, alertas moderados).
  final Color warning;

  /// Fundo do container de aviso.
  final Color warningContainer;

  /// Cor informativa (ex: dicas, notificações neutras).
  final Color info;

  /// Fundo do container informativo.
  final Color infoContainer;

  // ── Bordas ─────────────────────────────────────────────────────────────────

  /// Borda principal (cards, inputs, separadores visíveis).
  final Color borderPrimary;

  /// Borda sutil (separadores leves, divisórias).
  final Color borderSubtle;

  /// Borda de foco (input em foco).
  final Color borderFocus;

  // ── Inputs ─────────────────────────────────────────────────────────────────

  /// Fundo do campo de input.
  final Color inputBackground;

  /// Borda do campo de input.
  final Color inputBorder;

  /// Placeholder do input.
  final Color inputHint;

  // ── Interação ──────────────────────────────────────────────────────────────

  /// Cor do item selecionado (ex: tab ativa, opção marcada).
  final Color selectedState;

  /// Cor do item desativado.
  final Color disabledState;

  /// Opacidade aplicada a elementos desativados.
  final double disabledOpacity;

  // ── Sombras ────────────────────────────────────────────────────────────────

  /// Sombra de cards.
  final List<BoxShadow> cardShadow;

  /// Sombra de modais e bottom sheets.
  final List<BoxShadow> modalShadow;

  /// Sombra de botões primários.
  final List<BoxShadow> buttonShadow;

  // ── Gradientes ─────────────────────────────────────────────────────────────

  /// Gradiente principal do app (ex: banners, headers de perfil).
  final LinearGradient primaryGradient;

  /// Gradiente de destaque (ex: badges de nível, elementos premium).
  final LinearGradient accentGradient;

  /// Gradiente do FAB de criação.
  final LinearGradient fabGradient;

  /// Gradiente de streak/check-in.
  final LinearGradient streakGradient;

  /// Gradiente da wallet/moedas.
  final LinearGradient walletGradient;

  /// Gradiente do banner Amino Plus.
  final LinearGradient aminoPlusGradient;

  // ── Bottom Navigation ──────────────────────────────────────────────────────

  /// Fundo da bottom nav bar.
  final Color bottomNavBackground;

  /// Cor do item ativo na bottom nav.
  final Color bottomNavSelectedItem;

  /// Cor do item inativo na bottom nav.
  final Color bottomNavUnselectedItem;

  // ── App Bar ────────────────────────────────────────────────────────────────

  /// Fundo da app bar.
  final Color appBarBackground;

  /// Cor dos ícones e texto da app bar.
  final Color appBarForeground;

  // ── Drawer ─────────────────────────────────────────────────────────────────

  /// Fundo do drawer lateral.
  final Color drawerBackground;

  /// Fundo do header do drawer.
  final Color drawerHeaderBackground;

  /// Sidebar escura do drawer de comunidade.
  final Color drawerSidebarBackground;

  // ── Chips ──────────────────────────────────────────────────────────────────

  /// Fundo do chip não selecionado.
  final Color chipBackground;

  /// Fundo do chip selecionado.
  final Color chipSelectedBackground;

  /// Texto do chip.
  final Color chipText;

  /// Texto do chip selecionado.
  final Color chipSelectedText;

  // ── Divider ────────────────────────────────────────────────────────────────

  /// Cor do divisor.
  final Color divider;

  // ── Shimmer / Loading ──────────────────────────────────────────────────────

  /// Cor base do shimmer.
  final Color shimmerBase;

  /// Cor de destaque do shimmer (brilho animado).
  final Color shimmerHighlight;

  // ── Gamificação ────────────────────────────────────────────────────────────

  /// Cor do badge de nível.
  final Color levelBadgeBackground;

  /// Cor do texto do badge de nível.
  final Color levelBadgeForeground;

  /// Cor da moeda.
  final Color coinColor;

  /// Cor do indicador online.
  final Color onlineIndicator;

  // ── Preview (usado na ThemeSelectorScreen) ─────────────────────────────────

  /// Cor de destaque usada no preview do card de seleção.
  final Color previewAccent;

  // ── Construtor ─────────────────────────────────────────────────────────────

  const NexusThemeData({
    required this.id,
    this.remoteSlug,
    required this.name,
    this.description,
    required this.baseMode,
    // Fundos
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    // Superfícies
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.cardBackground,
    required this.cardBackgroundElevated,
    required this.modalBackground,
    // Overlay
    required this.overlayColor,
    required this.overlayOpacity,
    // Textos
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textDisabled,
    // Ícones
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconDisabled,
    // Destaques
    required this.accentPrimary,
    required this.accentSecondary,
    // Botões
    required this.buttonPrimaryBackground,
    required this.buttonPrimaryForeground,
    required this.buttonSecondaryBackground,
    required this.buttonSecondaryForeground,
    required this.buttonDestructiveBackground,
    required this.buttonDestructiveForeground,
    // Estados
    required this.success,
    required this.successContainer,
    required this.error,
    required this.errorContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    // Bordas
    required this.borderPrimary,
    required this.borderSubtle,
    required this.borderFocus,
    // Inputs
    required this.inputBackground,
    required this.inputBorder,
    required this.inputHint,
    // Interação
    required this.selectedState,
    required this.disabledState,
    required this.disabledOpacity,
    // Sombras
    required this.cardShadow,
    required this.modalShadow,
    required this.buttonShadow,
    // Gradientes
    required this.primaryGradient,
    required this.accentGradient,
    required this.fabGradient,
    required this.streakGradient,
    required this.walletGradient,
    required this.aminoPlusGradient,
    // Bottom Nav
    required this.bottomNavBackground,
    required this.bottomNavSelectedItem,
    required this.bottomNavUnselectedItem,
    // App Bar
    required this.appBarBackground,
    required this.appBarForeground,
    // Drawer
    required this.drawerBackground,
    required this.drawerHeaderBackground,
    required this.drawerSidebarBackground,
    // Chips
    required this.chipBackground,
    required this.chipSelectedBackground,
    required this.chipText,
    required this.chipSelectedText,
    // Divider
    required this.divider,
    // Shimmer
    required this.shimmerBase,
    required this.shimmerHighlight,
    // Gamificação
    required this.levelBadgeBackground,
    required this.levelBadgeForeground,
    required this.coinColor,
    required this.onlineIndicator,
    // Preview
    required this.previewAccent,
  });

   // ── Factory: tema remoto do Supabase ─────────────────────────────────────

  /// Cria um [NexusThemeData] a partir do JSONB armazenado na tabela
  /// `app_themes` do Supabase. Usa o tema Principal como fallback para
  /// qualquer token ausente.
  factory NexusThemeData.fromRemoteJson(Map<String, dynamic> row) {
    final colors    = (row['colors']    as Map<String, dynamic>?) ?? {};
    final gradients = (row['gradients'] as Map<String, dynamic>?) ?? {};
    final shadows   = (row['shadows']   as Map<String, dynamic>?) ?? {};
    final opacities = (row['opacities'] as Map<String, dynamic>?) ?? {};

    Color c(String key, Color fallback) {
      final v = colors[key];
      if (v == null) return fallback;
      try {
        final hex = v.toString().replaceAll('#', '');
        final val = int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
        return Color(val);
      } catch (_) {
        return fallback;
      }
    }

    LinearGradient grad(String key, LinearGradient fallback) {
      final g = gradients[key];
      if (g == null) return fallback;
      try {
        final colorList = (g['colors'] as List).map<Color>((hex) {
          final h = hex.toString().replaceAll('#', '');
          final val = int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
          return Color(val);
        }).toList();
        final alignMap = {
          'topLeft': Alignment.topLeft, 'topCenter': Alignment.topCenter,
          'topRight': Alignment.topRight, 'centerLeft': Alignment.centerLeft,
          'center': Alignment.center, 'centerRight': Alignment.centerRight,
          'bottomLeft': Alignment.bottomLeft, 'bottomCenter': Alignment.bottomCenter,
          'bottomRight': Alignment.bottomRight,
        };
        return LinearGradient(
          colors: colorList,
          begin: alignMap[g['begin']] ?? Alignment.topLeft,
          end: alignMap[g['end']] ?? Alignment.bottomRight,
        );
      } catch (_) {
        return fallback;
      }
    }

    List<BoxShadow> shadow(String key, List<BoxShadow> fallback) {
      final list = shadows[key];
      if (list == null) return fallback;
      try {
        return (list as List).map<BoxShadow>((s) {
          final hex = s['color'].toString().replaceAll('#', '');
          final val = int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
          return BoxShadow(
            color: Color(val),
            blurRadius: (s['blurRadius'] as num).toDouble(),
            offset: Offset(
              (s['offsetX'] as num).toDouble(),
              (s['offsetY'] as num).toDouble(),
            ),
          );
        }).toList();
      } catch (_) {
        return fallback;
      }
    }

    double op(String key, double fallback) {
      final v = opacities[key];
      if (v == null) return fallback;
      return (v as num).toDouble();
    }

    // Alias para o tema Principal como fallback
    // (importado via NexusThemes.principal — evita dependência circular
    //  usando valores hardcoded do Principal)
    const bg1 = Color(0xFF0D1B2A);
    const bg2 = Color(0xFF0A1628);
    const sf1 = Color(0xFF1B2838);
    const sf2 = Color(0xFF213040);
    const acc = Color(0xFF00BCD4);
    const acc2 = Color(0xFF4DD0E1);
    const btn = Color(0xFF1A9E4A);
    const txt = Color(0xFFF2F2F2);
    const txt2 = Color(0xFF8899AA);
    const brd = Color(0xFF2A3A50);
    const brdS = Color(0xFF1E2E40);

    final baseMode = row['base_mode'] == 'light'
        ? NexusThemeMode.light
        : NexusThemeMode.dark;

    return NexusThemeData(
      id: NexusThemeId.remote,
      remoteSlug: row['slug'] as String? ?? 'remote',
      name: row['name'] as String? ?? 'Tema Remoto',
      description: row['description'] as String?,
      baseMode: baseMode,
      // Fundos
      backgroundPrimary:        c('backgroundPrimary',        bg1),
      backgroundSecondary:      c('backgroundSecondary',      bg2),
      // Superfícies
      surfacePrimary:           c('surfacePrimary',           sf1),
      surfaceSecondary:         c('surfaceSecondary',         sf2),
      cardBackground:           c('cardBackground',           sf2),
      cardBackgroundElevated:   c('cardBackgroundElevated',   const Color(0xFF2A3A4E)),
      modalBackground:          c('modalBackground',          sf1),
      // Overlay
      overlayColor:             c('overlayColor',             const Color(0xCC000000)),
      overlayOpacity:           op('overlayOpacity',          0.8),
      // Textos
      textPrimary:              c('textPrimary',              txt),
      textSecondary:            c('textSecondary',            txt2),
      textHint:                 c('textHint',                 const Color(0xFF8A9FB0)),
      textDisabled:             c('textDisabled',             const Color(0xFF3A4A5A)),
      // Ícones
      iconPrimary:              c('iconPrimary',              txt),
      iconSecondary:            c('iconSecondary',            txt2),
      iconDisabled:             c('iconDisabled',             const Color(0xFF3A4A5A)),
      // Destaques
      accentPrimary:            c('accentPrimary',            acc),
      accentSecondary:          c('accentSecondary',          acc2),
      // Botões
      buttonPrimaryBackground:  c('buttonPrimaryBackground',  btn),
      buttonPrimaryForeground:  c('buttonPrimaryForeground',  const Color(0xFFFFFFFF)),
      buttonSecondaryBackground:c('buttonSecondaryBackground',sf2),
      buttonSecondaryForeground:c('buttonSecondaryForeground',acc),
      buttonDestructiveBackground:c('buttonDestructiveBackground',const Color(0xFFE53935)),
      buttonDestructiveForeground:c('buttonDestructiveForeground',const Color(0xFFFFFFFF)),
      // Estados
      success:                  c('success',                  const Color(0xFF69F0AE)),
      successContainer:         c('successContainer',         const Color(0xFF1A3A2A)),
      error:                    c('error',                    const Color(0xFFE53935)),
      errorContainer:           c('errorContainer',           const Color(0xFF3A1A1A)),
      warning:                  c('warning',                  const Color(0xFFFF9800)),
      warningContainer:         c('warningContainer',         const Color(0xFF3A2A10)),
      info:                     c('info',                     const Color(0xFF2979FF)),
      infoContainer:            c('infoContainer',            const Color(0xFF1A2A3A)),
      // Bordas
      borderPrimary:            c('borderPrimary',            brd),
      borderSubtle:             c('borderSubtle',             brdS),
      borderFocus:              c('borderFocus',              acc),
      // Inputs
      inputBackground:          c('inputBackground',          sf2),
      inputBorder:              c('inputBorder',              brd),
      inputHint:                c('inputHint',                const Color(0xFF8A9FB0)),
      // Interação
      selectedState:            c('selectedState',            acc),
      disabledState:            c('disabledState',            brd),
      disabledOpacity:          op('disabledOpacity',         0.38),
      // Sombras
      cardShadow:   shadow('cardShadow',   [const BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))]),
      modalShadow:  shadow('modalShadow',  [const BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))]),
      buttonShadow: shadow('buttonShadow', [const BoxShadow(color: Color(0x4000BCD4), blurRadius: 12, offset: Offset(0, 4))]),
      // Gradientes
      primaryGradient:   grad('primaryGradient',   const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF0090CC)])),
      accentGradient:    grad('accentGradient',    const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF00B8E0)])),
      fabGradient:       grad('fabGradient',       const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF0090CC)])),
      streakGradient:    grad('streakGradient',    const LinearGradient(colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)])),
      walletGradient:    grad('walletGradient',    const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF0090CC)])),
      aminoPlusGradient: grad('aminoPlusGradient', const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF0090CC)])),
      // Bottom Nav
      bottomNavBackground:     c('bottomNavBackground',     sf1),
      bottomNavSelectedItem:   c('bottomNavSelectedItem',   acc),
      bottomNavUnselectedItem: c('bottomNavUnselectedItem', txt2),
      // App Bar
      appBarBackground:  c('appBarBackground',  sf1),
      appBarForeground:  c('appBarForeground',  txt),
      // Drawer
      drawerBackground:       c('drawerBackground',       sf1),
      drawerHeaderBackground: c('drawerHeaderBackground', sf2),
      drawerSidebarBackground:c('drawerSidebarBackground',const Color(0xFF0A1628)),
      // Chips
      chipBackground:         c('chipBackground',         sf2),
      chipSelectedBackground: c('chipSelectedBackground', acc),
      chipText:               c('chipText',               txt2),
      chipSelectedText:       c('chipSelectedText',       const Color(0xFFFFFFFF)),
      // Divider
      divider: c('divider', brdS),
      // Shimmer
      shimmerBase:      c('shimmerBase',      sf2),
      shimmerHighlight: c('shimmerHighlight', const Color(0xFF2A3A4E)),
      // Gamificação
      levelBadgeBackground: c('levelBadgeBackground', acc),
      levelBadgeForeground: c('levelBadgeForeground', const Color(0xFFFFFFFF)),
      coinColor:            c('coinColor',            const Color(0xFFFFD700)),
      onlineIndicator:      c('onlineIndicator',      const Color(0xFF69F0AE)),
      // Preview
      previewAccent: c('previewAccent', acc),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  /// Retorna o Brightness do Material equivalente ao baseMode.
  Brightness get brightness =>
      baseMode == NexusThemeMode.dark ? Brightness.dark : Brightness.light;

  /// Gera um [ThemeData] do Material Design a partir dos tokens do tema.
  ///
  /// Usado no MaterialApp para garantir que widgets nativos (BottomSheet,
  /// Dialog, SnackBar, etc.) herdem as cores corretas do tema ativo.
  ThemeData toMaterialTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: accentPrimary,
      scaffoldBackgroundColor: backgroundPrimary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accentPrimary,
        onPrimary: buttonPrimaryForeground,
        primaryContainer: accentSecondary.withValues(alpha: 0.2),
        onPrimaryContainer: accentPrimary,
        secondary: buttonPrimaryBackground,
        onSecondary: buttonPrimaryForeground,
        secondaryContainer: buttonPrimaryBackground.withValues(alpha: 0.15),
        onSecondaryContainer: buttonPrimaryBackground,
        tertiary: accentSecondary,
        onTertiary: Colors.white,
        tertiaryContainer: accentSecondary.withValues(alpha: 0.15),
        onTertiaryContainer: accentSecondary,
        error: error,
        onError: buttonDestructiveForeground,
        errorContainer: errorContainer,
        onErrorContainer: error,
        surface: surfacePrimary,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: borderPrimary,
        outlineVariant: borderSubtle,
        shadow: Colors.black,
        scrim: overlayColor,
        inverseSurface: textPrimary,
        onInverseSurface: backgroundPrimary,
        inversePrimary: accentSecondary,
        surfaceTint: accentPrimary.withValues(alpha: 0.05),
      ),
      fontFamily: 'PlusJakartaSans',
      textTheme: TextTheme(
        displayLarge: TextStyle(
            color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
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
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: appBarForeground),
        titleTextStyle: TextStyle(
            color: appBarForeground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'PlusJakartaSans'),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomNavBackground,
        selectedItemColor: bottomNavSelectedItem,
        unselectedItemColor: bottomNavUnselectedItem,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shadowColor: cardShadow.isNotEmpty
            ? cardShadow.first.color
            : Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackground,
        hintStyle: TextStyle(color: inputHint),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: inputBorder, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderFocus, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonPrimaryBackground,
          foregroundColor: buttonPrimaryForeground,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'PlusJakartaSans'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonSecondaryForeground,
          side: BorderSide(color: borderPrimary, width: 1.5),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBackground,
        selectedColor: chipSelectedBackground,
        labelStyle: TextStyle(color: chipText, fontSize: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme:
          DividerThemeData(color: divider, thickness: 0.5, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfacePrimary,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: modalBackground,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20))),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: modalBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accentPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: accentPrimary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonPrimaryBackground,
        foregroundColor: buttonPrimaryForeground,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentPrimary;
          }
          return disabledState;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentPrimary.withValues(alpha: 0.4);
          }
          return disabledState.withValues(alpha: 0.3);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(buttonPrimaryForeground),
        side: BorderSide(color: borderPrimary, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentPrimary;
          }
          return borderPrimary;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentPrimary,
        linearTrackColor: borderSubtle,
        circularTrackColor: borderSubtle,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderSubtle),
        ),
        textStyle: TextStyle(color: textPrimary, fontSize: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfacePrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderSubtle)),
        textStyle: TextStyle(color: textPrimary),
        elevation: 4,
        shadowColor: cardShadow.isNotEmpty
            ? cardShadow.first.color
            : Colors.transparent,
      ),
    );
  }

  // ── Compatibilidade com a extensão NexusColors legada ──────────────────────

  /// Alias para manter compatibilidade com `context.scaffoldBg`.
  Color get scaffoldBg => backgroundPrimary;

  /// Alias para manter compatibilidade com `context.surfaceColor`.
  Color get surfaceColor => surfacePrimary;

  /// Alias para manter compatibilidade com `context.cardBg`.
  Color get cardBg => cardBackground;

  /// Alias para manter compatibilidade com `context.cardBgAlt`.
  Color get cardBgAlt => cardBackgroundElevated;

  /// Alias para manter compatibilidade com `context.bottomNavBg`.
  Color get bottomNavBg => bottomNavBackground;

  /// Alias para manter compatibilidade com `context.dividerClr`.
  Color get dividerClr => divider;
}
