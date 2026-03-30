import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// ============================================================================
/// CacheService — Cache Offline-First com Hive.
///
/// Estratégia: Cache-first com fallback para rede.
/// - Ao carregar dados, primeiro tenta o cache local
/// - Em paralelo, busca dados frescos da rede
/// - Atualiza o cache quando dados novos chegam
/// - Se offline, usa dados do cache
///
/// Boxes:
///   - 'posts'        → Posts do feed (por comunidade)
///   - 'communities'  → Comunidades do usuário
///   - 'messages'     → Mensagens de chat (por thread)
///   - 'profiles'     → Perfis de usuários visitados
///   - 'feed'         → Feed global / For You
///   - 'metadata'     → Timestamps de última sincronização
/// ============================================================================
class CacheService {
  CacheService._();

  static bool _initialized = false;

  // Box names
  static const String _postsBox = 'posts_cache';
  static const String _communitiesBox = 'communities_cache';
  static const String _messagesBox = 'messages_cache';
  static const String _profilesBox = 'profiles_cache';
  static const String _feedBox = 'feed_cache';
  static const String _metadataBox = 'cache_metadata';
  static const String _notificationsBox = 'notifications_cache';
  static const String _wikiBox = 'wiki_cache';

  /// Inicializa o Hive e abre todos os boxes necessários.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();

      // Abrir todos os boxes
      await Future.wait([
        Hive.openBox<String>(_postsBox),
        Hive.openBox<String>(_communitiesBox),
        Hive.openBox<String>(_messagesBox),
        Hive.openBox<String>(_profilesBox),
        Hive.openBox<String>(_feedBox),
        Hive.openBox<String>(_metadataBox),
        Hive.openBox<String>(_notificationsBox),
        Hive.openBox<String>(_wikiBox),
      ]);

      _initialized = true;
      debugPrint('CacheService: Inicializado com sucesso');
    } catch (e) {
      debugPrint('CacheService: Erro ao inicializar: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POSTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Salva posts de uma comunidade no cache.
  static Future<void> cachePosts(
      String communityId, List<Map<String, dynamic>> posts) async {
    try {
      final box = Hive.box<String>(_postsBox);
      await box.put(communityId, jsonEncode(posts));
      await _updateTimestamp('posts:$communityId');
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear posts: $e');
    }
  }

  /// Recupera posts de uma comunidade do cache.
  static List<Map<String, dynamic>>? getCachedPosts(String communityId) {
    try {
      final box = Hive.box<String>(_postsBox);
      final data = box.get(communityId);
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      debugPrint('CacheService: Erro ao ler posts do cache: $e');
      return null;
    }
  }

  /// Salva um post individual no cache.
  static Future<void> cachePost(
      String postId, Map<String, dynamic> post) async {
    try {
      final box = Hive.box<String>(_postsBox);
      await box.put('post:$postId', jsonEncode(post));
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear post: $e');
    }
  }

  /// Recupera um post individual do cache.
  static Map<String, dynamic>? getCachedPost(String postId) {
    try {
      final box = Hive.box<String>(_postsBox);
      final data = box.get('post:$postId');
      if (data == null) return null;
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      debugPrint('CacheService: Erro ao ler post do cache: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMUNIDADES
  // ══════════════════════════════════════════════════════════════════════════

  /// Salva lista de comunidades do usuário no cache.
  static Future<void> cacheMyCommunities(
      List<Map<String, dynamic>> communities) async {
    try {
      final box = Hive.box<String>(_communitiesBox);
      await box.put('my_communities', jsonEncode(communities));
      await _updateTimestamp('my_communities');
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear comunidades: $e');
    }
  }

  /// Recupera lista de comunidades do usuário do cache.
  static List<Map<String, dynamic>>? getCachedMyCommunities() {
    try {
      final box = Hive.box<String>(_communitiesBox);
      final data = box.get('my_communities');
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      debugPrint('CacheService: Erro ao ler comunidades do cache: $e');
      return null;
    }
  }

  /// Salva detalhes de uma comunidade no cache.
  static Future<void> cacheCommunity(
      String communityId, Map<String, dynamic> community) async {
    try {
      final box = Hive.box<String>(_communitiesBox);
      await box.put(communityId, jsonEncode(community));
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear comunidade: $e');
    }
  }

  /// Recupera detalhes de uma comunidade do cache.
  static Map<String, dynamic>? getCachedCommunity(String communityId) {
    try {
      final box = Hive.box<String>(_communitiesBox);
      final data = box.get(communityId);
      if (data == null) return null;
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      debugPrint('CacheService: Erro ao ler comunidade do cache: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MENSAGENS
  // ══════════════════════════════════════════════════════════════════════════

  /// Salva mensagens de um thread no cache.
  static Future<void> cacheMessages(
      String threadId, List<Map<String, dynamic>> messages) async {
    try {
      final box = Hive.box<String>(_messagesBox);
      await box.put(threadId, jsonEncode(messages));
      await _updateTimestamp('messages:$threadId');
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear mensagens: $e');
    }
  }

  /// Recupera mensagens de um thread do cache.
  static List<Map<String, dynamic>>? getCachedMessages(String threadId) {
    try {
      final box = Hive.box<String>(_messagesBox);
      final data = box.get(threadId);
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      debugPrint('CacheService: Erro ao ler mensagens do cache: $e');
      return null;
    }
  }

  /// Adiciona uma mensagem ao cache de um thread existente.
  static Future<void> appendMessage(
      String threadId, Map<String, dynamic> message) async {
    try {
      final existing = getCachedMessages(threadId) ?? [];
      existing.add(message);
      // Manter no máximo 200 mensagens no cache por thread
      if (existing.length > 200) {
        existing.removeRange(0, existing.length - 200);
      }
      await cacheMessages(threadId, existing);
    } catch (e) {
      debugPrint('CacheService: Erro ao adicionar mensagem ao cache: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERFIS
  // ══════════════════════════════════════════════════════════════════════════

  /// Salva perfil de um usuário no cache.
  static Future<void> cacheProfile(
      String userId, Map<String, dynamic> profile) async {
    try {
      final box = Hive.box<String>(_profilesBox);
      await box.put(userId, jsonEncode(profile));
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear perfil: $e');
    }
  }

  /// Recupera perfil de um usuário do cache.
  static Map<String, dynamic>? getCachedProfile(String userId) {
    try {
      final box = Hive.box<String>(_profilesBox);
      final data = box.get(userId);
      if (data == null) return null;
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      debugPrint('CacheService: Erro ao ler perfil do cache: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FEED GLOBAL
  // ══════════════════════════════════════════════════════════════════════════

  /// Salva o feed global no cache.
  static Future<void> cacheGlobalFeed(
      List<Map<String, dynamic>> posts) async {
    try {
      final box = Hive.box<String>(_feedBox);
      await box.put('global_feed', jsonEncode(posts));
      await _updateTimestamp('global_feed');
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear feed global: $e');
    }
  }

  /// Recupera o feed global do cache.
  static List<Map<String, dynamic>>? getCachedGlobalFeed() {
    try {
      final box = Hive.box<String>(_feedBox);
      final data = box.get('global_feed');
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      debugPrint('CacheService: Erro ao ler feed global do cache: $e');
      return null;
    }
  }

  /// Salva o feed "For You" no cache.
  static Future<void> cacheForYouFeed(
      List<Map<String, dynamic>> posts) async {
    try {
      final box = Hive.box<String>(_feedBox);
      await box.put('for_you_feed', jsonEncode(posts));
      await _updateTimestamp('for_you_feed');
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear feed For You: $e');
    }
  }

  /// Recupera o feed "For You" do cache.
  static List<Map<String, dynamic>>? getCachedForYouFeed() {
    try {
      final box = Hive.box<String>(_feedBox);
      final data = box.get('for_you_feed');
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      debugPrint('CacheService: Erro ao ler feed For You do cache: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICAÇÕES
  // ══════════════════════════════════════════════════════════════════════════

  /// Salva notificações no cache.
  static Future<void> cacheNotifications(
      List<Map<String, dynamic>> notifications) async {
    try {
      final box = Hive.box<String>(_notificationsBox);
      await box.put('notifications', jsonEncode(notifications));
      await _updateTimestamp('notifications');
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear notificações: $e');
    }
  }

  /// Recupera notificações do cache.
  static List<Map<String, dynamic>>? getCachedNotifications() {
    try {
      final box = Hive.box<String>(_notificationsBox);
      final data = box.get('notifications');
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      debugPrint('CacheService: Erro ao ler notificações do cache: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIKI
  // ══════════════════════════════════════════════════════════════════════════

  /// Salva entradas wiki de uma comunidade no cache.
  static Future<void> cacheWikiEntries(
      String communityId, List<Map<String, dynamic>> entries) async {
    try {
      final box = Hive.box<String>(_wikiBox);
      await box.put(communityId, jsonEncode(entries));
      await _updateTimestamp('wiki:$communityId');
    } catch (e) {
      debugPrint('CacheService: Erro ao cachear wiki: $e');
    }
  }

  /// Recupera entradas wiki de uma comunidade do cache.
  static List<Map<String, dynamic>>? getCachedWikiEntries(
      String communityId) {
    try {
      final box = Hive.box<String>(_wikiBox);
      final data = box.get(communityId);
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      debugPrint('CacheService: Erro ao ler wiki do cache: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ══════════════════════════════════════════════════════════════════════════

  /// Atualiza o timestamp de última sincronização de um recurso.
  static Future<void> _updateTimestamp(String key) async {
    try {
      final box = Hive.box<String>(_metadataBox);
      await box.put('ts:$key', DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      debugPrint('[cache_service] Erro: $e');
    }
  }

  /// Retorna o timestamp de última sincronização de um recurso.
  static DateTime? getLastSync(String key) {
    try {
      final box = Hive.box<String>(_metadataBox);
      final ts = box.get('ts:$key');
      if (ts == null) return null;
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }

  /// Verifica se o cache de um recurso está expirado.
  /// [maxAge] é a duração máxima do cache (padrão: 5 minutos).
  static bool isCacheExpired(String key,
      {Duration maxAge = const Duration(minutes: 5)}) {
    final lastSync = getLastSync(key);
    if (lastSync == null) return true;
    return DateTime.now().toUtc().difference(lastSync) > maxAge;
  }

  /// Verifica se o cache de um recurso existe.
  static bool hasCache(String key) {
    return getLastSync(key) != null;
  }

  /// Limpa todo o cache.
  static Future<void> clearAll() async {
    try {
      await Hive.box<String>(_postsBox).clear();
      await Hive.box<String>(_communitiesBox).clear();
      await Hive.box<String>(_messagesBox).clear();
      await Hive.box<String>(_profilesBox).clear();
      await Hive.box<String>(_feedBox).clear();
      await Hive.box<String>(_metadataBox).clear();
      await Hive.box<String>(_notificationsBox).clear();
      await Hive.box<String>(_wikiBox).clear();
      debugPrint('CacheService: Cache limpo com sucesso');
    } catch (e) {
      debugPrint('CacheService: Erro ao limpar cache: $e');
    }
  }

  /// Limpa o cache de um box específico.
  static Future<void> clearBox(String boxName) async {
    try {
      await Hive.box<String>(boxName).clear();
    } catch (e) {
      debugPrint('CacheService: Erro ao limpar box $boxName: $e');
    }
  }

  /// Retorna o tamanho total do cache em bytes (aproximado).
  static int getCacheSize() {
    int total = 0;
    try {
      for (final name in [
        _postsBox,
        _communitiesBox,
        _messagesBox,
        _profilesBox,
        _feedBox,
        _metadataBox,
        _notificationsBox,
        _wikiBox,
      ]) {
        final box = Hive.box<String>(name);
        for (final key in box.keys) {
          final value = box.get(key);
          if (value != null) {
            total += value.length * 2; // UTF-16 chars
          }
        }
      }
    } catch (e) {
      debugPrint('[cache_service] Erro: $e');
    }
    return total;
  }

  /// Retorna o tamanho do cache formatado (KB, MB).
  static String getFormattedCacheSize() {
    final bytes = getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
