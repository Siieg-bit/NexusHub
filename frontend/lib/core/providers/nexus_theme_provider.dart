import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';
import 'package:amino_clone/core/services/supabase_service.dart';

// =============================================================================
// NexusThemeProvider — Gerenciamento centralizado de temas do NexusHub
//
// Após a migration 237, o banco de dados (tabela `app_themes`) é a ÚNICA
// fonte de temas — incluindo os temas built-in (principal, midnight, greenLeaf).
// O arquivo nexus_themes.dart foi removido.
//
// Responsabilidades:
//   - Manter o tema ativo em memória (StateNotifier)
//   - Persistir a escolha do usuário via SharedPreferences (por slug)
//   - Restaurar o tema salvo ao iniciar o app (busca pelo slug no banco)
//   - Carregar todos os temas ativos do banco para a ThemeSelectorScreen
//   - Notificar toda a árvore de widgets sobre mudanças de tema
//
// Uso:
//   // Ler o tema atual
//   final theme = ref.watch(nexusThemeProvider);
//
//   // Trocar o tema
//   ref.read(nexusThemeProvider.notifier).setTheme(theme);
//
//   // Listar todos os temas disponíveis
//   final themes = await ref.read(allThemesProvider.future);
// =============================================================================

/// Chave para persistir o slug do tema ativo no SharedPreferences.
/// Formato: slug direto (ex: "principal", "midnight", "ocean_blue").
const _kNexusThemeKey = 'nexushub_active_theme_slug';

// =============================================================================
// Tema de fallback síncrono (Principal dark — azul-marinho)
//
// Usado APENAS como estado inicial do notifier antes do banco responder.
// Garante que o app não fique com tela branca no primeiro frame.
// Todos os tokens são os mesmos do tema 'principal' no banco.
// =============================================================================
/// Tema de fallback público — usado pelo NexusThemeScope quando fora da árvore.
final kFallbackTheme = NexusThemeData(
  id: NexusThemeId.remote,
  remoteSlug: 'principal',
  name: 'Principal',
  description: '',
  baseMode: NexusThemeMode.dark,
  backgroundPrimary: const Color(0xFF0D1B2A),
  backgroundSecondary: const Color(0xFF0A1628),
  surfacePrimary: const Color(0xFF1B2838),
  surfaceSecondary: const Color(0xFF213040),
  cardBackground: const Color(0xFF213040),
  cardBackgroundElevated: const Color(0xFF2A3A4E),
  modalBackground: const Color(0xFF1B2838),
  overlayColor: const Color(0xCC000000),
  overlayOpacity: 0.8,
  textPrimary: const Color(0xFFF2F2F2),
  textSecondary: const Color(0xFF8899AA),
  textHint: const Color(0xFF8A9FB0),
  textDisabled: const Color(0xFF3A4A5A),
  iconPrimary: const Color(0xFFF2F2F2),
  iconSecondary: const Color(0xFF8899AA),
  iconDisabled: const Color(0xFF3A4A5A),
  accentPrimary: const Color(0xFF00BCD4),
  accentSecondary: const Color(0xFF4DD0E1),
  buttonPrimaryBackground: const Color(0xFF1A9E4A),
  buttonPrimaryForeground: const Color(0xFFFFFFFF),
  buttonSecondaryBackground: const Color(0xFF213040),
  buttonSecondaryForeground: const Color(0xFF00BCD4),
  buttonDestructiveBackground: const Color(0xFFE53935),
  buttonDestructiveForeground: const Color(0xFFFFFFFF),
  success: const Color(0xFF69F0AE),
  successContainer: const Color(0xFF1A3A2A),
  error: const Color(0xFFE53935),
  errorContainer: const Color(0xFF3A1A1A),
  warning: const Color(0xFFFF9800),
  warningContainer: const Color(0xFF3A2A10),
  info: const Color(0xFF2979FF),
  infoContainer: const Color(0xFF1A2A3A),
  borderPrimary: const Color(0xFF2A3A50),
  borderSubtle: const Color(0xFF1E2E40),
  borderFocus: const Color(0xFF00BCD4),
  inputBackground: const Color(0xFF213040),
  inputBorder: const Color(0xFF2A3A50),
  inputHint: const Color(0xFF8A9FB0),
  selectedState: const Color(0xFF00BCD4),
  disabledState: const Color(0xFF2A3A50),
  disabledOpacity: 0.38,
  cardShadow: const [
    BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
  modalShadow: const [
    BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 8)),
  ],
  buttonShadow: const [
    BoxShadow(color: Color(0x401A9E4A), blurRadius: 8, offset: Offset(0, 3)),
  ],
  primaryGradient: const LinearGradient(
    colors: [Color(0xFF1A9E4A), Color(0xFF00BCD4)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  ),
  accentGradient: const LinearGradient(
    colors: [Color(0xFF00BCD4), Color(0xFF4DD0E1)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  ),
  fabGradient: const LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFFFF5C8D)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  ),
  streakGradient: const LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
  ),
  walletGradient: const LinearGradient(
    colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
  ),
  aminoPlusGradient: const LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
    begin: Alignment.centerLeft, end: Alignment.centerRight,
  ),
  bottomNavBackground: const Color(0xFF0A1628),
  bottomNavSelectedItem: const Color(0xFFFFFFFF),
  bottomNavUnselectedItem: const Color(0xFF6A7D8E),
  appBarBackground: const Color(0xFF0D1B2A),
  appBarForeground: const Color(0xFFF2F2F2),
  drawerBackground: const Color(0xFF1B2838),
  drawerHeaderBackground: const Color(0xFF213040),
  drawerSidebarBackground: const Color(0xFF000000),
  chipBackground: const Color(0xFF213040),
  chipSelectedBackground: const Color(0xFF1A3A4A),
  chipText: const Color(0xFF8899AA),
  chipSelectedText: const Color(0xFF00BCD4),
  divider: const Color(0xFF2A3A50),
  shimmerBase: const Color(0xFF213040),
  shimmerHighlight: const Color(0xFF2A3A4E),
  levelBadgeBackground: const Color(0xFF1565C0),
  levelBadgeForeground: const Color(0xFF0D1B2A),
  coinColor: const Color(0xFFFFD700),
  onlineIndicator: const Color(0xFF2DBE60),
  previewAccent: const Color(0xFF00BCD4),
);

// =============================================================================
// Providers
// =============================================================================

/// Provider global do tema NexusHub.
///
/// Observado pelo MaterialApp para reconstruir o ThemeData quando o
/// usuário troca o tema. Também acessível via `context.nexusTheme`.
final nexusThemeProvider =
    StateNotifierProvider<NexusThemeNotifier, NexusThemeData>((ref) {
  return NexusThemeNotifier(ref);
});

/// FutureProvider que busca TODOS os temas ativos do Supabase.
///
/// Inclui temas built-in (is_builtin=true) e temas criados pelo admin.
/// Retorna apenas temas com `is_active = true`, ordenados por `sort_order`.
final allThemesProvider = FutureProvider<List<NexusThemeData>>((ref) async {
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
    // Em caso de erro de rede, retorna o fallback para não deixar a tela vazia
    return [kFallbackTheme];
  }
});

// =============================================================================
// NexusThemeNotifier
// =============================================================================

/// Notifier que gerencia o ciclo de vida do tema ativo.
class NexusThemeNotifier extends StateNotifier<NexusThemeData> {
  final Ref _ref;

  NexusThemeNotifier(this._ref) : super(kFallbackTheme) {
    _restoreFromPrefs();
  }

  // ── Persistência ───────────────────────────────────────────────────────────

  /// Carrega o tema salvo do SharedPreferences ao iniciar o app.
  ///
  /// Formato da chave: slug direto (ex: "principal", "midnight", "ocean_blue").
  /// Compatibilidade retroativa: suporta o formato antigo "remote:slug".
  Future<void> _restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedKey = prefs.getString(_kNexusThemeKey);

      // Compatibilidade com formato antigo ("remote:slug" → "slug")
      if (savedKey != null && savedKey.startsWith('remote:')) {
        savedKey = savedKey.substring('remote:'.length);
      }
      // Compatibilidade com formato antigo de built-ins ("midnight" → "midnight")
      // O slug no banco é o mesmo que o NexusThemeId.name para os built-ins,
      // exceto greenLeaf → green_leaf. Normalizar:
      if (savedKey == 'greenLeaf') savedKey = 'green_leaf';

      if (savedKey == null || !mounted) return;
      await _loadThemeBySlug(savedKey);
    } catch (e) {
      _log('[NexusTheme] Erro ao restaurar tema: $e');
    }
  }

  /// Busca um tema pelo slug no banco e o aplica como estado.
  Future<void> _loadThemeBySlug(String slug) async {
    try {
      final rows = await SupabaseService.client
          .from('app_themes')
          .select()
          .eq('slug', slug)
          .eq('is_active', true)
          .limit(1);
      if ((rows as List).isNotEmpty && mounted) {
        state = NexusThemeData.fromRemoteJson(rows.first as Map<String, dynamic>);
      }
    } catch (e) {
      _log('[NexusTheme] Erro ao carregar tema "$slug": $e');
      // Mantém o fallback em memória se o banco falhar
    }
  }

  /// Persiste o slug do tema no SharedPreferences.
  Future<void> _persistSlug(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNexusThemeKey, slug);
    } catch (e) {
      _log('[NexusTheme] Erro ao persistir tema: $e');
    }
  }

  // ── API Pública ────────────────────────────────────────────────────────────

  /// Troca o tema ativo para [theme] e persiste a escolha pelo slug.
  void setTheme(NexusThemeData theme) {
    if (!mounted) return;
    state = theme;
    final slug = theme.remoteSlug ?? theme.id.name;
    _persistSlug(slug);
  }

  /// Recarrega todos os temas do Supabase.
  /// Útil após criar/editar um tema no bubble-admin.
  Future<void> refreshThemes() async {
    _ref.invalidate(allThemesProvider);
  }

  // ── Getters de conveniência ────────────────────────────────────────────────

  /// Retorna o tema ativo atual.
  NexusThemeData get currentTheme => state;

  /// Retorna o slug do tema ativo.
  String get currentSlug => state.remoteSlug ?? state.id.name;

  /// Retorna `true` se o tema ativo é escuro.
  bool get isDark => state.baseMode == NexusThemeMode.dark;

  /// Retorna `true` se o tema ativo é claro.
  bool get isLight => state.baseMode == NexusThemeMode.light;

  // ── Utilitário interno ─────────────────────────────────────────────────────

  // ignore: avoid_print
  void _log(String msg) => print(msg);
}
