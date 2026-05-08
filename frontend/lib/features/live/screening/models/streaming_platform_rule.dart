// =============================================================================
// StreamingPlatformRule — regra server-driven para Sala de Projeção
//
// Mantém allowlist/blocklist e metadados de plataforma fora do APK, com parsing
// tolerante para que payloads incompletos não quebrem a experiência local.
// =============================================================================

class StreamingPlatformRule {
  final String platformId;
  final String displayName;
  final bool enabled;
  final bool allowDirectPlayback;
  final bool requiresDrm;
  final bool supportsEmbed;
  final String resolverStrategy;
  final String? initialUrl;
  final String? loginUrl;
  final String? loggedInUrl;
  final String? directUrlHint;
  final List<String> hostPatterns;
  final List<String> videoUrlPatterns;
  final List<String> blockedUrlPatterns;
  final int priority;
  final Map<String, dynamic> metadata;

  const StreamingPlatformRule({
    required this.platformId,
    required this.displayName,
    this.enabled = true,
    this.allowDirectPlayback = false,
    this.requiresDrm = false,
    this.supportsEmbed = false,
    this.resolverStrategy = 'embed',
    this.initialUrl,
    this.loginUrl,
    this.loggedInUrl,
    this.directUrlHint,
    this.hostPatterns = const [],
    this.videoUrlPatterns = const [],
    this.blockedUrlPatterns = const [],
    this.priority = 100,
    this.metadata = const {},
  });

  factory StreamingPlatformRule.fromJson(Map<String, dynamic> json) {
    return StreamingPlatformRule(
      platformId: _readString(json, ['platform_id', 'platformId', 'id']),
      displayName: _readString(
        json,
        ['display_name', 'displayName', 'name'],
        fallback: 'Streaming',
      ),
      enabled: _readBool(json, ['enabled'], fallback: true),
      allowDirectPlayback: _readBool(
        json,
        ['allow_direct_playback', 'allowDirectPlayback', 'allow_direct'],
      ),
      requiresDrm: _readBool(json, ['requires_drm', 'requiresDrm']),
      supportsEmbed: _readBool(json, ['supports_embed', 'supportsEmbed']),
      resolverStrategy: _readString(
        json,
        ['resolver_strategy', 'resolverStrategy'],
        fallback: 'embed',
      ),
      initialUrl: _readNullableString(json, ['initial_url', 'initialUrl']),
      loginUrl: _readNullableString(json, ['login_url', 'loginUrl']),
      loggedInUrl: _readNullableString(json, ['logged_in_url', 'loggedInUrl']),
      directUrlHint: _readNullableString(json, ['direct_url_hint', 'directUrlHint']),
      hostPatterns: _readStringList(json, ['host_patterns', 'hostPatterns']),
      videoUrlPatterns: _readStringList(json, [
        'video_url_patterns',
        'videoUrlPatterns',
        'url_patterns',
        'patterns',
      ]),
      blockedUrlPatterns: _readStringList(json, [
        'blocked_url_patterns',
        'blockedUrlPatterns',
        'blocked_patterns',
      ]),
      priority: _readInt(json, ['priority'], fallback: 100),
      metadata: _readMap(json, ['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
        'platform_id': platformId,
        'display_name': displayName,
        'enabled': enabled,
        'allow_direct_playback': allowDirectPlayback,
        'requires_drm': requiresDrm,
        'supports_embed': supportsEmbed,
        'resolver_strategy': resolverStrategy,
        if (initialUrl != null) 'initial_url': initialUrl,
        if (loginUrl != null) 'login_url': loginUrl,
        if (loggedInUrl != null) 'logged_in_url': loggedInUrl,
        if (directUrlHint != null) 'direct_url_hint': directUrlHint,
        'host_patterns': hostPatterns,
        'video_url_patterns': videoUrlPatterns,
        'blocked_url_patterns': blockedUrlPatterns,
        'priority': priority,
        'metadata': metadata,
      };

  bool get isValid => platformId.trim().isNotEmpty && displayName.trim().isNotEmpty;

  bool matchesUrl(String url) {
    final normalized = url.toLowerCase();
    if (_matchesAny(normalized, blockedUrlPatterns)) return false;
    if (_matchesAny(normalized, videoUrlPatterns)) return true;
    return _matchesAny(normalized, hostPatterns);
  }

  bool blocksUrl(String url) => _matchesAny(url.toLowerCase(), blockedUrlPatterns);

  bool get hasPositiveMatcher => hostPatterns.isNotEmpty || videoUrlPatterns.isNotEmpty;

  static bool _matchesAny(String normalizedUrl, List<String> patterns) {
    for (final pattern in patterns) {
      if (pattern.trim().isEmpty) continue;
      try {
        if (RegExp(pattern, caseSensitive: false).hasMatch(normalizedUrl)) {
          return true;
        }
      } catch (_) {
        if (normalizedUrl.contains(pattern.toLowerCase())) return true;
      }
    }
    return false;
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  static String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
    final value = _readString(json, keys);
    return value.isEmpty ? null : value;
  }

  static bool _readBool(
    Map<String, dynamic> json,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase().trim();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
    }
    return fallback;
  }

  static int _readInt(
    Map<String, dynamic> json,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static List<String> _readStringList(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is List) {
        return value
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
      }
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(',')
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
      }
    }
    return const [];
  }

  static Map<String, dynamic> _readMap(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return const {};
  }
}

class StreamingRuleDecision {
  final bool allowed;
  final String platformId;
  final String? reason;
  final StreamingPlatformRule? rule;

  const StreamingRuleDecision._({
    required this.allowed,
    required this.platformId,
    this.reason,
    this.rule,
  });

  factory StreamingRuleDecision.allow(StreamingPlatformRule rule) {
    return StreamingRuleDecision._(
      allowed: true,
      platformId: rule.platformId,
      rule: rule,
    );
  }

  factory StreamingRuleDecision.block({
    required String platformId,
    required String reason,
    StreamingPlatformRule? rule,
  }) {
    return StreamingRuleDecision._(
      allowed: false,
      platformId: platformId,
      reason: reason,
      rule: rule,
    );
  }
}
