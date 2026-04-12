import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import '../utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// MediaViewer — Visualizador de mídia fullscreen (imagem, GIF, vídeo)
//
// Features:
// - Imagens: zoom com pinch, double-tap, hero animation
// - GIFs: exibição animada com zoom
// - Vídeos: player com play/pause, seek, mute, fullscreen
// - Salvar/compartilhar segurando o dedo ou pelo botão
// - Fechar com botão X
// - Galeria de múltiplas mídias com navegação
// - Indicador de carregamento
// ============================================================================

/// Tipo de mídia
enum MediaType { image, gif, video }

/// Detecta o tipo de mídia pela URL
MediaType _detectMediaType(String url) {
  final lower = url.toLowerCase().split('?').first;
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mkv') ||
      lower.contains('/video/')) {
    return MediaType.video;
  }
  if (lower.endsWith('.gif')) {
    return MediaType.gif;
  }
  return MediaType.image;
}

/// Abre o visualizador de mídia em sobreposição fullscreen.
void showMediaViewer(
  BuildContext context, {
  required List<String> mediaUrls,
  int initialIndex = 0,
  String? heroTag,
}) {
  if (mediaUrls.isEmpty) return;
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          // FIX: _MediaViewerScreen usa Scaffold+Stack internamente,
          // sem Positioned dentro do FadeTransition
          child: _MediaViewerScreen(
            mediaUrls: mediaUrls,
            initialIndex: initialIndex,
            heroTag: heroTag,
          ),
        );
      },
    ),
  );
}

/// Atalho para uma única mídia.
void showSingleMediaViewer(
  BuildContext context, {
  required String url,
  String? heroTag,
}) {
  showMediaViewer(
    context,
    mediaUrls: [url],
    initialIndex: 0,
    heroTag: heroTag,
  );
}

// Manter compatibilidade com código antigo que chama showImageViewer
void showImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? heroTag,
}) {
  showMediaViewer(
    context,
    mediaUrls: imageUrls,
    initialIndex: initialIndex,
    heroTag: heroTag,
  );
}

void showSingleImageViewer(
  BuildContext context, {
  required String imageUrl,
  String? heroTag,
}) {
  showSingleMediaViewer(context, url: imageUrl, heroTag: heroTag);
}

// ============================================================================
// _MediaViewerScreen
// ============================================================================
class _MediaViewerScreen extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;
  final String? heroTag;

  const _MediaViewerScreen({
    required this.mediaUrls,
    required this.initialIndex,
    this.heroTag,
  });

  @override
  State<_MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<_MediaViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  bool _showControls = true;
  bool _isSaving = false;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _controlsAnim = CurvedAnimation(
      parent: _controlsAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controlsAnimController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsAnimController.forward();
    } else {
      _controlsAnimController.reverse();
    }
  }

  Future<void> _saveMedia(String url) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      HapticFeedback.mediumImpact();

      // Verificar/solicitar permissão de acesso à galeria
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Permissão negada para acessar a galeria'),
                backgroundColor: context.nexusTheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          return;
        }
      }

      // Baixar a mídia
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Download falhou');
      final bytes = response.bodyBytes;

      // Salvar em arquivo temporário
      final tempDir = await getTemporaryDirectory();
      final ext = _extensionFromUrl(url);
      final fileName =
          'nexushub_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      // Salvar direto na galeria do dispositivo
      final isVideo = _detectMediaType(url) == MediaType.video;
      if (isVideo) {
        await Gal.putVideo(file.path, album: 'NexusHub');
      } else {
        await Gal.putImage(file.path, album: 'NexusHub');
      }

      // Limpar arquivo temporário
      await file.delete().catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('Salvo na galeria!'),
              ],
            ),
            backgroundColor: const Color(0xFF2DBE60),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        final msg = e.type == GalExceptionType.notEnoughSpace
            ? 'Sem espaço suficiente no dispositivo'
            : e.type == GalExceptionType.accessDenied
                ? 'Acesso à galeria negado'
                : 'Erro ao salvar na galeria';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao salvar mídia'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _extensionFromUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    for (final ext in ['mp4', 'mov', 'avi', 'webm', 'mkv', 'gif', 'png', 'jpg', 'jpeg', 'webp']) {
      if (lower.endsWith('.$ext')) return ext;
    }
    return 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isSingle = widget.mediaUrls.length == 1;
    final currentUrl = widget.mediaUrls[_currentIndex];
    final mediaType = _detectMediaType(currentUrl);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Conteúdo principal ──────────────────────────────────────────
            GestureDetector(
              onTap: _toggleControls,
              child: isSingle
                  ? _buildSingleMedia(r, currentUrl, mediaType)
                  : _buildGallery(r),
            ),

            // ── Barra superior (FIX: Positioned está DENTRO do Stack, não dentro de FadeTransition) ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _controlsAnim,
                child: _buildTopBar(r, currentUrl, mediaType),
              ),
            ),

            // ── Indicador de página ─────────────────────────────────────────
            if (!isSingle)
              Positioned(
                bottom: r.s(40),
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _controlsAnim,
                  child: _buildPageIndicator(r),
                ),
              ),

            // ── Indicador de salvando ───────────────────────────────────────
            if (_isSaving)
              Center(
                child: Container(
                  padding: EdgeInsets.all(r.s(20)),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(r.s(16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: context.nexusTheme.accentSecondary,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: r.s(12)),
                      Text(
                        'Salvando...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleMedia(Responsive r, String url, MediaType type) {
    switch (type) {
      case MediaType.video:
        return _VideoPlayerWidget(
          url: url,
          onTap: _toggleControls,
        );
      case MediaType.gif:
      case MediaType.image:
        return GestureDetector(
          onLongPress: () => _saveMedia(url),
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: widget.heroTag != null
                ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                : null,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (_, event) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: event == null
                        ? null
                        : event.cumulativeBytesLoaded /
                            (event.expectedTotalBytes ?? 1),
                    color: context.nexusTheme.accentSecondary,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: r.s(12)),
                  Text(
                    type == MediaType.gif
                        ? 'Carregando GIF...'
                        : 'Carregando imagem...',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: r.fs(13),
                    ),
                  ),
                ],
              ),
            ),
            errorBuilder: (_, __, ___) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_rounded,
                      color: Colors.white38, size: r.s(64)),
                  SizedBox(height: r.s(12)),
                  Text(
                    'Erro ao carregar mídia',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: r.fs(14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _buildGallery(Responsive r) {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount: widget.mediaUrls.length,
      onPageChanged: (i) => setState(() => _currentIndex = i),
      builder: (context, index) {
        final url = widget.mediaUrls[index];
        final type = _detectMediaType(url);
        if (type == MediaType.video) {
          return PhotoViewGalleryPageOptions.customChild(
            child: _VideoPlayerWidget(url: url, onTap: _toggleControls),
          );
        }
        return PhotoViewGalleryPageOptions(
          imageProvider: CachedNetworkImageProvider(url),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: widget.heroTag != null && index == widget.initialIndex
              ? PhotoViewHeroAttributes(tag: widget.heroTag!)
              : null,
          gestureDetectorBehavior: HitTestBehavior.translucent,
        );
      },
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (_, event) => Center(
        child: CircularProgressIndicator(
          value: event == null
              ? null
              : event.cumulativeBytesLoaded /
                  (event.expectedTotalBytes ?? 1),
          color: context.nexusTheme.accentSecondary,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildTopBar(Responsive r, String currentUrl, MediaType mediaType) {
    // FIX: este widget NÃO é Positioned — o Positioned está no Stack pai
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.s(8),
            vertical: r.s(4),
          ),
          child: Row(
            children: [
              // Botão fechar
              _ControlButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
              ),
              const Spacer(),
              // Contador de páginas
              if (widget.mediaUrls.length > 1)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(6),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(r.s(20)),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.mediaUrls.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              // Botão salvar (não para vídeo)
              if (mediaType != MediaType.video)
                _ControlButton(
                  icon: Icons.save_alt_rounded,
                  onTap: () => _saveMedia(currentUrl),
                  tooltip: 'Salvar',
                )
              else
                SizedBox(width: r.s(44)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(Responsive r) {
    // FIX: este widget NÃO é Positioned — o Positioned está no Stack pai
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.mediaUrls.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: i == _currentIndex ? r.s(20) : r.s(6),
          height: r.s(6),
          margin: EdgeInsets.symmetric(horizontal: r.s(3)),
          decoration: BoxDecoration(
            color: i == _currentIndex
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(r.s(3)),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _VideoPlayerWidget — Player de vídeo embutido
// ============================================================================
class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  final VoidCallback? onTap;

  const _VideoPlayerWidget({required this.url, this.onTap});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
          _controller.setLooping(true);
        }
      });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    if (!_initialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: context.nexusTheme.accentSecondary,
              strokeWidth: 3,
            ),
            SizedBox(height: r.s(12)),
            Text(
              'Carregando vídeo...',
              style: TextStyle(color: Colors.white54, fontSize: r.fs(13)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _togglePlayPause();
        widget.onTap?.call();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vídeo
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),

          // Overlay de play/pause
          AnimatedOpacity(
            opacity: !_controller.value.isPlaying ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: r.s(72),
              height: r.s(72),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: r.s(44),
              ),
            ),
          ),

          // Controles inferiores
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.fromLTRB(r.s(12), r.s(8), r.s(12), r.s(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barra de progresso
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: context.nexusTheme.accentSecondary,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white12,
                    ),
                    padding: EdgeInsets.symmetric(vertical: r.s(4)),
                  ),
                  SizedBox(height: r.s(4)),
                  // Linha de controles
                  Row(
                    children: [
                      // Play/Pause
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: r.s(28),
                        ),
                      ),
                      SizedBox(width: r.s(8)),
                      // Tempo atual / duração
                      Text(
                        '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: r.fs(11),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      // Mute
                      GestureDetector(
                        onTap: _toggleMute,
                        child: Icon(
                          _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: r.s(22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ============================================================================
// _ControlButton — Botão de controle circular
// ============================================================================
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: r.s(44),
          height: r.s(44),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: r.s(22),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TappableImage — Widget de imagem/GIF/vídeo clicável que abre o MediaViewer
//
// Uso:
//   TappableImage(url: 'https://...')
//   TappableImage(url: 'https://...video.mp4')  // abre player de vídeo
//   TappableImage(url: 'https://...anim.gif')   // abre GIF animado
// ============================================================================
class TappableImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? heroTag;
  final List<String>? galleryUrls;
  final int galleryIndex;

  const TappableImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.heroTag,
    this.galleryUrls,
    this.galleryIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final br = borderRadius ?? BorderRadius.circular(r.s(10));
    final urls = galleryUrls ?? [url];
    final mediaType = _detectMediaType(url);

    void openViewer() => showMediaViewer(
          context,
          mediaUrls: urls,
          initialIndex: galleryIndex,
          heroTag: heroTag ?? 'tappable_media_$url',
        );

    // Para vídeo, mostrar thumbnail com ícone de play
    if (mediaType == MediaType.video) {
      return GestureDetector(
        onTap: openViewer,
        child: ClipRRect(
          borderRadius: br,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: width ?? 220,
                height: height ?? 140,
                color: Colors.black87,
                child: Icon(
                  Icons.videocam_rounded,
                  color: Colors.white24,
                  size: r.s(48),
                ),
              ),
              Container(
                width: r.s(52),
                height: r.s(52),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54, width: 2),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: r.s(32),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Para imagem e GIF
    return GestureDetector(
      onTap: openViewer,
      onLongPress: openViewer,
      child: Hero(
        tag: heroTag ?? 'tappable_media_$url',
        child: ClipRRect(
          borderRadius: br,
          child: CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, __) => Container(
              width: width ?? 160,
              height: height ?? 120,
              color: Colors.grey[900],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.nexusTheme.accentSecondary,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: width ?? 80,
              height: height ?? 80,
              color: Colors.grey[900],
              child: Icon(
                Icons.broken_image_rounded,
                color: Colors.grey[600],
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
