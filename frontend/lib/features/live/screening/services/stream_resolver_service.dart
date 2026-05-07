// =============================================================================
// StreamResolverService — Orquestra todos os serviços de stream
//
// Detecta a plataforma pela URL e delega para o serviço correto.
// Retorna um StreamResolution com a URL HLS (ou embed) e metadados.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'twitch_stream_service.dart';
import 'tubi_stream_service.dart';
import 'pluto_stream_service.dart';
import 'youtube_stream_service.dart';
import 'google_drive_stream_service.dart';
import 'disney/disney_playback_service.dart';
import 'disney/disney_auth_service.dart';

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
  /// Vídeo local enviado pelo host para o Supabase Storage
  local,
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
    // Vídeo local enviado para o Supabase Storage
    if (u.contains('supabase.co/storage') && u.contains('screening-videos')) {
      return StreamPlatform.local;
    }
    return StreamPlatform.web;
  }

  // ── Constrói embed URL para plataformas que usam iframe ───────────────────
  static String? _toEmbedUrl(String url, StreamPlatform platform) {
    switch (platform) {
      case StreamPlatform.youtube:
      case StreamPlatform.youtubeLive:
        final id = _extractYouTubeId(url);
        if (id.isNotEmpty) {
          // origin= deve bater com o baseUrl do InAppWebView ('https://nexushub.app').
          // Não usar youtube.com como baseUrl pois causa erro 152-4 (embed bloqueado).
          // controls=0 oculta os controles nativos do YouTube (usamos os do Flutter).
          // iv_load_policy=3: desativa info cards e anotações (badges nativos ao pausar)
          // disablekb=1: desativa atalhos de teclado nativos do YouTube
          // controls=0: oculta a barra de progresso nativa
          // iv_load_policy=3: desativa info cards e anotações
          // disablekb=1: desativa atalhos de teclado
          // showinfo=0: oculta título e info do canal (legado, ainda funciona em alguns casos)
          // fs=0: desativa botão de fullscreen nativo
          // cc_load_policy=0: desativa legendas automáticas
          // hl=pt: idioma português (reduz elementos de UI em inglês)
          // color=white: barra de progresso branca (menos visível)
          return 'https://www.youtube.com/embed/$id'
              '?autoplay=1&mute=0&rel=0&modestbranding=1'
              '&playsinline=1&enablejsapi=1&controls=0'
              '&iv_load_policy=3&disablekb=1&showinfo=0'
              '&fs=0&cc_load_policy=0&hl=pt&color=white'
              '&origin=https://nexushub.app';
        }
        return null;

      case StreamPlatform.twitch:
        // Twitch embed: player.twitch.tv com parent=nexushub.app
        // O HLS direto via GQL falha por autenticação (token expirado/inválido).
        // O embed oficial é o método mais confiável e não requer auth adicional.
        final twitchMatch = RegExp(r'twitch\.tv/(?:videos/)?(\d+|[a-zA-Z0-9_]+)').firstMatch(url);
        final twitchId = twitchMatch?.group(1) ?? '';
        if (twitchId.isNotEmpty) {
          // VOD: twitch.tv/videos/123456789
          if (url.contains('/videos/')) {
            return 'https://player.twitch.tv/?video=$twitchId'
                '&parent=nexushub.app&parent=localhost'
                '&autoplay=true&muted=true&controls=false';
          }
          // Canal ao vivo: twitch.tv/channelname
          return 'https://player.twitch.tv/?channel=$twitchId'
              '&parent=nexushub.app&parent=localhost'
              '&autoplay=true&muted=true&controls=false';
        }
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
      // ── Twitch: HLS nativo otimizado com fallback para embed ─────────────
      case StreamPlatform.twitch:
        // Priorizar HLS direto no media_kit. O embed oficial da Twitch dentro de
        // WebView é pesado em aparelhos menos potentes, disputa GPU/thread com a
        // UI Flutter e derruba FPS quando chat/controles ficam ativos. O player
        // nativo reduz composição, elimina DOM/JS contínuo e mantém o embed como
        // fallback quando a Twitch negar token, o canal estiver offline ou for uma
        // URL que o resolver HLS não consiga tratar.
        try {
          final result = await TwitchStreamService.resolve(url);
          return StreamResolution(
            url: result.hlsUrl,
            type: StreamType.hls,
            platform: platform,
            title: result.title,
            thumbnailUrl: result.thumbnailUrl,
            originalUrl: url,
          );
        } catch (_) {
          final twitchEmbedUrl = _toEmbedUrl(url, platform);
          return StreamResolution(
            url: twitchEmbedUrl ?? url,
            type: twitchEmbedUrl != null ? StreamType.embed : StreamType.direct,
            platform: platform,
            originalUrl: url,
          );
        }

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

       // ── YouTube VOD: Innertube (HLS/MP4 direto) primeiro, embed como fallback ─
      case StreamPlatform.youtube:
        // Priorizar stream direto via Innertube — igual ao padrão Twitch/Kick.
        // O player nativo (media_kit) é mais confiável que o WebView+IFrame API:
        // não tem race condition de bridge JS, controles Flutter funcionam
        // imediatamente, seek/play/pause são síncronos e sem polling.
        // Fallback para embed se o Innertube bloquear (IP, região, DRM).
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
          debugPrint('[StreamResolver] YouTube Innertube falhou, usando embed: $e');
        }
        // Fallback: embed IFrame API
        final embedUrl = _toEmbedUrl(url, platform);
        if (embedUrl != null) {
          return StreamResolution(
            url: embedUrl,
            type: StreamType.embed,
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

      case StreamPlatform.youtubeLive:
        // Lives: tentar Innertube primeiro (melhor qualidade para HLS ao vivo)
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
          // Fallback para embed se Innertube falhar
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

      // ── Disney+ — API BAMGrid nativa com DRM Widevine ──────────────────
      case StreamPlatform.disneyPlus:
        try {
          // Tentar resolver via DisneyPlaybackService (API BAMGrid direta)
          // Requer que o usuário tenha feito login via DisneyBrowserSheet
          final disneyStream = await DisneyPlaybackService.resolveFromUrl(url);
          return StreamResolution(
            url: disneyStream.manifestUrl,
            type: StreamType.hls,
            platform: platform,
            title: disneyStream.title,
            thumbnailUrl: disneyStream.thumbnailUrl,
            requiresDrm: disneyStream.licenseUrl != null,
            licenseUrl: disneyStream.licenseUrl,
            pssh: disneyStream.pssh,
            headers: disneyStream.headers,
            originalUrl: url,
          );
        } on DisneyAuthException {
          // Usuário não autenticado — abrir WebView de login
          return StreamResolution(
            url: 'https://www.disneyplus.com/login',
            type: StreamType.embed,
            platform: platform,
            requiresDrm: true,
            originalUrl: url,
          );
        } catch (_) {
          // Fallback genérico — abrir site no WebView
          return StreamResolution(
            url: url,
            type: StreamType.embed,
            platform: platform,
            requiresDrm: true,
            originalUrl: url,
          );
        }
      // ── DRM (outras plataformas — relay futuro) ─────────────────────────
      case StreamPlatform.netflix:
      case StreamPlatform.amazonPrime:
      case StreamPlatform.hboMax:
      case StreamPlatform.crunchyroll:
        // Abre o site no WebView para login
        // Relay completo a ser implementado por plataforma
        return StreamResolution(
          url: url,
          type: StreamType.embed,
          platform: platform,
          requiresDrm: true,
          originalUrl: url,
        );

      // ── Google Drive (preview autenticado em WebView) ─────────────────────
      case StreamPlatform.googleDrive:
        try {
          final result = await GoogleDriveStreamService.resolve(url);
          return StreamResolution(
            url: result.streamUrl,
            type: StreamType.embed,
            platform: platform,
            title: result.title,
            thumbnailUrl: result.thumbnailUrl,
            originalUrl: url,
          );
        } catch (_) {
          // Fallback: manter a URL original em WebView para preservar login/cookies.
          return StreamResolution(
            url: url,
            type: StreamType.embed,
            platform: platform,
            originalUrl: url,
          );
        }

      // ── Vídeo local (Supabase Storage) ───────────────────────────────────────
      case StreamPlatform.local:
        // URL pública do Supabase Storage — reproduzir diretamente com media_kit
        return StreamResolution(
          url: url,
          type: StreamType.direct,
          platform: platform,
          originalUrl: url,
        );

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
