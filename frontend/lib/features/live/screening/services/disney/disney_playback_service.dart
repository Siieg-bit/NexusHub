import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'disney_auth_service.dart';
import 'disney_api_service.dart';
import 'disney_models.dart';

/// Serviço de playback do Disney+.
///
/// Responsável por:
/// 1. Resolver um contentId em um playbackId via deeplink.
/// 2. Obter o manifesto HLS/DASH via endpoint de playback BAMGrid.
/// 3. Retornar a URL de licença Widevine para o ExoPlayer.
///
/// Baseado no fluxo `getManifest` → `fetchDeepLinkInfo` → `fetchDisneyStreams`
/// do DisneyServer do Rave (extraído via engenharia reversa do APK).
class DisneyPlaybackService {
  // ── UUID de sessão único por dispositivo ──────────────────────────────────
  // O Rave usa um UUID hardcoded, o que causa conflito entre usuários.
  // O NexusHub gera um UUID único por dispositivo, persistido no secure storage.
  // Isso é mais correto e evita que múltiplos usuários compartilhem o mesmo ID.
  static const _storage = FlutterSecureStorage();
  static const _kDeviceSessionId = 'disney_device_session_id';
  static const _uuid = Uuid();
  static String? _cachedSessionId;

  /// Retorna o UUID de sessão único deste dispositivo.
  /// Gerado na primeira chamada e persistido no secure storage.
  static Future<String> _getDeviceSessionId() async {
    if (_cachedSessionId != null) return _cachedSessionId!;
    final stored = await _storage.read(key: _kDeviceSessionId);
    if (stored != null && stored.isNotEmpty) {
      _cachedSessionId = stored;
      return stored;
    }
    // Gerar novo UUID v4 para este dispositivo
    final newId = _uuid.v4();
    await _storage.write(key: _kDeviceSessionId, value: newId);
    _cachedSessionId = newId;
    debugPrint('[DisneyPlayback] Novo device session ID gerado: $newId');
    return newId;
  }

  // ── Endpoints de playback (extraídos do DisneyServer.smali do Rave) ───────

  /// Endpoint principal de playback CTR (Clear Text Response).
  /// Retorna o manifesto HLS/DASH + URL de licença Widevine.
  static const _playbackEndpoint =
      'https://disney.playback.edge.bamgrid.com/v7/playback/ctr-regular';

  /// Endpoint alternativo para conteúdo com SGAI (Server-Guided Ad Insertion).
  static const _playbackSgaiEndpoint =
      'https://disney.playback.edge.bamgrid.com/v7/playback/ctr-sgai';

  // ── Payload de playback (hardcoded do Rave — DisneyServer.smali) ──────────
  // Este JSON é enviado no body do POST para o endpoint de playback.
  // Valores extraídos diretamente da string hardcoded no APK do Rave:
  // const-string v6, "\n        {\n            \"playback\": {\n..."
  static Future<Map<String, dynamic>> _buildPlaybackBody(String playbackId) async {
    // UUID único por dispositivo (gerado uma vez e persistido no secure storage)
    // O Rave usa um UUID hardcoded — o NexusHub usa um UUID único por dispositivo
    // para evitar conflitos entre múltiplos usuários simultâneos.
    final sessionId = await _getDeviceSessionId();
    return {
      'playback': {
        'attributes': {
          'resolution': {
            'max': ['1280x720'],
          },
          'protocol': 'HTTPS',
          'assetInsertionStrategy': 'SGAI',
          'playbackInitiationContext': 'ONLINE',
          'frameRates': [60],
          'slugDuration': null,
        },
        'adTracking': {
          'limitAdTrackingEnabled': 'YES',
          'deviceAdId': '00000000-0000-0000-0000-000000000000',
        },
        'tracking': {
          'playbackSessionId': sessionId,
        },
      },
      'playbackId': playbackId,
    };
  }

  // ── Headers de playback ───────────────────────────────────────────────────
  static Map<String, String> _playbackHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'X-BAMSDK-Client-ID': 'disney-svod-3d9324fc',
        'X-BAMSDK-Platform': 'android/google/handset',
        'X-BAMSDK-Version': '8.3.3',
        'X-Application-Version': '2.16.2-rc2.0',
        'X-DSS-Edge-Accept': 'vnd.dss.edge+json; version=2',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ── Método principal ──────────────────────────────────────────────────────

  /// Resolve um contentId em um stream reproduzível.
  ///
  /// Fluxo:
  /// 1. Obtém o playbackId via deeplink (`/deeplink?action=playback&refId=`)
  /// 2. Chama o endpoint de playback com o playbackId
  /// 3. Extrai a URL do manifesto HLS/DASH e a URL de licença Widevine
  ///
  /// Retorna um [DisneyStream] com a URL do manifesto e a URL de licença.
  static Future<DisneyStream> resolveStream(String contentId) async {
    debugPrint('[DisneyPlayback] Resolvendo stream para contentId: $contentId');
    return await _resolveWithRetry(contentId, retryCount: 0);
  }

  /// Resolve o stream com retry automático em caso de 401 (token expirado).
  ///
  /// Idêntico ao comportamento do Rave: quando o endpoint de playback retorna 401,
  /// o token é renovado via refresh_token e a requisição é repetida automaticamente,
  /// sem exibir erro ao usuário.
  static Future<DisneyStream> _resolveWithRetry(
    String contentId, {
    required int retryCount,
  }) async {
    final accessToken = await DisneyAuthService.getValidAccessToken();

    // Passo 1: Resolver o playbackId via deeplink
    String playbackId;
    try {
      final deepLink = await DisneyApiService.fetchDeepLink(contentId);
      playbackId = deepLink.resourceId ?? deepLink.playbackId ?? contentId;
      debugPrint('[DisneyPlayback] playbackId resolvido: $playbackId');
    } catch (e) {
      if (e is DisneyAuthException && e.isExpired && retryCount == 0) {
        debugPrint('[DisneyPlayback] Token expirado no deeplink, renovando e tentando novamente...');
        await DisneyAuthService.forceRefresh();
        return _resolveWithRetry(contentId, retryCount: retryCount + 1);
      }
      // Fallback: usar o contentId diretamente como playbackId
      debugPrint('[DisneyPlayback] Deeplink falhou, usando contentId como playbackId: $e');
      playbackId = contentId;
    }

    // Passo 2: Obter o manifesto via endpoint de playback
    try {
      return await _fetchPlaybackStream(playbackId, accessToken);
    } on DisneyAuthException catch (e) {
      if (e.isExpired && retryCount == 0) {
        // Token expirou durante o playback — renovar e tentar novamente (igual ao Rave)
        debugPrint('[DisneyPlayback] Token expirado no playback, renovando e tentando novamente...');
        await DisneyAuthService.forceRefresh();
        return _resolveWithRetry(contentId, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  /// Resolve um contentId a partir de uma URL do Disney+.
  ///
  /// Suporta os formatos:
  /// - `https://www.disneyplus.com/video/{contentId}`
  /// - `https://www.disneyplus.com/movies/{slug}/{contentId}`
  /// - `https://www.disneyplus.com/series/{slug}/{contentId}`
  static Future<DisneyStream> resolveFromUrl(String url) async {
    final contentId = _extractContentIdFromUrl(url);
    if (contentId == null) {
      throw Exception('Disney+: não foi possível extrair o contentId da URL: $url');
    }
    // Resolver o stream
    final stream = await resolveStream(contentId);
    // Tentar buscar metadados do conteúdo (título e thumbnail).
    // Falha silenciosa — metadados são opcionais para o player funcionar.
    try {
      final accessToken = await DisneyAuthService.getValidAccessToken();
      final metaRaw = await DisneyApiService.fetchPlayerExperience(contentId);
      // Extrair título e thumbnail do JSON bruto do playerExperience
      final data = metaRaw['data'] as Map<String, dynamic>?;
      final experience = data?['DmcVideo'] as Map<String, dynamic>?
          ?? data?['DmcSeries'] as Map<String, dynamic>?
          ?? data;
      final text = experience?['text'] as Map<String, dynamic>?;
      final titleField = text?['title'] as Map<String, dynamic>?;
      final titleFull = (titleField?['full'] as Map<String, dynamic>?)?['program']
          as Map<String, dynamic>?;
      final title = titleFull?['content'] as String?
          ?? titleFull?['default'] as String?;
      final image = experience?['image'] as Map<String, dynamic>?;
      String? thumbnailUrl;
      if (image != null) {
        for (final key in ['tile', 'thumbnail', 'background']) {
          final field = image[key] as Map<String, dynamic>?;
          if (field == null) continue;
          for (final aspect in field.values) {
            final aspectMap = aspect as Map<String, dynamic>?;
            if (aspectMap == null) continue;
            for (final size in aspectMap.values) {
              final sizeMap = size as Map<String, dynamic>?;
              final url = (sizeMap?['default'] as Map<String, dynamic>?)?['url'] as String?;
              if (url != null && url.isNotEmpty) {
                thumbnailUrl = url;
                break;
              }
            }
            if (thumbnailUrl != null) break;
          }
          if (thumbnailUrl != null) break;
        }
      }
      return stream.copyWith(
        title: title,
        thumbnailUrl: thumbnailUrl,
        // Headers com Authorization para segmentos protegidos pelo DRM
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-BAMSDK-Client-ID': 'disney-svod-3d9324fc',
          'X-BAMSDK-Platform': 'android/google/handset',
        },
      );
    } catch (e) {
      debugPrint('[DisneyPlayback] Metadados não disponíveis: $e');
    }
    return stream;
  }

  // ── Fetch do manifesto ────────────────────────────────────────────────────

  static Future<DisneyStream> _fetchPlaybackStream(
    String playbackId,
    String accessToken,
  ) async {
    debugPrint('[DisneyPlayback] Chamando endpoint de playback para: $playbackId');

    final body = jsonEncode(await _buildPlaybackBody(playbackId));

    http.Response response;
    try {
      response = await http.post(
        Uri.parse(_playbackEndpoint),
        headers: _playbackHeaders(accessToken),
        body: body,
      );
    } catch (e) {
      throw Exception('Disney+: falha de rede ao obter stream: $e');
    }

    if (response.statusCode == 401) {
      // Token expirado — tentar renovar e tentar novamente
      debugPrint('[DisneyPlayback] Token expirado, renovando...');
      throw DisneyAuthException(
        'Sessão Disney+ expirada. Por favor, faça login novamente.',
        isExpired: true,
      );
    }

    if (response.statusCode == 403) {
      // Conteúdo bloqueado por região ou assinatura
      final error = _tryParseError(response.body);
      throw Exception(
        'Disney+: acesso negado. '
        '${error ?? "Verifique se sua assinatura está ativa."}',
      );
    }

    if (response.statusCode != 200) {
      final error = _tryParseError(response.body);
      throw Exception(
        'Disney+ playback erro ${response.statusCode}: '
        '${error ?? response.body.substring(0, response.body.length.clamp(0, 200))}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _parsePlaybackResponse(data);
  }

  // ── Parser da resposta de playback ────────────────────────────────────────

  static DisneyStream _parsePlaybackResponse(Map<String, dynamic> data) {
    // Estrutura baseada em StreamsResponse e DisneyStreamsSourceComplete do Rave
    // A resposta contém: stream.complete.url (manifesto HLS/DASH)
    // e playbackUrls[].href (URL de licença Widevine)

    String? manifestUrl;
    String? licenseUrl;

    // Tentar extrair URL do manifesto
    final stream = data['stream'] as Map<String, dynamic>?;
    if (stream != null) {
      final complete = stream['complete'] as Map<String, dynamic>?;
      manifestUrl = complete?['url'] as String?;

      // Fallback: tentar 'sources'
      if (manifestUrl == null) {
        final sources = stream['sources'] as List<dynamic>?;
        if (sources != null && sources.isNotEmpty) {
          final first = sources.first as Map<String, dynamic>;
          manifestUrl = first['url'] as String?
              ?? first['complete']?['url'] as String?;
        }
      }
    }

    // Tentar extrair URL de licença Widevine
    final playbackUrls = data['playbackUrls'] as List<dynamic>?;
    if (playbackUrls != null) {
      for (final urlEntry in playbackUrls) {
        final entry = urlEntry as Map<String, dynamic>;
        final rel = entry['rel'] as String? ?? '';
        if (rel.contains('widevine') || rel.contains('license') || rel.contains('drm')) {
          licenseUrl = entry['href'] as String?;
          break;
        }
      }
      // Fallback: pegar o primeiro href disponível
      if (licenseUrl == null && playbackUrls.isNotEmpty) {
        final first = playbackUrls.first as Map<String, dynamic>;
        licenseUrl = first['href'] as String?;
      }
    }

    // Tentar estrutura alternativa
    if (manifestUrl == null) {
      final sources = data['sources'] as List<dynamic>?;
      if (sources != null && sources.isNotEmpty) {
        final first = sources.first as Map<String, dynamic>;
        manifestUrl = first['url'] as String?;
        licenseUrl ??= first['licenseUrl'] as String?;
      }
    }

    if (manifestUrl == null || manifestUrl.isEmpty) {
      debugPrint('[DisneyPlayback] Resposta completa: ${jsonEncode(data).substring(0, (jsonEncode(data).length).clamp(0, 500))}');
      throw Exception(
        'Disney+: URL do manifesto não encontrada na resposta de playback.',
      );
    }

    debugPrint('[DisneyPlayback] Manifesto: $manifestUrl');
    debugPrint('[DisneyPlayback] Licença: $licenseUrl');

    return DisneyStream(
      manifestUrl: manifestUrl,
      licenseUrl: licenseUrl,
      isDrm: licenseUrl != null,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _extractContentIdFromUrl(String url) {
    // https://www.disneyplus.com/video/{contentId}
    var m = RegExp(r'disneyplus\.com/video/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (m != null) return m.group(1);

    // https://www.disneyplus.com/movies/{slug}/{contentId}
    m = RegExp(r'disneyplus\.com/movies/[^/]+/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (m != null) return m.group(1);

    // https://www.disneyplus.com/series/{slug}/{contentId}
    m = RegExp(r'disneyplus\.com/series/[^/]+/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (m != null) return m.group(1);

    // https://www.disneyplus.com/play/{contentId}
    m = RegExp(r'disneyplus\.com/play/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (m != null) return m.group(1);

    return null;
  }

  static String? _tryParseError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String?
          ?? json['message'] as String?
          ?? json['description'] as String?;
    } catch (_) {
      return null;
    }
  }
}
