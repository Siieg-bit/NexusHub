import 'package:flutter/material.dart';
import 'nexus_theme_data.dart';
import 'package:amino_clone/core/providers/nexus_theme_provider.dart';

// =============================================================================
// NexusThemeScope — InheritedWidget que propaga NexusThemeData pela árvore
//
// Responsabilidade:
//   Tornar context.nexusTheme REATIVO: quando o tema muda no provider,
//   o main.dart reconstrói o NexusThemeScope com o novo tema, e todos
//   os widgets que dependem de context.nexusTheme são automaticamente
//   reconstruídos via InheritedWidget.
//
// Integração no main.dart:
//   builder: (context, child) {
//     return NexusThemeScope(
//       theme: nexusTheme,
//       child: child ?? const SizedBox.shrink(),
//     );
//   }
//
// Acesso via context:
//   context.nexusTheme.accentPrimary
//   context.nexusTheme.backgroundPrimary
// =============================================================================

/// InheritedWidget que disponibiliza o [NexusThemeData] ativo para toda
/// a árvore de widgets abaixo dele.
///
/// Quando o tema muda (via [nexusThemeProvider]), o [NexusThemeScope] é
/// reconstruído com o novo tema, e todos os widgets que chamaram
/// [NexusThemeScope.of] são marcados para rebuild automaticamente.
class NexusThemeScope extends InheritedWidget {
  const NexusThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  /// O tema ativo atual.
  final NexusThemeData theme;

  /// Retorna o [NexusThemeData] mais próximo na árvore.
  ///
  /// Registra o widget chamador como dependente — ele será reconstruído
  /// automaticamente quando o tema mudar.
  ///
  /// Lança [FlutterError] se não houver [NexusThemeScope] na árvore.
  static NexusThemeData of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NexusThemeScope>();
    if (scope == null) {
      // Fallback seguro: retornar tema Principal para não crashar
      // (pode acontecer em widgets fora do MaterialApp, como testes)
      assert(
        false,
        'NexusThemeScope.of() chamado fora de um NexusThemeScope. '
        'Certifique-se de que o NexusThemeScope está acima na árvore.',
      );
      return kFallbackTheme;
    }
    return scope.theme;
  }

  /// Retorna o [NexusThemeData] mais próximo na árvore, ou null se não
  /// houver [NexusThemeScope] disponível.
  ///
  /// Use quando o contexto pode estar fora do escopo do tema.
  static NexusThemeData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NexusThemeScope>()
        ?.theme;
  }

  @override
  bool updateShouldNotify(NexusThemeScope oldWidget) {
    // Reconstruir dependentes quando o slug ou id do tema mudar
    return theme.remoteSlug != oldWidget.theme.remoteSlug ||
        theme.id != oldWidget.theme.id;
  }
}
