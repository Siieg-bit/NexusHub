import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image_cropper/image_cropper.dart';

import '../utils/responsive.dart';
import '../../config/nexus_theme_extension.dart';
import '../../config/nexus_theme_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tipos públicos
// ─────────────────────────────────────────────────────────────────────────────

/// Representa um arquivo de mídia selecionado pelo NexusMediaPicker.
class NexusMediaFile {
  final File file;
  final bool isVideo;
  final Uint8List? thumbnail;
  final int? durationMs;

  const NexusMediaFile({
    required this.file,
    this.isVideo = false,
    this.thumbnail,
    this.durationMs,
  });
}

/// Modo de seleção do picker.
enum NexusPickerMode {
  imageOnly,
  videoOnly,
  all,
}

/// Configuração de crop para imagens.
class NexusCropConfig {
  final CropAspectRatio? aspectRatio;
  final bool useCircleCrop;
  final int? maxWidth;
  final int? maxHeight;

  const NexusCropConfig({
    this.aspectRatio,
    this.useCircleCrop = false,
    this.maxWidth,
    this.maxHeight,
  });

  static const NexusCropConfig avatar = NexusCropConfig(
    aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
    useCircleCrop: true,
    maxWidth: 512,
    maxHeight: 512,
  );

  static const NexusCropConfig banner = NexusCropConfig(
    aspectRatio: CropAspectRatio(ratioX: 16, ratioY: 9),
    maxWidth: 1920,
    maxHeight: 1080,
  );

  static const NexusCropConfig square = NexusCropConfig(
    aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Função de entrada pública
// ─────────────────────────────────────────────────────────────────────────────

/// Abre o NexusMediaPicker como bottom sheet e retorna os arquivos selecionados.
///
/// [maxSelect] — máximo de arquivos selecionáveis. Use -1 para ilimitado.
/// [mode] — tipo de mídia permitida.
/// [cropConfig] — configuração de crop (apenas para seleção única de imagem).
Future<List<NexusMediaFile>> showNexusMediaPicker(
  BuildContext context, {
  int maxSelect = 1,
  NexusPickerMode mode = NexusPickerMode.imageOnly,
  NexusCropConfig? cropConfig,
}) async {
  final result = await showModalBottomSheet<List<NexusMediaFile>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: false,
    builder: (_) => NexusMediaPickerSheet(
      maxSelect: maxSelect,
      mode: mode,
      cropConfig: cropConfig,
    ),
  );
  return result ?? [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────

class NexusMediaPickerSheet extends StatefulWidget {
  final int maxSelect;
  final NexusPickerMode mode;
  final NexusCropConfig? cropConfig;

  const NexusMediaPickerSheet({
    super.key,
    this.maxSelect = 1,
    this.mode = NexusPickerMode.imageOnly,
    this.cropConfig,
  });

  @override
  State<NexusMediaPickerSheet> createState() => _NexusMediaPickerSheetState();
}

class _NexusMediaPickerSheetState extends State<NexusMediaPickerSheet>
    with TickerProviderStateMixin {
  // Dados
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];

  // Estado
  bool _loading = true;
  bool _permissionDenied = false;
  int _page = 0;
  static const int _pageSize = 80;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _confirming = false;

  // Scroll
  final ScrollController _scrollController = ScrollController();

  // Tab controller (Recentes | Câmera)
  late TabController _tabController;

  // Animação do shimmer
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _requestPermissionAndLoad();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_loadingMore &&
        _hasMore) {
      _loadMoreAssets();
    }
  }

  RequestType get _requestType {
    switch (widget.mode) {
      case NexusPickerMode.imageOnly:
        return RequestType.image;
      case NexusPickerMode.videoOnly:
        return RequestType.video;
      case NexusPickerMode.all:
        return RequestType.common;
    }
  }

  Future<void> _requestPermissionAndLoad() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    await _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final albums = await PhotoManager.getAssetPathList(
      type: _requestType,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _albums = albums;
        _currentAlbum = albums.first;
      });
    }
    await _loadAssets(reset: true);
  }

  Future<void> _loadAssets({bool reset = false}) async {
    if (_currentAlbum == null) return;
    if (reset) {
      _page = 0;
      _hasMore = true;
    }
    final assets = await _currentAlbum!.getAssetListPaged(
      page: _page,
      size: _pageSize,
    );
    if (mounted) {
      setState(() {
        if (reset) {
          _assets = assets;
        } else {
          _assets.addAll(assets);
        }
        _hasMore = assets.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMoreAssets() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;
    await _loadAssets();
  }

  Future<void> _switchAlbum(AssetPathEntity album) async {
    setState(() {
      _currentAlbum = album;
      _loading = true;
      _selected.clear();
    });
    await _loadAssets(reset: true);
  }

  void _toggleSelect(AssetEntity asset) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else {
        final isUnlimited = widget.maxSelect == -1;
        if (isUnlimited || _selected.length < widget.maxSelect) {
          _selected.add(asset);
        } else if (widget.maxSelect == 1) {
          _selected
            ..clear()
            ..add(asset);
        }
      }
    });
  }

  void _removeSelected(AssetEntity asset) {
    HapticFeedback.lightImpact();
    setState(() => _selected.remove(asset));
  }

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    final source = widget.mode == NexusPickerMode.videoOnly
        ? ImageSource.camera
        : ImageSource.camera;

    XFile? file;
    if (widget.mode == NexusPickerMode.videoOnly) {
      file = await picker.pickVideo(source: source);
    } else {
      file = await picker.pickImage(source: source);
    }

    if (file == null || !mounted) return;
    final ioFile = File(file.path);
    final isVideo = widget.mode == NexusPickerMode.videoOnly;

    if (!isVideo && widget.cropConfig != null) {
      final cropped = await _cropImage(ioFile, widget.cropConfig!);
      if (!mounted) return;
      Navigator.of(context).pop([NexusMediaFile(file: cropped ?? ioFile)]);
    } else {
      Uint8List? thumb;
      int? dur;
      if (isVideo) {
        thumb = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 320,
          quality: 75,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop([
        NexusMediaFile(file: ioFile, isVideo: isVideo, thumbnail: thumb, durationMs: dur)
      ]);
    }
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _confirming) return;
    setState(() => _confirming = true);

    try {
      final results = <NexusMediaFile>[];
      for (final asset in _selected) {
        final file = await asset.originFile;
        if (file == null) continue;

        if (asset.type == AssetType.video) {
          final thumbBytes = await VideoThumbnail.thumbnailData(
            video: file.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 320,
            quality: 75,
          );
          results.add(NexusMediaFile(
            file: file,
            isVideo: true,
            thumbnail: thumbBytes,
            durationMs: asset.duration * 1000,
          ));
        } else {
          if (widget.cropConfig != null && widget.maxSelect == 1) {
            final cropped = await _cropImage(file, widget.cropConfig!);
            results.add(NexusMediaFile(file: cropped ?? file));
          } else {
            results.add(NexusMediaFile(file: file));
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pop(results);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar mídia: $e')),
        );
      }
    }
  }

  Future<File?> _cropImage(File file, NexusCropConfig config) async {
    final theme = context.nexusTheme;
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: config.aspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar',
          toolbarColor: theme.backgroundPrimary,
          toolbarWidgetColor: theme.textPrimary,
          activeControlsWidgetColor: theme.accentPrimary,
          backgroundColor: theme.backgroundPrimary,
          lockAspectRatio: config.aspectRatio != null,
          cropStyle: config.useCircleCrop ? CropStyle.circle : CropStyle.rectangle,
        ),
        IOSUiSettings(
          title: 'Recortar',
          aspectRatioLockEnabled: config.aspectRatio != null,
          resetAspectRatioEnabled: config.aspectRatio == null,
          cropStyle: config.useCircleCrop ? CropStyle.circle : CropStyle.rectangle,
        ),
      ],
    );
    if (cropped == null) return null;
    return File(cropped.path);
  }

  void _openFullPreview(AssetEntity asset) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullPreviewScreen(
          asset: asset,
          isSelected: _selected.contains(asset),
          onToggle: () => _toggleSelect(asset),
          accentColor: context.nexusTheme.accentPrimary,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.nexusTheme;
    final r = context.r;

    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      snap: true,
      snapSizes: const [0.5, 0.93, 0.97],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHandle(theme, r),
              _buildHeader(theme, r),
              _buildTabBar(theme, r),
              if (_permissionDenied)
                _buildPermissionDenied(theme, r)
              else
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Tab 0: Galeria
                      _loading
                          ? _buildShimmerGrid(theme, r)
                          : _buildGrid(theme, r, scrollController),
                      // Tab 1: Câmera (abre câmera ao entrar na tab)
                      _buildCameraTab(theme, r),
                    ],
                  ),
                ),
              if (_selected.isNotEmpty) _buildConfirmBar(theme, r),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle(NexusThemeData theme, Responsive r) {
    return Padding(
      padding: EdgeInsets.only(top: r.s(10), bottom: r.s(6)),
      child: Container(
        width: r.s(36),
        height: r.s(4),
        decoration: BoxDecoration(
          color: theme.divider,
          borderRadius: BorderRadius.circular(r.s(2)),
        ),
      ),
    );
  }

  Widget _buildHeader(NexusThemeData theme, Responsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(4), r.s(12), r.s(8)),
      child: Row(
        children: [
          // Seletor de álbum
          Expanded(
            child: GestureDetector(
              onTap: _albums.length > 1 ? () => _showAlbumPicker(theme, r) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentAlbum?.name ?? 'Galeria',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.fs(17),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (_albums.length > 1) ...[
                    SizedBox(width: r.s(4)),
                    AnimatedRotation(
                      turns: 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.accentPrimary,
                        size: r.s(22),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Badge de contagem
          if (widget.maxSelect != 1 && _selected.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
              decoration: BoxDecoration(
                gradient: theme.accentGradient,
                borderRadius: BorderRadius.circular(r.s(12)),
                boxShadow: [
                  BoxShadow(
                    color: theme.accentPrimary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.maxSelect == -1
                    ? '${_selected.length}'
                    : '${_selected.length}/${widget.maxSelect}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          SizedBox(width: r.s(8)),
          // Fechar
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: r.s(32),
              height: r.s(32),
              decoration: BoxDecoration(
                color: theme.surfacePrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: theme.textSecondary,
                size: r.s(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(NexusThemeData theme, Responsive r) {
    return Container(
      margin: EdgeInsets.fromLTRB(r.s(16), 0, r.s(16), r.s(8)),
      height: r.s(36),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(10)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: theme.accentGradient,
          borderRadius: BorderRadius.circular(r.s(8)),
          boxShadow: [
            BoxShadow(
              color: theme.accentPrimary.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: theme.textSecondary,
        labelStyle: TextStyle(
          fontSize: r.fs(13),
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: r.fs(13),
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Galeria'),
          Tab(text: 'Câmera'),
        ],
        onTap: (index) {
          if (index == 1) {
            _openCamera();
            // Volta para galeria após abrir câmera
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _tabController.animateTo(0);
            });
          }
        },
      ),
    );
  }

  Widget _buildShimmerGrid(NexusThemeData theme, Responsive r) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (_, __) {
        return GridView.builder(
          padding: EdgeInsets.all(r.s(2)),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: r.s(2),
            mainAxisSpacing: r.s(2),
          ),
          itemCount: 24,
          itemBuilder: (_, __) => _ShimmerCell(
            baseColor: theme.shimmerBase,
            highlightColor: theme.shimmerHighlight,
            animValue: _shimmerAnimation.value,
          ),
        );
      },
    );
  }

  Widget _buildGrid(
      NexusThemeData theme, Responsive r, ScrollController sc) {
    if (_assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                color: theme.textSecondary, size: r.s(48)),
            SizedBox(height: r.s(12)),
            Text(
              'Nenhuma mídia encontrada',
              style: TextStyle(color: theme.textSecondary, fontSize: r.fs(14)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: sc,
      padding: EdgeInsets.all(r.s(2)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: r.s(2),
        mainAxisSpacing: r.s(2),
      ),
      itemCount: _assets.length + (_loadingMore ? 3 : 0),
      itemBuilder: (_, i) {
        if (i >= _assets.length) {
          return AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (_, __) => _ShimmerCell(
              baseColor: theme.shimmerBase,
              highlightColor: theme.shimmerHighlight,
              animValue: _shimmerAnimation.value,
            ),
          );
        }
        final asset = _assets[i];
        final selIdx = _selected.indexOf(asset);
        final isSelected = selIdx >= 0;
        return _AssetThumbnail(
          key: ValueKey(asset.id),
          asset: asset,
          isSelected: isSelected,
          selectionIndex: isSelected && widget.maxSelect != 1 ? selIdx + 1 : null,
          onTap: () => _toggleSelect(asset),
          onLongPress: () => _openFullPreview(asset),
          accentColor: theme.accentPrimary,
          accentGradient: theme.accentGradient,
          shimmerBase: theme.shimmerBase,
          shimmerHighlight: theme.shimmerHighlight,
          shimmerAnim: _shimmerAnimation,
        );
      },
    );
  }

  Widget _buildCameraTab(NexusThemeData theme, Responsive r) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(72),
            height: r.s(72),
            decoration: BoxDecoration(
              gradient: theme.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.accentPrimary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              widget.mode == NexusPickerMode.videoOnly
                  ? Icons.videocam_rounded
                  : Icons.camera_alt_rounded,
              color: Colors.white,
              size: r.s(32),
            ),
          ),
          SizedBox(height: r.s(16)),
          Text(
            widget.mode == NexusPickerMode.videoOnly
                ? 'Gravar vídeo'
                : 'Tirar foto',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: r.fs(16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(8)),
          Text(
            'Toque na aba Câmera para abrir',
            style: TextStyle(color: theme.textSecondary, fontSize: r.fs(13)),
          ),
        ],
      ),
    );
  }

  void _showAlbumPicker(NexusThemeData theme, Responsive r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
            child: Text(
              'Selecionar álbum',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(color: theme.divider, height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _albums.length,
              itemBuilder: (_, i) {
                final album = _albums[i];
                final isSelected = album.id == _currentAlbum?.id;
                return ListTile(
                  leading: FutureBuilder<List<AssetEntity>>(
                    future: album.getAssetListPaged(page: 0, size: 1),
                    builder: (_, snap) {
                      if (snap.hasData && snap.data!.isNotEmpty) {
                        return _AlbumThumb(asset: snap.data!.first);
                      }
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.surfacePrimary,
                          borderRadius: BorderRadius.circular(r.s(8)),
                        ),
                        child: Icon(Icons.photo, color: theme.textSecondary, size: 20),
                      );
                    },
                  ),
                  title: Text(
                    album.name,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded,
                          color: theme.accentPrimary, size: 22)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _switchAlbum(album);
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildConfirmBar(NexusThemeData theme, Responsive r) {
    final isMulti = widget.maxSelect != 1;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(r.s(12), r.s(10), r.s(12), r.s(10)),
        decoration: BoxDecoration(
          color: theme.backgroundSecondary,
          border: Border(
            top: BorderSide(color: theme.divider.withValues(alpha: 0.4)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila de previews selecionados (multi-select)
            if (isMulti && _selected.isNotEmpty)
              SizedBox(
                height: r.s(60),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(bottom: r.s(8)),
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => SizedBox(width: r.s(6)),
                  itemBuilder: (_, i) {
                    final asset = _selected[i];
                    return _SelectedPreviewChip(
                      asset: asset,
                      onRemove: () => _removeSelected(asset),
                      accentColor: theme.accentPrimary,
                      r: r,
                    );
                  },
                ),
              ),
            // Botão de confirmação
            Row(
              children: [
                if (!isMulti)
                  Expanded(
                    child: Text(
                      '1 item selecionado',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(13),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      widget.maxSelect == -1
                          ? '${_selected.length} selecionado${_selected.length > 1 ? 's' : ''}'
                          : '${_selected.length} de ${widget.maxSelect}',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(13),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: _confirming ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(22)),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _confirming
                            ? LinearGradient(
                                colors: [
                                  theme.accentPrimary.withValues(alpha: 0.5),
                                  theme.accentPrimary.withValues(alpha: 0.5),
                                ],
                              )
                            : theme.accentGradient,
                        borderRadius: BorderRadius.circular(r.s(22)),
                        boxShadow: _confirming
                            ? []
                            : [
                                BoxShadow(
                                  color: theme.accentPrimary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.s(28),
                          vertical: r.s(12),
                        ),
                        child: _confirming
                            ? SizedBox(
                                width: r.s(18),
                                height: r.s(18),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isMulti
                                    ? 'Enviar (${_selected.length})'
                                    : 'Usar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: r.fs(14),
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied(NexusThemeData theme, Responsive r) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(r.s(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.s(80),
                height: r.s(80),
                decoration: BoxDecoration(
                  color: theme.surfacePrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: theme.textSecondary,
                  size: r.s(36),
                ),
              ),
              SizedBox(height: r.s(20)),
              Text(
                'Acesso à galeria necessário',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: r.fs(17),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: r.s(10)),
              Text(
                'Para enviar fotos e vídeos, permita o acesso à galeria nas configurações do dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.fs(14),
                  height: 1.5,
                ),
              ),
              SizedBox(height: r.s(24)),
              ElevatedButton.icon(
                onPressed: () => PhotoManager.openSetting(),
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Abrir configurações'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(24),
                    vertical: r.s(12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(22)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer cell
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerCell extends StatelessWidget {
  final Color baseColor;
  final Color highlightColor;
  final double animValue;

  const _ShimmerCell({
    required this.baseColor,
    required this.highlightColor,
    required this.animValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(animValue - 1, 0),
          end: Alignment(animValue, 0),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnail de asset individual
// ─────────────────────────────────────────────────────────────────────────────

class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final int? selectionIndex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Color accentColor;
  final LinearGradient accentGradient;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Animation<double> shimmerAnim;

  const _AssetThumbnail({
    super.key,
    required this.asset,
    required this.isSelected,
    this.selectionIndex,
    required this.onTap,
    required this.onLongPress,
    required this.accentColor,
    required this.accentGradient,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.shimmerAnim,
  });

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail>
    with SingleTickerProviderStateMixin {
  Uint8List? _thumb;
  bool _loaded = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleController;
    _loadThumb();
  }

  @override
  void didUpdateWidget(_AssetThumbnail old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      if (widget.isSelected) {
        _scaleController.reverse().then((_) => _scaleController.forward());
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadThumb() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(240, 240),
      quality: 85,
    );
    if (mounted) {
      setState(() {
        _thumb = data;
        _loaded = true;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String? _getTypeBadge() {
    final title = widget.asset.title?.toLowerCase() ?? '';
    if (title.endsWith('.gif')) return 'GIF';
    if (title.endsWith('.heic') || title.endsWith('.heif')) return 'HEIC';
    if (title.endsWith('.raw') || title.endsWith('.dng')) return 'RAW';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.type == AssetType.video;
    final typeBadge = _getTypeBadge();

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail ou shimmer
            if (!_loaded)
              AnimatedBuilder(
                animation: widget.shimmerAnim,
                builder: (_, __) => _ShimmerCell(
                  baseColor: widget.shimmerBase,
                  highlightColor: widget.shimmerHighlight,
                  animValue: widget.shimmerAnim.value,
                ),
              )
            else if (_thumb != null)
              Image.memory(_thumb!, fit: BoxFit.cover)
            else
              Container(color: widget.shimmerBase),

            // Overlay de seleção
            AnimatedOpacity(
              opacity: widget.isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accentColor.withValues(alpha: 0.45),
                      widget.accentColor.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),

            // Badge de vídeo (duração)
            if (isVideo)
              Positioned(
                bottom: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 11),
                      const SizedBox(width: 2),
                      Text(
                        _formatDuration(widget.asset.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Badge de tipo (GIF, HEIC, RAW)
            if (typeBadge != null)
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeBadge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // Círculo de seleção
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.isSelected ? widget.accentGradient : null,
                  color: widget.isSelected ? null : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1.8,
                  ),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: widget.isSelected
                    ? Center(
                        child: widget.selectionIndex != null
                            ? Text(
                                '${widget.selectionIndex}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : const Icon(Icons.check_rounded,
                                color: Colors.white, size: 15),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de preview na barra de confirmação
// ─────────────────────────────────────────────────────────────────────────────

class _SelectedPreviewChip extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onRemove;
  final Color accentColor;
  final Responsive r;

  const _SelectedPreviewChip({
    required this.asset,
    required this.onRemove,
    required this.accentColor,
    required this.r,
  });

  @override
  State<_SelectedPreviewChip> createState() => _SelectedPreviewChipState();
}

class _SelectedPreviewChipState extends State<_SelectedPreviewChip> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(120, 120),
      quality: 80,
    );
    if (mounted) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(r.s(8)),
          child: SizedBox(
            width: r.s(48),
            height: r.s(48),
            child: _thumb != null
                ? Image.memory(_thumb!, fit: BoxFit.cover)
                : Container(color: Colors.grey[800]),
          ),
        ),
        Positioned(
          top: -5,
          right: -5,
          child: GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              width: r.s(18),
              height: r.s(18),
              decoration: BoxDecoration(
                color: widget.accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 11),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnail de álbum
// ─────────────────────────────────────────────────────────────────────────────

class _AlbumThumb extends StatefulWidget {
  final AssetEntity asset;
  const _AlbumThumb({required this.asset});

  @override
  State<_AlbumThumb> createState() => _AlbumThumbState();
}

class _AlbumThumbState extends State<_AlbumThumb> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(88, 88),
      quality: 75,
    );
    if (mounted) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: _thumb != null
            ? Image.memory(_thumb!, fit: BoxFit.cover)
            : Container(color: Colors.grey[800]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela de preview fullscreen (long press)
// ─────────────────────────────────────────────────────────────────────────────

class _FullPreviewScreen extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onToggle;
  final Color accentColor;

  const _FullPreviewScreen({
    required this.asset,
    required this.isSelected,
    required this.onToggle,
    required this.accentColor,
  });

  @override
  State<_FullPreviewScreen> createState() => _FullPreviewScreenState();
}

class _FullPreviewScreenState extends State<_FullPreviewScreen> {
  Uint8List? _fullThumb;
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.isSelected;
    _load();
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(1080, 1080),
      quality: 95,
    );
    if (mounted) setState(() => _fullThumb = data);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.type == AssetType.video;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        body: Stack(
          children: [
            // Imagem centralizada
            Center(
              child: _fullThumb != null
                  ? Hero(
                      tag: widget.asset.id,
                      child: Image.memory(
                        _fullThumb!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            // Ícone de vídeo
            if (isVideo)
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 36),
                ),
              ),
            // Botão fechar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
            // Botão selecionar
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selected = !_selected);
                    widget.onToggle();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selected
                          ? widget.accentColor
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _selected
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: _selected
                          ? [
                              BoxShadow(
                                color: widget.accentColor.withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      _selected ? '✓  Selecionado' : 'Selecionar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
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
}
