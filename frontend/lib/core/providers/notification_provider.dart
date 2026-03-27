import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// ============================================================================
/// NotificationProvider — State Management para notificações.
///
/// Gerencia:
/// - Lista de notificações (paginada)
/// - Contagem de não lidas
/// - Marcar como lida
/// - Realtime para novas notificações
/// ============================================================================

class NotificationState {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final bool hasMore;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = true,
  });

  NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    bool? hasMore,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  int _page = 0;
  static const _pageSize = 20;
  RealtimeChannel? _channel;

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

    final list = List<Map<String, dynamic>>.from(res as List);

    return NotificationState(
      notifications: list,
      unreadCount: unreadRes.count,
      hasMore: list.length >= _pageSize,
    );
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
    if (current == null || !current.hasMore) return;

    _page++;
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      final list = List<Map<String, dynamic>>.from(res as List);
      state = AsyncData(current.copyWith(
        notifications: [...current.notifications, ...list],
        hasMore: list.length >= _pageSize,
      ));
    } catch (e) {
      _page--;
    }
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
    } catch (_) {}
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
    } catch (_) {}
  }

  Future<void> refresh() async {
    _page = 0;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationState>(
        NotificationNotifier.new);

// ── Unread badge count (lightweight) ──
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return 0;

  final res = await SupabaseService.table('notifications')
      .select()
      .eq('user_id', userId)
      .eq('is_read', false)
      .count(CountOption.exact);

  return res.count;
});
