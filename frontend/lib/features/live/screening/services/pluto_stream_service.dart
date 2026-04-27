// =============================================================================
// PlutoStreamService — Extrai URL HLS do Pluto TV (FAST gratuito)
//
// O Pluto TV é gratuito e não requer login. Usa o client_id extraído do
// Rave APK para identificar o app no boot endpoint.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class PlutoStreamResult {
  final String hlsUrl;
  final String title;
  final String? thumbnailUrl;
  final bool isLive;

  const PlutoStreamResult({
    required this.hlsUrl,
    required this.title,
    this.thumbnailUrl,
    required this.isLive,
  });
}

class PlutoStreamService {
  // client_id do app Rave no Pluto TV (extraído do APK)
  static const _clientId = 'b6746ddc-7bc7-471f-a16c-f6aaf0c34d26';
  static const _bootUrl = 'https://boot.pluto.tv/v4/start';
  static const _vodBase = 'https://service-vod.clusters.pluto.tv';
  static const _channelsBase = 'https://service-channels.clusters.pluto.tv';

  // ── Parâmetros do boot endpoint ───────────────────────────────────────────
  static Uri _buildBootUri() {
    return Uri.parse(_bootUrl).replace(queryParameters: {
      'appName': 'web',
      'appVersion': '7.0.0',
      'deviceVersion': '1.0.0',
      'deviceModel': 'web',
      'deviceMake': 'web',
      'deviceType': 'web',
      'clientID': _clientId,
      'clientModelNumber': '1.0.0',
      'serverSideAds': 'false',
      'constraints': '',
      'drmCapabilities': '',
    });
  }

  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json',
    'Origin': 'https://pluto.tv',
    'Referer': 'https://pluto.tv/',
  };

  // ── Extrai IDs da URL ─────────────────────────────────────────────────────
  static ({String? channelSlug, String? vodId, bool isLive}) _parseUrl(
      String url) {
    // VOD: pluto.tv/movies/movie-slug ou pluto.tv/on-demand/movies/slug
    final vodMatch = RegExp(
      r'pluto\.tv/(?:on-demand/)?(?:movies|series|episodes)/([a-zA-Z0-9_-]+)',
    ).firstMatch(url);
    if (vodMatch != null) {
      return (channelSlug: null, vodId: vodMatch.group(1), isLive: false);
    }

    // Canal ao vivo: pluto.tv/live-tv/channel-slug
    final liveMatch = RegExp(
      r'pluto\.tv/live-tv/([a-zA-Z0-9_-]+)',
    ).firstMatch(url);
    if (liveMatch != null) {
      return (channelSlug: liveMatch.group(1), vodId: null, isLive: true);
    }

    return (channelSlug: null, vodId: null, isLive: false);
  }

  // ── Resolve canal ao vivo ─────────────────────────────────────────────────
  static Future<PlutoStreamResult> _resolveLive(String channelSlug) async {
    // Busca sessão anônima para obter o sessionToken
    final bootResponse = await http.get(_buildBootUri(), headers: _headers);
    if (bootResponse.statusCode != 200) {
      throw Exception('Pluto TV boot error: ${bootResponse.statusCode}');
    }
    final bootData = jsonDecode(bootResponse.body) as Map<String, dynamic>;
    final sessionToken = bootData['sessionToken'] as String?;

    // Busca metadados do canal
    final channelsUrl = Uri.parse(
      '$_channelsBase/v2/guide/channels',
    ).replace(queryParameters: {'channelSlugs': channelSlug});

    final channelHeaders = {
      ...?sessionToken != null
          ? {'Authorization': 'Bearer $sessionToken'}
          : null,
      ..._headers,
    };

    final channelResponse = await http.get(channelsUrl, headers: channelHeaders);
    if (channelResponse.statusCode != 200) {
      throw Exception('Pluto TV channels error: ${channelResponse.statusCode}');
    }

    final channelData = jsonDecode(channelResponse.body) as Map<String, dynamic>;
    final channels = channelData['data'] as List<dynamic>?;
    if (channels == null || channels.isEmpty) {
      throw Exception('Pluto TV: canal "$channelSlug" não encontrado');
    }

    final channel = channels[0] as Map<String, dynamic>;
    final title = channel['name'] as String? ?? channelSlug;
    final thumbnail = channel['thumbnail']?['path'] as String?;

    // Construir URL HLS do canal
    // O Pluto TV usa um manifest HLS com segmentos de anúncio
    // O Rave remove os segmentos de anúncio via removeAdSegments()
    final stitcherUrl = channel['stitched']?['urls']?[0]?['url'] as String?;
    if (stitcherUrl == null) {
      throw Exception('Pluto TV: sem URL HLS para canal "$channelSlug"');
    }

    return PlutoStreamResult(
      hlsUrl: stitcherUrl,
      title: title,
      thumbnailUrl: thumbnail,
      isLive: true,
    );
  }

  // ── Resolve VOD ───────────────────────────────────────────────────────────
  static Future<PlutoStreamResult> _resolveVod(String vodId) async {
    // Busca metadados do VOD
    final vodUrl = Uri.parse('$_vodBase/v4/vod/items').replace(
      queryParameters: {'ids': vodId},
    );

    final response = await http.get(vodUrl, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Pluto TV VOD error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['data'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      throw Exception('Pluto TV: VOD "$vodId" não encontrado');
    }

    final item = items[0] as Map<String, dynamic>;
    final title = item['name'] as String? ?? 'Pluto TV';
    final thumbnail = item['thumbnail']?['path'] as String?;

    // URL HLS do VOD
    final hlsUrl = item['stitched']?['urls']?[0]?['url'] as String?;
    if (hlsUrl == null) {
      throw Exception('Pluto TV: sem URL HLS para VOD "$vodId"');
    }

    return PlutoStreamResult(
      hlsUrl: hlsUrl,
      title: title,
      thumbnailUrl: thumbnail,
      isLive: false,
    );
  }

  // ── API pública ───────────────────────────────────────────────────────────
  /// Resolve uma URL do Pluto TV para um stream HLS direto.
  static Future<PlutoStreamResult> resolve(String url) async {
    final parsed = _parseUrl(url);

    if (parsed.isLive && parsed.channelSlug != null) {
      return _resolveLive(parsed.channelSlug!);
    } else if (!parsed.isLive && parsed.vodId != null) {
      return _resolveVod(parsed.vodId!);
    }

    throw Exception('URL do Pluto TV inválida: $url');
  }

  /// Verifica se uma URL é do Pluto TV.
  static bool canHandle(String url) {
    return url.contains('pluto.tv');
  }
}
