import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'remote_config_service.dart';
import '../l10n/locale_provider.dart';

/// Serviço de Rate Limiting client-side + server-side.
///
/// Implementa rate limiting em duas camadas:
/// 1. **Client-side**: Throttle local para evitar chamadas desnecessárias
/// 2. **Server-side**: Verifica via RPC `check_rate_limit` no Supabase
///
/// Os limites são carregados dinamicamente do RemoteConfigService
/// (tabela `app_remote_config`), com fallback para valores hardcoded
/// caso o serviço ainda não tenha sido inicializado.
class RateLimiterService {
  /// Cache local de timestamps por ação
  static final Map<String, Queue<DateTime>> _localCache = {};

  /// Fallback de limites — usado se RemoteConfigService ainda não inicializou.
  static const Map<String, Map<String, int>> _fallbackLimits = {
    'post_create':    {'max': 5,   'window': 3600},
    'comment_create': {'max': 30,  'window': 3600},
    'message_send':   {'max': 60,  'window': 60},
    'like_toggle':    {'max': 120, 'window': 60},
    'report_create':  {'max': 10,  'window': 3600},
    'transfer_coins': {'max': 20,  'window': 3600},
    'wiki_create':    {'max': 10,  'window': 3600},
    'profile_update': {'max': 10,  'window': 300},
    'search':         {'max': 30,  'window': 60},
    'auth_attempt':   {'max': 5,   'window': 300},
  };

  /// Retorna o limite para uma ação, priorizando o RemoteConfigService.
  static Map<String, int> _limitFor(String action) {
    final remote = RemoteConfigService.rateLimitFor(action);
    if (remote.isNotEmpty) {
      final max    = remote['max']    is int ? remote['max']    as int
                   : int.tryParse(remote['max']?.toString() ?? '') ?? 0;
      final window = remote['window'] is int ? remote['window'] as int
                   : int.tryParse(remote['window']?.toString() ?? '') ?? 60;
      if (max > 0) return {'max': max, 'window': window};
    }
    return _fallbackLimits[action] ?? {'max': 30, 'window': 60};
  }

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
    final limit = _limitFor(action);
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
      final limit = _limitFor(action);
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
    final s = getStrings();
    switch (action) {
      case 'post_create':
        return s.postingTooFast;
      case 'comment_create':
        return s.tooManyComments;
      case 'message_send':
        return 'Você está enviando mensagens muito rápido. Aguarde alguns segundos.';
      case 'like_toggle':
        return 'Muitas curtidas em pouco tempo. Aguarde um momento.';
      case 'report_create':
        return s.tooManyReports;
      case 'transfer_coins':
        return s.tooManyTransfers;
      case 'auth_attempt':
        return 'Muitas tentativas de login. Aguarde 5 minutos.';
      default:
        return 'Muitas requisições. Aguarde um momento e tente novamente.';
    }
  }

  /// Calcula tempo de espera em segundos
  static int _retryAfter(String action) {
    final limit = _limitFor(action);
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
