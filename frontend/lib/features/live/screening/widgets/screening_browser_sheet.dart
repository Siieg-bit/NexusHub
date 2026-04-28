import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import '../services/drm_relay_service.dart';
import '../services/stream_resolver_service.dart';
import '../services/youtube_stream_service.dart';
import '../services/twitch_stream_service.dart';
import '../services/vimeo_meta_service.dart';
import '../services/kick_meta_service.dart';
import '../services/og_tags_meta_service.dart';
import '../services/google_drive_stream_service.dart';
import '../services/pluto_stream_service.dart';

// =============================================================================
// ScreeningBrowserSheet — Navegador integrado tematizado para seleção de vídeo
//
// Abre como página cheia (fullscreenDialog) via Navigator.push.
// Funcionalidades:
// - Barra de endereço editável com navegação por URL ou busca Google
// - Botões: fechar, voltar, avançar, copiar URL, recarregar/parar
// - Barra de progresso de carregamento animada (cor da plataforma)
// - Detecção automática de URL de vídeo com banner de confirmação
// - Overlay de captura com feedback visual e haptic
// - Suporte a todas as plataformas: YouTube, Twitch, Kick, Vimeo,
//   Google Drive, e URL direta (WEB)
// =============================================================================

// ── Modelo de plataforma ──────────────────────────────────────────────────────

class ScreeningPlatform {
  final String id;
  final String displayName;
  final String? initialUrl;
  final List<_VideoUrlPattern> videoPatterns;
  final bool isDirectUrl;
  final bool isDrm;
  const ScreeningPlatform({
    required this.id,
    required this.displayName,
    this.initialUrl,
    this.videoPatterns = const [],
    this.isDirectUrl = false,
    this.isDrm = false,
  });
}

class _VideoUrlPattern {
  final RegExp pattern;
  const _VideoUrlPattern(this.pattern);
}

// ── Plataformas suportadas ────────────────────────────────────────────────────

final _kPlatforms = <String, ScreeningPlatform>{
  'youtube': ScreeningPlatform(
    id: 'youtube',
    displayName: 'YouTube',
    initialUrl: 'https://www.youtube.com',
    videoPatterns: [
      _VideoUrlPattern(RegExp(r'youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})')),
      _VideoUrlPattern(RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})')),
      _VideoUrlPattern(RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})')),
    ],
  ),
  'youtube_live': ScreeningPlatform(
    id: 'youtube_live',
    displayName: 'YouTube Live',
    initialUrl: 'https://www.youtube.com/live',
    videoPatterns: [
      _VideoUrlPattern(RegExp(r'youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})')),
      _VideoUrlPattern(RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})')),
      _VideoUrlPattern(RegExp(r'youtube\.com/@[^/]+/live')),
    ],
  ),
  'twitch': ScreeningPlatform(
    id: 'twitch',
    displayName: 'Twitch',
    initialUrl: 'https://www.twitch.tv',
    videoPatterns: [
      _VideoUrlPattern(RegExp(r'twitch\.tv/videos/\d+')),
      _VideoUrlPattern(RegExp(r'twitch\.tv/[a-zA-Z0-9_]+$')),
      _VideoUrlPattern(RegExp(r'twitch\.tv/[a-zA-Z0-9_]+\?')),
    ],
  ),
  'kick': ScreeningPlatform(
    id: 'kick',
    displayName: 'Kick',
    initialUrl: 'https://kick.com',
    videoPatterns: [
      _VideoUrlPattern(RegExp(r'kick\.com/video/[a-zA-Z0-9_-]+')),
      _VideoUrlPattern(RegExp(r'kick\.com/[a-zA-Z0-9_-]+$')),
    ],
  ),
  'vimeo': ScreeningPlatform(
    id: 'vimeo',
    displayName: 'Vimeo',
    initialUrl: 'https://vimeo.com',
    videoPatterns: [
      _VideoUrlPattern(RegExp(r'vimeo\.com/\d+')),
    ],
  ),
  'drive': ScreeningPlatform(
    id: 'drive',
    displayName: 'Google Drive',
    initialUrl: 'https://drive.google.com',
    videoPatterns: [
      _VideoUrlPattern(RegExp(r'drive\.google\.com/file/d/[a-zA-Z0-9_-]+')),
    ],
  ),
  'web': ScreeningPlatform(
    id: 'web',
    displayName: 'URL Direta',
    isDirectUrl: true,
  ),
};

// ── Widget principal ──────────────────────────────────────────────────────────

class ScreeningBrowserSheet extends ConsumerStatefulWidget {
  final String platformId;
  final String sessionId;
  final String threadId;
  final bool addToQueue;
  /// Quando true, renderiza como Scaffold (página cheia) em vez de Container
  /// com altura fixa. Usar ao abrir via Navigator.push para que o scroll
  /// nativo dos sites funcione corretamente.
  final bool fullscreen;

  const ScreeningBrowserSheet({
    super.key,
    required this.platformId,
    required this.sessionId,
    required this.threadId,
    this.addToQueue = false,
    this.fullscreen = false,
  });

  @override
  ConsumerState<ScreeningBrowserSheet> createState() =>
      _ScreeningBrowserSheetState();
}

class _ScreeningBrowserSheetState
    extends ConsumerState<ScreeningBrowserSheet>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _webViewController;
  final _urlBarController = TextEditingController();
  final _directUrlController = TextEditingController();
  final _urlFocusNode = FocusNode();

  bool _isLoading = false;
  double _loadingProgress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  bool _isCapturing = false;
  bool _urlBarEditing = false;
  bool _isVideoDetected = false;
  String _detectedVideoUrl = '';

  late final ScreeningPlatform _platform;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // Cor de destaque por plataforma
  static const _platformColors = <String, Color>{
    'youtube': Color(0xFFFF0000),
    'youtube_live': Color(0xFFFF0000),
    'twitch': Color(0xFF9146FF),
    'kick': Color(0xFF53FC18),
    'vimeo': Color(0xFF1AB7EA),
    'drive': Color(0xFF4285F4),
    'web': Color(0xFF6C63FF),
  };

  Color get _accentColor =>
      _platformColors[_platform.id] ?? const Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _platform = _kPlatforms[widget.platformId] ?? _kPlatforms['web']!;
    if (_platform.initialUrl != null) {
      _currentUrl = _platform.initialUrl!;
      _urlBarController.text = _platform.initialUrl!;
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 0.96), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _urlFocusNode.addListener(() {
      if (!_urlFocusNode.hasFocus && _urlBarEditing) {
        setState(() => _urlBarEditing = false);
      }
    });
  }

  @override
  void dispose() {
    _urlBarController.dispose();
    _directUrlController.dispose();
    _urlFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Detecção de URL de vídeo ──────────────────────────────────────────────

  bool _isVideoUrl(String url) {
    for (final p in _platform.videoPatterns) {
      if (p.pattern.hasMatch(url)) return true;
    }
    return false;
  }

  void _markVideoDetected(String url) {
    if (_isCapturing || (_isVideoDetected && _detectedVideoUrl == url)) return;
    setState(() {
      _isVideoDetected = true;
      _detectedVideoUrl = url;
    });
    _pulseController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  // ── Captura e envio do vídeo ──────────────────────────────────────────────

  Future<void> _captureUrl(String url) async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();

    try {
      String finalUrl = url;
      if (_platform.isDrm && _webViewController != null) {
        final platform = StreamResolverService.detectPlatform(url);
        StreamResolution? resolution;
        try {
          switch (platform) {
            case StreamPlatform.netflix:
              resolution = await DrmRelayService.resolveNetflix(url, _webViewController!);
              break;
            case StreamPlatform.disneyPlus:
              resolution = await DrmRelayService.resolveDisney(url, _webViewController!);
              break;
            case StreamPlatform.amazonPrime:
              resolution = await DrmRelayService.resolveAmazon(url, _webViewController!);
              break;
            case StreamPlatform.hboMax:
              resolution = await DrmRelayService.resolveHbo(url, _webViewController!);
              break;
            case StreamPlatform.crunchyroll:
              resolution = await DrmRelayService.resolveCrunchyroll(url, _webViewController!);
              break;
            default:
              break;
          }
          if (resolution != null) finalUrl = resolution.url;
        } catch (e) {
          debugPrint('[ScreeningBrowserSheet] Relay DRM falhou: $e');
          if (mounted) {
            _showError('Erro ao conectar ao serviço: $e');
            setState(() { _isCapturing = false; _isVideoDetected = false; });
          }
          return;
        }
      }

      // Resolver metadados reais (título + thumbnail) antes de enfileirar.
      // Cada plataforma usa seu serviço dedicado; OG tags como fallback universal.
      // Em caso de falha, continua com o título genérico — não bloqueia.
      String title = _inferTitle(url);
      String? thumbnail;
      try {
        final meta = await _resolveMetadata(url);
        if (meta != null) {
          if (meta.title.isNotEmpty) title = meta.title;
          thumbnail = meta.thumbnailUrl;
        }
      } catch (e) {
        debugPrint('[ScreeningBrowserSheet] Metadados não resolvidos: $e');
      }
      final notifier = ref.read(screeningRoomProvider(widget.threadId).notifier);
      if (widget.addToQueue) {
        await notifier.addToQueue(url: finalUrl, title: title, thumbnail: thumbnail);
        if (mounted) { HapticFeedback.lightImpact(); Navigator.of(context).pop(); }
      } else {
        await notifier.updateVideo(videoUrl: finalUrl, videoTitle: title);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() { _isCapturing = false; _isVideoDetected = false; });
      rethrow;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: const Color(0xFFB00020),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Resolução de metadados por plataforma ─────────────────────────────────

  /// Resolve título e thumbnail reais para qualquer plataforma.
  /// Retorna null se não for possível resolver (a chamada deve usar o fallback).
  Future<({String title, String? thumbnailUrl})?> _resolveMetadata(String url) async {
    final u = url.toLowerCase();

    // ── YouTube / YouTube Live ────────────────────────────────────────────────────────
    if (u.contains('youtube') || u.contains('youtu.be')) {
      final meta = await YouTubeStreamService.resolve(url);
      return (title: meta.title, thumbnailUrl: meta.thumbnailUrl);
    }

    // ── Twitch ─────────────────────────────────────────────────────────────────────────
    if (u.contains('twitch.tv')) {
      final meta = await TwitchStreamService.resolveMetaOnly(url);
      return (title: meta.title, thumbnailUrl: meta.thumbnailUrl);
    }

    // ── Kick ────────────────────────────────────────────────────────────────────────────
    if (u.contains('kick.com')) {
      final meta = await KickMetaService.resolve(url);
      return (title: meta.title, thumbnailUrl: meta.thumbnailUrl);
    }

    // ── Vimeo ──────────────────────────────────────────────────────────────────────────
    if (u.contains('vimeo.com')) {
      final meta = await VimeoMetaService.resolve(url);
      return (title: meta.title, thumbnailUrl: meta.thumbnailUrl);
    }

    // ── Google Drive ────────────────────────────────────────────────────────────────
    if (u.contains('drive.google.com')) {
      final meta = await GoogleDriveStreamService.resolve(url);
      return (title: meta.title, thumbnailUrl: meta.thumbnailUrl);
    }

    // ── Pluto TV ───────────────────────────────────────────────────────────────────
    if (u.contains('pluto.tv')) {
      final meta = await PlutoStreamService.resolve(url);
      return (title: meta.title, thumbnailUrl: meta.thumbnailUrl);
    }

    // ── Plataformas DRM + WEB genérico: OG tags via WebView (já carregado) ────────
    // Netflix, Disney+, Prime Video, Max, Crunchyroll e qualquer URL direta.
    // O WebView já está aberto na página correta, então lemos as OG tags via JS.
    if (_webViewController != null) {
      final meta = await OgTagsMetaService.resolveFromWebView(_webViewController!);
      if (meta != null) {
        return (title: meta.title, thumbnailUrl: meta.thumbnailUrl);
      }
    }
    // Fallback HTTP para OG tags (ex: URL direta sem WebView)
    final httpMeta = await OgTagsMetaService.resolveFromHttp(url);
    if (httpMeta != null) {
      return (title: httpMeta.title, thumbnailUrl: httpMeta.thumbnailUrl);
    }

    return null;
  }

  /// Título genérico de fallback (usado quando a resolução de metadados falha).
  String _inferTitle(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube')) return 'YouTube';
    if (u.contains('twitch')) return 'Twitch';
    if (u.contains('kick')) return 'Kick';
    if (u.contains('vimeo')) return 'Vimeo';
    if (u.contains('drive.google')) return 'Google Drive';
    if (u.contains('netflix')) return 'Netflix';
    if (u.contains('disneyplus')) return 'Disney+';
    if (u.contains('primevideo') || u.contains('amazon')) return 'Prime Video';
    if (u.contains('max.com') || u.contains('hbomax')) return 'Max';
    if (u.contains('crunchyroll')) return 'Crunchyroll';
    return _platform.displayName;
  }

  // ── Submissão de URL direta ───────────────────────────────────────────────

  Future<void> _submitDirectUrl() async {
    final input = _directUrlController.text.trim();
    if (input.isEmpty) return;
    String url = input;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    await _captureUrl(url);
  }

  // ── Navegação pela barra de endereço ─────────────────────────────────────

  void _onUrlBarTap() {
    setState(() {
      _urlBarEditing = true;
      _urlBarController.text = _currentUrl;
      _urlBarController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _urlBarController.text.length,
      );
    });
    _urlFocusNode.requestFocus();
  }

  void _onUrlBarSubmit(String value) {
    _urlFocusNode.unfocus();
    setState(() => _urlBarEditing = false);
    String url = value.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _copyUrl() {
    if (_currentUrl.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _currentUrl));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('URL copiada'),
      backgroundColor: const Color(0xFF1E1E2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _updateUrlBar(String url) {
    if (!_urlBarEditing) {
      setState(() {
        _currentUrl = url;
        _urlBarController.text = url;
      });
    } else {
      setState(() => _currentUrl = url);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    if (widget.fullscreen) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Column(children: [
            _buildTopBar(),
            if (!_platform.isDirectUrl) _buildHint(),
            Expanded(child: _buildContent()),
          ]),
        ),
      );
    }

    // Modo bottom sheet (legado)
    return Container(
      height: mq.size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildTopBar(),
        if (!_platform.isDirectUrl) _buildHint(),
        Expanded(child: _buildContent()),
      ]),
    );
  }

  // ── TopBar tematizado ─────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF0A0A0F),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Fechar
              _NavBtn(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop(), tooltip: 'Fechar'),
              const SizedBox(width: 2),
              // Voltar
              _NavBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _canGoBack ? () => _webViewController?.goBack() : null,
                tooltip: 'Voltar',
              ),
              // Avançar
              _NavBtn(
                icon: Icons.arrow_forward_ios_rounded,
                onTap: _canGoForward ? () => _webViewController?.goForward() : null,
                tooltip: 'Avançar',
              ),
              const SizedBox(width: 4),
              // Barra de endereço
              Expanded(child: _buildUrlBar()),
              const SizedBox(width: 4),
              // Copiar URL
              _NavBtn(icon: Icons.copy_rounded, onTap: _currentUrl.isNotEmpty ? _copyUrl : null, tooltip: 'Copiar URL'),
              // Recarregar / parar
              _NavBtn(
                icon: _isLoading ? Icons.close_rounded : Icons.refresh_rounded,
                onTap: _isLoading ? () => _webViewController?.stopLoading() : () => _webViewController?.reload(),
                tooltip: _isLoading ? 'Parar' : 'Recarregar',
                color: _isLoading ? _accentColor.withValues(alpha: 0.8) : null,
              ),
            ],
          ),
          // Barra de progresso
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _isLoading ? 2.5 : 0.0,
            margin: const EdgeInsets.only(top: 4),
            child: _isLoading
                ? LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                    minHeight: 2.5,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildUrlBar() {
    return GestureDetector(
      onTap: _urlBarEditing ? null : _onUrlBarTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        decoration: BoxDecoration(
          color: _urlBarEditing ? const Color(0xFF16162A) : const Color(0xFF111120),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _urlBarEditing
                ? _accentColor.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.09),
            width: _urlBarEditing ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(
              _isLoading
                  ? Icons.hourglass_top_rounded
                  : _currentUrl.startsWith('https://')
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
              color: _isLoading
                  ? _accentColor.withValues(alpha: 0.7)
                  : _currentUrl.startsWith('https://')
                      ? Colors.greenAccent.withValues(alpha: 0.55)
                      : Colors.orange.withValues(alpha: 0.6),
              size: 13,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _urlBarEditing
                  ? TextField(
                      controller: _urlBarController,
                      focusNode: _urlFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: _onUrlBarSubmit,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : Text(
                      _formatDisplayUrl(_currentUrl),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
            ),
            if (_urlBarEditing)
              GestureDetector(
                onTap: () { _urlBarController.clear(); _urlFocusNode.requestFocus(); },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.cancel_rounded, color: Colors.white.withValues(alpha: 0.35), size: 16),
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  String _formatDisplayUrl(String url) {
    if (url.isEmpty) return _platform.initialUrl ?? 'Navegar...';
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceFirst('www.', '');
      final path = uri.path.length > 1 ? uri.path : '';
      return host + path;
    } catch (_) { return url; }
  }

  // ── Hint de captura ───────────────────────────────────────────────────────

  Widget _buildHint() {
    if (_isVideoDetected && !_isCapturing) {
      return _buildDetectedBanner();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_rounded, color: _accentColor.withValues(alpha: 0.65), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Navegue até um vídeo no ${_platform.displayName} — ele será capturado automaticamente.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedBanner() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Transform.scale(scale: _pulseAnim.value, child: child),
      child: GestureDetector(
        onTap: () => _captureUrl(_detectedVideoUrl),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _accentColor.withValues(alpha: 0.22),
              _accentColor.withValues(alpha: 0.10),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentColor.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_circle_filled_rounded, color: _accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vídeo detectado!',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Toque para adicionar à sala',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: _accentColor, borderRadius: BorderRadius.circular(8)),
                child: const Text('Usar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Conteúdo principal ────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_platform.isDirectUrl) return _buildDirectUrlInput();
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(_platform.initialUrl ?? 'about:blank'),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            useHybridComposition: true,
            supportZoom: true,
            builtInZoomControls: true,
            displayZoomControls: false,
            domStorageEnabled: true,
            databaseEnabled: true,
            allowFileAccessFromFileURLs: false,
            allowUniversalAccessFromFileURLs: false,
            userAgent:
                'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/124.0.0.0 Mobile Safari/537.36',
          ),
          onWebViewCreated: (c) => _webViewController = c,
          onLoadStart: (c, url) {
            if (!mounted) return;
            setState(() { _isLoading = true; _loadingProgress = 0.0; _isVideoDetected = false; });
            _updateUrlBar(url?.toString() ?? '');
          },
          onProgressChanged: (c, progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress / 100.0);
          },
          onLoadStop: (c, url) async {
            if (!mounted) return;
            final urlStr = url?.toString() ?? '';
            final back = await c.canGoBack();
            final fwd = await c.canGoForward();
            if (!mounted) return;
            setState(() { _isLoading = false; _loadingProgress = 1.0; _canGoBack = back; _canGoForward = fwd; });
            _updateUrlBar(urlStr);
            if (_isVideoUrl(urlStr) && !_isCapturing) _markVideoDetected(urlStr);
          },
          onLoadError: (c, url, code, msg) {
            if (!mounted) return;
            setState(() { _isLoading = false; _loadingProgress = 0.0; });
          },
          onUpdateVisitedHistory: (c, url, isReload) async {
            if (!mounted) return;
            final urlStr = url?.toString() ?? '';
            final back = await c.canGoBack();
            final fwd = await c.canGoForward();
            if (!mounted) return;
            setState(() { _canGoBack = back; _canGoForward = fwd; });
            _updateUrlBar(urlStr);
            if (_isVideoUrl(urlStr) && !_isCapturing) _markVideoDetected(urlStr);
          },
          shouldOverrideUrlLoading: (c, nav) async {
            final urlStr = nav.request.url?.toString() ?? '';
            if (_isVideoUrl(urlStr) && !_isCapturing) _markVideoDetected(urlStr);
            return NavigationActionPolicy.ALLOW;
          },
        ),
        if (_isCapturing) _buildCapturingOverlay(),
      ],
    );
  }

  Widget _buildCapturingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52, height: 52,
              child: CircularProgressIndicator(color: _accentColor, strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text('Carregando vídeo...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_platform.displayName,
                style: TextStyle(color: _accentColor.withValues(alpha: 0.75), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Input de URL direta ───────────────────────────────────────────────────

  Widget _buildDirectUrlInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.28)),
            ),
            child: const Icon(Icons.link_rounded, color: Color(0xFF6C63FF), size: 28),
          ),
          const SizedBox(height: 20),
          const Text('Cole a URL do vídeo',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
            'Funciona com qualquer site de vídeo: Netflix, Disney+, Prime Video, Max, Crunchyroll e outros.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111120),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3), width: 1.5),
            ),
            child: TextField(
              controller: _directUrlController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _submitDirectUrl(),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 14),
                prefixIcon: Icon(Icons.link_rounded, color: const Color(0xFF6C63FF).withValues(alpha: 0.55), size: 20),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _isCapturing ? null : _submitDirectUrl,
              icon: _isCapturing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(
                _isCapturing ? 'Carregando...' : 'Reproduzir',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plataformas suportadas',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    'Netflix', 'Disney+', 'Prime Video', 'Max',
                    'Crunchyroll', 'Apple TV+', 'Globoplay', 'Qualquer site',
                  ].map((n) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(n, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _NavBtn ───────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;

  const _NavBtn({required this.icon, this.onTap, this.tooltip, this.color});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color ?? (enabled ? Colors.white.withValues(alpha: 0.78) : Colors.white.withValues(alpha: 0.18)),
          size: 17,
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}
