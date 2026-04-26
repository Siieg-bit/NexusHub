import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../services/realtime_service.dart';
import '../services/push_notification_service.dart';

// =============================================================================
// NotificationProvider — Sistema completo de notificações
// Suporta: paginação, filtros por categoria, realtime, agrupamento, cache
// =============================================================================

// ── Categorias de notificação ─────────────────────────────────────────────────
enum NotificationCategory {
  all,
  social,
  chat,
  community,
  system;

  String get label => switch (this) {
        NotificationCategory.all       => 'Tudo',
        NotificationCategory.social    => 'Social',
        NotificationCategory.chat      => 'Chat',
        NotificationCategory.community => 'Comunidade',
        NotificationCategory.system    => 'Sistema',
      };

  String get rpcValue => switch (this) {
        NotificationCategory.all       => 'all',
        NotificationCategory.social    => 'social',
        NotificationCategory.chat      => 'chat',
        NotificationCategory.community => 'community',
        NotificationCategory.system    => 'system',
      };
}

// ── Estado ────────────────────────────────────────────────────────────────────
class NotificationState {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
  final NotificationCategory category;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.category = NotificationCategory.all,
  });

  NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
    NotificationCategory? category,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      category: category ?? this.category,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class NotificationNotifier extends AsyncNotifier<NotificationState> {
  static const int _pageSize = 30;
  int _page = 0;
  bool _isLoadingMore = false;

  bool _isGlobalNotification(Map<String, dynamic> notification) {
    final communityId = notification['community_id'];
    return communityId == null ||
        (communityId is String && communityId.trim().isEmpty);
  }

  List<Map<String, dynamic>> _filterGlobalNotifications(List<dynamic> rows) {
    return rows
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where(_isGlobalNotification)
        .toList();
  }

  @override
  Future<NotificationState> build() async {
    _page = 0;
    _isLoadingMore = false;
    _subscribeRealtime();

    ref.onDispose(() {
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        RealtimeService.instance.unsubscribe('notifications:$userId');
      }
    });

    return _fetch(category: NotificationCategory.all);
  }

  // ─── Fetch principal ───────────────────────────────────────────────────────
  Future<NotificationState> _fetch({
    NotificationCategory category = NotificationCategory.all,
    int offset = 0,
    List<Map<String, dynamic>> existing = const [],
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const NotificationState(hasMore: false);

    // Cache-first apenas na primeira página
    if (offset == 0) {
      final cached = CacheService.getCachedNotifications();
      if (cached != null && cached.isNotEmpty) {
        final globalCached = cached.where(_isGlobalNotification).toList();
        // Retornar cache imediatamente e atualizar em background
        _fetchAndUpdate(category: category);
        return NotificationState(
          notifications: globalCached,
          unreadCount: globalCached.where((n) => n['is_read'] != true).length,
          hasMore: globalCached.length >= _pageSize,
          category: category,
        );
      }
    }

    return _fetchFromNetwork(
      category: category,
      offset: offset,
      existing: existing,
    );
  }

  Future<NotificationState> _fetchFromNetwork({
    required NotificationCategory category,
    int offset = 0,
    List<Map<String, dynamic>> existing = const [],
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const NotificationState(hasMore: false);

    try {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          SupabaseService.table('notifications').select(
        '*, profiles!notifications_actor_id_fkey(id, nickname, icon_url)',
      );

      query = query.eq('user_id', userId).isFilter('community_id', null);

      switch (category) {
        case NotificationCategory.social:
          query = query.inFilter('type', ['like', 'comment', 'follow', 'mention', 'wall_post', 'match']);
          break;
        case NotificationCategory.chat:
          query = query.inFilter('type', ['chat_message', 'chat_mention', 'dm_invite', 'roleplay']);
          break;
        case NotificationCategory.community:
          query = query.inFilter('type', ['community_invite', 'community_update', 'join_request', 'role_change']);
          break;
        case NotificationCategory.system:
          query = query.inFilter('type', ['level_up', 'achievement', 'check_in_streak', 'moderation', 'strike', 'ban', 'broadcast', 'wiki_approved', 'wiki_rejected', 'tip']);
          break;
        case NotificationCategory.all:
          break;
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final items = _filterGlobalNotifications(rows);
      final unreadCount = await _fetchUnreadCount();

      if (offset == 0) {
        await CacheService.cacheNotifications(items);
      }

      return NotificationState(
        notifications: [...existing, ...items],
        unreadCount: unreadCount,
        hasMore: items.length == _pageSize,
        category: category,
      );
    } catch (e) {
      debugPrint('[notification_provider] Falha ao buscar notificações globais: $e');
      return _fetchFallback(
        category: category,
        offset: offset,
        existing: existing,
      );
    }
  }

  Future<NotificationState> _fetchFallback({
    required NotificationCategory category,
    int offset = 0,
    List<Map<String, dynamic>> existing = const [],
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const NotificationState(hasMore: false);

    try {
      final rows = await SupabaseService.table('notifications')
          .select('*, profiles!notifications_actor_id_fkey(id, nickname, icon_url)')
          .eq('user_id', userId)
          .isFilter('community_id', null)
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final items = _filterGlobalNotifications(rows as List<dynamic>);

      final unreadCount = await SupabaseService.table('notifications')
          .select()
          .eq('user_id', userId)
          .isFilter('community_id', null)
          .eq('is_read', false)
          .count(CountOption.exact);

      if (offset == 0) {
        await CacheService.cacheNotifications(items);
      }

      return NotificationState(
        notifications: [...existing, ...items],
        unreadCount: unreadCount.count,
        hasMore: items.length == _pageSize,
        category: category,
      );
    } catch (e2) {
      debugPrint('[notification_provider] Fallback também falhou: $e2');
      // Tentar cache como último recurso
      final cached = CacheService.getCachedNotifications();
      if (cached != null && cached.isNotEmpty) {
        final globalCached = cached.where(_isGlobalNotification).toList();
        return NotificationState(
          notifications: globalCached,
          unreadCount: globalCached.where((n) => n['is_read'] != true).length,
          hasMore: false,
          category: category,
        );
      }
      return const NotificationState(hasMore: false);
    }
  }

  /// Busca em background e atualiza o estado sem loading indicator
  void _fetchAndUpdate({required NotificationCategory category}) {
    _fetchFromNetwork(category: category).then((fresh) {
      if (state.hasValue) {
        state = AsyncData(fresh);
      }
    }).catchError((e) {
      debugPrint('[notification_provider] Background refresh falhou: $e');
    });
  }

  Future<int> _fetchUnreadCount() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return 0;
      final res = await SupabaseService.table('notifications')
          .select()
          .eq('user_id', userId)
          .isFilter('community_id', null)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  // ─── Realtime subscription ─────────────────────────────────────────────────
  void _subscribeRealtime() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    RealtimeService.instance.subscribeWithRetry(
      channelName: 'notifications:$userId',
      configure: (channel) {
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) => _onNewNotification(payload.newRecord),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) => _onUpdateNotification(payload.newRecord),
            );
      },
    );
  }

  void _onNewNotification(Map<String, dynamic> record) {
    if (!_isGlobalNotification(record)) return;

    final current = state.valueOrNull;
    if (current == null) return;

    // Verificar se é atualização de notificação agrupada existente
    final groupKey = record['group_key'] as String?;
    if (groupKey != null) {
      final existingIndex = current.notifications.indexWhere(
        (n) => n['group_key'] == groupKey && n['is_read'] == false,
      );
      if (existingIndex >= 0) {
        final updated = List<Map<String, dynamic>>.from(current.notifications);
        updated[existingIndex] = {...updated[existingIndex], ...record};
        state = AsyncData(current.copyWith(notifications: updated));
        return;
      }
    }

    // Nova notificação no topo
    state = AsyncData(current.copyWith(
      notifications: [record, ...current.notifications],
      unreadCount: current.unreadCount + 1,
    ));
  }

  void _onUpdateNotification(Map<String, dynamic> record) {
    if (!_isGlobalNotification(record)) return;

    final current = state.valueOrNull;
    if (current == null) return;

    final id = record['id'] as String?;
    if (id == null) return;

    final updated = current.notifications.map((n) {
      if (n['id'] == id) return {...n, ...record};
      return n;
    }).toList();

    state = AsyncData(current.copyWith(notifications: updated));
  }

  // ─── Ações públicas ────────────────────────────────────────────────────────

  Future<void> setCategory(NotificationCategory category) async {
    _page = 0;
    _isLoadingMore = false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchFromNetwork(category: category),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    _page++;
    state = AsyncData(current.copyWith(isLoadingMore: true, clearLoadMoreError: true));

    try {
      final offset = _page * _pageSize;
      final next = await _fetchFromNetwork(
        category: current.category,
        offset: offset,
        existing: current.notifications,
      );
      state = AsyncData(next.copyWith(isLoadingMore: false));
    } catch (e) {
      _page--;
      final cur = state.valueOrNull ?? current;
      state = AsyncData(cur.copyWith(
        isLoadingMore: false,
        loadMoreError: 'Erro ao carregar mais notificações',
      ));
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> retryLoadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearLoadMoreError: true));
    await loadMore();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.table('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', SupabaseService.currentUserId ?? '')
          .isFilter('community_id', null);

      final current = state.valueOrNull;
      if (current == null) return;

      bool wasUnread = false;
      final updated = current.notifications.map((n) {
        if (n['id'] == notificationId && n['is_read'] == false) {
          wasUnread = true;
          return {...n, 'is_read': true};
        }
        return n;
      }).toList();

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: wasUnread
            ? (current.unreadCount - 1).clamp(0, 999)
            : current.unreadCount,
      ));
    } catch (e) {
      debugPrint('[notification_provider] Erro markAsRead: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .isFilter('community_id', null)
          .eq('is_read', false);

      final current = state.valueOrNull;
      if (current == null) return;

      final updated = current.notifications
          .map((n) => {...n, 'is_read': true})
          .toList();

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: 0,
      ));
    } catch (e) {
      debugPrint('[notification_provider] Erro markAllAsRead: $e');
    }
  }

  Future<void> markCategoryAsRead(NotificationCategory category) async {
    if (category == NotificationCategory.all) {
      await markAllAsRead();
      return;
    }

    try {
      final types = switch (category) {
        NotificationCategory.social    => ['like', 'comment', 'follow', 'mention', 'wall_post', 'match'],
        NotificationCategory.chat      => ['chat_message', 'chat_mention', 'dm_invite', 'roleplay'],
        NotificationCategory.community => ['community_invite', 'community_update', 'join_request', 'role_change'],
        NotificationCategory.system    => ['level_up', 'achievement', 'check_in_streak', 'moderation', 'strike', 'ban', 'broadcast', 'wiki_approved', 'wiki_rejected', 'tip'],
        NotificationCategory.all       => <String>[],
      };

      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .isFilter('community_id', null)
          .eq('is_read', false)
          .inFilter('type', types);

      final current = state.valueOrNull;
      if (current == null) return;

      final updated = current.notifications.map((n) {
        if (types.contains(n['type'])) return {...n, 'is_read': true};
        return n;
      }).toList();

      final newUnread = updated.where((n) => n['is_read'] == false).length;

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: newUnread,
      ));
    } catch (e) {
      debugPrint('[notification_provider] Erro markCategoryAsRead: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await SupabaseService.table('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', SupabaseService.currentUserId ?? '')
          .isFilter('community_id', null);

      final current = state.valueOrNull;
      if (current == null) return;

      final wasUnread = current.notifications
          .any((n) => n['id'] == notificationId && n['is_read'] == false);

      final updated = current.notifications
          .where((n) => n['id'] != notificationId)
          .toList();

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: wasUnread
            ? (current.unreadCount - 1).clamp(0, 999)
            : current.unreadCount,
      ));
    } catch (e) {
      debugPrint('[notification_provider] Erro deleteNotification: $e');
    }
  }

  Future<void> deleteAll() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('notifications')
          .delete()
          .eq('user_id', userId)
          .isFilter('community_id', null);
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(current.copyWith(
        notifications: [],
        unreadCount: 0,
        hasMore: false,
      ));
    } catch (e) {
      debugPrint('[notification_provider] Erro deleteAll: $e');
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _isLoadingMore = false;
    final currentCategory = state.valueOrNull?.category ?? NotificationCategory.all;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchFromNetwork(category: currentCategory),
    );
  }
}

class CommunityNotificationNotifier
    extends FamilyAsyncNotifier<NotificationState, String> {
  static const int _pageSize = 30;
  int _page = 0;
  bool _isLoadingMore = false;

  @override
  Future<NotificationState> build(String communityId) async {
    _page = 0;
    _isLoadingMore = false;
    _subscribeRealtime(communityId);

    ref.onDispose(() {
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        RealtimeService.instance.unsubscribe(
          'community_notifications:$userId:$communityId',
        );
      }
    });

    return _fetchFromNetwork(
      communityId: communityId,
      category: NotificationCategory.all,
    );
  }

  Future<NotificationState> _fetchFromNetwork({
    required String communityId,
    required NotificationCategory category,
    int offset = 0,
    List<Map<String, dynamic>> existing = const [],
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const NotificationState(hasMore: false);

    try {
      // Usar RPC para buscar notificações com perfil local correto do ator
      final categoryValue = switch (category) {
        NotificationCategory.social => 'social',
        NotificationCategory.chat => 'chat',
        NotificationCategory.community => 'community',
        NotificationCategory.system => 'system',
        NotificationCategory.all => 'all',
      };

      final rows = await SupabaseService.rpc(
        'get_community_notifications_by_category',
        params: {
          'p_community_id': communityId,
          'p_category': categoryValue,
          'p_limit': _pageSize,
          'p_offset': offset,
        },
      ) as List<dynamic>;

      final items = rows
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Transformar dados da RPC para o formato esperado pelo frontend
      final normalizedItems = items.map((item) {
        final actorLocalNickname = item['actor_local_nickname'] as String?;
        final actorLocalIconUrl = item['actor_local_icon_url'] as String?;
        final actorGlobalNickname = item['actor_global_nickname'] as String?;
        final actorGlobalIconUrl = item['actor_global_icon_url'] as String?;

        return {
          ...item,
          // Estrutura esperada pela tela: community_members com dados locais
          'community_members': actorLocalNickname != null || actorLocalIconUrl != null
              ? {
                  'local_nickname': actorLocalNickname,
                  'local_icon_url': actorLocalIconUrl,
                }
              : null,
          // Estrutura esperada pela tela: profiles com dados globais
          'profiles': {
            'id': item['actor_id'],
            'nickname': actorGlobalNickname,
            'icon_url': actorGlobalIconUrl,
          },
        };
      }).toList();

      final unreadCount = await _fetchUnreadCount(communityId);

      return NotificationState(
        notifications: [...existing, ...normalizedItems],
        unreadCount: unreadCount,
        hasMore: items.length == _pageSize,
        category: category,
      );
    } catch (e) {
      debugPrint('[community_notification_provider] Falha ao buscar alertas da comunidade: $e');
      return NotificationState(
        notifications: existing,
        unreadCount: existing.where((n) => n['is_read'] != true).length,
        hasMore: false,
        category: category,
      );
    }
  }

  Future<int> _fetchUnreadCount(String communityId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return 0;
      final res = await SupabaseService.table('notifications')
          .select()
          .eq('user_id', userId)
          .eq('community_id', communityId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  void _subscribeRealtime(String communityId) {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    RealtimeService.instance.subscribeWithRetry(
      channelName: 'community_notifications:$userId:$communityId',
      configure: (channel) {
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) => _onNewNotification(
                communityId,
                payload.newRecord,
              ),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) => _onUpdateNotification(
                communityId,
                payload.newRecord,
              ),
            );
      },
    );
  }

  void _onNewNotification(String communityId, Map<String, dynamic> record) {
    if (record['community_id'] != communityId) return;

    final current = state.valueOrNull;
    if (current == null) return;

    final groupKey = record['group_key'] as String?;
    if (groupKey != null) {
      final existingIndex = current.notifications.indexWhere(
        (n) => n['group_key'] == groupKey && n['is_read'] == false,
      );
      if (existingIndex >= 0) {
        final updated = List<Map<String, dynamic>>.from(current.notifications);
        updated[existingIndex] = {...updated[existingIndex], ...record};
        state = AsyncData(current.copyWith(notifications: updated));
        return;
      }
    }

    state = AsyncData(current.copyWith(
      notifications: [record, ...current.notifications],
      unreadCount: current.unreadCount + 1,
    ));
  }

  void _onUpdateNotification(String communityId, Map<String, dynamic> record) {
    if (record['community_id'] != communityId) return;

    final current = state.valueOrNull;
    if (current == null) return;

    final id = record['id'] as String?;
    if (id == null) return;

    final updated = current.notifications.map((n) {
      if (n['id'] == id) return {...n, ...record};
      return n;
    }).toList();

    state = AsyncData(current.copyWith(notifications: updated));
  }

  Future<void> setCategory(NotificationCategory category) async {
    _page = 0;
    _isLoadingMore = false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchFromNetwork(communityId: arg, category: category),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    _page++;
    state = AsyncData(current.copyWith(isLoadingMore: true, clearLoadMoreError: true));

    try {
      final offset = _page * _pageSize;
      final next = await _fetchFromNetwork(
        communityId: arg,
        category: current.category,
        offset: offset,
        existing: current.notifications,
      );
      state = AsyncData(next.copyWith(isLoadingMore: false));
    } catch (_) {
      _page--;
      final cur = state.valueOrNull ?? current;
      state = AsyncData(cur.copyWith(
        isLoadingMore: false,
        loadMoreError: 'Erro ao carregar mais alertas da comunidade',
      ));
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> retryLoadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearLoadMoreError: true));
    await loadMore();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.table('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', SupabaseService.currentUserId ?? '')
          .eq('community_id', arg);

      final current = state.valueOrNull;
      if (current == null) return;

      bool wasUnread = false;
      final updated = current.notifications.map((n) {
        if (n['id'] == notificationId && n['is_read'] == false) {
          wasUnread = true;
          return {...n, 'is_read': true};
        }
        return n;
      }).toList();

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: wasUnread
            ? (current.unreadCount - 1).clamp(0, 999)
            : current.unreadCount,
      ));
    } catch (e) {
      debugPrint('[community_notification_provider] Erro markAsRead: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('community_id', arg)
          .eq('is_read', false);

      final current = state.valueOrNull;
      if (current == null) return;

      final updated = current.notifications
          .map((n) => {...n, 'is_read': true})
          .toList();

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: 0,
      ));
    } catch (e) {
      debugPrint('[community_notification_provider] Erro markAllAsRead: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await SupabaseService.rpc('delete_notification', params: {
        'p_notification_id': notificationId,
      });

      final current = state.valueOrNull;
      if (current == null) return;

      final wasUnread = current.notifications
          .any((n) => n['id'] == notificationId && n['is_read'] == false);

      final updated = current.notifications
          .where((n) => n['id'] != notificationId)
          .toList();

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: wasUnread
            ? (current.unreadCount - 1).clamp(0, 999)
            : current.unreadCount,
      ));
    } catch (e) {
      debugPrint('[community_notification_provider] Erro deleteNotification: $e');
    }
  }

  Future<void> deleteAll() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('notifications')
          .delete()
          .eq('user_id', userId)
          .eq('community_id', arg);

      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(current.copyWith(
        notifications: [],
        unreadCount: 0,
        hasMore: false,
      ));
    } catch (e) {
      debugPrint('[community_notification_provider] Erro deleteAll: $e');
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _isLoadingMore = false;
    final currentCategory = state.valueOrNull?.category ?? NotificationCategory.all;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchFromNetwork(communityId: arg, category: currentCategory),
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationState>(
        NotificationNotifier.new);

final communityNotificationProvider = AsyncNotifierProvider.family<
    CommunityNotificationNotifier, NotificationState, String>(
  CommunityNotificationNotifier.new,
);

/// Badge count — derivado do provider principal (leve, sem rebuild desnecessário)
/// Também atualiza o badge no ícone do app automaticamente.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifState = ref.watch(notificationProvider);
  final count = notifState.valueOrNull?.unreadCount ?? 0;
  // Atualizar badge no ícone do app sempre que o count mudar
  PushNotificationService.updateBadgeFromUnreadCount(count);
  return count;
});

/// Badge count de notificações não lidas de uma comunidade específica.
/// Derivado do communityNotificationProvider (sem rebuild desnecessário).
final unreadCommunityNotificationCountProvider =
    Provider.family<int, String>((ref, communityId) {
  final state = ref.watch(communityNotificationProvider(communityId));
  return state.valueOrNull?.unreadCount ?? 0;
});

/// Total de notificações não lidas em TODAS as comunidades do usuário.
/// Usado para o badge na aba "Comunidades" da bottom nav.
final totalUnreadCommunityNotificationsProvider = StreamProvider<int>((ref) {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return Stream.value(0);

  return SupabaseService.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((rows) {
        return rows
            .where((r) =>
                r['is_read'] == false &&
                r['community_id'] != null &&
                (r['community_id'] as String).isNotEmpty)
            .length;
      });
});

/// Categoria selecionada atual
final notificationCategoryProvider = Provider<NotificationCategory>((ref) {
  final notifState = ref.watch(notificationProvider);
  return notifState.valueOrNull?.category ?? NotificationCategory.all;
});
