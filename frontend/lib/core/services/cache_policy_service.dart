import 'package:flutter/foundation.dart';

import 'remote_config_service.dart';

/// ============================================================================
/// CachePolicyService — Políticas centralizadas de TTL do cache local.
///
/// Responsabilidade:
/// - Converter chaves de cache (`posts:<id>`, `messages:<id>`, etc.) em
///   políticas semânticas de expiração.
/// - Ler TTLs server-driven de `app_remote_config` quando a feature flag estiver
///   ativa.
/// - Preservar fallback local conservador quando Remote Config falhar, vier
///   incompleto ou for desligado para rollback.
///
/// O serviço é síncrono porque depende apenas do `RemoteConfigService`, que já é
/// inicializado no boot do app e mantém cache local próprio.
/// ============================================================================
class CachePolicyService {
  CachePolicyService._();

  static const int _minTtlSeconds = 15;
  static const int _maxTtlSeconds = 7 * 24 * 60 * 60;

  /// Fallback local equivalente à política anterior para recursos críticos,
  /// refinado por domínio para não degradar a UX offline-first.
  static const Map<String, int> _fallbackTtlSeconds = {
    'default': 5 * 60,
    'posts': 5 * 60,
    'post': 5 * 60,
    'my_communities': 15 * 60,
    'community': 15 * 60,
    'messages': 2 * 60,
    'profiles': 60 * 60,
    'global_feed': 5 * 60,
    'for_you_feed': 5 * 60,
    'notifications': 3 * 60,
    'wiki': 15 * 60,
  };

  /// Retorna a duração máxima permitida para uma chave de cache específica.
  static Duration maxAgeFor(String cacheKey) {
    final policyKey = policyKeyFor(cacheKey);
    final seconds = _ttlSecondsFor(policyKey);
    return Duration(seconds: seconds);
  }

  /// Verifica expiração com base em uma data de sincronização já conhecida.
  static bool isExpired(String cacheKey, DateTime? lastSync) {
    if (lastSync == null) return true;
    return DateTime.now().toUtc().difference(lastSync) > maxAgeFor(cacheKey);
  }

  /// Normaliza chaves concretas de cache para políticas semânticas.
  static String policyKeyFor(String cacheKey) {
    final key = cacheKey.trim();
    if (key.isEmpty) return 'default';

    if (key.startsWith('posts:')) return 'posts';
    if (key.startsWith('post:')) return 'post';
    if (key == 'my_communities') return 'my_communities';
    if (key.startsWith('community:')) return 'community';
    if (key.startsWith('messages:')) return 'messages';
    if (key.startsWith('profile:')) return 'profiles';
    if (key == 'global_feed') return 'global_feed';
    if (key == 'for_you_feed') return 'for_you_feed';
    if (key == 'notifications') return 'notifications';
    if (key.startsWith('wiki:')) return 'wiki';

    return _fallbackTtlSeconds.containsKey(key) ? key : 'default';
  }

  /// Expõe um snapshot tipado das políticas efetivas para telas de diagnóstico
  /// ou validações futuras, sem vazar parsing de Remote Config para outras
  /// camadas do app.
  static Map<String, Duration> effectivePolicies() {
    return {
      for (final key in _fallbackTtlSeconds.keys)
        key: Duration(seconds: _ttlSecondsFor(key)),
    };
  }

  static int _ttlSecondsFor(String policyKey) {
    final fallback = _fallbackTtlSeconds[policyKey] ??
        _fallbackTtlSeconds['default']!;

    if (!RemoteConfigService.isRemoteCachePoliciesEnabled) {
      return fallback;
    }

    final remote = RemoteConfigService.cacheTtlSeconds;
    if (remote.isEmpty) return fallback;

    final raw = remote[policyKey] ?? remote['default'];
    final parsed = _parsePositiveInt(raw);
    if (parsed == null) return fallback;

    final clamped = parsed.clamp(_minTtlSeconds, _maxTtlSeconds) as int;
    if (clamped != parsed) {
      debugPrint(
        '[CachePolicyService] TTL remoto "$policyKey" ajustado de '
        '$parsed para $clamped segundos',
      );
    }
    return clamped;
  }

  static int? _parsePositiveInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is double) return raw > 0 ? raw.round() : null;
    final parsed = int.tryParse(raw.toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }
}
