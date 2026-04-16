import 'dart:async';

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Serviço de presença baseado em janelas de 15 minutos.
///
/// Em vez de usar presença em tempo real por canal, o app apenas mantém
/// `profiles.last_seen_at` atualizado a cada 15 minutos e deriva o estado
/// online/offline a partir desse timestamp.
///
/// Se `profiles.is_ghost_mode = true`, o usuário sempre aparece offline para os
/// demais, independentemente da atividade recente.
class PresenceService {
  PresenceService._();
  static final PresenceService _instance = PresenceService._();
  static PresenceService get instance => _instance;

  static const Duration heartbeatInterval = Duration(minutes: 15);
  static const Duration onlineWindow = Duration(minutes: 15);

  Timer? _heartbeatTimer;
  String? _currentUserId;
  DateTime? _lastHeartbeatAt;

  Future<void> initialize() async {
    _currentUserId = SupabaseService.currentUserId;
    if (_currentUserId == null) return;

    _heartbeatTimer?.cancel();
    await refreshPresenceNow(forceOnline: true);
    _heartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (_) => refreshPresenceNow(),
    );
  }

  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final uid = _currentUserId;
    _currentUserId = null;
    if (uid == null) return;

    try {
      await SupabaseService.table('profiles').update({
        'online_status': 2,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('[PresenceService] Erro ao finalizar presença: $e');
    }
  }

  Future<void> refreshPresenceNow({bool forceOnline = false}) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final profile = await SupabaseService.table('profiles')
          .select('is_ghost_mode')
          .eq('id', uid)
          .maybeSingle();

      final isGhostMode = profile?['is_ghost_mode'] as bool? ?? false;
      final nowUtc = DateTime.now().toUtc();
      final payload = <String, dynamic>{
        'last_seen_at': nowUtc.toIso8601String(),
        'online_status': (forceOnline || !isGhostMode) ? 1 : 2,
      };

      await SupabaseService.table('profiles').update(payload).eq('id', uid);
      _lastHeartbeatAt = nowUtc;
    } catch (e) {
      debugPrint('[PresenceService] Erro ao atualizar presença: $e');
    }
  }

  Future<void> setManualOfflineMode(bool isOffline) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final nowUtc = DateTime.now().toUtc();
    try {
      await SupabaseService.table('profiles').update({
        'is_ghost_mode': isOffline,
        'online_status': isOffline ? 2 : 1,
        'last_seen_at': nowUtc.toIso8601String(),
      }).eq('id', uid);
      _lastHeartbeatAt = nowUtc;
    } catch (e) {
      debugPrint('[PresenceService] Erro ao alternar modo offline manual: $e');
      rethrow;
    }
  }

  bool isConsideredOnline({
    required int onlineStatus,
    required bool isGhostMode,
    required DateTime? lastSeenAt,
    DateTime? now,
  }) {
    if (isGhostMode) return false;
    if (onlineStatus == 1 && lastSeenAt == null) return true;
    if (lastSeenAt == null) return false;

    final reference = now?.toUtc() ?? DateTime.now().toUtc();
    return reference.difference(lastSeenAt.toUtc()) <= onlineWindow;
  }

  int bucketLastSeenMinutes(DateTime? lastSeenAt, {DateTime? now}) {
    if (lastSeenAt == null) return 0;
    final reference = now?.toUtc() ?? DateTime.now().toUtc();
    final minutes = reference.difference(lastSeenAt.toUtc()).inMinutes;
    if (minutes <= 0) return 0;
    return ((minutes + 14) ~/ 15) * 15;
  }

  String formatGradualLastSeen(
    DateTime? lastSeenAt, {
    required bool isGhostMode,
    int onlineStatus = 2,
    DateTime? now,
  }) {
    if (isConsideredOnline(
      onlineStatus: onlineStatus,
      isGhostMode: isGhostMode,
      lastSeenAt: lastSeenAt,
      now: now,
    )) {
      return 'online';
    }

    final reference = now?.toUtc() ?? DateTime.now().toUtc();
    final seenAt = lastSeenAt;
    if (seenAt == null) return 'offline';
    final elapsed = reference.difference(seenAt.toUtc());
    if (elapsed.inMinutes < 1) return 'agora mesmo';
    if (elapsed.inMinutes < 60) {
      final m = elapsed.inMinutes;
      return 'há $m ${m == 1 ? 'minuto' : 'minutos'}';
    }
    if (elapsed.inHours < 24) {
      final h = elapsed.inHours;
      return 'há $h ${h == 1 ? 'hora' : 'horas'}';
    }
    if (elapsed.inDays < 30) {
      final d = elapsed.inDays;
      return 'há $d ${d == 1 ? 'dia' : 'dias'}';
    }
    if (elapsed.inDays < 365) {
      final mo = (elapsed.inDays / 30).floor();
      return 'há $mo ${mo == 1 ? 'mês' : 'meses'}';
    }
    final y = (elapsed.inDays / 365).floor();
    return 'há $y ${y == 1 ? 'ano' : 'anos'}';
  }

  DateTime? get lastHeartbeatAt => _lastHeartbeatAt;

  @Deprecated('Presença em tempo real foi removida em favor de janelas de 15 minutos.')
  Stream<Set<String>> onlineUsersStream(String channelId) =>
      const Stream<Set<String>>.empty();

  @Deprecated('Presença em tempo real foi removida em favor de janelas de 15 minutos.')
  Future<void> joinChannel(String channelId) async {}

  @Deprecated('Presença em tempo real foi removida em favor de janelas de 15 minutos.')
  Future<void> leaveChannel(String channelId) async {}

  @Deprecated('Presença em tempo real foi removida em favor de janelas de 15 minutos.')
  Set<String> getOnlineUsers(String channelId) => const {};

  @Deprecated('Presença em tempo real foi removida em favor de janelas de 15 minutos.')
  int getOnlineCount(String channelId) => 0;

  @Deprecated('Presença em tempo real foi removida em favor de janelas de 15 minutos.')
  bool isUserOnline(String userId) => false;

  @Deprecated('Presença em tempo real foi removida em favor de janelas de 15 minutos.')
  bool isUserOnlineInChannel(String channelId, String userId) => false;
}
