import 'package:flutter/material.dart';
import 'nexus_theme_data.dart';
import 'nexus_theme_scope.dart';

// =============================================================================
// NexusThemeExtension — Acesso direto ao NexusThemeData via BuildContext
//
// Permite usar `context.nexusTheme` em qualquer widget para acessar os
// tokens visuais do tema ativo, sem precisar de WidgetRef.
//
// REATIVIDADE GARANTIDA:
//   context.nexusTheme usa NexusThemeScope.of(context), que é um
//   InheritedWidget. Isso significa que o widget será automaticamente
//   reconstruído quando o tema mudar — sem necessidade de ref.watch().
//
// Para widgets ConsumerWidget/ConsumerStatefulWidget, você pode usar
// tanto context.nexusTheme quanto ref.watch(nexusThemeProvider) — ambos
// são reativos e equivalentes em termos de atualização.
//
// Uso:
//   context.nexusTheme.accentPrimary
//   context.nexusTheme.backgroundPrimary
//   context.nexusTheme.textPrimary
//
// Aliases de compatibilidade com a extensão NexusColors legada:
//   context.scaffoldBg   → context.nexusTheme.backgroundPrimary
//   context.cardBg       → context.nexusTheme.cardBackground
//   context.dividerClr   → context.nexusTheme.divider
//   (etc.)
// =============================================================================

extension NexusThemeContext on BuildContext {
  /// Retorna o [NexusThemeData] do tema ativo.
  ///
  /// Usa [NexusThemeScope.of] para acessar o tema via InheritedWidget,
  /// garantindo que o widget seja reconstruído quando o tema mudar.
  NexusThemeData get nexusTheme => NexusThemeScope.of(this);

  // ── Aliases de compatibilidade com NexusColors (legado) ──────────────────
  // Mantidos para não quebrar os usos existentes de context.scaffoldBg,
  // context.cardBg, etc. durante a migração gradual.

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
