// =============================================================================
// VimeoMetaService — Resolve título e thumbnail de vídeos do Vimeo
//
// Usa a API oEmbed pública do Vimeo (sem autenticação necessária).
// Endpoint: https://vimeo.com/api/oembed.json?url=<url>
// Retorna: title, thumbnail_url, author_name, etc.
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VimeoMetaResult {
  final String title;
  final String? thumbnailUrl;

  const VimeoMetaResult({required this.title, this.thumbnailUrl});
}

class VimeoMetaService {
  static const _oEmbedEndpoint = 'https://vimeo.com/api/oembed.json';

  /// Resolve título e thumbnail de um vídeo do Vimeo via oEmbed.
  static Future<VimeoMetaResult> resolve(String url) async {
    final uri = Uri.parse(
      '$_oEmbedEndpoint?url=${Uri.encodeComponent(url)}&width=1280',
    );

    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; NexusHub/1.0)',
    }).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Vimeo oEmbed error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Vimeo';
    final thumbnail = data['thumbnail_url'] as String?;

    debugPrint('[VimeoMeta] "$title" thumbnail=$thumbnail');
    return VimeoMetaResult(title: title, thumbnailUrl: thumbnail);
  }

  static bool canHandle(String url) => url.contains('vimeo.com');
}
