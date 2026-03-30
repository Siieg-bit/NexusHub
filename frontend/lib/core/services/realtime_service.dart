import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// ============================================================================
/// RealtimeService — Gerenciamento centralizado de canais Realtime com
/// reconexão automática e backoff exponencial.
///
/// Problemas resolvidos:
/// - Canais que morrem silenciosamente após perda de conexão
/// - Sem feedback visual de status de conexão
/// - Sem retry automático
///
/// Uso:
/// ```dart
/// final channel = RealtimeService.instance.subscribeWithRetry(
///   channelName: 'chat:thread_123',
///   configure: (channel) {
///     channel.onPostgresChanges(
///       event: PostgresChangeEvent.insert,
///       schema: 'public',
///       table: 'chat_messages',
///       callback: (payload) { ... },
///     );
///   },
/// );
/// ```
/// ============================================================================

/// Status de conexão Realtime observável.
enum RealtimeConnectionStatus {
  connected,
  connecting,
  disconnected,
}

class RealtimeService {
  RealtimeService._();
  static final RealtimeService _instance = RealtimeService._();
  static RealtimeService get instance => _instance;

  /// Status global de conexão Realtime.
  /// Widgets podem escutar via ValueListenableBuilder.
  final ValueNotifier<RealtimeConnectionStatus> connectionStatus =
      ValueNotifier(RealtimeConnectionStatus.connected);

  /// Canais gerenciados: channelName → _ManagedChannel
  final Map<String, _ManagedChannel> _channels = {};

  /// Cria e inscreve um canal Realtime com reconexão automática.
  ///
  /// [channelName] — Nome único do canal (ex: 'chat:thread_123').
  /// [configure] — Callback para configurar listeners no canal
  ///   (onPostgresChanges, onBroadcast, etc.) ANTES do subscribe.
  ///
  /// Retorna o [RealtimeChannel] criado. Para cancelar, use [unsubscribe].
  RealtimeChannel subscribeWithRetry({
    required String channelName,
    required void Function(RealtimeChannel channel) configure,
  }) {
    // Se já existe um canal com esse nome, desinscrever primeiro
    unsubscribe(channelName);

    final channel = SupabaseService.client.channel(channelName);
    configure(channel);

    final managed = _ManagedChannel(
      name: channelName,
      channel: channel,
      configure: configure,
    );
    _channels[channelName] = managed;

    _subscribeManaged(managed);

    return channel;
  }

  /// Desinscreve e remove um canal gerenciado.
  void unsubscribe(String channelName) {
    final managed = _channels.remove(channelName);
    if (managed != null) {
      managed.retryTimer?.cancel();
      managed.channel.unsubscribe();
    }
  }

  /// Desinscreve todos os canais gerenciados.
  void unsubscribeAll() {
    for (final managed in _channels.values) {
      managed.retryTimer?.cancel();
      managed.channel.unsubscribe();
    }
    _channels.clear();
    connectionStatus.value = RealtimeConnectionStatus.disconnected;
  }

  /// Inscreve um canal gerenciado com monitoramento de status.
  void _subscribeManaged(_ManagedChannel managed) {
    managed.channel.subscribe((status, error) {
      debugPrint(
          '[RealtimeService] ${managed.name}: status=$status, error=$error');

      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          managed.retryCount = 0;
          managed.retryTimer?.cancel();
          _updateGlobalStatus();
          break;

        case RealtimeSubscribeStatus.closed:
          _handleDisconnect(managed);
          break;

        case RealtimeSubscribeStatus.channelError:
          _handleDisconnect(managed);
          break;

        case RealtimeSubscribeStatus.timedOut:
          _handleDisconnect(managed);
          break;
      }
    });
  }

  /// Trata desconexão com retry exponencial.
  void _handleDisconnect(_ManagedChannel managed) {
    _updateGlobalStatus();

    // Calcular delay com backoff exponencial: 1s, 2s, 4s, 8s, 16s, max 30s
    final delay = min(
      30,
      pow(2, managed.retryCount).toInt(),
    );
    managed.retryCount++;

    debugPrint(
        '[RealtimeService] ${managed.name}: reconectando em ${delay}s (tentativa ${managed.retryCount})');

    connectionStatus.value = RealtimeConnectionStatus.connecting;

    managed.retryTimer?.cancel();
    managed.retryTimer = Timer(Duration(seconds: delay), () {
      if (!_channels.containsKey(managed.name)) return; // Foi removido

      debugPrint(
          '[RealtimeService] ${managed.name}: tentando reconexão...');

      // Recriar o canal (o antigo pode estar em estado inválido)
      try {
        managed.channel.unsubscribe();
      } catch (_) {}

      final newChannel = SupabaseService.client.channel(managed.name);
      managed.configure(newChannel);
      managed.channel = newChannel;

      _subscribeManaged(managed);
    });
  }

  /// Atualiza o status global baseado no estado de todos os canais.
  void _updateGlobalStatus() {
    if (_channels.isEmpty) {
      connectionStatus.value = RealtimeConnectionStatus.disconnected;
      return;
    }

    // Se qualquer canal está tentando reconectar, status global = connecting
    final anyRetrying = _channels.values.any((m) => m.retryCount > 0);
    if (anyRetrying) {
      connectionStatus.value = RealtimeConnectionStatus.connecting;
    } else {
      connectionStatus.value = RealtimeConnectionStatus.connected;
    }
  }
}

/// Canal gerenciado internamente pelo RealtimeService.
class _ManagedChannel {
  final String name;
  RealtimeChannel channel;
  final void Function(RealtimeChannel channel) configure;
  int retryCount = 0;
  Timer? retryTimer;

  _ManagedChannel({
    required this.name,
    required this.channel,
    required this.configure,
  });
}
