// =============================================================================
// KickMetaService — Resolve título e thumbnail de canais/vídeos do Kick
//
// Usa a API pública do Kick (sem autenticação).
// Endpoints:
//   Canal ao vivo: https://kick.com/api/v2/channels/<slug>
//   VOD:           https://kick.com/api/v2/video/<uuid>
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class KickMetaResult {
  final String title;
  final String? thumbnailUrl;

  const KickMetaResult({required this.title, this.thumbnailUrl});
}

class KickMetaService {
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json',
    'Referer': 'https://kick.com/',
    'Origin': 'https://kick.com',
  };

  /// Resolve metadados de um canal ao vivo ou VOD do Kick.
  static Future<KickMetaResult> resolve(String url) async {
    // VOD: kick.com/video/<uuid>
    final vodMatch = RegExp(r'kick\.com/video/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (vodMatch != null) {
      return _resolveVod(vodMatch.group(1)!);
    }

    // Canal ao vivo: kick.com/<slug>
    final channelMatch =
        RegExp(r'kick\.com/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (channelMatch != null) {
      return _resolveChannel(channelMatch.group(1)!);
    }

    throw Exception('Kick: URL não reconhecida: $url');
  }

  static Future<KickMetaResult> _resolveChannel(String slug) async {
    final uri = Uri.parse('https://kick.com/api/v2/channels/$slug');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Kick channel API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Título: título da live atual ou nome do canal
    final livestream = data['livestream'] as Map<String, dynamic>?;
    final title = (livestream?['session_title'] as String?)?.isNotEmpty == true
        ? livestream!['session_title'] as String
        : (data['user']?['username'] as String? ?? slug);

    // Thumbnail: thumbnail da live ou banner do canal
    final thumbnail = (livestream?['thumbnail']?['url'] as String?) ??
        (data['banner_image']?['url'] as String?);

    debugPrint('[KickMeta] "$title" thumbnail=$thumbnail');
    return KickMetaResult(title: title, thumbnailUrl: thumbnail);
  }

  static Future<KickMetaResult> _resolveVod(String videoId) async {
    final uri = Uri.parse('https://kick.com/api/v2/video/$videoId');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Kick VOD API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Kick';
    final thumbnail = data['thumbnail'] as String?;

    debugPrint('[KickMeta] VOD "$title" thumbnail=$thumbnail');
    return KickMetaResult(title: title, thumbnailUrl: thumbnail);
  }

  static bool canHandle(String url) => url.contains('kick.com');
}
