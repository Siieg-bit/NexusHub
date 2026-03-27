import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Serviço de Rate Limiting client-side + server-side.
///
/// Implementa rate limiting em duas camadas:
/// 1. **Client-side**: Throttle local para evitar chamadas desnecessárias
/// 2. **Server-side**: Verifica via RPC `check_rate_limit` no Supabase
///
/// Ações protegidas:
/// - `post_create`: 5 posts/hora
/// - `comment_create`: 30 comentários/hora
/// - `message_send`: 60 mensagens/minuto
/// - `like_toggle`: 120 likes/minuto
/// - `report_create`: 10 reports/hora
/// - `transfer_coins`: 20 transferências/hora
class RateLimiterService {
  /// Cache local de timestamps por ação
  static final Map<String, Queue<DateTime>> _localCache = {};

  /// Limites por ação (ação → {maxRequests, windowSeconds})
  static const Map<String, Map<String, int>> _limits = {
    'post_create': {'max': 5, 'window': 3600},
    'comment_create': {'max': 30, 'window': 3600},
    'message_send': {'max': 60, 'window': 60},
    'like_toggle': {'max': 120, 'window': 60},
    'report_create': {'max': 10, 'window': 3600},
    'transfer_coins': {'max': 20, 'window': 3600},
    'wiki_create': {'max': 10, 'window': 3600},
    'profile_update': {'max': 10, 'window': 300},
    'search': {'max': 30, 'window': 60},
    'auth_attempt': {'max': 5, 'window': 300},
  };

  /// Verifica se a ação é permitida (client-side + server-side)
  ///
  /// Retorna `true` se permitido, `false` se bloqueado.
  /// Lança exceção com mensagem amigável se bloqueado.
  static Future<bool> checkAndConsume(String action) async {
    // 1. Verificação client-side (rápida)
    if (!_checkLocal(action)) {
      throw RateLimitException(
        action: action,
        message: _friendlyMessage(action),
        retryAfterSeconds: _retryAfter(action),
      );
    }

    // 2. Verificação server-side (para ações críticas)
    if (_requiresServerCheck(action)) {
      final allowed = await _checkServer(action);
      if (!allowed) {
        throw RateLimitException(
          action: action,
          message: _friendlyMessage(action),
          retryAfterSeconds: _retryAfter(action),
        );
      }
    }

    // 3. Registrar no cache local
    _recordLocal(action);
    return true;
  }

  /// Verificação rápida sem server call (para UI)
  static bool canPerform(String action) {
    return _checkLocal(action);
  }

  /// Verificação client-side
  static bool _checkLocal(String action) {
    final limit = _limits[action];
    if (limit == null) return true;

    final maxRequests = limit['max']!;
    final windowSeconds = limit['window']!;
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(seconds: windowSeconds));

    final queue = _localCache[action];
    if (queue == null) return true;

    // Limpar entradas expiradas
    while (queue.isNotEmpty && queue.first.isBefore(windowStart)) {
      queue.removeFirst();
    }

    return queue.length < maxRequests;
  }

  /// Registra uma ação no cache local
  static void _recordLocal(String action) {
    _localCache.putIfAbsent(action, () => Queue<DateTime>());
    _localCache[action]!.add(DateTime.now());
  }

  /// Verificação server-side via RPC
  static Future<bool> _checkServer(String action) async {
    try {
      final limit = _limits[action]!;
      final result =
          await SupabaseService.client.rpc('check_rate_limit', params: {
        'p_action': action,
        'p_max_requests': limit['max'],
        'p_window_seconds': limit['window'],
      });
      return result as bool? ?? true;
    } catch (e) {
      debugPrint('[RateLimiter] Server check failed: $e');
      // Em caso de erro, permitir (fail-open para não bloquear o usuário)
      return true;
    }
  }

  /// Ações que requerem verificação no servidor
  static bool _requiresServerCheck(String action) {
    return const {
      'post_create',
      'report_create',
      'transfer_coins',
      'auth_attempt',
    }.contains(action);
  }

  /// Mensagem amigável para o usuário
  static String _friendlyMessage(String action) {
    switch (action) {
      case 'post_create':
        return 'Você está postando muito rápido. Aguarde um pouco antes de criar outro post.';
      case 'comment_create':
        return 'Muitos comentários em pouco tempo. Aguarde um momento.';
      case 'message_send':
        return 'Você está enviando mensagens muito rápido. Aguarde alguns segundos.';
      case 'like_toggle':
        return 'Muitas curtidas em pouco tempo. Aguarde um momento.';
      case 'report_create':
        return 'Você já enviou muitas denúncias recentemente. Tente novamente mais tarde.';
      case 'transfer_coins':
        return 'Muitas transferências em pouco tempo. Aguarde antes de transferir novamente.';
      case 'auth_attempt':
        return 'Muitas tentativas de login. Aguarde 5 minutos.';
      default:
        return 'Muitas requisições. Aguarde um momento e tente novamente.';
    }
  }

  /// Calcula tempo de espera em segundos
  static int _retryAfter(String action) {
    final limit = _limits[action];
    if (limit == null) return 30;
    return (limit['window']! / limit['max']!).ceil();
  }

  /// Limpa o cache local (útil no logout)
  static void clearCache() {
    _localCache.clear();
  }
}

/// Exceção de rate limit
class RateLimitException implements Exception {
  final String action;
  final String message;
  final int retryAfterSeconds;

  const RateLimitException({
    required this.action,
    required this.message,
    required this.retryAfterSeconds,
  });

  @override
  String toString() => 'RateLimitException($action): $message';
}
