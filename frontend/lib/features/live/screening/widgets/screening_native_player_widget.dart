// =============================================================================
// ScreeningNativePlayerWidget — Player nativo HLS via media_kit
//
// Usado para plataformas com HLS direto: Twitch, Tubi, Pluto TV, .m3u8 direto.
// Suporta sincronização de play/pause/seek via ScreeningPlayerProvider.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/screening_player_provider.dart';
import '../services/stream_resolver_service.dart';

class ScreeningNativePlayerWidget extends ConsumerStatefulWidget {
  final String hlsUrl;
  final String sessionId;
  final String threadId;
  final StreamPlatform platform;

  const ScreeningNativePlayerWidget({
    super.key,
    required this.hlsUrl,
    required this.sessionId,
    required this.threadId,
    required this.platform,
  });

  @override
  ConsumerState<ScreeningNativePlayerWidget> createState() =>
      _ScreeningNativePlayerWidgetState();
}

class _ScreeningNativePlayerWidgetState
    extends ConsumerState<ScreeningNativePlayerWidget> {
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Configurar headers para Twitch (necessário para o HLS)
    await _player.open(
      Media(
        widget.hlsUrl,
        httpHeaders: _headersForPlatform(widget.platform),
      ),
    );

    // Registrar callbacks de sincronização
    _player.stream.playing.listen((playing) {
      if (!mounted) return;
      final notifier =
          ref.read(screeningPlayerProvider(widget.sessionId).notifier);
      if (playing) {
        notifier.onNativePlay();
      } else {
        notifier.onNativePause();
      }
    });

    _player.stream.position.listen((position) {
      if (!mounted) return;
      ref
          .read(screeningPlayerProvider(widget.sessionId).notifier)
          .onNativePositionUpdate(position.inMilliseconds / 1000.0);
    });

    _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      ref
          .read(screeningPlayerProvider(widget.sessionId).notifier)
          .onNativeBuffering(buffering);
    });

    if (mounted) {
      setState(() => _initialized = true);
      ref
          .read(screeningPlayerProvider(widget.sessionId).notifier)
          .registerNativePlayer(_player);
    }
  }

  Map<String, String> _headersForPlatform(StreamPlatform platform) {
    switch (platform) {
      case StreamPlatform.twitch:
        return {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://www.twitch.tv/',
          'Origin': 'https://www.twitch.tv',
        };
      case StreamPlatform.tubi:
        return {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://tubitv.com/',
          'Origin': 'https://tubitv.com',
        };
      case StreamPlatform.plutoTv:
        return {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://pluto.tv/',
          'Origin': 'https://pluto.tv',
        };
      default:
        return {};
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    return Video(
      controller: _controller,
      controls: NoVideoControls, // Controles gerenciados pelo ScreeningPlayerWidget
      fill: Colors.black,
    );
  }
}
