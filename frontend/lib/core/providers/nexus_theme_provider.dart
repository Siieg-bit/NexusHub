import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';
import 'package:amino_clone/config/nexus_themes.dart';

// =============================================================================
// NexusThemeProvider — Gerenciamento centralizado de temas do NexusHub
//
// Responsabilidades:
//   - Manter o tema ativo em memória (StateNotifier)
//   - Persistir a escolha do usuário via SharedPreferences
//   - Restaurar o tema salvo ao iniciar o app
//   - Notificar toda a árvore de widgets sobre mudanças de tema
//   - Fornecer helpers de acesso ao estado atual
//
// Uso:
//   // Ler o tema atual
//   final theme = ref.watch(nexusThemeProvider);
//
//   // Trocar o tema
//   ref.read(nexusThemeProvider.notifier).setTheme(NexusThemes.midnight);
//   ref.read(nexusThemeProvider.notifier).setThemeById(NexusThemeId.midnight);
// =============================================================================

/// Chave usada para persistir o id do tema no SharedPreferences.
const _kNexusThemeKey = 'nexushub_active_theme_id';

/// Provider global do tema NexusHub.
///
/// Observado pelo MaterialApp para reconstruir o ThemeData quando o
/// usuário troca o tema. Também acessível via `context.nexusTheme`.
final nexusThemeProvider =
    StateNotifierProvider<NexusThemeNotifier, NexusThemeData>((ref) {
  return NexusThemeNotifier();
});

/// Notifier que gerencia o ciclo de vida do tema ativo.
class NexusThemeNotifier extends StateNotifier<NexusThemeData> {
  NexusThemeNotifier() : super(NexusThemes.principal) {
    _restoreFromPrefs();
  }

  // ── Persistência ───────────────────────────────────────────────────────────

  /// Carrega o tema salvo do SharedPreferences ao iniciar o app.
  ///
  /// Executado no construtor. Se não houver tema salvo ou ocorrer erro,
  /// mantém o tema Principal como padrão.
  Future<void> _restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kNexusThemeKey);

      if (savedId != null && mounted) {
        final themeId = NexusThemeId.values.firstWhere(
          (id) => id.name == savedId,
          orElse: () => NexusThemeId.principal,
        );
        state = NexusThemes.byId(themeId);
      }
    } catch (e) {
      // Silenciar: manter Principal como fallback seguro
      debugLog('[NexusTheme] Erro ao restaurar tema: $e');
    }
  }

  /// Persiste o id do tema escolhido no SharedPreferences.
  Future<void> _persistTheme(NexusThemeId id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNexusThemeKey, id.name);
    } catch (e) {
      debugLog('[NexusTheme] Erro ao persistir tema: $e');
    }
  }

  // ── API Pública ────────────────────────────────────────────────────────────

  /// Troca o tema ativo para [theme] e persiste a escolha.
  ///
  /// A mudança é imediata: todos os widgets que observam
  /// `nexusThemeProvider` serão reconstruídos.
  void setTheme(NexusThemeData theme) {
    if (!mounted) return;
    state = theme;
    _persistTheme(theme.id);
  }

  /// Troca o tema ativo pelo seu [NexusThemeId].
  void setThemeById(NexusThemeId id) {
    setTheme(NexusThemes.byId(id));
  }

  // ── Getters de conveniência ────────────────────────────────────────────────

  /// Retorna o tema ativo atual.
  NexusThemeData get currentTheme => state;

  /// Retorna o [NexusThemeId] do tema ativo.
  NexusThemeId get currentId => state.id;

  /// Retorna `true` se o tema ativo é escuro.
  bool get isDark => state.baseMode == NexusThemeMode.dark;

  /// Retorna `true` se o tema ativo é claro.
  bool get isLight => state.baseMode == NexusThemeMode.light;

  // ── Utilitário interno ─────────────────────────────────────────────────────

  // ignore: avoid_print
  void debugLog(String msg) => print(msg);
}
