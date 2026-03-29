import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';

/// Widget para exibir embeds de SoundCloud e Bandcamp nos posts.
///
/// Detecta automaticamente o tipo de link e exibe um player visual
/// com artwork, título e botão de play que abre no app/browser externo.
class MusicEmbedWidget extends StatelessWidget {
  final String url;
  final String? title;
  final String? artist;
  final String? artworkUrl;

  const MusicEmbedWidget({
    super.key,
    required this.url,
    this.title,
    this.artist,
    this.artworkUrl,
  });

  /// Detecta se é SoundCloud, Bandcamp ou outro serviço.
  MusicPlatform get platform {
    final lower = url.toLowerCase();
    if (lower.contains('soundcloud.com')) return MusicPlatform.soundcloud;
    if (lower.contains('bandcamp.com')) return MusicPlatform.bandcamp;
    if (lower.contains('spotify.com')) return MusicPlatform.spotify;
    if (lower.contains('music.apple.com')) return MusicPlatform.appleMusic;
    return MusicPlatform.unknown;
  }

  Color get _platformColor {
    switch (platform) {
      case MusicPlatform.soundcloud:
        return const Color(0xFFFF5500);
      case MusicPlatform.bandcamp:
        return const Color(0xFF1DA0C3);
      case MusicPlatform.spotify:
        return const Color(0xFF1DB954);
      case MusicPlatform.appleMusic:
        return const Color(0xFFFA243C);
      case MusicPlatform.unknown:
        return AppTheme.primaryColor;
    }
  }

  IconData get _platformIcon {
    switch (platform) {
      case MusicPlatform.soundcloud:
        return Icons.cloud_rounded;
      case MusicPlatform.bandcamp:
        return Icons.album_rounded;
      case MusicPlatform.spotify:
        return Icons.music_note_rounded;
      case MusicPlatform.appleMusic:
        return Icons.apple;
      case MusicPlatform.unknown:
        return Icons.music_note_rounded;
    }
  }

  String get _platformName {
    switch (platform) {
      case MusicPlatform.soundcloud:
        return 'SoundCloud';
      case MusicPlatform.bandcamp:
        return 'Bandcamp';
      case MusicPlatform.spotify:
        return 'Spotify';
      case MusicPlatform.appleMusic:
        return 'Apple Music';
      case MusicPlatform.unknown:
        return 'Music';
    }
  }

  Future<void> _openUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _openUrl,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: r.s(8)),
        decoration: BoxDecoration(
          color: isDark ? context.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(r.s(14)),
          border: Border.all(
            color: _platformColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _platformColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork / Header
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: Stack(
                children: [
                  // Artwork ou gradient placeholder
                  if (artworkUrl != null)
                    Image.network(
                      artworkUrl!,
                      width: double.infinity,
                      height: r.s(160),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _ArtworkPlaceholder(color: _platformColor),
                    )
                  else
                    _ArtworkPlaceholder(color: _platformColor),

                  // Overlay gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Play button
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: r.s(56),
                        height: r.s(56),
                        decoration: BoxDecoration(
                          color: _platformColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _platformColor.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: r.s(32)),
                      ),
                    ),
                  ),

                  // Platform badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(10), vertical: r.s(4)),
                      decoration: BoxDecoration(
                        color: _platformColor,
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_platformIcon, color: Colors.white, size: r.s(14)),
                          SizedBox(width: r.s(4)),
                          Text(
                            _platformName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(11),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: EdgeInsets.all(r.s(12)),
              child: Row(
                children: [
                  // Waveform visual (decorativo)
                  _MiniWaveform(color: _platformColor),
                  SizedBox(width: r.s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? 'Abrir no $_platformName',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(14),
                            color: isDark
                                ? context.textPrimary
                                : context.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artist != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            artist!,
                            style: TextStyle(
                              fontSize: r.fs(12),
                              color: isDark
                                  ? context.textSecondary
                                  : context.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded,
                      color: _platformColor, size: r.s(18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder visual para quando não há artwork.
class _ArtworkPlaceholder extends StatelessWidget {
  final Color color;
  const _ArtworkPlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      height: r.s(160),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note_rounded,
            color: color.withValues(alpha: 0.5), size: r.s(64)),
      ),
    );
  }
}

/// Mini waveform decorativo para o player.
class _MiniWaveform extends StatelessWidget {
  final Color color;
  const _MiniWaveform({required this.color});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return SizedBox(
      width: r.s(32),
      height: r.s(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _WaveBar(height: r.s(8), color: color),
          _WaveBar(height: r.s(18), color: color),
          _WaveBar(height: r.s(12), color: color),
          _WaveBar(height: r.s(22), color: color),
          _WaveBar(height: r.s(6), color: color),
        ],
      ),
    );
  }
}

class _WaveBar extends StatelessWidget {
  final double height;
  final Color color;
  const _WaveBar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: r.s(3),
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Enum para plataformas de música suportadas.
enum MusicPlatform {
  soundcloud,
  bandcamp,
  spotify,
  appleMusic,
  unknown,
}

/// Helper para detectar se uma URL é de música.
bool isMusicUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('soundcloud.com') ||
      lower.contains('bandcamp.com') ||
      lower.contains('spotify.com') ||
      lower.contains('music.apple.com');
}
