// =============================================================================
// GoogleDriveStreamService — Extrai URL de reprodução do Google Drive
//
// O Google Drive tem dois modos de reprodução de vídeo:
// 1. /file/d/{id}/preview — iframe embed (funciona sem API key)
// 2. /playback?id={id}&key={apiKey} — stream direto (precisa de API key)
//
// API key extraída do Rave APK:
//   AIzaSyDVQw45DwoYh632gvsP5vPDqEKvb-Ywnb8
//
// O Drive não expõe HLS manifest — retorna um MP4 com range requests.
// O media_kit suporta MP4 com range requests nativamente.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleDriveStreamResult {
  final String streamUrl;
  final String title;
  final String? thumbnailUrl;

  const GoogleDriveStreamResult({
    required this.streamUrl,
    required this.title,
    this.thumbnailUrl,
  });
}

class GoogleDriveStreamService {
  // API key do Google Drive extraída do Rave APK
  static const _apiKey = 'AIzaSyDVQw45DwoYh632gvsP5vPDqEKvb-Ywnb8';
  static const _driveApiBase = 'https://www.googleapis.com/drive/v3';

  // ── Extrai o file ID da URL do Drive ─────────────────────────────────────
  static String? extractFileId(String url) {
    final patterns = [
      RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)'),
      RegExp(r'drive\.google\.com/open\?id=([a-zA-Z0-9_-]+)'),
      RegExp(r'docs\.google\.com/file/d/([a-zA-Z0-9_-]+)'),
      RegExp(r'id=([a-zA-Z0-9_-]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  // ── Busca metadados do arquivo via Drive API v3 ───────────────────────────
  static Future<({String name, String? thumbnailUrl})> _getFileMeta(
      String fileId) async {
    final metaUrl = Uri.parse(
      '$_driveApiBase/files/$fileId'
      '?fields=name,thumbnailLink,mimeType'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(metaUrl, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (
          name: data['name'] as String? ?? 'Google Drive',
          thumbnailUrl: data['thumbnailLink'] as String?,
        );
      }
    } catch (_) {}
    return (name: 'Google Drive', thumbnailUrl: null);
  }

  // ── Constrói a URL de stream do Drive ────────────────────────────────────
  static String _buildStreamUrl(String fileId) {
    // URL de download direto — o Drive serve o MP4 com suporte a range requests
    // O parâmetro confirm=t bypassa o aviso de arquivo grande
    return 'https://drive.google.com/uc?export=download&id=$fileId&confirm=t';
  }

  // ── API pública ───────────────────────────────────────────────────────────
  /// Resolve uma URL do Google Drive para um stream de vídeo direto.
  static Future<GoogleDriveStreamResult> resolve(String url) async {
    final fileId = extractFileId(url);
    if (fileId == null) {
      throw Exception('Google Drive: ID de arquivo não encontrado em: $url');
    }

    // Buscar metadados e construir URL em paralelo
    final meta = await _getFileMeta(fileId);
    final streamUrl = _buildStreamUrl(fileId);

    return GoogleDriveStreamResult(
      streamUrl: streamUrl,
      title: meta.name,
      thumbnailUrl: meta.thumbnailUrl,
    );
  }

  /// Verifica se uma URL é do Google Drive.
  static bool canHandle(String url) {
    return url.contains('drive.google.com') ||
        url.contains('docs.google.com/file');
  }
}
