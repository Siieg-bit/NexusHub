import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import 'package:flutter/foundation.dart';

/// ============================================================================
/// NotificationProvider — State Management para notificações.
///
/// Gerencia:
/// - Lista de notificações (paginada) com dados do ator (perfil)
/// - Contagem de não lidas
/// - Marcar como lida (individual e em massa)
/// - Realtime para novas notificações
/// - Feedback de erro em páginas intermediárias (Sprint 3D)
/// - Cache offline-first via CacheService (Sprint 3D)
/// ============================================================================

class NotificationState {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final bool hasMore;

  /// Erro ocorrido ao carregar página intermediária.
  /// Quando não-nulo, a tela deve exibir retry inline ao invés de spinner.
  final String? loadMoreError;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = true,
    this.loadMoreError,
  });

  NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    bool? hasMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  int _page = 0;
  static const _pageSize = 20;
  bool _isLoadingMore = false;
  RealtimeChannel? _channel;

  /// Select com join para trazer dados do ator (quem gerou a notificação).
  /// A foreign key `notifications_actor_id_fkey` aponta para `profiles`.
  static const _selectWithActor =
      '*, profiles!notifications_actor_id_fkey(id, nickname, icon_url)';

  @override
  Future<NotificationState> build() async {
    _page = 0;
    _subscribeRealtime();

    ref.onDispose(() {
      _channel?.unsubscribe();
    });

    return _fetch();
  }

  Future<NotificationState> _fetch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const NotificationState();

    // ── Cache-first: exibir dados do cache enquanto busca rede ──
    final cached = CacheService.getCachedNotifications();
    NotificationState? cachedState;
    if (cached != null && cached.isNotEmpty) {
      cachedState = NotificationState(
        notifications: cached,
        unreadCount: cached.where((n) => n['is_read'] != true).length,
        hasMore: cached.length >= _pageSize,
      );
    }

    try {
      final res = await SupabaseService.table('notifications')
          .select(_selectWithActor)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      final unreadRes = await SupabaseService.table('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);

      final list = List<Map<String, dynamic>>.from(res as List? ?? []);

      // Atualizar cache com dados frescos
      CacheService.cacheNotifications(list);

      return NotificationState(
        notifications: list,
        unreadCount: unreadRes.count,
        hasMore: list.length >= _pageSize,
      );
    } catch (e) {
      // Se o join falhar (ex: FK não existe), fallback sem join
      try {
        final res = await SupabaseService.table('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .range(0, _pageSize - 1);

        final unreadRes = await SupabaseService.table('notifications')
            .select()
            .eq('user_id', userId)
            .eq('is_read', false)
            .count(CountOption.exact);

        final list = List<Map<String, dynamic>>.from(res as List? ?? []);

        CacheService.cacheNotifications(list);

        return NotificationState(
          notifications: list,
          unreadCount: unreadRes.count,
          hasMore: list.length >= _pageSize,
        );
      } catch (_) {
        // Se offline e temos cache, usar cache
        if (cachedState != null) return cachedState;
        return const NotificationState();
      }
    }
  }

  void _subscribeRealtime() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final current = state.valueOrNull;
            if (current == null) return;
            state = AsyncData(current.copyWith(
              notifications: [payload.newRecord, ...current.notifications],
              unreadCount: current.unreadCount + 1,
            ));
          },
        )
        .subscribe();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    _page++;
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('notifications')
          .select(_selectWithActor)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      state = AsyncData(current.copyWith(
        notifications: [...current.notifications, ...list],
        hasMore: list.length >= _pageSize,
        clearLoadMoreError: true,
      ));
    } catch (e) {
      _page--;
      // Surfacear o erro no state para que a tela mostre retry inline
      state = AsyncData(current.copyWith(
        loadMoreError: 'Erro ao carregar mais notificações',
      ));
      debugPrint('[notification_provider] loadMore error: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Retry explícito após falha em loadMore.
  /// Limpa o erro e tenta novamente.
  Future<void> retryLoadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearLoadMoreError: true));
    await loadMore();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.table('notifications')
          .update({'is_read': true}).eq('id', notificationId);

      final current = state.valueOrNull;
      if (current == null) return;

      final updated = current.notifications.map((n) {
        if (n['id'] == notificationId) {
          return {...n, 'is_read': true};
        }
        return n;
      }).toList();

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: (current.unreadCount - 1).clamp(0, 999),
      ));
    } catch (e) {
      debugPrint('[notification_provider] Erro: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      final current = state.valueOrNull;
      if (current == null) return;

      final updated = current.notifications.map((n) {
        return {...n, 'is_read': true};
      }).toList();

      state = AsyncData(current.copyWith(
        notifications: updated,
        unreadCount: 0,
      ));
    } catch (e) {
      debugPrint('[notification_provider] Erro: $e');
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _isLoadingMore = false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationState>(
        NotificationNotifier.new);

// ── Unread badge count (lightweight, derived from main provider) ──
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifState = ref.watch(notificationProvider);
  return notifState.valueOrNull?.unreadCount ?? 0;
});
