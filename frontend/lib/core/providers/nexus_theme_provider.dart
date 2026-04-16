import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';
import 'package:amino_clone/config/nexus_themes.dart';
import 'package:amino_clone/core/services/supabase_service.dart';

// =============================================================================
// NexusThemeProvider — Gerenciamento centralizado de temas do NexusHub
//
// Responsabilidades:
//   - Manter o tema ativo em memória (StateNotifier)
//   - Persistir a escolha do usuário via SharedPreferences
//   - Restaurar o tema salvo ao iniciar o app (built-in ou remoto)
//   - Carregar temas remotos criados pelo admin no bubble-admin
//   - Notificar toda a árvore de widgets sobre mudanças de tema
//
// Uso:
//   // Ler o tema atual
//   final theme = ref.watch(nexusThemeProvider);
//
//   // Trocar o tema
//   ref.read(nexusThemeProvider.notifier).setTheme(NexusThemes.midnight);
//   ref.read(nexusThemeProvider.notifier).setThemeById(NexusThemeId.midnight);
//
//   // Listar todos os temas (built-in + remotos)
//   final themes = await ref.read(allThemesProvider.future);
// =============================================================================

/// Chave para persistir o tema ativo no SharedPreferences.
/// Para temas built-in: armazena o NexusThemeId.name (ex: "midnight").
/// Para temas remotos: armazena "remote:ocean_blue" (prefixo + slug).
const _kNexusThemeKey = 'nexushub_active_theme_id';

/// Provider global do tema NexusHub.
///
/// Observado pelo MaterialApp para reconstruir o ThemeData quando o
/// usuário troca o tema. Também acessível via `context.nexusTheme`.
final nexusThemeProvider =
    StateNotifierProvider<NexusThemeNotifier, NexusThemeData>((ref) {
  return NexusThemeNotifier(ref);
});

/// FutureProvider que busca os temas remotos ativos do Supabase.
///
/// Retorna apenas temas com `is_active = true`, ordenados por `sort_order`.
/// Usado pela ThemeSelectorScreen para listar temas criados pelo admin.
final remoteThemesProvider = FutureProvider<List<NexusThemeData>>((ref) async {
  try {
    final rows = await SupabaseService.client
        .from('app_themes')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((row) => NexusThemeData.fromRemoteJson(row as Map<String, dynamic>))
        .toList();
  } catch (e) {
    // Se a tabela não existir ainda ou houver erro de rede, retorna lista vazia
    return [];
  }
});

/// FutureProvider que combina temas built-in + remotos em uma única lista.
///
/// Usado pela ThemeSelectorScreen para exibir todos os temas disponíveis.
final allThemesProvider = FutureProvider<List<NexusThemeData>>((ref) async {
  final remotes = await ref.watch(remoteThemesProvider.future);
  return [...NexusThemes.all, ...remotes];
});

/// Notifier que gerencia o ciclo de vida do tema ativo.
class NexusThemeNotifier extends StateNotifier<NexusThemeData> {
  final Ref _ref;

  NexusThemeNotifier(this._ref) : super(NexusThemes.principal) {
    _restoreFromPrefs();
  }

  // ── Persistência ───────────────────────────────────────────────────────────

  /// Carrega o tema salvo do SharedPreferences ao iniciar o app.
  ///
  /// Suporta dois formatos de chave:
  ///   - "midnight"          → tema built-in pelo NexusThemeId.name
  ///   - "remote:ocean_blue" → tema remoto pelo slug
  Future<void> _restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_kNexusThemeKey);
      if (savedKey == null || !mounted) return;

      if (savedKey.startsWith('remote:')) {
        // Tema remoto — buscar do Supabase pelo slug
        final slug = savedKey.substring('remote:'.length);
        await _loadRemoteThemeBySlug(slug);
      } else {
        // Tema built-in
        final themeId = NexusThemeId.values.firstWhere(
          (id) => id.name == savedKey,
          orElse: () => NexusThemeId.principal,
        );
        if (themeId != NexusThemeId.remote) {
          state = NexusThemes.byId(themeId);
        }
      }
    } catch (e) {
      debugLog('[NexusTheme] Erro ao restaurar tema: $e');
    }
  }

  /// Busca um tema remoto pelo slug e o aplica como estado.
  Future<void> _loadRemoteThemeBySlug(String slug) async {
    try {
      final rows = await SupabaseService.client
          .from('app_themes')
          .select()
          .eq('slug', slug)
          .eq('is_active', true)
          .limit(1);
      if (rows.isNotEmpty && mounted) {
        state = NexusThemeData.fromRemoteJson(rows.first);
      }
    } catch (e) {
      debugLog('[NexusTheme] Erro ao carregar tema remoto "$slug": $e');
    }
  }

  /// Persiste a chave do tema no SharedPreferences.
  Future<void> _persistThemeKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNexusThemeKey, key);
    } catch (e) {
      debugLog('[NexusTheme] Erro ao persistir tema: $e');
    }
  }

  // ── API Pública ────────────────────────────────────────────────────────────

  /// Troca o tema ativo para [theme] e persiste a escolha.
  ///
  /// Funciona para temas built-in e remotos.
  void setTheme(NexusThemeData theme) {
    if (!mounted) return;
    state = theme;
    if (theme.id == NexusThemeId.remote && theme.remoteSlug != null) {
      _persistThemeKey('remote:${theme.remoteSlug}');
    } else {
      _persistThemeKey(theme.id.name);
    }
  }

  /// Troca o tema ativo pelo seu [NexusThemeId].
  /// Não suporta [NexusThemeId.remote] — use [setTheme] diretamente.
  void setThemeById(NexusThemeId id) {
    if (id == NexusThemeId.remote) return;
    setTheme(NexusThemes.byId(id));
  }

  /// Recarrega os temas remotos do Supabase.
  /// Útil após criar/editar um tema no bubble-admin.
  Future<void> refreshRemoteThemes() async {
    _ref.invalidate(remoteThemesProvider);
    _ref.invalidate(allThemesProvider);
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
