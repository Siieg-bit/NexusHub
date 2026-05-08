import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'supabase_service.dart';
import 'haptic_service.dart';
import 'notification_channel_config_service.dart';

// ============================================================================
// MatchQueueService — Singleton de fila de matchmaking em background
//
// Mantém o polling ativo mesmo quando o usuário sai da MatchQueueScreen.
// Ao fazer match, dispara uma notificação local para o usuário.
// A MatchQueueScreen sincroniza com este serviço ao ser aberta.
//
// Uso:
//   MatchQueueService.instance.enter()    — entrar na fila
//   MatchQueueService.instance.leave()    — sair da fila
//   MatchQueueService.instance.stateStream — ouvir mudanças de estado
// ============================================================================

enum MatchQueueStatus { idle, waiting, matched, error }

class MatchQueueState {
  final MatchQueueStatus status;
  final String? threadId;
  final List<String> matchInterests;
  final int waitingSeconds;
  final String? error;

  const MatchQueueState({
    required this.status,
    this.threadId,
    this.matchInterests = const [],
    this.waitingSeconds = 0,
    this.error,
  });

  MatchQueueState copyWith({
    MatchQueueStatus? status,
    String? threadId,
    List<String>? matchInterests,
    int? waitingSeconds,
    String? error,
  }) =>
      MatchQueueState(
        status: status ?? this.status,
        threadId: threadId ?? this.threadId,
        matchInterests: matchInterests ?? this.matchInterests,
        waitingSeconds: waitingSeconds ?? this.waitingSeconds,
        error: error ?? this.error,
      );
}

class MatchQueueService {
  MatchQueueService._();
  static final MatchQueueService instance = MatchQueueService._();

  // ── Estado ─────────────────────────────────────────────────────────────────
  MatchQueueState _state = const MatchQueueState(status: MatchQueueStatus.idle);
  MatchQueueState get state => _state;

  final _stateController = StreamController<MatchQueueState>.broadcast();
  Stream<MatchQueueState> get stateStream => _stateController.stream;

  Timer? _pollTimer;
  Timer? _waitTimer;

  // ── Notificações locais ────────────────────────────────────────────────────
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _notifInitialized = false;

  static Future<void> initNotifications() async {
    if (_notifInitialized) return;
    _notifInitialized = true;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Payload: {'type': 'match', 'chat_thread_id': '...'}
        // O PushNotificationService já lida com o tap via stream global.
        // Aqui apenas logamos para debug.
        debugPrint('[MatchQueueService] Notif tap payload: ${details.payload}');
      },
    );
  }

  Future<void> _showMatchNotification(String threadId) async {
    try {
      await initNotifications();
      final channelId = NotificationChannelConfigService.channelIdForType('match');
      final channelName =
          NotificationChannelConfigService.channelNameForId(channelId);

      await _localNotifications.show(
        9999, // ID fixo para match — sobrescreve notificação anterior
        '🎉 Match encontrado!',
        'Alguém com interesses em comum quer conversar. Toque para abrir o chat.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({
          'type': 'match',
          'chat_thread_id': threadId,
          'action_url': '/chat/$threadId',
        }),
      );
    } catch (e) {
      debugPrint('[MatchQueueService] Erro ao exibir notificação: $e');
    }
  }

  // ── API pública ─────────────────────────────────────────────────────────────

  /// Verifica o status atual da fila no banco (chamado ao abrir a tela)
  Future<void> syncStatus() async {
    try {
      final res = await SupabaseService.rpc('get_match_queue_status');
      final data = Map<String, dynamic>.from(res as Map);
      final status = data['status'] as String? ?? 'idle';

      debugPrint('[MatchQueueService] syncStatus: $status');

      if (status == 'matched' || status == 'promoted') {
        _onMatched(
          threadId: data['thread_id'] as String?,
          interests: (data['match_interests'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          notify: false, // já estava matched, não notificar de novo
        );
      } else if (status == 'waiting') {
        if (_state.status != MatchQueueStatus.waiting) {
          _updateState(_state.copyWith(
            status: MatchQueueStatus.waiting,
            waitingSeconds: 0,
          ));
          _startPolling();
          _startWaitTimer();
        }
      } else {
        // idle — se estava em waiting localmente mas o banco diz idle,
        // significa que a fila foi limpa externamente
        if (_state.status == MatchQueueStatus.waiting) {
          _stopTimers();
          _updateState(const MatchQueueState(status: MatchQueueStatus.idle));
        }
      }
    } catch (e, st) {
      debugPrint('[MatchQueueService] syncStatus error: $e');
      debugPrint('[MatchQueueService] syncStatus stacktrace: $st');
    }
  }

  /// Entrar na fila de matchmaking
  Future<void> enter() async {
    if (_state.status == MatchQueueStatus.waiting ||
        _state.status == MatchQueueStatus.matched) {
      debugPrint('[MatchQueueService] enter() ignorado — já em fila/match');
      return;
    }

    _updateState(const MatchQueueState(status: MatchQueueStatus.waiting));
    HapticService.action();

    try {
      final res = await SupabaseService.rpc('enter_match_queue');
      final data = Map<String, dynamic>.from(res as Map);
      final status = data['status'] as String? ?? 'waiting';

      debugPrint('[MatchQueueService] enter result: $status');

      if (status == 'matched') {
        HapticService.success();
        _onMatched(
          threadId: data['thread_id'] as String?,
          interests: [],
          notify: false, // acabou de entrar, usuário ainda está na tela
        );
      } else {
        // waiting
        _updateState(const MatchQueueState(
          status: MatchQueueStatus.waiting,
          waitingSeconds: 0,
        ));
        _startPolling();
        _startWaitTimer();
      }
    } catch (e, st) {
      debugPrint('[MatchQueueService] enter error: $e');
      debugPrint('[MatchQueueService] enter stacktrace: $st');
      final raw = e.toString();
      String userMsg;
      if (raw.contains('interesses')) {
        userMsg = 'Adicione interesses ao seu perfil antes de entrar na fila.';
      } else if (raw.contains('chat de match ativo') ||
          raw.contains('match ativo')) {
        userMsg = 'Você já possui um chat de match ativo.';
      } else if (raw.contains('P0001')) {
        final msgMatch = RegExp(r'message: ([^,}]+)').firstMatch(raw);
        userMsg = msgMatch?.group(1)?.trim() ?? 'Erro ao entrar na fila.';
      } else {
        userMsg = 'Erro ao entrar na fila. Tente novamente.';
      }
      _updateState(MatchQueueState(
        status: MatchQueueStatus.error,
        error: userMsg,
      ));
    }
  }

  /// Sair da fila de matchmaking
  Future<void> leave() async {
    _stopTimers();
    try {
      await SupabaseService.rpc('leave_match_queue');
      debugPrint('[MatchQueueService] leave: saiu da fila');
    } catch (e) {
      debugPrint('[MatchQueueService] leave error (non-critical): $e');
    }
    _updateState(const MatchQueueState(status: MatchQueueStatus.idle));
  }

  /// Limpar estado de erro para voltar ao idle
  void clearError() {
    if (_state.status == MatchQueueStatus.error) {
      _updateState(const MatchQueueState(status: MatchQueueStatus.idle));
    }
  }

  // ── Internos ────────────────────────────────────────────────────────────────

  void _onMatched({
    required String? threadId,
    required List<String> interests,
    required bool notify,
  }) {
    _stopTimers();
    _updateState(MatchQueueState(
      status: MatchQueueStatus.matched,
      threadId: threadId,
      matchInterests: interests,
    ));
    if (notify && threadId != null) {
      _showMatchNotification(threadId);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_state.status != MatchQueueStatus.waiting) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final res = await SupabaseService.rpc('get_match_queue_status');
        final data = Map<String, dynamic>.from(res as Map);
        final status = data['status'] as String? ?? 'idle';

        debugPrint('[MatchQueueService] poll: $status');

        if (status == 'matched' || status == 'promoted') {
          HapticService.success();
          _onMatched(
            threadId: data['thread_id'] as String?,
            interests: (data['match_interests'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            notify: true, // notificar porque pode estar em background
          );
        } else if (status == 'idle') {
          // Saiu da fila por motivo externo
          _stopTimers();
          _updateState(const MatchQueueState(status: MatchQueueStatus.idle));
        }
        // 'waiting' — continuar polling
      } catch (e, st) {
        debugPrint('[MatchQueueService] polling error: $e');
        debugPrint('[MatchQueueService] polling stacktrace: $st');
        // Não parar o polling por erro transitório de rede
      }
    });
  }

  void _startWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.status != MatchQueueStatus.waiting) {
        _waitTimer?.cancel();
        return;
      }
      _updateState(_state.copyWith(
        waitingSeconds: _state.waitingSeconds + 1,
      ));
    });
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _waitTimer?.cancel();
    _pollTimer = null;
    _waitTimer = null;
  }

  void _updateState(MatchQueueState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void dispose() {
    _stopTimers();
    _stateController.close();
  }
}
