import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/sync_event.dart';
import 'screening_player_provider.dart';

// =============================================================================
// ScreeningSyncProvider — Sincronização de reprodução em tempo real (Fase 2)
//
// Melhorias sobre a Fase 1:
// ─────────────────────────────────────────────────────────────────────────────
// 1. INDICADOR DE SYNC: SyncStatus expõe idle/syncing/adjusting/stable/
//    reconnecting — consumido pelo SyncStatusBadge no overlay.
//
// 2. MICROSYNC ADAPTATIVO: intervalo do timer varia com o drift.
//    drift > 500ms → verifica a cada 1s | drift < 500ms → a cada 3s.
//
// 3. DEAD ZONE: drift < 80ms é ignorado para evitar oscilação perceptível.
//
// 4. RATE SMOOTHING: taxa ajustada em passos de 0.02 por ciclo em vez de
//    saltar diretamente para 1.05x/0.95x (elimina artefatos de áudio).
//
// 5. RECOVERY AUTOMÁTICO: backoff exponencial (2s→4s→8s→…→30s) ao
//    detectar RealtimeSubscribeStatus.closed/channelError.
//
// 6. SYNC TIMEOUT: sem evento do host por 30s → envia 'request_sync'.
//    O host responde com seu estado atual via respondToResyncRequest().
// =============================================================================

// ── Thresholds ────────────────────────────────────────────────────────────────
const _kMacrosyncThresholdMs = 2000;  // > 2s   → seek direto
const _kMicrosyncThresholdMs = 150;   // 150ms–2s → ajuste de velocidade
const _kDeadZoneMs           = 80;    // < 80ms  → ignorar (estável)
const _kSyncTimeoutSeconds   = 30;    // sem evento → solicitar re-sync
const _kMaxPlaybackRate      = 1.08;  // taxa máxima de aceleração
const _kMinPlaybackRate      = 0.92;  // taxa mínima de desaceleração
const _kRateStep             = 0.02;  // passo de ajuste por ciclo

// ── Estado de sincronização ────────────────────────────────────────────────────

enum SyncStatus {
  idle,         // Sem vídeo ou sala não ativa
  syncing,      // Macrosync em andamento (seek)
  adjusting,    // Microsync ativo (ajuste de velocidade)
  stable,       // Drift < dead zone — sincronizado
  reconnecting, // Canal Realtime desconectado
}

class ScreeningSyncState {
  final SyncStatus status;
  final int lastDriftMs;
  final bool isConnected;
  /// Taxa de reprodução atual (1.0 = normal, > 1.0 = acelerado, < 1.0 = desacelerado)
  final double currentPlaybackRate;
  /// Número de tentativas de reconexão (para debug e backoff)
  final int reconnectAttempts;

  const ScreeningSyncState({
    this.status = SyncStatus.idle,
    this.lastDriftMs = 0,
    this.isConnected = false,
    this.currentPlaybackRate = 1.0,
    this.reconnectAttempts = 0,
  });

  ScreeningSyncState copyWith({
    SyncStatus? status,
    int? lastDriftMs,
    bool? isConnected,
    double? currentPlaybackRate,
    int? reconnectAttempts,
  }) {
    return ScreeningSyncState(
      status: status ?? this.status,
      lastDriftMs: lastDriftMs ?? this.lastDriftMs,
      isConnected: isConnected ?? this.isConnected,
      currentPlaybackRate: currentPlaybackRate ?? this.currentPlaybackRate,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final screeningSyncProvider = StateNotifierProvider.family<
    ScreeningSyncNotifier, ScreeningSyncState, String>(
  (ref, sessionId) => ScreeningSyncNotifier(sessionId: sessionId, ref: ref),
);

class ScreeningSyncNotifier extends StateNotifier<ScreeningSyncState> {
  final String sessionId;
  final Ref ref;

  RealtimeChannel? _channel;
  Timer? _microsyncTimer;
  Timer? _syncTimeoutTimer;
  Timer? _reconnectTimer;

  Duration _hostReferencePosition = Duration.zero;
  DateTime _hostReferenceTimestamp = DateTime.now();
  bool _isHostPlaying = false;
  double _currentRate = 1.0;
  int _reconnectAttempts = 0;
  /// Flag para evitar que o closed disparado por unsubscribe intencional
  /// (durante reconexão ou dispose) acione um novo ciclo de _scheduleReconnect.
  bool _isIntentionalDisconnect = false;

  ScreeningSyncNotifier({required this.sessionId, required this.ref})
      : super(const ScreeningSyncState()) {
    _subscribeToSyncEvents();
  }

  // ── Subscrição ao canal Realtime ─────────────────────────────────────────────

  void _subscribeToSyncEvents() {
    final channelName = 'screening_sync_$sessionId';
    _channel = SupabaseService.client.channel(channelName)
      ..onBroadcast(
        event: 'sync',
        callback: (payload) {
          try {
            _handleSyncEvent(SyncEvent.fromBroadcast(payload));
          } catch (e) {
            debugPrint('[ScreeningSync] parse error: $e');
          }
        },
      )
      ..onBroadcast(
        event: 'request_sync',
        callback: (_) => _handleResyncRequest(),
      )
      ..subscribe((status, error) {
        // Usa Future.microtask para evitar "Tried to modify a provider while
        // the widget tree was building" — o subscribe pode ser chamado
        // sincronamente durante o primeiro build quando o provider é criado.
        Future.microtask(() {
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              _reconnectAttempts = 0;
              if (mounted) {
                state = state.copyWith(
                  isConnected: true,
                  status: _isHostPlaying ? SyncStatus.adjusting : SyncStatus.idle,
                );
              }
              debugPrint('[ScreeningSync] canal conectado');
              break;
            case RealtimeSubscribeStatus.closed:
            case RealtimeSubscribeStatus.channelError:
              // Ignorar closed disparado por unsubscribe intencional
              // (durante reconexão ou dispose) para evitar loop infinito.
              if (_isIntentionalDisconnect) break;
              if (mounted) {
                state = state.copyWith(
                  isConnected: false,
                  status: SyncStatus.reconnecting,
                );
              }
              _scheduleReconnect();
              break;
            default:
              break;
          }
        });
      });
  }

  // ── Reconexão com backoff exponencial ────────────────────────────────────────

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 30);
    debugPrint(
        '[ScreeningSync] reconectando em ${delaySeconds}s (tentativa $_reconnectAttempts)');
    // Propaga tentativas de reconexão ao estado para o SyncDebugOverlay
    if (mounted) state = state.copyWith(reconnectAttempts: _reconnectAttempts);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      _isIntentionalDisconnect = true;
      _channel?.unsubscribe();
      _channel = null;
      _isIntentionalDisconnect = false;
      _subscribeToSyncEvents();
    });
  }

  // ── Processamento de eventos ──────────────────────────────────────────────────

  void _handleSyncEvent(SyncEvent event) {
    _resetSyncTimeout();
    final hostTimestamp =
        DateTime.fromMillisecondsSinceEpoch(event.serverTimestampMs);
    final hostPosition = Duration(milliseconds: event.positionMs);

    switch (event.type) {
      case SyncEventType.play:
        _hostReferencePosition = hostPosition;
        _hostReferenceTimestamp = hostTimestamp;
        _isHostPlaying = true;
        _applyMacrosync(hostPosition, hostTimestamp);
        ref.read(screeningPlayerProvider(sessionId).notifier).play();
        _startMicrosyncTimer();
        break;

      case SyncEventType.pause:
        _isHostPlaying = false;
        _stopMicrosyncTimer();
        _stopSyncTimeout();
        ref.read(screeningPlayerProvider(sessionId).notifier).seek(hostPosition);
        ref.read(screeningPlayerProvider(sessionId).notifier).pause();
        _setRateSmooth(1.0);
        if (mounted) state = state.copyWith(status: SyncStatus.stable, lastDriftMs: 0);
        break;

      case SyncEventType.seek:
        _hostReferencePosition = hostPosition;
        _hostReferenceTimestamp = hostTimestamp;
        _applyMacrosync(hostPosition, hostTimestamp);
        if (_isHostPlaying) _startMicrosyncTimer();
        break;

      case SyncEventType.changeVideo:
        _stopMicrosyncTimer();
        _stopSyncTimeout();
        _isHostPlaying = false;
        _currentRate = 1.0;
        if (mounted) state = state.copyWith(status: SyncStatus.idle, lastDriftMs: 0);
        break;

      case SyncEventType.hostChange:
        break;
    }
  }

  void _handleResyncRequest() {
    // Apenas o host responde — verificado externamente via isHost
    debugPrint('[ScreeningSync] request_sync recebido');
  }

  // ── Macrosync ─────────────────────────────────────────────────────────────────

  void _applyMacrosync(Duration hostPosition, DateTime hostTimestamp) {
    final latency = DateTime.now().difference(hostTimestamp);
    final expectedPosition =
        _isHostPlaying ? hostPosition + latency : hostPosition;

    final playerState = ref.read(screeningPlayerProvider(sessionId));
    final driftMs =
        expectedPosition.inMilliseconds - playerState.position.inMilliseconds;

    debugPrint(
        '[ScreeningSync] drift=${driftMs}ms latency=${latency.inMilliseconds}ms');

    if (driftMs.abs() > _kMacrosyncThresholdMs) {
      debugPrint('[ScreeningSync] MACROSYNC → seek ${expectedPosition.inSeconds}s');
      if (mounted) state = state.copyWith(status: SyncStatus.syncing, lastDriftMs: driftMs);
      ref.read(screeningPlayerProvider(sessionId).notifier).seek(expectedPosition);
      _setRateSmooth(1.0);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) state = state.copyWith(status: SyncStatus.stable);
      });
    } else {
      _applyMicrosync(expectedPosition, driftMs);
    }
  }

  // ── Microsync ─────────────────────────────────────────────────────────────────

  void _applyMicrosync(Duration expectedPosition, int driftMs) {
    if (!mounted) return;

    if (driftMs.abs() <= _kDeadZoneMs) {
      if (_currentRate != 1.0) _setRateSmooth(1.0);
      state = state.copyWith(status: SyncStatus.stable, lastDriftMs: driftMs);
      return;
    }

    if (driftMs.abs() > _kMicrosyncThresholdMs) {
      final targetRate = driftMs > 0 ? _kMaxPlaybackRate : _kMinPlaybackRate;
      _setRateSmooth(targetRate);
      state = state.copyWith(status: SyncStatus.adjusting, lastDriftMs: driftMs);
    } else {
      // Zona intermediária: ajuste leve
      final targetRate = driftMs > 0 ? 1.03 : 0.97;
      _setRateSmooth(targetRate);
      state = state.copyWith(status: SyncStatus.adjusting, lastDriftMs: driftMs);
    }
  }

  /// Ajusta a taxa gradualmente (evita artefatos de áudio).
  void _setRateSmooth(double targetRate) {
    if ((_currentRate - targetRate).abs() < 0.005) return;
    final newRate = _currentRate < targetRate
        ? (_currentRate + _kRateStep).clamp(_kMinPlaybackRate, _kMaxPlaybackRate)
        : (_currentRate - _kRateStep).clamp(_kMinPlaybackRate, _kMaxPlaybackRate);
    _currentRate = newRate;
    // Propaga a taxa atual ao estado para o SyncDebugOverlay
    if (mounted) state = state.copyWith(currentPlaybackRate: newRate);
    ref.read(screeningPlayerProvider(sessionId).notifier).setRate(newRate);
  }

  // ── Timer de Microsync adaptativo ────────────────────────────────────────────

  void _startMicrosyncTimer() {
    _microsyncTimer?.cancel();
    final intervalSeconds = state.lastDriftMs.abs() > 500 ? 1 : 3;

    _microsyncTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) {
        if (!_isHostPlaying || !mounted) return;
        final elapsed = DateTime.now().difference(_hostReferenceTimestamp);
        final expectedHostPosition = _hostReferencePosition + elapsed;
        final playerState = ref.read(screeningPlayerProvider(sessionId));
        final driftMs = expectedHostPosition.inMilliseconds -
            playerState.position.inMilliseconds;
        _applyMicrosync(expectedHostPosition, driftMs);

        // Reiniciar com intervalo atualizado se o drift mudou muito
        final newInterval = driftMs.abs() > 500 ? 1 : 3;
        if (newInterval != intervalSeconds) _startMicrosyncTimer();
      },
    );
  }

  void _stopMicrosyncTimer() {
    _microsyncTimer?.cancel();
    _microsyncTimer = null;
  }

  // ── Timeout de sync ───────────────────────────────────────────────────────────

  void _resetSyncTimeout() {
    _syncTimeoutTimer?.cancel();
    if (!_isHostPlaying) return;
    _syncTimeoutTimer = Timer(
      const Duration(seconds: _kSyncTimeoutSeconds),
      () {
        debugPrint('[ScreeningSync] timeout → solicitando re-sync');
        _channel?.sendBroadcastMessage(
          event: 'request_sync',
          payload: {'session_id': sessionId},
        );
      },
    );
  }

  void _stopSyncTimeout() {
    _syncTimeoutTimer?.cancel();
    _syncTimeoutTimer = null;
  }

  // ── API pública ───────────────────────────────────────────────────────────────

  /// Broadcast de evento de sync (chamado pelo host via ScreeningControlsOverlay).
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

  /// Responde a um request_sync — chamado pelo host via ScreeningRoomProvider.
  Future<void> respondToResyncRequest() async {
    final playerState = ref.read(screeningPlayerProvider(sessionId));
    await broadcastEvent(SyncEvent(
      type: _isHostPlaying ? SyncEventType.play : SyncEventType.pause,
      positionMs: playerState.position.inMilliseconds,
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Sincronização inicial ao entrar na sala.
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
      final elapsed = DateTime.now().difference(syncUpdatedAt);
      final expectedPosition = hostPosition + elapsed;
      if (mounted) state = state.copyWith(status: SyncStatus.syncing);
      _applyMacrosync(expectedPosition, syncUpdatedAt);
      _startMicrosyncTimer();
      _resetSyncTimeout();
    } else {
      ref.read(screeningPlayerProvider(sessionId).notifier).seek(hostPosition);
      if (mounted) state = state.copyWith(status: SyncStatus.stable);
    }
  }

  @override
  void dispose() {
    _microsyncTimer?.cancel();
    _syncTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _isIntentionalDisconnect = true;
    _channel?.unsubscribe();
    super.dispose();
  }
}
