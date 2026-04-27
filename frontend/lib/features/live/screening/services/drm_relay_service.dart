// =============================================================================
// DrmRelayService — Captura cookies/tokens do WebView e chama as Edge Functions
//
// Fluxo para plataformas DRM (Netflix, Disney+, Amazon, HBO Max, Crunchyroll):
//
// 1. O usuário faz login no ScreeningBrowserSheet (WebView)
// 2. Ao navegar para a URL de um vídeo, este serviço:
//    a. Captura os cookies de sessão via InAppWebView CookieManager
//    b. Extrai o contentId/movieId/ASIN da URL
//    c. Chama a Edge Function relay correspondente no Supabase
//    d. Retorna StreamResolution com HLS URL + dados DRM
//
// Keys extraídas do Rave APK:
//   Netflix: cookies NetflixId + SecureNetflixId
//   Disney+: Bearer token via OAuth redirect
//   Amazon:  cookies de sessão + ASIN
//   HBO Max: Bearer token + contentId
//   Crunchyroll: Bearer token (OAuth2) + episodeId
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../../../../config/app_config.dart';
import 'stream_resolver_service.dart';

class DrmRelayService {
  // URL base das Edge Functions do Supabase — via AppConfig

  // ── Captura cookies do WebView para uma plataforma ────────────────────────
  static Future<Map<String, String>> captureCookies(
    String platformHost,
  ) async {
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(
      url: WebUri('https://$platformHost'),
    );

    final cookieMap = <String, String>{};
    for (final cookie in cookies) {
      cookieMap[cookie.name] = cookie.value;
    }
    return cookieMap;
  }

  // ── Extrai o contentId da URL por plataforma ──────────────────────────────
  static String? extractContentId(String url, String platform) {
    switch (platform) {
      case 'netflix':
        // https://www.netflix.com/watch/12345678
        final m = RegExp(r'netflix\.com/watch/(\d+)').firstMatch(url);
        return m?.group(1);

      case 'disney':
        // https://www.disneyplus.com/video/abc123
        // https://www.disneyplus.com/play/abc123
        final m = RegExp(r'disneyplus\.com/(?:video|play)/([a-zA-Z0-9_-]+)')
            .firstMatch(url);
        return m?.group(1);

      case 'amazon':
        // https://www.primevideo.com/detail/B0XXXXXX
        // https://www.amazon.com/gp/video/detail/B0XXXXXX
        final m = RegExp(
                r'(?:primevideo|amazon)\.com/(?:detail|gp/video/detail)/([A-Z0-9]+)')
            .firstMatch(url);
        return m?.group(1);

      case 'hbo':
        // https://www.max.com/movies/feature/abc-123
        // https://www.max.com/episodes/episode/abc-123
        final m = RegExp(
                r'max\.com/(?:[a-z-]+/)?(?:movie|episode|feature)/([a-zA-Z0-9_-]+)')
            .firstMatch(url);
        return m?.group(1);

      case 'crunchyroll':
        // https://www.crunchyroll.com/watch/GXXXXXX
        final m =
            RegExp(r'crunchyroll\.com/(?:[a-z-]+/)?watch/([A-Z0-9]+)')
                .firstMatch(url);
        return m?.group(1);

      default:
        return null;
    }
  }

  // ── Chama a Edge Function relay para Netflix ──────────────────────────────
  static Future<StreamResolution> resolveNetflix(
    String url,
    InAppWebViewController webViewController,
  ) async {
    final movieId = extractContentId(url, 'netflix');
    if (movieId == null) throw Exception('Netflix: movieId não encontrado');

    // Capturar cookies de sessão
    final cookies = await captureCookies('www.netflix.com');
    final netflixId = cookies['NetflixId'];
    final secureNetflixId = cookies['SecureNetflixId'];

    if (netflixId == null || secureNetflixId == null) {
      throw Exception(
        'Netflix: cookies de sessão não encontrados. '
        'Por favor, faça login no Netflix primeiro.',
      );
    }

    final result = await _callRelay(
      function: 'screening-relay-netflix',
      body: {
        'movieId': movieId,
        'netflixId': netflixId,
        'secureNetflixId': secureNetflixId,
      },
    );

    return StreamResolution(
      url: result['hlsUrl'] as String,
      type: StreamType.hls,
      platform: StreamPlatform.netflix,
      licenseUrl: result['licenseUrl'] as String?,
      pssh: result['pssh'] as String?,
      requiresDrm: true,
      originalUrl: url,
    );
  }

  // ── Chama a Edge Function relay para Disney+ ──────────────────────────────
  static Future<StreamResolution> resolveDisney(
    String url,
    InAppWebViewController webViewController,
  ) async {
    final contentId = extractContentId(url, 'disney');
    if (contentId == null) throw Exception('Disney+: contentId não encontrado');

    // Capturar token de acesso via JavaScript
    final accessToken = await _extractTokenFromStorage(
      webViewController,
      'disneyplus.com',
      keys: ['access_token', 'bamAccessToken', 'token'],
    );

    if (accessToken == null) {
      throw Exception(
        'Disney+: token de acesso não encontrado. '
        'Por favor, faça login no Disney+ primeiro.',
      );
    }

    final result = await _callRelay(
      function: 'screening-relay-disney',
      body: {
        'contentId': contentId,
        'accessToken': accessToken,
      },
    );

    return StreamResolution(
      url: result['hlsUrl'] as String,
      type: StreamType.hls,
      platform: StreamPlatform.disneyPlus,
      licenseUrl: result['licenseUrl'] as String?,
      pssh: result['pssh'] as String?,
      requiresDrm: true,
      originalUrl: url,
    );
  }

  // ── Chama a Edge Function relay para Amazon Prime ─────────────────────────
  static Future<StreamResolution> resolveAmazon(
    String url,
    InAppWebViewController webViewController,
  ) async {
    final asin = extractContentId(url, 'amazon');
    if (asin == null) throw Exception('Amazon: ASIN não encontrado');

    // Capturar cookies de sessão
    final cookies = await captureCookies('www.primevideo.com');
    if (cookies.isEmpty) {
      // Tentar amazon.com
      final amazonCookies = await captureCookies('www.amazon.com');
      cookies.addAll(amazonCookies);
    }

    if (cookies.isEmpty) {
      throw Exception(
        'Amazon: cookies de sessão não encontrados. '
        'Por favor, faça login no Prime Video primeiro.',
      );
    }

    // Converter mapa de cookies para string
    final cookieString = cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    final result = await _callRelay(
      function: 'screening-relay-amazon',
      body: {
        'asin': asin,
        'cookies': cookieString,
        'region': 'br',
      },
    );

    return StreamResolution(
      url: result['hlsUrl'] as String,
      type: StreamType.hls,
      platform: StreamPlatform.amazonPrime,
      licenseUrl: result['licenseUrl'] as String?,
      requiresDrm: true,
      originalUrl: url,
    );
  }

  // ── Chama a Edge Function relay para HBO Max ──────────────────────────────
  static Future<StreamResolution> resolveHbo(
    String url,
    InAppWebViewController webViewController,
  ) async {
    final contentId = extractContentId(url, 'hbo');
    if (contentId == null) throw Exception('HBO Max: contentId não encontrado');

    // Capturar token de acesso via localStorage/sessionStorage
    final accessToken = await _extractTokenFromStorage(
      webViewController,
      'max.com',
      keys: ['access_token', 'hboAccessToken', 'authToken'],
    );

    if (accessToken == null) {
      throw Exception(
        'HBO Max: token de acesso não encontrado. '
        'Por favor, faça login no Max primeiro.',
      );
    }

    final result = await _callRelay(
      function: 'screening-relay-hbo',
      body: {
        'contentId': contentId,
        'accessToken': accessToken,
      },
    );

    return StreamResolution(
      url: result['hlsUrl'] as String,
      type: StreamType.hls,
      platform: StreamPlatform.hboMax,
      licenseUrl: result['licenseUrl'] as String?,
      pssh: result['pssh'] as String?,
      requiresDrm: true,
      originalUrl: url,
    );
  }

  // ── Chama a Edge Function relay para Crunchyroll ──────────────────────────
  static Future<StreamResolution> resolveCrunchyroll(
    String url,
    InAppWebViewController webViewController,
  ) async {
    final episodeId = extractContentId(url, 'crunchyroll');
    if (episodeId == null) {
      throw Exception('Crunchyroll: episodeId não encontrado');
    }

    // Capturar token de acesso via localStorage
    final accessToken = await _extractTokenFromStorage(
      webViewController,
      'www.crunchyroll.com',
      keys: ['access_token', 'cr_access_token', 'authToken'],
    );

    if (accessToken == null) {
      throw Exception(
        'Crunchyroll: token de acesso não encontrado. '
        'Por favor, faça login no Crunchyroll primeiro.',
      );
    }

    final result = await _callRelay(
      function: 'screening-relay-crunchyroll',
      body: {
        'episodeId': episodeId,
        'accessToken': accessToken,
        'locale': 'pt-BR',
      },
    );

    final isDrm = result['isDrm'] as bool? ?? false;

    return StreamResolution(
      url: result['hlsUrl'] as String,
      type: StreamType.hls,
      platform: StreamPlatform.crunchyroll,
      licenseUrl: isDrm ? result['licenseUrl'] as String? : null,
      requiresDrm: isDrm,
      originalUrl: url,
    );
  }

  // ── Helper: extrai token do localStorage/sessionStorage via JS ────────────
  static Future<String?> _extractTokenFromStorage(
    InAppWebViewController controller,
    String host,
    {required List<String> keys}
  ) async {
    for (final key in keys) {
      // Tentar localStorage
      final localResult = await controller.evaluateJavascript(
        source: "localStorage.getItem('$key')",
      );
      if (localResult != null && localResult != 'null') {
        final token = localResult.toString().replaceAll('"', '');
        if (token.isNotEmpty) return token;
      }

      // Tentar sessionStorage
      final sessionResult = await controller.evaluateJavascript(
        source: "sessionStorage.getItem('$key')",
      );
      if (sessionResult != null && sessionResult != 'null') {
        final token = sessionResult.toString().replaceAll('"', '');
        if (token.isNotEmpty) return token;
      }
    }

    // Tentar extrair de cookies como fallback
    final cookies = await captureCookies(host);
    for (final key in keys) {
      if (cookies.containsKey(key)) return cookies[key];
    }

    return null;
  }

  // ── Helper: chama uma Edge Function do Supabase ───────────────────────────
  static Future<Map<String, dynamic>> _callRelay({
    required String function,
    required Map<String, dynamic> body,
  }) async {
    // Obter URL do Supabase do AppConfig em runtime
    final supabaseUrl = _getSupabaseUrl();
    final anonKey = _getSupabaseAnonKey();

    if (supabaseUrl.isEmpty) {
      throw Exception('SUPABASE_URL não configurado');
    }

    final url = '$supabaseUrl/functions/v1/$function';

    debugPrint('[DrmRelay] Chamando $function...');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $anonKey',
        'apikey': anonKey,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        'Relay error (${response.statusCode}): ${error['error'] ?? response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Obtém URL do Supabase em runtime ──────────────────────────────────────────────────
  static String _getSupabaseUrl() => AppConfig.supabaseUrl;
  static String _getSupabaseAnonKey() => AppConfig.supabaseAnonKey;
}
