import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/sync_event.dart';
import 'screening_player_provider.dart';

// =============================================================================
// ScreeningSyncProvider — Sincronização de reprodução em tempo real
//
// Implementa o algoritmo de dois níveis do Rave:
//
// MACROSYNC: Quando o drift entre o cliente e o host é > 2s, aplica um
//   seekTo() direto para a posição correta. Acionado por eventos de
//   play/pause/seek recebidos via Supabase Realtime Broadcast.
//
// MICROSYNC: A cada 2s, verifica o drift atual. Se estiver entre 300ms e 2s,
//   ajusta a velocidade de reprodução (1.05x ou 0.95x) para alcançar a
//   posição correta gradualmente, sem interrupção perceptível.
//
// O timestamp do servidor é incluído em cada evento para compensar a
// latência de rede no cálculo da posição esperada.
// =============================================================================

// Thresholds do algoritmo de sync (em milissegundos)
const _kMacrosyncThresholdMs = 2000;
const _kMicrosyncThresholdMs = 300;
const _kSyncIntervalSeconds = 2;

final screeningSyncProvider = StateNotifierProvider.family<
    ScreeningSyncNotifier, AsyncValue<void>, String>(
  (ref, sessionId) => ScreeningSyncNotifier(sessionId: sessionId, ref: ref),
);

class ScreeningSyncNotifier extends StateNotifier<AsyncValue<void>> {
  final String sessionId;
  final Ref ref;

  RealtimeChannel? _channel;
  Timer? _microsyncTimer;

  // Estado de referência do host para o Microsync contínuo
  Duration _hostReferencePosition = Duration.zero;
  DateTime _hostReferenceTimestamp = DateTime.now();
  bool _isHostPlaying = false;

  ScreeningSyncNotifier({required this.sessionId, required this.ref})
      : super(const AsyncValue.data(null)) {
    _subscribeToSyncEvents();
  }

  // ── Subscrição ao canal de sync ─────────────────────────────────────────────

  void _subscribeToSyncEvents() {
    _channel = SupabaseService.client.channel('screening_sync_$sessionId')
      ..onBroadcast(
        event: 'sync',
        callback: (payload) {
          try {
            final event = SyncEvent.fromBroadcast(payload);
            _handleSyncEvent(event);
          } catch (e) {
            debugPrint('[ScreeningSync] parse error: $e');
          }
        },
      )
      ..subscribe();
  }

  // ── Processar evento de sync recebido ───────────────────────────────────────

  void _handleSyncEvent(SyncEvent event) {
    final hostTimestamp =
        DateTime.fromMillisecondsSinceEpoch(event.serverTimestampMs);
    final hostPosition = Duration(milliseconds: event.positionMs);

    switch (event.type) {
      case SyncEventType.play:
        _isHostPlaying = true;
        _hostReferencePosition = hostPosition;
        _hostReferenceTimestamp = hostTimestamp;
        ref.read(screeningPlayerProvider(sessionId).notifier).play();
        _applyMacrosync(hostPosition, hostTimestamp);
        _startMicrosyncTimer();
        break;

      case SyncEventType.pause:
        _isHostPlaying = false;
        _stopMicrosyncTimer();
        ref.read(screeningPlayerProvider(sessionId).notifier).pause();
        // Ao pausar, sincroniza a posição exata
        ref.read(screeningPlayerProvider(sessionId).notifier).seek(hostPosition);
        ref.read(screeningPlayerProvider(sessionId).notifier).setRate(1.0);
        break;

      case SyncEventType.seek:
        _hostReferencePosition = hostPosition;
        _hostReferenceTimestamp = hostTimestamp;
        _applyMacrosync(hostPosition, hostTimestamp);
        if (_isHostPlaying) _startMicrosyncTimer();
        break;

      case SyncEventType.changeVideo:
        // O ScreeningRoomProvider já trata a troca de vídeo via 'video_changed'
        // O sync será reiniciado quando o novo vídeo carregar
        _stopMicrosyncTimer();
        _isHostPlaying = false;
        break;

      case SyncEventType.hostChange:
        // Nada a fazer no sync — o ScreeningRoomProvider trata a mudança de host
        break;
    }
  }

  // ── Macrosync ───────────────────────────────────────────────────────────────

  void _applyMacrosync(Duration hostPosition, DateTime hostTimestamp) {
    final latency = DateTime.now().difference(hostTimestamp);
    final expectedPosition = hostPosition + latency;

    final playerState = ref.read(screeningPlayerProvider(sessionId));
    final localPosition = playerState.position;
    final driftMs =
        expectedPosition.inMilliseconds - localPosition.inMilliseconds;

    if (driftMs.abs() > _kMacrosyncThresholdMs) {
      debugPrint('[ScreeningSync] MACROSYNC drift=${driftMs}ms → seek');
      ref
          .read(screeningPlayerProvider(sessionId).notifier)
          .seek(expectedPosition);
      ref.read(screeningPlayerProvider(sessionId).notifier).setRate(1.0);
    } else {
      _applyMicrosync(expectedPosition);
    }
  }

  // ── Microsync ───────────────────────────────────────────────────────────────

  void _applyMicrosync(Duration expectedPosition) {
    final playerState = ref.read(screeningPlayerProvider(sessionId));
    final localPosition = playerState.position;
    final driftMs =
        expectedPosition.inMilliseconds - localPosition.inMilliseconds;

    if (driftMs > _kMicrosyncThresholdMs) {
      debugPrint('[ScreeningSync] MICROSYNC drift=${driftMs}ms → rate=1.05');
      ref.read(screeningPlayerProvider(sessionId).notifier).setRate(1.05);
    } else if (driftMs < -_kMicrosyncThresholdMs) {
      debugPrint('[ScreeningSync] MICROSYNC drift=${driftMs}ms → rate=0.95');
      ref.read(screeningPlayerProvider(sessionId).notifier).setRate(0.95);
    } else {
      ref.read(screeningPlayerProvider(sessionId).notifier).setRate(1.0);
    }
  }

  void _startMicrosyncTimer() {
    _microsyncTimer?.cancel();
    _microsyncTimer = Timer.periodic(
      const Duration(seconds: _kSyncIntervalSeconds),
      (_) {
        if (!_isHostPlaying) return;
        // Recalcula a posição esperada do host baseado no tempo decorrido
        final elapsed = DateTime.now().difference(_hostReferenceTimestamp);
        final expectedHostPosition = _hostReferencePosition + elapsed;
        _applyMicrosync(expectedHostPosition);
      },
    );
  }

  void _stopMicrosyncTimer() {
    _microsyncTimer?.cancel();
    _microsyncTimer = null;
  }

  // ── Broadcast de eventos (chamado pelo Host) ────────────────────────────────

  Future<void> broadcastEvent(SyncEvent event) async {
    try {
      await _channel?.sendBroadcastMessage(
        event: 'sync',
        payload: event.toBroadcast(),
      );

      // Persistir no banco como fallback para novos entrantes
      if (event.type == SyncEventType.play ||
          event.type == SyncEventType.pause ||
          event.type == SyncEventType.seek) {
        await SupabaseService.client.rpc('update_sync_state', params: {
          'p_session_id': sessionId,
          'p_position': event.positionMs,
          'p_is_playing': event.type == SyncEventType.play,
        });
      }
    } catch (e) {
      debugPrint('[ScreeningSync] broadcastEvent error: $e');
    }
  }

  // ── Sincronização inicial (ao entrar na sala) ───────────────────────────────

  /// Chamado quando um novo participante entra na sala.
  /// Sincroniza com o estado atual do host lido do banco.
  Future<void> syncOnJoin({
    required int positionMs,
    required bool isPlaying,
    required DateTime syncUpdatedAt,
  }) async {
    final hostPosition = Duration(milliseconds: positionMs);
    _hostReferencePosition = hostPosition;
    _hostReferenceTimestamp = syncUpdatedAt;
    _isHostPlaying = isPlaying;

    if (isPlaying) {
      // Calcula a posição esperada compensando o tempo desde o último sync
      final elapsed = DateTime.now().difference(syncUpdatedAt);
      final expectedPosition = hostPosition + elapsed;
      _applyMacrosync(expectedPosition, DateTime.now());
      _startMicrosyncTimer();
    } else {
      ref
          .read(screeningPlayerProvider(sessionId).notifier)
          .seek(hostPosition);
    }
  }

  @override
  void dispose() {
    _microsyncTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
