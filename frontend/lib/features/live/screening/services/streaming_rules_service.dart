// =============================================================================
// StreamingRulesService — allowlist/blocklist server-driven da Sala de Projeção
//
// A falha remota é conservadora: quando a flag remota está ativa mas o payload
// não chega ou é inválido, o app usa uma allowlist local mínima e bloqueia URL
// desconhecida em vez de aceitar qualquer domínio por padrão.
// =============================================================================

import 'package:flutter/foundation.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/streaming_platform_rule.dart';

class StreamingRulesException implements Exception {
  final String message;
  const StreamingRulesException(this.message);

  @override
  String toString() => message;
}

class StreamingRulesService {
  static const int _schemaVersion = 1;
  static List<StreamingPlatformRule>? _memoryCache;

  static Future<List<StreamingPlatformRule>> getRules({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null && _memoryCache!.isNotEmpty) {
      return _memoryCache!;
    }

    if (!RemoteConfigService.isRemoteStreamingRulesEnabled) {
      _memoryCache = fallbackRules;
      return _memoryCache!;
    }

    try {
      final result = await SupabaseService.rpc(
        'get_streaming_platform_rules',
        params: {'p_schema_version': _schemaVersion},
      );
      final rawRules = _extractRules(result);
      final parsed = rawRules
          .whereType<Map>()
          .map((raw) => StreamingPlatformRule.fromJson(Map<String, dynamic>.from(raw)))
          .where((rule) => rule.isValid)
          .toList(growable: false)
        ..sort((a, b) => a.priority.compareTo(b.priority));

      if (parsed.isEmpty) {
        debugPrint('[StreamingRules] Payload remoto vazio; usando fallback conservador.');
        _memoryCache = fallbackRules;
      } else {
        _memoryCache = parsed;
      }
    } catch (e) {
      debugPrint('[StreamingRules] Falha ao carregar regras remotas: $e');
      _memoryCache = fallbackRules;
    }

    return _memoryCache!;
  }

  static Future<StreamingRuleDecision> evaluateUrl(
    String url, {
    String? preferredPlatformId,
  }) async {
    final normalized = _normalizeUrl(url);
    if (normalized == null) {
      return StreamingRuleDecision.block(
        platformId: preferredPlatformId ?? 'unknown',
        reason: 'URL inválida. Use um endereço http(s) válido.',
      );
    }

    final rules = await getRules();
    final preferredRule = _findPreferredRule(rules, preferredPlatformId);
    if (preferredRule != null && preferredRule.blocksUrl(normalized)) {
      return StreamingRuleDecision.block(
        platformId: preferredRule.platformId,
        reason: '${preferredRule.displayName} está bloqueado pelas regras atuais.',
        rule: preferredRule,
      );
    }

    final matchingRules = rules
        .where((rule) => rule.hasPositiveMatcher && rule.matchesUrl(normalized))
        .toList(growable: false)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (matchingRules.isEmpty) {
      return StreamingRuleDecision.block(
        platformId: preferredPlatformId ?? 'unknown',
        reason: 'Domínio não permitido para a Sala de Projeção.',
      );
    }

    final rule = preferredRule != null && matchingRules.any((r) => r.platformId == preferredRule.platformId)
        ? preferredRule
        : matchingRules.first;

    if (!rule.enabled) {
      return StreamingRuleDecision.block(
        platformId: rule.platformId,
        reason: '${rule.displayName} está temporariamente indisponível.',
        rule: rule,
      );
    }

    if (rule.blocksUrl(normalized)) {
      return StreamingRuleDecision.block(
        platformId: rule.platformId,
        reason: '${rule.displayName} está bloqueado pelas regras atuais.',
        rule: rule,
      );
    }

    return StreamingRuleDecision.allow(rule);
  }

  static Future<void> assertUrlAllowed(
    String url, {
    String? preferredPlatformId,
  }) async {
    final decision = await evaluateUrl(url, preferredPlatformId: preferredPlatformId);
    if (!decision.allowed) {
      throw StreamingRulesException(decision.reason ?? 'URL não permitida.');
    }
  }

  static Future<Map<String, StreamingPlatformRule>> rulesByPlatformId() async {
    final rules = await getRules();
    return {for (final rule in rules) rule.platformId: rule};
  }

  static List<dynamic> _extractRules(dynamic result) {
    if (result is List) return result;
    if (result is Map) {
      final rules = result['rules'] ?? result['platforms'] ?? result['data'];
      if (rules is List) return rules;
    }
    return const [];
  }

  static StreamingPlatformRule? _findPreferredRule(
    List<StreamingPlatformRule> rules,
    String? preferredPlatformId,
  ) {
    if (preferredPlatformId == null || preferredPlatformId.trim().isEmpty) {
      return null;
    }
    for (final rule in rules) {
      if (rule.platformId == preferredPlatformId) return rule;
    }
    return null;
  }

  static String? _normalizeUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;
    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return null;
    return input;
  }

  static List<StreamingPlatformRule> get fallbackRules => const [
        StreamingPlatformRule(
          platformId: 'youtube',
          displayName: 'YouTube',
          enabled: true,
          supportsEmbed: true,
          resolverStrategy: 'youtube',
          initialUrl: 'https://www.youtube.com',
          hostPatterns: [r'(^|\.)youtube\.com', r'(^|\.)youtu\.be'],
          videoUrlPatterns: [
            r'youtube\.com/watch\?.*v=[a-zA-Z0-9_-]{11}',
            r'youtu\.be/[a-zA-Z0-9_-]{11}',
            r'youtube\.com/shorts/[a-zA-Z0-9_-]{11}',
          ],
          priority: 10,
        ),
        StreamingPlatformRule(
          platformId: 'youtube_live',
          displayName: 'YouTube Live',
          enabled: true,
          supportsEmbed: true,
          resolverStrategy: 'youtube_live',
          initialUrl: 'https://www.youtube.com/live',
          hostPatterns: [r'(^|\.)youtube\.com', r'(^|\.)youtu\.be'],
          videoUrlPatterns: [
            r'youtube\.com/watch\?.*v=[a-zA-Z0-9_-]{11}',
            r'youtu\.be/[a-zA-Z0-9_-]{11}',
            r'youtube\.com/@[^/]+/live',
          ],
          priority: 11,
        ),
        StreamingPlatformRule(
          platformId: 'twitch',
          displayName: 'Twitch',
          enabled: true,
          supportsEmbed: true,
          resolverStrategy: 'twitch',
          initialUrl: 'https://www.twitch.tv',
          hostPatterns: [r'(^|\.)twitch\.tv'],
          videoUrlPatterns: [
            r'twitch\.tv/videos/\d+',
            r'twitch\.tv/[a-zA-Z0-9_]+$',
            r'twitch\.tv/[a-zA-Z0-9_]+\?',
          ],
          priority: 20,
        ),
        StreamingPlatformRule(
          platformId: 'kick',
          displayName: 'Kick',
          enabled: true,
          supportsEmbed: true,
          resolverStrategy: 'kick',
          initialUrl: 'https://kick.com',
          hostPatterns: [r'(^|\.)kick\.com'],
          videoUrlPatterns: [
            r'kick\.com/video/[a-zA-Z0-9_-]+',
            r'kick\.com/[a-zA-Z0-9_-]+$',
          ],
          priority: 30,
        ),
        StreamingPlatformRule(
          platformId: 'vimeo',
          displayName: 'Vimeo',
          enabled: true,
          supportsEmbed: true,
          resolverStrategy: 'vimeo',
          initialUrl: 'https://vimeo.com/login',
          loginUrl: 'https://vimeo.com/login',
          loggedInUrl: 'https://vimeo.com/manage/videos',
          hostPatterns: [r'(^|\.)vimeo\.com'],
          videoUrlPatterns: [r'vimeo\.com/\d+'],
          priority: 40,
        ),
        StreamingPlatformRule(
          platformId: 'drive',
          displayName: 'Google Drive',
          enabled: true,
          supportsEmbed: true,
          resolverStrategy: 'google_drive',
          initialUrl: 'https://accounts.google.com/ServiceLogin?service=wise&continue=https://drive.google.com/drive/my-drive',
          loginUrl: 'https://accounts.google.com/ServiceLogin?service=wise&continue=https://drive.google.com/drive/my-drive',
          loggedInUrl: 'https://drive.google.com/drive/my-drive',
          hostPatterns: [r'(^|\.)drive\.google\.com'],
          videoUrlPatterns: [r'drive\.google\.com/file/d/[a-zA-Z0-9_-]+'],
          priority: 50,
        ),
        StreamingPlatformRule(
          platformId: 'pluto',
          displayName: 'Pluto TV',
          enabled: true,
          resolverStrategy: 'pluto',
          initialUrl: 'https://pluto.tv/live-tv',
          loggedInUrl: 'https://pluto.tv/live-tv',
          hostPatterns: [r'(^|\.)pluto\.tv'],
          videoUrlPatterns: [
            r'pluto\.tv/live-tv/[a-zA-Z0-9_-]+',
            r'pluto\.tv/on-demand/[^?]+',
          ],
          priority: 60,
        ),
        StreamingPlatformRule(
          platformId: 'netflix',
          displayName: 'Netflix',
          enabled: true,
          requiresDrm: true,
          supportsEmbed: true,
          resolverStrategy: 'drm_relay',
          initialUrl: 'https://www.netflix.com/login',
          loginUrl: 'https://www.netflix.com/login',
          loggedInUrl: 'https://www.netflix.com/browse',
          hostPatterns: [r'(^|\.)netflix\.com'],
          videoUrlPatterns: [r'netflix\.com/watch/\d+', r'netflix\.com/title/\d+'],
          priority: 70,
        ),
        StreamingPlatformRule(
          platformId: 'disney',
          displayName: 'Disney+',
          enabled: true,
          requiresDrm: true,
          supportsEmbed: true,
          resolverStrategy: 'disney_bamgrid',
          initialUrl: 'https://www.disneyplus.com/login',
          loginUrl: 'https://www.disneyplus.com/login',
          loggedInUrl: 'https://www.disneyplus.com/home',
          hostPatterns: [r'(^|\.)disneyplus\.com'],
          videoUrlPatterns: [
            r'disneyplus\.com/video/[a-zA-Z0-9_-]+',
            r'disneyplus\.com/movies/[^/]+/[a-zA-Z0-9_-]+',
            r'disneyplus\.com/series/[^/]+/[a-zA-Z0-9_-]+',
          ],
          priority: 80,
        ),
        StreamingPlatformRule(
          platformId: 'amazon',
          displayName: 'Prime Video',
          enabled: true,
          requiresDrm: true,
          supportsEmbed: true,
          resolverStrategy: 'drm_relay',
          initialUrl: 'https://www.primevideo.com',
          loginUrl: 'https://www.amazon.com/ap/signin?openid.return_to=https://www.primevideo.com',
          loggedInUrl: 'https://www.primevideo.com/storefront/',
          hostPatterns: [r'(^|\.)primevideo\.com', r'(^|\.)amazon\.com'],
          videoUrlPatterns: [
            r'primevideo\.com/detail/[A-Z0-9]+',
            r'primevideo\.com/.*dp/[A-Z0-9]+',
            r'amazon\.com/.*dp/[A-Z0-9]+',
          ],
          priority: 90,
        ),
        StreamingPlatformRule(
          platformId: 'hbo',
          displayName: 'Max',
          enabled: true,
          requiresDrm: true,
          supportsEmbed: true,
          resolverStrategy: 'drm_relay',
          initialUrl: 'https://www.max.com/login',
          loginUrl: 'https://www.max.com/login',
          loggedInUrl: 'https://www.max.com/home',
          hostPatterns: [r'(^|\.)max\.com', r'(^|\.)hbomax\.com'],
          videoUrlPatterns: [
            r'max\.com/video/watch/[a-zA-Z0-9_-]+',
            r'max\.com/movies/[^/]+/[a-zA-Z0-9_-]+',
            r'max\.com/series/[^/]+/[a-zA-Z0-9_-]+',
          ],
          priority: 100,
        ),
        StreamingPlatformRule(
          platformId: 'crunchyroll',
          displayName: 'Crunchyroll',
          enabled: true,
          requiresDrm: true,
          supportsEmbed: true,
          resolverStrategy: 'drm_relay',
          initialUrl: 'https://www.crunchyroll.com/login',
          loginUrl: 'https://www.crunchyroll.com/login',
          loggedInUrl: 'https://www.crunchyroll.com/videos/new',
          hostPatterns: [r'(^|\.)crunchyroll\.com'],
          videoUrlPatterns: [
            r'crunchyroll\.com/watch/[A-Z0-9]+',
            r'crunchyroll\.com/series/[A-Z0-9]+',
          ],
          priority: 110,
        ),
        StreamingPlatformRule(
          platformId: 'local',
          displayName: 'Vídeo local',
          enabled: true,
          allowDirectPlayback: true,
          resolverStrategy: 'local_storage',
          hostPatterns: [r'supabase\.co/storage'],
          videoUrlPatterns: [r'supabase\.co/storage/.*/screening-videos'],
          priority: 120,
        ),
        StreamingPlatformRule(
          platformId: 'web',
          displayName: 'URL Direta',
          enabled: true,
          allowDirectPlayback: true,
          resolverStrategy: 'direct',
          directUrlHint: 'Cole uma URL direta HTTPS de vídeo (.m3u8, .mp4 ou .webm).',
          videoUrlPatterns: [
            r'https://[^\s]+\.(m3u8|mp4|webm)(\?.*)?$',
          ],
          blockedUrlPatterns: [
            r'javascript:',
            r'data:',
            r'file:',
            r'localhost',
            r'127\.0\.0\.1',
            r'(^|\.)10\.\d+\.\d+\.\d+',
            r'(^|\.)192\.168\.',
            r'(^|\.)172\.(1[6-9]|2\d|3[0-1])\.',
          ],
          priority: 900,
        ),
      ];
}
