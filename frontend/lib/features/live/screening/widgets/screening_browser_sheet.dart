import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';

// =============================================================================
// ScreeningBrowserSheet — WebView embutido para seleção de vídeo por plataforma
//
// O usuário navega normalmente no site da plataforma (YouTube, Twitch, Kick,
// Vimeo, Dailymotion, Google Drive). Quando navega para uma URL de vídeo
// válida, o app captura essa URL, chama updateVideo() no provider e fecha o
// sheet. Para WEB (URL direta), exibe campo de texto para colar a URL.
// =============================================================================

// ── Modelo de plataforma ──────────────────────────────────────────────────────

class ScreeningPlatform {
  final String id;
  final String displayName;
  final String? initialUrl;
  final List<_VideoUrlPattern> videoPatterns;
  final bool isDirectUrl; // WEB: campo de texto livre

  const ScreeningPlatform({
    required this.id,
    required this.displayName,
    this.initialUrl,
    this.videoPatterns = const [],
    this.isDirectUrl = false,
  });
}

class _VideoUrlPattern {
  final RegExp pattern;
  const _VideoUrlPattern(this.pattern);
}

// ── Definição das plataformas suportadas ──────────────────────────────────────

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
  'dailymotion': ScreeningPlatform(
    id: 'dailymotion',
    displayName: 'Dailymotion',
    initialUrl: 'https://www.dailymotion.com',
    videoPatterns: [
      _VideoUrlPattern(RegExp(r'dailymotion\.com/video/[a-zA-Z0-9]+')),
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

  const ScreeningBrowserSheet({
    super.key,
    required this.platformId,
    required this.sessionId,
    required this.threadId,
  });

  @override
  ConsumerState<ScreeningBrowserSheet> createState() =>
      _ScreeningBrowserSheetState();
}

class _ScreeningBrowserSheetState
    extends ConsumerState<ScreeningBrowserSheet> {
  InAppWebViewController? _webViewController;
  final _urlBarController = TextEditingController();
  final _directUrlController = TextEditingController();

  bool _isLoading = true;
  bool _canGoBack = false;
  String _currentUrl = '';
  bool _isCapturing = false;

  late final ScreeningPlatform _platform;

  @override
  void initState() {
    super.initState();
    _platform = _kPlatforms[widget.platformId] ??
        _kPlatforms['web']!;
    if (_platform.initialUrl != null) {
      _currentUrl = _platform.initialUrl!;
      _urlBarController.text = _platform.initialUrl!;
    }
  }

  @override
  void dispose() {
    _urlBarController.dispose();
    _directUrlController.dispose();
    super.dispose();
  }

  // ── Detecção de URL de vídeo ──────────────────────────────────────────────

  bool _isVideoUrl(String url) {
    for (final pattern in _platform.videoPatterns) {
      if (pattern.pattern.hasMatch(url)) return true;
    }
    return false;
  }

  // ── Captura e envio do vídeo ──────────────────────────────────────────────

  Future<void> _captureUrl(String url) async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    HapticFeedback.mediumImpact();

    final title = _inferTitle(url);
    await ref
        .read(screeningRoomProvider(widget.threadId).notifier)
        .updateVideo(videoUrl: url, videoTitle: title);

    if (mounted) {
      // Fechar o browser sheet e o add video sheet (2 pops)
      Navigator.of(context).pop(); // fecha browser sheet
    }
  }

  String _inferTitle(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube')) return 'YouTube';
    if (u.contains('twitch')) return 'Twitch';
    if (u.contains('kick')) return 'Kick';
    if (u.contains('vimeo')) return 'Vimeo';
    if (u.contains('dailymotion')) return 'Dailymotion';
    if (u.contains('drive.google')) return 'Google Drive';
    return _platform.displayName;
  }

  // ── Submissão de URL direta (plataforma WEB) ──────────────────────────────

  Future<void> _submitDirectUrl() async {
    final input = _directUrlController.text.trim();
    if (input.isEmpty) return;

    String url = input;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    await _captureUrl(url);
  }

  // ── Atualizar barra de endereço ───────────────────────────────────────────

  void _updateUrlBar(String url) {
    setState(() {
      _currentUrl = url;
      _urlBarController.text = url;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Topbar do browser ────────────────────────────────────────────
          _BrowserTopBar(
            platform: _platform,
            urlController: _urlBarController,
            currentUrl: _currentUrl,
            canGoBack: _canGoBack,
            isLoading: _isLoading,
            onBack: () => _webViewController?.goBack(),
            onClose: () => Navigator.of(context).pop(),
            onRefresh: () => _webViewController?.reload(),
          ),

          // ── Dica de captura ──────────────────────────────────────────────
          if (!_platform.isDirectUrl)
            _CaptureHint(platformName: _platform.displayName),

          // ── Conteúdo principal ───────────────────────────────────────────
          Expanded(
            child: _platform.isDirectUrl
                ? _DirectUrlInput(
                    controller: _directUrlController,
                    onSubmit: _submitDirectUrl,
                    isCapturing: _isCapturing,
                  )
                : Stack(
                    children: [
                      // WebView
                      InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(_platform.initialUrl!),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          // Cookies persistentes para login (Netflix, etc.)
                          thirdPartyCookiesEnabled: true,
                          useHybridComposition: true,
                          allowsInlineMediaPlayback: true,
                          userAgent:
                              'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                              'AppleWebKit/537.36 (KHTML, like Gecko) '
                              'Chrome/120.0.0.0 Mobile Safari/537.36',
                        ),
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
                        },
                        onLoadStart: (controller, url) {
                          if (!mounted) return;
                          final urlStr = url?.toString() ?? '';
                          setState(() {
                            _isLoading = true;
                          });
                          _updateUrlBar(urlStr);
                        },
                        onLoadStop: (controller, url) async {
                          if (!mounted) return;
                          final urlStr = url?.toString() ?? '';
                          final canGoBack =
                              await controller.canGoBack();
                          if (!mounted) return;
                          setState(() {
                            _isLoading = false;
                            _canGoBack = canGoBack;
                          });
                          _updateUrlBar(urlStr);

                          // Verificar se é URL de vídeo após carregamento
                          if (_isVideoUrl(urlStr) && !_isCapturing) {
                            await _captureUrl(urlStr);
                          }
                        },
                        onUpdateVisitedHistory:
                            (controller, url, isReload) async {
                          if (!mounted) return;
                          final urlStr = url?.toString() ?? '';
                          final canGoBack =
                              await controller.canGoBack();
                          if (!mounted) return;
                          setState(() => _canGoBack = canGoBack);
                          _updateUrlBar(urlStr);

                          // Verificar URL em tempo real durante navegação
                          if (_isVideoUrl(urlStr) && !_isCapturing) {
                            await _captureUrl(urlStr);
                          }
                        },
                        shouldOverrideUrlLoading:
                            (controller, navigationAction) async {
                          final urlStr = navigationAction
                                  .request.url
                                  ?.toString() ??
                              '';
                          // Capturar URL de vídeo antes de carregar
                          if (_isVideoUrl(urlStr) && !_isCapturing) {
                            await _captureUrl(urlStr);
                            return NavigationActionPolicy.CANCEL;
                          }
                          return NavigationActionPolicy.ALLOW;
                        },
                      ),

                      // Loading indicator
                      if (_isLoading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            color: Colors.white54,
                            minHeight: 2,
                          ),
                        ),

                      // Overlay de captura
                      if (_isCapturing)
                        Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Carregando vídeo...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── _BrowserTopBar ────────────────────────────────────────────────────────────

class _BrowserTopBar extends StatelessWidget {
  final ScreeningPlatform platform;
  final TextEditingController urlController;
  final String currentUrl;
  final bool canGoBack;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  const _BrowserTopBar({
    required this.platform,
    required this.urlController,
    required this.currentUrl,
    required this.canGoBack,
    required this.isLoading,
    required this.onBack,
    required this.onClose,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Botão voltar
          _TopBarButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: canGoBack ? onBack : null,
            enabled: canGoBack,
          ),
          const SizedBox(width: 8),

          // Barra de endereço (readonly)
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    _platformIcon(platform.id),
                    color: Colors.white54,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatUrl(currentUrl),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Botão refresh
          _TopBarButton(
            icon: isLoading
                ? Icons.close_rounded
                : Icons.refresh_rounded,
            onTap: onRefresh,
          ),

          const SizedBox(width: 8),

          // Botão fechar
          _TopBarButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  String _formatUrl(String url) {
    if (url.isEmpty) return platform.initialUrl ?? '';
    try {
      final uri = Uri.parse(url);
      return uri.host + (uri.path.length > 1 ? uri.path : '');
    } catch (_) {
      return url;
    }
  }

  IconData _platformIcon(String platformId) {
    switch (platformId) {
      case 'youtube':
      case 'youtube_live':
        return Icons.play_circle_outline_rounded;
      case 'twitch':
        return Icons.live_tv_rounded;
      case 'kick':
        return Icons.sports_esports_rounded;
      case 'vimeo':
        return Icons.videocam_rounded;
      case 'dailymotion':
        return Icons.movie_rounded;
      case 'drive':
        return Icons.folder_rounded;
      default:
        return Icons.language_rounded;
    }
  }
}

// ── _TopBarButton ─────────────────────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? color;

  const _TopBarButton({
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: (color ??
                  (enabled
                      ? Colors.white70
                      : Colors.white.withValues(alpha: 0.25))),
          size: 18,
        ),
      ),
    );
  }
}

// ── _CaptureHint ──────────────────────────────────────────────────────────────

class _CaptureHint extends StatelessWidget {
  final String platformName;
  const _CaptureHint({required this.platformName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Navegue até um vídeo no $platformName e ele será capturado automaticamente.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DirectUrlInput ───────────────────────────────────────────────────────────

class _DirectUrlInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isCapturing;

  const _DirectUrlInput({
    required this.controller,
    required this.onSubmit,
    required this.isCapturing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cole a URL do vídeo',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Funciona com qualquer site de vídeo: Netflix, Disney+, Prime Video, etc.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => onSubmit(),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isCapturing ? null : onSubmit,
              icon: isCapturing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                isCapturing ? 'Carregando...' : 'Reproduzir',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
