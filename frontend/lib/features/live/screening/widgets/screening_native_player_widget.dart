// =============================================================================
// ScreeningNativePlayerWidget — Player nativo HLS + DRM Widevine
//
// Arquitetura híbrida:
//   • Sem DRM (Twitch, Tubi, Pluto TV, YouTube, Google Drive):
//       usa media_kit — leve, eficiente, sem overhead
//
//   • Com DRM Widevine (Netflix, Disney+, Amazon, HBO Max, Crunchyroll):
//       usa better_player_plus — ExoPlayer nativo com suporte Widevine L1/L3
//
// O widget recebe um StreamResolution completo e decide internamente qual
// engine usar com base em resolution.requiresDrm.
// =============================================================================

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
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

  /// StreamResolution completo — se fornecido, tem prioridade sobre hlsUrl/platform.
  /// Necessário para DRM (contém licenseUrl, pssh, headers).
  final StreamResolution? resolution;

  /// Chamado quando o player nativo falha repetidamente (ex: DNS não resolve,
  /// HLS URL inválida). O widget pai deve usar isso para fazer fallback para embed.
  final VoidCallback? onNativeError;

  const ScreeningNativePlayerWidget({
    super.key,
    required this.hlsUrl,
    required this.sessionId,
    required this.threadId,
    required this.platform,
    this.resolution,
    this.onNativeError,
  });

  @override
  ConsumerState<ScreeningNativePlayerWidget> createState() =>
      _ScreeningNativePlayerWidgetState();
}

class _ScreeningNativePlayerWidgetState
    extends ConsumerState<ScreeningNativePlayerWidget> {
  // ── media_kit (sem DRM) ────────────────────────────────────────────────────
  Player? _mkPlayer;
  VideoController? _mkController;

  // ── better_player_plus (com DRM) ──────────────────────────────────────────
  BetterPlayerController? _bpController;

  bool _initialized = false;
  int _errorCount = 0;
  bool get _usesDrm =>
      widget.resolution?.requiresDrm == true &&
      widget.resolution?.licenseUrl != null;

  @override
  void initState() {
    super.initState();
    if (_usesDrm) {
      _initDrmPlayer();
    } else {
      _initMediaKitPlayer();
    }
  }

  // ── Inicialização media_kit (sem DRM) ──────────────────────────────────────
  Future<void> _initMediaKitPlayer() async {
    _mkPlayer = Player();
    _mkController = VideoController(_mkPlayer!);

    // Callbacks de sincronização com o ScreeningPlayerProvider.
    // Registrados ANTES do open() para não perder eventos emitidos durante a abertura.
    _mkPlayer!.stream.playing.listen((playing) {
      if (!mounted) return;
      debugPrint('[NativePlayer] stream.playing=$playing');
      final notifier =
          ref.read(screeningPlayerProvider(widget.sessionId).notifier);
      if (playing) {
        notifier.onNativePlay();
      } else {
        notifier.onNativePause();
      }
    });

    _mkPlayer!.stream.duration.listen((duration) {
      if (!mounted || duration == Duration.zero) return;
      debugPrint('[NativePlayer] stream.duration=${duration.inMilliseconds}ms');
      ref
          .read(screeningPlayerProvider(widget.sessionId).notifier)
          .onNativeDurationUpdate(duration.inMilliseconds);
    });

    _mkPlayer!.stream.position.listen((position) {
      if (!mounted) return;
      ref
          .read(screeningPlayerProvider(widget.sessionId).notifier)
          .onNativePositionUpdate(position.inMilliseconds / 1000.0);
    });

    _mkPlayer!.stream.buffering.listen((buffering) {
      if (!mounted) return;
      debugPrint('[NativePlayer] stream.buffering=$buffering');
      ref
          .read(screeningPlayerProvider(widget.sessionId).notifier)
          .onNativeBuffering(buffering);
    });

    _mkPlayer!.stream.error.listen((error) {
      debugPrint('[NativePlayer] stream.error=$error');
      _errorCount++;
      // Após 2 erros consecutivos, acionar o fallback para embed.
      // Um único erro pode ser transitório (ex: perda de pacote), mas 2 erros
      // indicam falha real (DNS não resolve, URL inválida, bloqueio de rede).
      if (_errorCount >= 2 && mounted) {
        debugPrint('[NativePlayer] ≥2 erros — acionando fallback para embed');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onNativeError?.call();
        });
      }
    });

    // IMPORTANTE: registerNativePlayer() modifica o provider (state=).
    // Não pode ser chamado durante o ciclo de build (initState é chamado
    // durante StatefulElement._firstBuild). Usar addPostFrameCallback garante
    // que a modificação ocorre após o build, evitando o erro Riverpod:
    // "Tried to modify a provider while the widget tree was building".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(screeningPlayerProvider(widget.sessionId).notifier)
          .registerNativePlayer(_mkPlayer!);
      debugPrint('[NativePlayer] registerNativePlayer chamado (post-frame) sessionId=${widget.sessionId}');
    });

    await _mkPlayer!.open(
      Media(
        widget.hlsUrl,
        httpHeaders: widget.resolution?.headers ??
            _headersForPlatform(widget.platform),
      ),
    );
    debugPrint('[NativePlayer] open() concluído — url=${widget.hlsUrl}');

    // Sincronizar isPlaying com o estado real do player após o open().
    // O stream.playing pode ter emitido antes do registerNativePlayer,
    // então verificamos o estado atual e atualizamos o provider via
    // addPostFrameCallback para garantir que o provider já foi registrado.
    if (mounted) {
      final isPlaying = _mkPlayer!.state.playing;
      final duration = _mkPlayer!.state.duration;
      debugPrint('[NativePlayer] estado após open(): isPlaying=$isPlaying, duration=${duration.inMilliseconds}ms');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(screeningPlayerProvider(widget.sessionId).notifier);
        if (isPlaying) notifier.onNativePlay();
        if (duration > Duration.zero) notifier.onNativeDurationUpdate(duration.inMilliseconds);
      });
      setState(() => _initialized = true);
    }
  }

  // ── Inicialização better_player_plus (DRM Widevine) ───────────────────────
  Future<void> _initDrmPlayer() async {
    final res = widget.resolution!;

    // Configuração DRM Widevine
    final drmConfig = BetterPlayerDrmConfiguration(
      drmType: BetterPlayerDrmType.widevine,
      licenseUrl: res.licenseUrl,
      headers: res.headers,
    );

    // Configuração da fonte de dados
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      res.url,
      videoFormat: BetterPlayerVideoFormat.hls,
      drmConfiguration: drmConfig,
      headers: res.headers,
      notificationConfiguration: const BetterPlayerNotificationConfiguration(
        showNotification: false,
      ),
    );

    // Configuração do controller
    _bpController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false, // Controles gerenciados pelo ScreeningPlayerWidget
        ),
        eventListener: _onBetterPlayerEvent,
      ),
    );

    await _bpController!.setupDataSource(dataSource);

    if (mounted) {
      setState(() => _initialized = true);
      // Registrar callbacks no provider via wrapper
      ref
          .read(screeningPlayerProvider(widget.sessionId).notifier)
          .registerDrmPlayer(_bpController!);
    }
  }

  void _onBetterPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    final notifier =
        ref.read(screeningPlayerProvider(widget.sessionId).notifier);

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.play:
        notifier.onNativePlay();
        break;
      case BetterPlayerEventType.pause:
        notifier.onNativePause();
        break;
      case BetterPlayerEventType.progress:
        final position = event.parameters?['progress'] as Duration?;
        if (position != null) {
          notifier.onNativePositionUpdate(position.inMilliseconds / 1000.0);
        }
        break;
      case BetterPlayerEventType.bufferingStart:
        notifier.onNativeBuffering(true);
        break;
      case BetterPlayerEventType.bufferingEnd:
        notifier.onNativeBuffering(false);
        break;
      default:
        break;
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
    _mkPlayer?.dispose();
    _bpController?.dispose();
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

    // ── Player DRM (better_player_plus) ──────────────────────────────────────
    if (_usesDrm && _bpController != null) {
      return BetterPlayer(controller: _bpController!);
    }

    // ── Player HLS direto (media_kit) ─────────────────────────────────────────
    if (_mkController != null) {
      return Video(
        controller: _mkController!,
        controls: NoVideoControls, // Controles gerenciados pelo ScreeningPlayerWidget
        fill: Colors.black,
      );
    }

    return const SizedBox.shrink();
  }
}
