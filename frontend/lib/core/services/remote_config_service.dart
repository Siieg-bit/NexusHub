import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

// =============================================================================
// RemoteConfigService — Configurações dinâmicas do NexusHub
//
// Busca todas as configurações da tabela `app_remote_config` via RPC
// `get_app_remote_config()` e as armazena em cache local (SharedPreferences).
//
// Uso:
//   // Inicializar no app start (main.dart, após Supabase.initialize)
//   await RemoteConfigService.initialize();
//
//   // Ler um valor
//   final maxBio = RemoteConfigService.getInt('limits.max_bio_length', fallback: 500);
//   final webhook = RemoteConfigService.getString('links.discord_bug_report_webhook');
//   final isEnabled = RemoteConfigService.getBool('features.ads_enabled', fallback: true);
//   final packages = RemoteConfigService.getList('iap.coin_packages');
//   final rateLimit = RemoteConfigService.getMap('rate_limits.post_create');
//
// Estratégia de cache:
//   - Na inicialização: tenta buscar do banco, salva no cache local
//   - Se o banco falhar: usa o cache local (última versão conhecida)
//   - Se não há cache: usa os valores fallback hardcoded neste arquivo
// =============================================================================

const _kCacheKey = 'nexushub_remote_config_v1';

class RemoteConfigService {
  RemoteConfigService._();

  /// Cache em memória das configurações.
  static Map<String, dynamic> _cache = {};

  /// Indica se o serviço foi inicializado.
  static bool _initialized = false;

  // ── Inicialização ──────────────────────────────────────────────────────────

  /// Inicializa o serviço: busca configs do banco e salva em cache.
  ///
  /// Deve ser chamado no `main.dart` após `Supabase.initialize()`.
  /// Não lança exceção — usa fallbacks em caso de falha.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // 1. Tentar buscar do banco
      final result = await SupabaseService.client.rpc('get_app_remote_config');
      if (result != null) {
        _cache = Map<String, dynamic>.from(result as Map);
        await _saveToLocalCache(_cache);
        debugPrint('[RemoteConfig] ✅ ${_cache.length} configs carregadas do banco');
      }
    } catch (e) {
      debugPrint('[RemoteConfig] ⚠️ Falha ao buscar do banco: $e');
      // 2. Tentar usar cache local
      final localCache = await _loadFromLocalCache();
      if (localCache.isNotEmpty) {
        _cache = localCache;
        debugPrint('[RemoteConfig] ✅ ${_cache.length} configs carregadas do cache local');
      } else {
        debugPrint('[RemoteConfig] ⚠️ Usando valores fallback hardcoded');
      }
    }
    _initialized = true;
  }

  /// Recarrega as configurações do banco (útil após atualização no admin).
  static Future<void> refresh() async {
    _initialized = false;
    await initialize();
  }

  // ── Getters tipados ────────────────────────────────────────────────────────

  /// Retorna um valor inteiro. Usa [fallback] se a chave não existir.
  static int getInt(String key, {required int fallback}) {
    final raw = _cache[key];
    if (raw == null) return fallback;
    try {
      if (raw is int) return raw;
      if (raw is double) return raw.toInt();
      return int.parse(raw.toString());
    } catch (_) {
      return fallback;
    }
  }

  /// Retorna um valor double. Usa [fallback] se a chave não existir.
  static double getDouble(String key, {required double fallback}) {
    final raw = _cache[key];
    if (raw == null) return fallback;
    try {
      if (raw is double) return raw;
      if (raw is int) return raw.toDouble();
      return double.parse(raw.toString());
    } catch (_) {
      return fallback;
    }
  }

  /// Retorna um valor booleano. Usa [fallback] se a chave não existir.
  static bool getBool(String key, {required bool fallback}) {
    final raw = _cache[key];
    if (raw == null) return fallback;
    if (raw is bool) return raw;
    final str = raw.toString().toLowerCase();
    if (str == 'true') return true;
    if (str == 'false') return false;
    return fallback;
  }

  /// Retorna uma string. Usa [fallback] se a chave não existir.
  static String getString(String key, {String fallback = ''}) {
    final raw = _cache[key];
    if (raw == null) return fallback;
    // Remove aspas extras do JSON se presente
    final str = raw.toString();
    if (str.startsWith('"') && str.endsWith('"')) {
      return str.substring(1, str.length - 1);
    }
    return str;
  }

  /// Retorna um Map (objeto JSON). Retorna {} se a chave não existir.
  static Map<String, dynamic> getMap(String key) {
    final raw = _cache[key];
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    try {
      return Map<String, dynamic>.from(
          jsonDecode(raw.toString()) as Map);
    } catch (_) {
      return {};
    }
  }

  /// Retorna uma List (array JSON). Retorna [] se a chave não existir.
  static List<dynamic> getList(String key) {
    final raw = _cache[key];
    if (raw == null) return [];
    if (raw is List) return raw;
    try {
      return jsonDecode(raw.toString()) as List;
    } catch (_) {
      return [];
    }
  }

  // ── Atalhos semânticos (evitam strings mágicas espalhadas no código) ───────

  // Limites
  static int get maxPostTitleLength =>
      getInt('limits.max_post_title_length', fallback: 300);
  static int get maxPostContentLength =>
      getInt('limits.max_post_content_length', fallback: 10000);
  static int get maxCommentLength =>
      getInt('limits.max_comment_length', fallback: 2000);
  static int get maxMessageLength =>
      getInt('limits.max_message_length', fallback: 5000);
  static int get maxBioLength =>
      getInt('limits.max_bio_length', fallback: 500);
  static int get maxCommunityNameLength =>
      getInt('limits.max_community_name_length', fallback: 100);
  static int get maxMediaPerPost =>
      getInt('limits.max_media_per_post', fallback: 10);
  static int get maxAvatarSizeBytes =>
      getInt('limits.max_avatar_size_bytes', fallback: 5 * 1024 * 1024);
  static int get maxNicknameLength =>
      getInt('limits.max_nickname_length', fallback: 30);
  static int get minNicknameLength =>
      getInt('limits.min_nickname_length', fallback: 3);

  // Paginação
  static int get feedPageSize =>
      getInt('pagination.feed_page_size', fallback: 20);
  static int get chatPageSize =>
      getInt('pagination.chat_page_size', fallback: 50);
  static int get searchPageSize =>
      getInt('pagination.search_page_size', fallback: 20);
  static int get leaderboardPageSize =>
      getInt('pagination.leaderboard_page_size', fallback: 50);
  static int get commentsPageSize =>
      getInt('pagination.comments_page_size', fallback: 30);

  // Rate limits
  static Map<String, dynamic> rateLimitFor(String action) =>
      getMap('rate_limits.$action');

  // Links
  static String get discordBugReportWebhook =>
      getString('links.discord_bug_report_webhook');
  static String get supportEmail =>
      getString('links.support_email', fallback: 'suporte@nexushub.app');
  static String get discordServer =>
      getString('links.discord_server', fallback: 'discord.gg/nexushub');
  static String get faqUrl =>
      getString('links.faq_url', fallback: 'nexushub.app/faq');

  // Anúncios
  static int get maxDailyRewardedAds =>
      getInt('ads.max_daily_rewarded_ads', fallback: 3);
  static int get rewardedCoinsPerAd =>
      getInt('ads.rewarded_coins_per_ad', fallback: 5);

  // IAP
  static List<dynamic> get coinPackages => getList('iap.coin_packages');

  // Feature flags
  static bool get isVoiceChatEnabled =>
      getBool('features.voice_chat_enabled', fallback: true);
  static bool get isScreeningEnabled =>
      getBool('features.screening_enabled', fallback: true);
  static bool get isRpgModeEnabled =>
      getBool('features.rpg_mode_enabled', fallback: true);
  static bool get isAdsEnabled =>
      getBool('features.ads_enabled', fallback: true);
  static bool get isIapEnabled =>
      getBool('features.iap_enabled', fallback: true);
  static bool get isOtaTranslationsEnabled =>
      getBool('features.ota_translations_enabled', fallback: true);
  static bool get isRemoteRewardTasksEnabled =>
      getBool('features.remote_reward_tasks_enabled', fallback: true);
  static bool get isMaintenanceMode =>
      getBool('features.maintenance_mode', fallback: false);
  static String get minAppVersion =>
      getString('features.min_app_version', fallback: '1.0.0');

  // ── Cache local ────────────────────────────────────────────────────────────

  static Future<void> _saveToLocalCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[RemoteConfig] Erro ao salvar cache local: $e');
    }
  }

  static Future<Map<String, dynamic>> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[RemoteConfig] Erro ao carregar cache local: $e');
      return {};
    }
  }
}
