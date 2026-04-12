import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../utils/responsive.dart';
import '../../config/app_theme.dart';

// ============================================================================
// ImageViewer — Visualizador de imagem em tela cheia com sobreposição
//
// Features:
// - Abre qualquer imagem (network ou local) em sobreposição fullscreen
// - Zoom com pinch-to-zoom e double-tap
// - Salvar imagem segurando o dedo (long press)
// - Compartilhar imagem
// - Fechar com botão X ou swipe down
// - Suporte a galeria de múltiplas imagens com navegação
// - Hero animation suave
// - Indicador de carregamento
// ============================================================================

/// Abre o visualizador de imagem em sobreposição fullscreen.
/// [imageUrls] lista de URLs de imagens (pode ser apenas 1)
/// [initialIndex] índice inicial da imagem a exibir
/// [heroTag] tag para animação Hero (opcional)
void showImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? heroTag,
}) {
  if (imageUrls.isEmpty) return;
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
          child: _ImageViewerScreen(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
            heroTag: heroTag,
          ),
        );
      },
    ),
  );
}

/// Abre o visualizador para uma única imagem.
void showSingleImageViewer(
  BuildContext context, {
  required String imageUrl,
  String? heroTag,
}) {
  showImageViewer(
    context,
    imageUrls: [imageUrl],
    initialIndex: 0,
    heroTag: heroTag,
  );
}

// ============================================================================
// _ImageViewerScreen — Tela interna do visualizador
// ============================================================================
class _ImageViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? heroTag;

  const _ImageViewerScreen({
    required this.imageUrls,
    required this.initialIndex,
    this.heroTag,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen>
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

  Future<void> _saveImage(String url) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Feedback háptico
      HapticFeedback.mediumImpact();

      // Download da imagem
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Download falhou');

      final bytes = response.bodyBytes;

      // Salvar em arquivo temporário
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'nexushub_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      // Compartilhar (permite salvar na galeria via share sheet)
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/jpeg')],
        text: 'Imagem do NexusHub',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao salvar imagem'),
            backgroundColor: AppTheme.errorColor,
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

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isSingle = widget.imageUrls.length == 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Galeria de imagens ──────────────────────────────────────────
            GestureDetector(
              onTap: _toggleControls,
              child: isSingle
                  ? _buildSingleImage(r)
                  : _buildGallery(r),
            ),

            // ── Controles superiores ────────────────────────────────────────
            FadeTransition(
              opacity: _controlsAnim,
              child: _buildTopBar(r),
            ),

            // ── Indicador de página (múltiplas imagens) ─────────────────────
            if (!isSingle)
              FadeTransition(
                opacity: _controlsAnim,
                child: _buildPageIndicator(r),
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
                      const CircularProgressIndicator(
                        color: AppTheme.accentColor,
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

  Widget _buildSingleImage(Responsive r) {
    final url = widget.imageUrls.first;
    return GestureDetector(
      onLongPress: () => _saveImage(url),
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
                color: AppTheme.accentColor,
                strokeWidth: 3,
              ),
              SizedBox(height: r.s(12)),
              Text(
                'Carregando imagem...',
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
                'Erro ao carregar imagem',
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

  Widget _buildGallery(Responsive r) {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount: widget.imageUrls.length,
      onPageChanged: (i) => setState(() => _currentIndex = i),
      builder: (context, index) {
        final url = widget.imageUrls[index];
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
          color: AppTheme.accentColor,
          strokeWidth: 3,
        ),
      ),
      onPageChanged: (i) => setState(() => _currentIndex = i),
    );
  }

  Widget _buildTopBar(Responsive r) {
    final currentUrl = widget.imageUrls[_currentIndex];
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
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
                  onTap: _close,
                  tooltip: 'Fechar',
                ),
                const Spacer(),
                // Contador de páginas
                if (widget.imageUrls.length > 1)
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
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                // Botão salvar/compartilhar
                _ControlButton(
                  icon: Icons.save_alt_rounded,
                  onTap: () => _saveImage(currentUrl),
                  tooltip: 'Salvar imagem',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(Responsive r) {
    return Positioned(
      bottom: r.s(40),
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.imageUrls.length,
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
      ),
    );
  }
}

// ============================================================================
// _ControlButton — Botão de controle circular com efeito de vidro
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
// TappableImage — Widget de imagem clicável que abre o ImageViewer
//
// Uso simples:
//   TappableImage(url: 'https://...')
//   TappableImage(url: 'https://...', width: 220, height: 160)
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

    return GestureDetector(
      onTap: () => showImageViewer(
        context,
        imageUrls: urls,
        initialIndex: galleryIndex,
        heroTag: heroTag ?? 'tappable_image_$url',
      ),
      onLongPress: () => showImageViewer(
        context,
        imageUrls: urls,
        initialIndex: galleryIndex,
        heroTag: heroTag ?? 'tappable_image_$url',
      ),
      child: Hero(
        tag: heroTag ?? 'tappable_image_$url',
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
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentColor,
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
