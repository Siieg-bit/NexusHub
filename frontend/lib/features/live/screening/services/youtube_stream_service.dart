// =============================================================================
// YouTubeStreamService — Extrai URL HLS do YouTube via Innertube API
//
// Usa a Player API key extraída do Rave APK para obter o manifest HLS
// diretamente, sem depender do iframe embed. Suporta vídeos normais,
// Shorts e lives.
//
// Keys extraídas do Rave APK:
//   Player API key: AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w
//   Web API key:    AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class YouTubeStreamResult {
  final String hlsUrl;
  final String title;
  final String? thumbnailUrl;
  final bool isLive;
  final Duration? duration;

  const YouTubeStreamResult({
    required this.hlsUrl,
    required this.title,
    this.thumbnailUrl,
    required this.isLive,
    this.duration,
  });
}

class YouTubeStreamService {
  // Player API key extraída do Rave APK
  static const _playerApiKey = 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';
  static const _playerEndpoint =
      'https://youtubei.googleapis.com/youtubei/v1/player';

  // Contexto de cliente web (necessário para o Innertube)
  static const _clientContext = {
    'context': {
      'client': {
        'clientName': 'WEB',
        'clientVersion': '2.20240101.00.00',
        'hl': 'pt',
        'gl': 'BR',
        'utcOffsetMinutes': -180,
      }
    }
  };

  // ── Extrai o video ID da URL ──────────────────────────────────────────────
  static String? extractVideoId(String url) {
    final patterns = [
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/live/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/@[^/]+/live.*v=([a-zA-Z0-9_-]{11})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  // ── Chama o endpoint /player do Innertube ─────────────────────────────────
  static Future<Map<String, dynamic>> _fetchPlayerData(String videoId) async {
    final body = {
      ..._clientContext,
      'videoId': videoId,
      'params': 'CgIQBg==', // parâmetro que habilita HLS manifest
      'playbackContext': {
        'contentPlaybackContext': {
          'html5Preference': 'HTML5_PREF_WANTS',
          'signatureTimestamp': 19950, // timestamp fixo — funciona para maioria
        }
      },
    };

    final response = await http.post(
      Uri.parse('$_playerEndpoint?key=$_playerApiKey'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'X-YouTube-Client-Name': '1',
        'X-YouTube-Client-Version': '2.20240101.00.00',
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('YouTube Innertube error: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Extrai URL HLS do playerData ─────────────────────────────────────────
  static String? _extractHlsUrl(Map<String, dynamic> playerData) {
    // Para lives: streamingData.hlsManifestUrl
    final streamingData =
        playerData['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    // HLS manifest direto (lives e alguns VODs)
    final hlsManifestUrl = streamingData['hlsManifestUrl'] as String?;
    if (hlsManifestUrl != null && hlsManifestUrl.isNotEmpty) {
      return hlsManifestUrl;
    }

    // Para VODs: adaptiveFormats com mimeType video/mp4 + audioFormats
    // Preferir o formato DASH se disponível
    final dashManifestUrl = streamingData['dashManifestUrl'] as String?;
    if (dashManifestUrl != null && dashManifestUrl.isNotEmpty) {
      return dashManifestUrl;
    }

    // Fallback: pegar o melhor formato progressivo
    final formats = streamingData['formats'] as List<dynamic>?;
    if (formats != null && formats.isNotEmpty) {
      // Ordenar por qualidade (itag 22 = 720p, 18 = 360p)
      final sorted = List<Map<String, dynamic>>.from(
        formats.whereType<Map<String, dynamic>>(),
      )..sort((a, b) {
          final itagA = (a['itag'] as num?)?.toInt() ?? 0;
          final itagB = (b['itag'] as num?)?.toInt() ?? 0;
          // Preferir 22 (720p) > 18 (360p)
          final priority = {22: 2, 18: 1};
          return (priority[itagB] ?? 0).compareTo(priority[itagA] ?? 0);
        });

      for (final fmt in sorted) {
        final url = fmt['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
    }

    return null;
  }

  // ── Extrai metadados do playerData ───────────────────────────────────────
  static ({String title, String? thumbnail, bool isLive, Duration? duration})
      _extractMeta(Map<String, dynamic> playerData) {
    final details =
        playerData['videoDetails'] as Map<String, dynamic>? ?? {};
    final title = details['title'] as String? ?? 'YouTube';
    final isLive = details['isLive'] as bool? ?? false;
    final durationSecs =
        int.tryParse(details['lengthSeconds'] as String? ?? '0') ?? 0;
    final duration =
        durationSecs > 0 ? Duration(seconds: durationSecs) : null;

    // Thumbnail de maior resolução
    final thumbnails = details['thumbnail']?['thumbnails'] as List<dynamic>?;
    String? thumbnail;
    if (thumbnails != null && thumbnails.isNotEmpty) {
      // Pegar a maior thumbnail (última da lista)
      thumbnail = (thumbnails.last as Map<String, dynamic>)['url'] as String?;
    }

    return (
      title: title,
      thumbnail: thumbnail,
      isLive: isLive,
      duration: duration,
    );
  }

  // ── API pública ───────────────────────────────────────────────────────────
  /// Resolve uma URL do YouTube para um stream HLS/MP4 direto.
  ///
  /// Nota: o YouTube usa assinatura de URL (n-parameter) que expira.
  /// Para VODs longos, o iframe embed ainda é mais confiável.
  /// Esta implementação é preferida para lives e Shorts.
  static Future<YouTubeStreamResult> resolve(String url) async {
    final videoId = extractVideoId(url);
    if (videoId == null) {
      throw Exception('YouTube: ID de vídeo não encontrado em: $url');
    }

    final playerData = await _fetchPlayerData(videoId);

    // Verificar se o vídeo está disponível
    final playabilityStatus =
        playerData['playabilityStatus'] as Map<String, dynamic>?;
    final status = playabilityStatus?['status'] as String?;
    if (status == 'LOGIN_REQUIRED' || status == 'UNPLAYABLE') {
      throw Exception(
        'YouTube: vídeo não disponível ($status) — '
        'usando embed como fallback',
      );
    }

    final hlsUrl = _extractHlsUrl(playerData);
    if (hlsUrl == null) {
      throw Exception(
        'YouTube: nenhum stream HLS/MP4 encontrado para $videoId',
      );
    }

    final meta = _extractMeta(playerData);

    debugPrint(
      '[YouTube] Resolvido: $videoId → ${meta.isLive ? "LIVE" : "VOD"} '
      '(${hlsUrl.contains(".m3u8") ? "HLS" : "MP4"})',
    );

    return YouTubeStreamResult(
      hlsUrl: hlsUrl,
      title: meta.title,
      thumbnailUrl: meta.thumbnail,
      isLive: meta.isLive,
      duration: meta.duration,
    );
  }

  /// Verifica se uma URL é do YouTube.
  static bool canHandle(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }
}
