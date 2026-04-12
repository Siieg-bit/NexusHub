import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/nexus_theme_provider.dart';
import 'nexus_theme_data.dart';
import 'nexus_themes.dart';

// =============================================================================
// NexusThemeExtension — Acesso direto ao NexusThemeData via BuildContext
//
// Permite usar `context.nexusTheme` em qualquer widget para acessar os
// tokens visuais do tema ativo, sem precisar de WidgetRef.
//
// Para widgets com WidgetRef, prefira:
//   final theme = ref.watch(nexusThemeProvider);
//
// Uso via context (widgets sem ref):
//   context.nexusTheme.accentPrimary
//   context.nexusTheme.backgroundPrimary
//   context.nexusTheme.textPrimary
//
// Aliases de compatibilidade com a extensão NexusColors legada:
//   context.scaffoldBg   → context.nexusTheme.backgroundPrimary
//   context.cardBg       → context.nexusTheme.cardBackground
//   context.textPrimary  → context.nexusTheme.textPrimary
//   (etc.)
// =============================================================================

extension NexusThemeContext on BuildContext {
  /// Retorna o [NexusThemeData] do tema ativo.
  ///
  /// Acessa o Riverpod container via ProviderScope.
  /// Caso não esteja disponível, usa fallback baseado no brightness do Material.
  NexusThemeData get nexusTheme {
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      return container.read(nexusThemeProvider);
    } catch (_) {
      // Fallback: inferir tema pelo brightness do MaterialTheme
      final brightness = Theme.of(this).brightness;
      return brightness == Brightness.dark
          ? NexusThemes.principal
          : NexusThemes.greenLeaf;
    }
  }

  // ── Aliases de compatibilidade com NexusColors (legado) ──────────────────
  // Mantidos para não quebrar os 1.708 usos existentes de context.scaffoldBg,
  // context.cardBg, etc. durante a migração gradual.

  bool get _isDark => nexusTheme.baseMode == NexusThemeMode.dark;

  // Fundos
  Color get scaffoldBg => nexusTheme.backgroundPrimary;
  Color get surfaceColor => nexusTheme.surfacePrimary;
  Color get cardBg => nexusTheme.cardBackground;
  Color get cardBgAlt => nexusTheme.cardBackgroundElevated;
  Color get bottomNavBg => nexusTheme.bottomNavBackground;
  Color get dividerClr => nexusTheme.divider;

  // Textos
  Color get textPrimary => nexusTheme.textPrimary;
  Color get textSecondary => nexusTheme.textSecondary;
  Color get textHint => nexusTheme.textHint;
}
