// =============================================================================
// TwitchStreamService — Extrai URL HLS da Twitch via GQL
//
// Usa o Client-ID do player web oficial da Twitch (extraído do Rave APK).
// Suporta canais ao vivo e VODs.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class TwitchStreamResult {
  final String hlsUrl;
  final String title;
  final String? thumbnailUrl;
  final bool isLive;

  const TwitchStreamResult({
    required this.hlsUrl,
    required this.title,
    this.thumbnailUrl,
    required this.isLive,
  });
}

class TwitchStreamService {
  // Client-ID do player web oficial da Twitch (extraído do Rave APK)
  static const _clientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';
  static const _gqlEndpoint = 'https://gql.twitch.tv/gql';
  static const _usherBase = 'https://usher.twitchapps.com';

  // ── Extrai canal ou VOD ID da URL ─────────────────────────────────────────
  static ({String? channel, String? vodId}) _parseUrl(String url) {
    // VOD: twitch.tv/videos/123456789
    final vodMatch = RegExp(r'twitch\.tv/videos/(\d+)').firstMatch(url);
    if (vodMatch != null) {
      return (channel: null, vodId: vodMatch.group(1));
    }
    // Canal ao vivo: twitch.tv/channelname
    final channelMatch = RegExp(r'twitch\.tv/([a-zA-Z0-9_]+)').firstMatch(url);
    if (channelMatch != null) {
      final channel = channelMatch.group(1)!;
      // Ignorar páginas de sistema
      const systemPages = {
        'directory', 'search', 'downloads', 'jobs', 'p', 'settings',
        'subscriptions', 'wallet', 'following', 'friends', 'prime',
      };
      if (!systemPages.contains(channel.toLowerCase())) {
        return (channel: channel, vodId: null);
      }
    }
    return (channel: null, vodId: null);
  }

  // ── Obtém o PlaybackAccessToken via GQL ──────────────────────────────────
  static Future<({String value, String signature})> _getAccessToken({
    String? channel,
    String? vodId,
  }) async {
    final isLive = channel != null;
    final body = jsonEncode([
      {
        'operationName': 'PlaybackAccessToken_Template',
        'query': '''
query PlaybackAccessToken_Template(
  \$login: String!, \$isLive: Boolean!,
  \$vodID: ID!, \$isVod: Boolean!, \$playerType: String!
) {
  streamPlaybackAccessToken(channelName: \$login, params: {
    platform: "web", playerBackend: "mediaplayer", playerType: \$playerType
  }) @include(if: \$isLive) {
    value
    signature
  }
  videoPlaybackAccessToken(id: \$vodID, params: {
    platform: "web", playerBackend: "mediaplayer", playerType: \$playerType
  }) @include(if: \$isVod) {
    value
    signature
  }
}
''',
        'variables': {
          'isLive': isLive,
          'login': channel ?? '',
          'isVod': !isLive,
          'vodID': vodId ?? '',
          'playerType': 'site',
        },
      }
    ]);

    final response = await http.post(
      Uri.parse(_gqlEndpoint),
      headers: {
        'Client-ID': _clientId,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Twitch GQL error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List;
    final tokenData = isLive
        ? data[0]['data']['streamPlaybackAccessToken']
        : data[0]['data']['videoPlaybackAccessToken'];

    if (tokenData == null) {
      throw Exception('Twitch: canal/VOD não encontrado ou offline');
    }

    return (
      value: tokenData['value'] as String,
      signature: tokenData['signature'] as String,
    );
  }

  // ── Obtém metadados do canal via GQL ─────────────────────────────────────
  static Future<({String title, String? thumbnail})> _getChannelMeta(
      String channel) async {
    final body = jsonEncode([
      {
        'operationName': 'StreamMetadata',
        'query': '''
query StreamMetadata(\$channelLogin: String!) {
  user(login: \$channelLogin) {
    displayName
    stream {
      title
      previewImageURL(width: 640, height: 360)
    }
  }
}
''',
        'variables': {'channelLogin': channel},
      }
    ]);

    try {
      final response = await http.post(
        Uri.parse(_gqlEndpoint),
        headers: {'Client-ID': _clientId, 'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final user = data[0]['data']['user'];
        if (user != null) {
          final stream = user['stream'];
          final displayName = user['displayName'] as String? ?? channel;
          final title = stream?['title'] as String? ?? displayName;
          final thumbnail = stream?['previewImageURL'] as String?;
          return (title: title, thumbnail: thumbnail);
        }
      }
    } catch (_) {}
    return (title: channel, thumbnail: null);
  }

  // ── Obtém metadados do VOD via GQL ────────────────────────────────────────
  static Future<({String title, String? thumbnail})> _getVodMeta(
      String vodId) async {
    final body = jsonEncode([
      {
        'operationName': 'VideoMetadata',
        'query': '''
query VideoMetadata(\$videoID: ID!) {
  video(id: \$videoID) {
    title
    previewThumbnailURL(width: 640, height: 360)
  }
}
''',
        'variables': {'videoID': vodId},
      }
    ]);

    try {
      final response = await http.post(
        Uri.parse(_gqlEndpoint),
        headers: {'Client-ID': _clientId, 'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final video = data[0]['data']['video'];
        if (video != null) {
          return (
            title: video['title'] as String? ?? 'Twitch VOD',
            thumbnail: video['previewThumbnailURL'] as String?,
          );
        }
      }
    } catch (_) {}
    return (title: 'Twitch VOD', thumbnail: null);
  }

  // ── Constrói a URL HLS do Usher ───────────────────────────────────────────
  static String _buildHlsUrl({
    String? channel,
    String? vodId,
    required String token,
    required String sig,
  }) {
    final params = {
      'sig': sig,
      'token': token,
      'allow_source': 'true',
      'allow_spectre': 'true',
      'allow_audio_only': 'true',
      'fast_bread': 'true',
      'p': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    if (channel != null) {
      return '$_usherBase/api/channel/hls/$channel.m3u8?$query';
    } else {
      return '$_usherBase/vod/$vodId.m3u8?$query';
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────
  /// Resolve uma URL da Twitch para um stream HLS direto.
  static Future<TwitchStreamResult> resolve(String url) async {
    final parsed = _parseUrl(url);
    if (parsed.channel == null && parsed.vodId == null) {
      throw Exception('URL da Twitch inválida: $url');
    }

    final isLive = parsed.channel != null;

    // Busca token e metadados em paralelo
    final tokenFuture = _getAccessToken(
      channel: parsed.channel,
      vodId: parsed.vodId,
    );
    final metaFuture = isLive
        ? _getChannelMeta(parsed.channel!)
        : _getVodMeta(parsed.vodId!);

    final results = await Future.wait([tokenFuture, metaFuture]);
    final tokenData = results[0] as ({String value, String signature});
    final meta = results[1] as ({String title, String? thumbnail});

    final hlsUrl = _buildHlsUrl(
      channel: parsed.channel,
      vodId: parsed.vodId,
      token: tokenData.value,
      sig: tokenData.signature,
    );

    return TwitchStreamResult(
      hlsUrl: hlsUrl,
      title: meta.title,
      thumbnailUrl: meta.thumbnail,
      isLive: isLive,
    );
  }

  /// Resolve apenas metadados (título/thumbnail) sem obter o token HLS.
  /// Usado quando o player usa embed iframe e não precisa do token HLS.
  static Future<TwitchStreamResult> resolveMetaOnly(String url) async {
    final parsed = _parseUrl(url);
    if (parsed.channel == null && parsed.vodId == null) {
      throw Exception('URL da Twitch inválida: $url');
    }
    final isLive = parsed.channel != null;
    final meta = isLive
        ? await _getChannelMeta(parsed.channel!)
        : await _getVodMeta(parsed.vodId!);
    return TwitchStreamResult(
      hlsUrl: '', // não usado no modo embed
      title: meta.title,
      thumbnailUrl: meta.thumbnail,
      isLive: isLive,
    );
  }

  /// Verifica se uma URL é da Twitch.
  static bool canHandle(String url) {
    return url.contains('twitch.tv');
  }
}
