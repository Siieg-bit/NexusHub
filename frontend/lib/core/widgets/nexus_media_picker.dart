import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
  final Uint8List? thumbnail; // Thumbnail do vídeo (null para imagens)
  final int? durationMs; // Duração do vídeo em ms (null para imagens)

  const NexusMediaFile({
    required this.file,
    this.isVideo = false,
    this.thumbnail,
    this.durationMs,
  });
}

/// Modo de seleção do picker.
enum NexusPickerMode {
  /// Apenas imagens.
  imageOnly,
  /// Apenas vídeos.
  videoOnly,
  /// Imagens e vídeos.
  all,
}

/// Configuração do crop para imagens.
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
/// [maxSelect] — máximo de arquivos selecionáveis (padrão: 1).
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

class _NexusMediaPickerSheetState extends State<NexusMediaPickerSheet> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  bool _loading = true;
  bool _permissionDenied = false;
  int _page = 0;
  static const int _pageSize = 80;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else if (_selected.length < widget.maxSelect) {
        _selected.add(asset);
      } else if (widget.maxSelect == 1) {
        // Seleção única: substitui
        _selected
          ..clear()
          ..add(asset);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final results = <NexusMediaFile>[];
      for (final asset in _selected) {
        final file = await asset.originFile;
        if (file == null) continue;

        if (asset.type == AssetType.video) {
          // Gerar thumbnail do vídeo
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
          // Imagem: aplicar crop se configurado e seleção única
          if (widget.cropConfig != null && widget.maxSelect == 1) {
            final cropped = await _cropImage(file, widget.cropConfig!);
            results.add(NexusMediaFile(file: cropped ?? file));
          } else {
            results.add(NexusMediaFile(file: file));
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Fecha loading
        Navigator.of(context).pop(results); // Fecha picker com resultado
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Fecha loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar mídia: $e')),
        );
      }
    }
  }

  Future<File?> _cropImage(File file, NexusCropConfig config) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: config.aspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: config.aspectRatio != null,
          cropStyle: config.useCircleCrop
              ? CropStyle.circle
              : CropStyle.rectangle,
        ),
        IOSUiSettings(
          title: 'Recortar',
          aspectRatioLockEnabled: config.aspectRatio != null,
          resetAspectRatioEnabled: config.aspectRatio == null,
          cropStyle: config.useCircleCrop
              ? CropStyle.circle
              : CropStyle.rectangle,
        ),
      ],
    );
    if (cropped == null) return null;
    return File(cropped.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.nexusTheme;
    final r = context.r; // Responsive

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
          ),
          child: Column(
            children: [
              _buildHandle(r),
              _buildHeader(theme, r),
              if (_permissionDenied)
                _buildPermissionDenied(theme, r)
              else if (_loading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: _buildGrid(theme, r, scrollController),
                ),
              if (_selected.isNotEmpty) _buildConfirmBar(theme, r),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle(ResponsiveHelper r) {
    return Padding(
      padding: EdgeInsets.only(top: r.s(8), bottom: r.s(4)),
      child: Container(
        width: r.s(40),
        height: r.s(4),
        decoration: BoxDecoration(
          color: Colors.grey[600],
          borderRadius: BorderRadius.circular(r.s(2)),
        ),
      ),
    );
  }

  Widget _buildHeader(NexusThemeData theme, ResponsiveHelper r) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
      child: Row(
        children: [
          // Album selector
          Expanded(
            child: GestureDetector(
              onTap: _albums.length > 1 ? _showAlbumPicker : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentAlbum?.name ?? 'Galeria',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_albums.length > 1) ...[
                    SizedBox(width: r.s(4)),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: theme.textSecondary, size: r.s(20)),
                  ],
                ],
              ),
            ),
          ),
          // Contagem de seleção
          if (widget.maxSelect > 1 && _selected.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(10), vertical: r.s(4)),
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Text(
                '${_selected.length}/${widget.maxSelect}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SizedBox(width: r.s(8)),
          // Fechar
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.close_rounded,
                color: theme.textSecondary, size: r.s(24)),
          ),
        ],
      ),
    );
  }

  void _showAlbumPicker() {
    final theme = context.nexusTheme;
    final r = context.r; // Responsive
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(16))),
      ),
      builder: (_) => ListView.builder(
        shrinkWrap: true,
        itemCount: _albums.length,
        itemBuilder: (_, i) {
          final album = _albums[i];
          final isSelected = album.id == _currentAlbum?.id;
          return ListTile(
            title: Text(album.name,
                style: TextStyle(color: theme.textPrimary)),
            trailing: isSelected
                ? Icon(Icons.check_rounded, color: theme.accent)
                : null,
            onTap: () {
              Navigator.pop(context);
              _switchAlbum(album);
            },
          );
        },
      ),
    );
  }

  Widget _buildGrid(
      NexusThemeData theme, ResponsiveHelper r, ScrollController sc) {
    return GridView.builder(
      controller: sc,
      padding: EdgeInsets.all(r.s(2)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: r.s(2),
        mainAxisSpacing: r.s(2),
      ),
      itemCount: _assets.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _assets.length) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ));
        }
        final asset = _assets[i];
        final selIdx = _selected.indexOf(asset);
        final isSelected = selIdx >= 0;
        return _AssetThumbnail(
          asset: asset,
          isSelected: isSelected,
          selectionIndex: isSelected && widget.maxSelect > 1 ? selIdx + 1 : null,
          onTap: () => _toggleSelect(asset),
          accentColor: theme.accent,
        );
      },
    );
  }

  Widget _buildConfirmBar(NexusThemeData theme, ResponsiveHelper r) {
    final isMulti = widget.maxSelect > 1;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(12)),
        decoration: BoxDecoration(
          color: theme.backgroundSecondary,
          border: Border(
              top: BorderSide(
                  color: theme.divider.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            if (isMulti)
              Text(
                '${_selected.length} selecionado${_selected.length > 1 ? 's' : ''}',
                style: TextStyle(
                    color: theme.textSecondary, fontSize: r.fs(13)),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(20))),
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(24), vertical: r.s(10)),
              ),
              child: Text(
                isMulti ? 'Enviar (${_selected.length})' : 'Usar',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: r.fs(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied(NexusThemeData theme, ResponsiveHelper r) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                color: theme.textSecondary, size: r.s(48)),
            SizedBox(height: r.s(12)),
            Text(
              'Permissão necessária',
              style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: r.s(8)),
            Text(
              'Permita o acesso à galeria nas configurações do dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.textSecondary, fontSize: r.fs(13)),
            ),
            SizedBox(height: r.s(16)),
            ElevatedButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text('Abrir configurações'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de thumbnail individual
// ─────────────────────────────────────────────────────────────────────────────

class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final int? selectionIndex;
  final VoidCallback onTap;
  final Color accentColor;

  const _AssetThumbnail({
    required this.asset,
    required this.isSelected,
    this.selectionIndex,
    required this.onTap,
    required this.accentColor,
  });

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _thumb;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
      quality: 80,
    );
    if (mounted) setState(() {
      _thumb = data;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.type == AssetType.video;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          if (_thumb != null)
            Image.memory(_thumb!, fit: BoxFit.cover)
          else
            Container(color: Colors.grey[850]),

          // Overlay de seleção
          if (widget.isSelected)
            Container(color: widget.accentColor.withValues(alpha: 0.35)),

          // Badge de vídeo (duração)
          if (isVideo)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(widget.asset.duration),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

          // Círculo de seleção
          Positioned(
            top: 6,
            right: 6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected
                    ? widget.accentColor
                    : Colors.transparent,
                border: Border.all(
                  color: widget.isSelected
                      ? widget.accentColor
                      : Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: widget.isSelected
                  ? Center(
                      child: widget.selectionIndex != null
                          ? Text(
                              '${widget.selectionIndex}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            )
                          : const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
