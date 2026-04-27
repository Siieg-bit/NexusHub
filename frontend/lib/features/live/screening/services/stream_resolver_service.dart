// =============================================================================
// StreamResolverService — Orquestra todos os serviços de stream
//
// Detecta a plataforma pela URL e delega para o serviço correto.
// Retorna um StreamResolution com a URL HLS (ou embed) e metadados.
// =============================================================================

import 'twitch_stream_service.dart';
import 'tubi_stream_service.dart';
import 'pluto_stream_service.dart';
import 'youtube_stream_service.dart';
import 'google_drive_stream_service.dart';

enum StreamType {
  /// Stream HLS direto — usa o player nativo (media_kit / video_player)
  hls,

  /// Embed iframe — usa InAppWebView
  embed,

  /// URL direta (ex: .mp4, .m3u8 direto)
  direct,
}

enum StreamPlatform {
  youtube,
  youtubeLive,
  twitch,
  kick,
  vimeo,
  dailymotion,
  googleDrive,
  tubi,
  plutoTv,
  netflix,
  disneyPlus,
  amazonPrime,
  hboMax,
  crunchyroll,
  vk,
  web,
  unknown,
}

class StreamResolution {
  /// URL final para reprodução (HLS manifest ou embed URL)
  final String url;

  /// Tipo de stream — determina qual player usar
  final StreamType type;

  /// Plataforma detectada
  final StreamPlatform platform;

  /// Título do conteúdo (se disponível)
  final String? title;

  /// URL da thumbnail (se disponível)
  final String? thumbnailUrl;

  /// Se true, requer DRM Widevine para reprodução
  final bool requiresDrm;

  /// URL do servidor de licença Widevine (obrigatório quando requiresDrm = true)
  final String? licenseUrl;

  /// PSSH box em base64 (opcional, melhora a inicialização DRM)
  final String? pssh;

  /// Headers HTTP adicionais para o manifest e segmentos
  final Map<String, String>? headers;

  /// URL original (antes da resolução)
  final String originalUrl;

  const StreamResolution({
    required this.url,
    required this.type,
    required this.platform,
    this.title,
    this.thumbnailUrl,
    this.requiresDrm = false,
    this.licenseUrl,
    this.pssh,
    this.headers,
    required this.originalUrl,
  });
}

class StreamResolverService {
  // ── Detecção de plataforma ────────────────────────────────────────────────
  static StreamPlatform detectPlatform(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      if (u.contains('/live') || u.contains('youtube.com/@')) {
        return StreamPlatform.youtubeLive;
      }
      return StreamPlatform.youtube;
    }
    if (u.contains('twitch.tv')) return StreamPlatform.twitch;
    if (u.contains('kick.com')) return StreamPlatform.kick;
    if (u.contains('vimeo.com')) return StreamPlatform.vimeo;
    if (u.contains('dailymotion.com')) return StreamPlatform.dailymotion;
    if (u.contains('drive.google.com')) return StreamPlatform.googleDrive;
    if (u.contains('tubitv.com')) return StreamPlatform.tubi;
    if (u.contains('pluto.tv')) return StreamPlatform.plutoTv;
    if (u.contains('netflix.com')) return StreamPlatform.netflix;
    if (u.contains('disneyplus.com') || u.contains('disney.com')) {
      return StreamPlatform.disneyPlus;
    }
    if (u.contains('primevideo.com') || u.contains('amazon.com/video')) {
      return StreamPlatform.amazonPrime;
    }
    if (u.contains('hbomax.com') || u.contains('max.com')) {
      return StreamPlatform.hboMax;
    }
    if (u.contains('crunchyroll.com')) return StreamPlatform.crunchyroll;
    if (u.contains('vk.com') || u.contains('vk.ru')) return StreamPlatform.vk;
    return StreamPlatform.web;
  }

  // ── Constrói embed URL para plataformas que usam iframe ───────────────────
  static String? _toEmbedUrl(String url, StreamPlatform platform) {
    switch (platform) {
      case StreamPlatform.youtube:
      case StreamPlatform.youtubeLive:
        final id = _extractYouTubeId(url);
        if (id.isNotEmpty) {
          return 'https://www.youtube-nocookie.com/embed/$id'
              '?autoplay=1&mute=0&rel=0&modestbranding=1'
              '&playsinline=1&enablejsapi=1&origin=https://nexushub.app';
        }
        return null;

      case StreamPlatform.twitch:
        // Twitch usa HLS direto — não usa embed aqui
        return null;

      case StreamPlatform.kick:
        final match = RegExp(r'kick\.com/([a-zA-Z0-9_-]+)').firstMatch(url);
        final channel = match?.group(1) ?? '';
        if (channel.isNotEmpty) {
          return 'https://player.kick.com/$channel?autoplay=true';
        }
        return null;

      case StreamPlatform.vimeo:
        final match = RegExp(r'vimeo\.com/(\d+)').firstMatch(url);
        final id = match?.group(1) ?? '';
        if (id.isNotEmpty) {
          return 'https://player.vimeo.com/video/$id?autoplay=1&dnt=1';
        }
        return null;

      case StreamPlatform.dailymotion:
        final match =
            RegExp(r'dailymotion\.com/video/([a-zA-Z0-9]+)').firstMatch(url);
        final id = match?.group(1) ?? '';
        if (id.isNotEmpty) {
          return 'https://www.dailymotion.com/embed/video/$id?autoplay=1';
        }
        return null;

      default:
        return null;
    }
  }

  static String _extractYouTubeId(String url) {
    final patterns = [
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/live/([a-zA-Z0-9_-]{11})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1) ?? '';
    }
    return '';
  }

  // ── API pública ───────────────────────────────────────────────────────────
  /// Resolve uma URL para um StreamResolution.
  ///
  /// Para plataformas HLS (Twitch, Tubi, Pluto TV), faz a requisição de API
  /// e retorna a URL HLS direta.
  ///
  /// Para plataformas embed (YouTube, Kick, Vimeo, Dailymotion), retorna
  /// a URL de embed sem requisição de rede.
  ///
  /// Para plataformas DRM (Netflix, Disney+, Amazon, HBO), retorna
  /// [StreamType.embed] com a URL original — o relay será implementado na
  /// Rodada 3.
  static Future<StreamResolution> resolve(String url) async {
    final platform = detectPlatform(url);

    switch (platform) {
      // ── HLS direto via API ──────────────────────────────────────────────
      case StreamPlatform.twitch:
        final result = await TwitchStreamService.resolve(url);
        return StreamResolution(
          url: result.hlsUrl,
          type: StreamType.hls,
          platform: platform,
          title: result.title,
          thumbnailUrl: result.thumbnailUrl,
          originalUrl: url,
        );

      case StreamPlatform.tubi:
        final result = await TubiStreamService.resolve(url);
        return StreamResolution(
          url: result.hlsUrl,
          type: StreamType.hls,
          platform: platform,
          title: result.title,
          thumbnailUrl: result.thumbnailUrl,
          requiresDrm: result.requiresWidevine,
          originalUrl: url,
        );

      case StreamPlatform.plutoTv:
        final result = await PlutoStreamService.resolve(url);
        return StreamResolution(
          url: result.hlsUrl,
          type: StreamType.hls,
          platform: platform,
          title: result.title,
          thumbnailUrl: result.thumbnailUrl,
          originalUrl: url,
        );

       // ── YouTube via Innertube (HLS nativo para lives, embed para VODs) ───
      case StreamPlatform.youtube:
      case StreamPlatform.youtubeLive:
        // Tentar Innertube primeiro (melhor para lives e Shorts)
        try {
          final result = await YouTubeStreamService.resolve(url);
          final isHls = result.hlsUrl.contains('.m3u8');
          return StreamResolution(
            url: result.hlsUrl,
            type: isHls ? StreamType.hls : StreamType.direct,
            platform: platform,
            title: result.title,
            thumbnailUrl: result.thumbnailUrl,
            originalUrl: url,
          );
        } catch (e) {
          // Fallback para embed se Innertube falhar (vídeos com restrição de idade, etc.)
          final embedUrl = _toEmbedUrl(url, platform);
          if (embedUrl != null) {
            return StreamResolution(
              url: embedUrl,
              type: StreamType.embed,
              platform: platform,
              originalUrl: url,
            );
          }
        }
        return StreamResolution(
          url: url,
          type: StreamType.direct,
          platform: platform,
          originalUrl: url,
        );

      // ── Embed iframe ──────────────────────────────────────────────────
      case StreamPlatform.kick:
      case StreamPlatform.vimeo:
      case StreamPlatform.dailymotion:
        final embedUrl = _toEmbedUrl(url, platform);
        if (embedUrl != null) {
          return StreamResolution(
            url: embedUrl,
            type: StreamType.embed,
            platform: platform,
            originalUrl: url,
          );
        }
        // Fallback: URL direta
        return StreamResolution(
          url: url,
          type: StreamType.direct,
          platform: platform,
          originalUrl: url,
        );

      // ── DRM (Rodada 3 — relay) ──────────────────────────────────────────
      case StreamPlatform.netflix:
      case StreamPlatform.disneyPlus:
      case StreamPlatform.amazonPrime:
      case StreamPlatform.hboMax:
      case StreamPlatform.crunchyroll:
        // Por enquanto, abre o site no WebView para login
        // A Rodada 3 implementará o relay completo
        return StreamResolution(
          url: url,
          type: StreamType.embed,
          platform: platform,
          requiresDrm: true,
          originalUrl: url,
        );

      // ── Google Drive (MP4 direto) ──────────────────────────────────────────
      case StreamPlatform.googleDrive:
        try {
          final result = await GoogleDriveStreamService.resolve(url);
          return StreamResolution(
            url: result.streamUrl,
            type: StreamType.direct,
            platform: platform,
            title: result.title,
            thumbnailUrl: result.thumbnailUrl,
            originalUrl: url,
          );
        } catch (_) {
          // Fallback: embed no WebView
          return StreamResolution(
            url: url,
            type: StreamType.embed,
            platform: platform,
            originalUrl: url,
          );
        }

      // ── Direto / Web ──────────────────────────────────────────────────
      case StreamPlatform.vk:
      case StreamPlatform.web:
      case StreamPlatform.unknown:
        // Verificar se é um .m3u8 direto
        if (url.contains('.m3u8')) {
          return StreamResolution(
            url: url,
            type: StreamType.hls,
            platform: platform,
            originalUrl: url,
          );
        }
        return StreamResolution(
          url: url,
          type: StreamType.direct,
          platform: platform,
          originalUrl: url,
        );
    }
  }
}
