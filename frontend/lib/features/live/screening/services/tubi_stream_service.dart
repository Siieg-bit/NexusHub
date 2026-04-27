// =============================================================================
// TubiStreamService — Extrai URL HLS do Tubi (AVOD gratuito)
//
// O Tubi é gratuito e não requer login. Usa um HMAC key extraído do Rave APK
// para assinar as requisições ao endpoint de conteúdo.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class TubiStreamResult {
  final String hlsUrl;
  final String title;
  final String? thumbnailUrl;
  final bool requiresWidevine;

  const TubiStreamResult({
    required this.hlsUrl,
    required this.title,
    this.thumbnailUrl,
    this.requiresWidevine = false,
  });
}

class TubiStreamService {
  static const _baseUrl = 'https://tubitv.com';

  // ── Extrai o ID do vídeo da URL ───────────────────────────────────────────
  static String? _extractId(String url) {
    // Formatos: /movies/123456, /tv-shows/123456, /series/123456, /video/123456
    final match = RegExp(
      r'tubitv\.com/(?:movies|tv-shows|series|video|oz/videos)/(\d+)',
    ).firstMatch(url);
    return match?.group(1);
  }

  // ── Busca metadados e URL do conteúdo ────────────────────────────────────
  static Future<TubiStreamResult> resolve(String url) async {
    final id = _extractId(url);
    if (id == null) {
      throw Exception('URL do Tubi inválida: $url');
    }

    // Endpoint de conteúdo — retorna HLS manifest
    // Tenta hlsv3 primeiro (sem DRM), fallback para hlsv6_widevine
    final contentUrl = Uri.parse(
      '$_baseUrl/oz/videos/$id/content'
      '?video_resources=hlsv3'
      '&video_resources=hlsv6_widevine_psshv0',
    );

    final response = await http.get(
      contentUrl,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': 'application/json',
        'Referer': 'https://tubitv.com/',
        'Origin': 'https://tubitv.com',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Tubi content error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Extrair URL HLS — preferir hlsv3 (sem DRM)
    String? hlsUrl;
    bool requiresWidevine = false;

    final videoResources = data['video_resources'] as List<dynamic>?;
    if (videoResources != null) {
      // Tentar hlsv3 primeiro
      for (final resource in videoResources) {
        if (resource['type'] == 'hlsv3') {
          hlsUrl = resource['manifest']?['url'] as String?;
          if (hlsUrl != null) break;
        }
      }
      // Fallback para hlsv6 (Widevine)
      if (hlsUrl == null) {
        for (final resource in videoResources) {
          if (resource['type'] == 'hlsv6_widevine_psshv0') {
            hlsUrl = resource['manifest']?['url'] as String?;
            requiresWidevine = true;
            if (hlsUrl != null) break;
          }
        }
      }
    }

    if (hlsUrl == null) {
      throw Exception('Tubi: nenhum stream HLS disponível para $id');
    }

    // Extrair metadados
    final title = data['title'] as String? ?? 'Tubi';
    final thumbnailUrl = data['thumbnails']?[0]?['url'] as String?;

    return TubiStreamResult(
      hlsUrl: hlsUrl,
      title: title,
      thumbnailUrl: thumbnailUrl,
      requiresWidevine: requiresWidevine,
    );
  }

  /// Verifica se uma URL é do Tubi.
  static bool canHandle(String url) {
    return url.contains('tubitv.com');
  }
}
