import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../utils/responsive.dart';

/// ============================================================================
/// ImageCarousel — Carrossel de imagens para posts com múltiplas fotos.
///
/// Features:
/// - PageView com indicadores de página (dots)
/// - Tap para abrir galeria fullscreen com zoom (PhotoView)
/// - Suporte a 1-10 imagens
/// - Aspect ratio adaptativo
/// ============================================================================

class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const ImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 300,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    // Uma única imagem — sem carrossel
    if (widget.imageUrls.length == 1) {
      return GestureDetector(
        onTap: () => _openGallery(context, 0),
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(r.s(12)),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrls.first,
              fit: widget.fit,
              placeholder: (_, __) => Container(
                color: Colors.grey[900],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[900],
                child: Icon(Icons.broken_image_rounded,
                    color: Colors.grey, size: r.s(48)),
              ),
            ),
          ),
        ),
      );
    }

    // Múltiplas imagens — carrossel
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(r.s(12)),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // PageView
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _openGallery(context, index),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    fit: widget.fit,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[900],
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.grey, size: r.s(48)),
                    ),
                  ),
                );
              },
            ),

            // Contador (ex: 2/5)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(r.s(12)),
                ),
                child: Text(
                  '${_currentPage + 1}/${widget.imageUrls.length}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // Dots indicator
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: r.s(3)),
                    width: _currentPage == i ? 20 : 6,
                    height: r.s(6),
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(r.s(3)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          imageUrls: widget.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// Galeria fullscreen com zoom via PhotoView
class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenGallery({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: TextStyle(color: Colors.white, fontSize: r.fs(16)),
        ),
        centerTitle: true,
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.imageUrls[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: PhotoViewHeroAttributes(tag: 'image_$index'),
          );
        },
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? null
                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
            color: Colors.white38,
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// ImagePickerGrid — Grid para selecionar e preview de imagens antes do upload
/// ============================================================================
class ImagePickerGrid extends StatelessWidget {
  final List<String> imageUrls;
  final List<String> localPaths;
  final VoidCallback onAddImages;
  final void Function(int index) onRemoveImage;
  final int maxImages;

  const ImagePickerGrid({
    super.key,
    this.imageUrls = const [],
    this.localPaths = const [],
    required this.onAddImages,
    required this.onRemoveImage,
    this.maxImages = 10,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final allImages = [...imageUrls, ...localPaths];
    final canAdd = allImages.length < maxImages;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...List.generate(allImages.length, (i) {
          final isLocal = i >= imageUrls.length;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(r.s(8)),
                child: SizedBox(
                  width: r.s(80),
                  height: r.s(80),
                  child: isLocal
                      ? Image.file(
                          File(allImages[i]),
                          fit: BoxFit.cover,
                        )
                      : CachedNetworkImage(
                          imageUrl: allImages[i],
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemoveImage(i),
                  child: Container(
                    width: r.s(20),
                    height: r.s(20),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.close, color: Colors.white, size: r.s(14)),
                  ),
                ),
              ),
            ],
          );
        }),
        if (canAdd)
          GestureDetector(
            onTap: onAddImages,
            child: Container(
              width: r.s(80),
              height: r.s(80),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(r.s(8)),
                border: Border.all(
                    color: Colors.grey[600]!, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: Colors.grey[400], size: r.s(28)),
                  Text('${allImages.length}/$maxImages',
                      style: TextStyle(color: Colors.grey[500], fontSize: r.fs(10))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
