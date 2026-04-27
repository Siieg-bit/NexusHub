import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// ============================================================================
/// RealtimeService — Gerenciamento centralizado de canais Realtime com
/// reconexão automática, backoff exponencial e refresh de JWT expirado.
///
/// Problemas resolvidos:
/// - Canais que morrem silenciosamente após perda de conexão
/// - Loop infinito de reconexão quando o JWT está expirado
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

  /// Flag para evitar múltiplos refreshes simultâneos de token.
  bool _isRefreshingToken = false;

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
      managed.isIntentionalDisconnect = true;
      managed.channel.unsubscribe();
    }
  }

  /// Desinscreve todos os canais gerenciados.
  void unsubscribeAll() {
    for (final managed in _channels.values) {
      managed.retryTimer?.cancel();
      managed.isIntentionalDisconnect = true;
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
          managed.jwtExpiredRetryDone = false;
          managed.retryTimer?.cancel();
          _updateGlobalStatus();
          break;

        case RealtimeSubscribeStatus.closed:
          _handleDisconnect(managed, error: error);
          break;

        case RealtimeSubscribeStatus.channelError:
          _handleDisconnect(managed, error: error);
          break;

        case RealtimeSubscribeStatus.timedOut:
          _handleDisconnect(managed, error: error);
          break;
      }
    });
  }

  /// Verifica se o erro é de JWT expirado.
  bool _isJwtExpiredError(Object? error) {
    if (error == null) return false;
    final msg = error.toString().toLowerCase();
    return msg.contains('invalidjwttoken') ||
        msg.contains('jwt expired') ||
        msg.contains('token has expired') ||
        msg.contains('token expired');
  }

  /// Trata desconexão com retry exponencial.
  /// Se o erro for JWT expirado, tenta refresh de sessão primeiro.
  void _handleDisconnect(_ManagedChannel managed, {Object? error}) {
    // Ignorar closed/error disparado por unsubscribe intencional para evitar
    // loop infinito de reconexão.
    if (managed.isIntentionalDisconnect) return;
    _updateGlobalStatus();

    // Detectar JWT expirado e fazer refresh antes de reconectar
    if (_isJwtExpiredError(error) && !managed.jwtExpiredRetryDone) {
      managed.jwtExpiredRetryDone = true;
      debugPrint(
          '[RealtimeService] ${managed.name}: JWT expirado — fazendo refresh de sessão...');
      connectionStatus.value = RealtimeConnectionStatus.connecting;

      managed.retryTimer?.cancel();
      managed.retryTimer = Timer(const Duration(milliseconds: 500), () async {
        if (!_channels.containsKey(managed.name)) return;

        // Evitar múltiplos refreshes simultâneos
        if (!_isRefreshingToken) {
          _isRefreshingToken = true;
          try {
            await SupabaseService.client.auth.refreshSession();
            debugPrint(
                '[RealtimeService] ${managed.name}: sessão renovada com sucesso');
          } catch (e) {
            debugPrint(
                '[RealtimeService] ${managed.name}: falha ao renovar sessão: $e');
          } finally {
            _isRefreshingToken = false;
          }
        } else {
          // Aguardar o refresh em andamento
          await Future.doWhile(() async {
            await Future.delayed(const Duration(milliseconds: 200));
            return _isRefreshingToken;
          });
        }

        if (!_channels.containsKey(managed.name)) return;
        _reconnectChannel(managed);
      });
      return;
    }

    // Backoff exponencial padrão: 1s, 2s, 4s, 8s, 16s, max 30s
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
      if (!_channels.containsKey(managed.name)) return;
      debugPrint('[RealtimeService] ${managed.name}: tentando reconexão...');
      _reconnectChannel(managed);
    });
  }

  /// Recria o canal e reinicia a inscrição.
  void _reconnectChannel(_ManagedChannel managed) {
    // Recriar o canal (o antigo pode estar em estado inválido)
    try {
      managed.channel.unsubscribe();
    } catch (e) {
      debugPrint('[realtime_service.dart] unsubscribe error: $e');
    }

    final newChannel = SupabaseService.client.channel(managed.name);
    managed.configure(newChannel);
    managed.channel = newChannel;

    _subscribeManaged(managed);
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

  /// Garante que o refresh de JWT seja tentado apenas uma vez por ciclo de erro.
  bool jwtExpiredRetryDone = false;
  /// Flag para evitar que o closed disparado por unsubscribe intencional
  /// (durante reconexão ou remoção do canal) acione um novo ciclo de retry.
  bool isIntentionalDisconnect = false;

  _ManagedChannel({
    required this.name,
    required this.channel,
    required this.configure,
  });
}
