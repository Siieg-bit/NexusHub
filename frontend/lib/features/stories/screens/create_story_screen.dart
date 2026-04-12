import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/post_model.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Create Story Screen — Criação de stories estilo Amino/Instagram.
///
/// Melhorias:
///   - Mais backgrounds: sólidos + gradientes
///   - Seletor de fonte (6 opções)
///   - Tamanho de texto ajustável
///   - Alinhamento de texto (esquerda, centro, direita)
///   - Duração configurável (3s, 5s, 7s, 10s, 15s)
///   - Stickers de texto decorativos
///   - Filtro de imagem básico (brilho)
class CreateStoryScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;
  const CreateStoryScreen({super.key, required this.communityId, this.editingPost});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  String _type = 'text'; // text, image, video
  final _textController = TextEditingController();
  String? _mediaUrl;
  bool _isSubmitting = false;
  int _selectedBgIndex = 0;
  int _selectedFontIndex = 0;
  double _fontSize = 22;
  TextAlign _textAlign = TextAlign.center;
  int _durationSeconds = 5;
  VideoPlayerController? _videoPreviewController;

  bool get _isEditing => widget.editingPost != null;

  // Backgrounds sólidos
  static final _bgColors = [
    const Color(0xFF0D1B2A),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF2196F3),
    const Color(0xFF00BCD4),
    const Color(0xFF4CAF50),
    const Color(0xFFFF5722),
    const Color(0xFFFF9800),
    const Color(0xFF795548),
    const Color(0xFF607D8B),
    const Color(0xFF1A1A2E),
    const Color(0xFF16213E),
    const Color(0xFF0F3460),
    const Color(0xFF533483),
    const Color(0xFF2B2D42),
  ];

  static final _bgHexCodes = [
    '#0D1B2A', '#E91E63', '#9C27B0', '#2196F3', '#00BCD4',
    '#4CAF50', '#FF5722', '#FF9800', '#795548', '#607D8B',
    '#1A1A2E', '#16213E', '#0F3460', '#533483', '#2B2D42',
  ];

  // Gradientes
  static final _bgGradients = <List<Color>>[
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
    [const Color(0xFFf093fb), const Color(0xFFf5576c)],
    [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
    [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
    [const Color(0xFFfa709a), const Color(0xFFfee140)],
    [const Color(0xFFa18cd1), const Color(0xFFfbc2eb)],
    [const Color(0xFF30cfd0), const Color(0xFF330867)],
    [const Color(0xFFf6d365), const Color(0xFFfda085)],
  ];

  // Fontes disponíveis
  static const _fontFamilies = [
    'Default',
    'Serif',
    'Monospace',
    'Cursive',
  ];

  static const _fontStyles = [
    TextStyle(fontWeight: FontWeight.w800),
    TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600),
    TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
    TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700),
  ];

  static const _durationOptions = [3, 5, 7, 10, 15];

  bool get _isGradient =>
      _selectedBgIndex >= _bgColors.length &&
      _selectedBgIndex < _bgColors.length + _bgGradients.length;

  int get _gradientIndex => _selectedBgIndex - _bgColors.length;

  Future<void> _pickImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted || image == null) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await image.readAsBytes();
      final path =
          'stories/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await SupabaseService.client.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      if (!mounted) return;
      final url =
          SupabaseService.client.storage.from('post-media').getPublicUrl(path);

      if (!mounted) return;
      setState(() {
        _mediaUrl = url;
        _type = 'image';
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    final s = getStrings();
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (!mounted || video == null) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await video.readAsBytes();
      final path =
          'stories/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${video.name}';
      await SupabaseService.client.storage.from('post-media').uploadBinary(
          path, bytes,
          fileOptions: const FileOptions(contentType: 'video/mp4'));
      final url =
          SupabaseService.client.storage.from('post-media').getPublicUrl(path);

      _videoPreviewController?.dispose();
      _videoPreviewController =
          VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPreviewController!.initialize();
      if (!mounted) return;
      _videoPreviewController!.setLooping(true);
      _videoPreviewController!.play();

      if (!mounted) return;
      setState(() {
        _mediaUrl = url;
        _type = 'video';
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitStory() async {
    final s = getStrings();
    if (_type == 'text' && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.writeStoryHint),
          backgroundColor: context.nexusTheme.error,
        ),
      );
      return;
    }
    if (_type == 'image' && _mediaUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.selectImage2),
          backgroundColor: context.nexusTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      // ── Modo de EDIÇÃO ──
      if (_isEditing) {
        String bgColor;
        if (_isGradient) {
          final g = _bgGradients[_gradientIndex];
          final c = g[0];
          final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
          final gv = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
          final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
          bgColor = '#$r$gv$b';
        } else if (_selectedBgIndex < _bgColors.length) {
          bgColor = _bgHexCodes[_selectedBgIndex];
        } else {
          bgColor = '#0D1B2A';
        }

        try {
          await SupabaseService.table('stories').update({
            'media_url': _mediaUrl ?? '',
            'media_type': _type,
            'caption': _textController.text.trim().isNotEmpty
                ? _textController.text.trim()
                : null,
            'background_color': bgColor,
            'duration_seconds': _durationSeconds,
          }).eq('id', widget.editingPost!.id);

          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.postUpdated),
                backgroundColor: context.nexusTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.anErrorOccurredTryAgain),
                backgroundColor: context.nexusTheme.error,
              ),
            );
          }
        }
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      // ── Modo de CRIAÇÃO ──
      String bgColor;
      if (_isGradient) {
        final g = _bgGradients[_gradientIndex];
        final c = g[0];
        final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
        final gv = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
        final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
        bgColor = '#$r$gv$b';
      } else if (_selectedBgIndex < _bgColors.length) {
        bgColor = _bgHexCodes[_selectedBgIndex];
      } else {
        bgColor = '#0D1B2A';
      }

      await SupabaseService.rpc('create_story', params: {
        'p_community_id': widget.communityId,
        'p_media_url': _mediaUrl ?? '',
        'p_media_type': _type,
        'p_caption': _textController.text.trim().isNotEmpty
            ? _textController.text.trim()
            : null,
        'p_background_color': bgColor,
        'p_duration_seconds': _durationSeconds,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.storyPublished),
            backgroundColor: context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromPost(widget.editingPost!);
    }
  }

  void _populateFromPost(PostModel post) {
    // Stories guardam dados em storyData
    final sd = post.storyData ?? {};
    _textController.text = sd['caption'] as String? ?? post.content;
    _type = sd['media_type'] as String? ?? 'text';
    _mediaUrl = sd['media_url'] as String?;
    _durationSeconds = (sd['duration_seconds'] as num?)?.toInt() ?? 5;

    // Restaurar background
    final bgColor = sd['background_color'] as String?;
    if (bgColor != null) {
      final idx = _bgHexCodes.indexWhere(
        (hex) => hex.toLowerCase() == bgColor.toLowerCase(),
      );
      if (idx >= 0) _selectedBgIndex = idx;
    }

    // Restaurar fonte e tamanho
    final fontIdx = sd['font_index'] as int?;
    if (fontIdx != null && fontIdx < _fontFamilies.length) {
      _selectedFontIndex = fontIdx;
    }
    final fs = sd['font_size'] as num?;
    if (fs != null) _fontSize = fs.toDouble();
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white, size: r.s(28)),
                  ),
                  const Spacer(),
                  Text(
                    _isEditing ? s.editPost : 'Criar Story',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitStory,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(8)),
                      decoration: BoxDecoration(
                        color: _isSubmitting
                            ? context.nexusTheme.accentSecondary.withValues(alpha: 0.5)
                            : context.nexusTheme.accentSecondary,
                        borderRadius: BorderRadius.circular(r.s(20)),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: r.s(16),
                              height: r.s(16),
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              s.publish,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: r.fs(13),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Type selector ──
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              child: Row(
                children: [
                  _TypeChip(
                    label: s.text,
                    icon: Icons.text_fields_rounded,
                    isSelected: _type == 'text',
                    onTap: () => setState(() {
                      _type = 'text';
                      _mediaUrl = null;
                    }),
                  ),
                  SizedBox(width: r.s(8)),
                  _TypeChip(
                    label: s.image,
                    icon: Icons.image_rounded,
                    isSelected: _type == 'image',
                    onTap: () {
                      if (_mediaUrl == null || _type != 'image') {
                        _pickImage();
                      } else {
                        setState(() => _type = 'image');
                      }
                    },
                  ),
                  SizedBox(width: r.s(8)),
                  _TypeChip(
                    label: s.videoLabel,
                    icon: Icons.videocam_rounded,
                    isSelected: _type == 'video',
                    onTap: () => _pickVideo(),
                  ),
                ],
              ),
            ),

            // ── Preview ──
            Expanded(
              child: Container(
                margin: EdgeInsets.all(r.s(16)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(16)),
                  color: _type == 'text'
                      ? (_isGradient ? null : _bgColors[_selectedBgIndex])
                      : context.nexusTheme.surfacePrimary,
                  gradient: _type == 'text' && _isGradient
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _bgGradients[_gradientIndex],
                        )
                      : null,
                  image: _type == 'image' && _mediaUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_mediaUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Preview de vídeo
                    if (_type == 'video' &&
                        _videoPreviewController != null &&
                        _videoPreviewController!.value.isInitialized)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoPreviewController!.value.size.width,
                            height: _videoPreviewController!.value.size.height,
                            child: VideoPlayer(_videoPreviewController!),
                          ),
                        ),
                      )
                    else if (_type == 'video')
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),

                    // Texto central
                    if (_type == 'text')
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(r.s(24)),
                          child: TextField(
                            controller: _textController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(_fontSize),
                              height: 1.4,
                            ).merge(_fontStyles[_selectedFontIndex]),
                            decoration: InputDecoration(
                              hintText: s.writePost,
                              hintStyle: TextStyle(
                                  color: Colors.white38,
                                  fontSize: r.fs(_fontSize)),
                              border: InputBorder.none,
                            ),
                            textAlign: _textAlign,
                            maxLines: null,
                          ),
                        ),
                      ),

                    // Texto overlay para imagem
                    if (_type == 'image')
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: EdgeInsets.all(r.s(8)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(r.s(12)),
                          ),
                          child: TextField(
                            controller: _textController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(14),
                            ),
                            decoration: InputDecoration(
                              hintText: s.addCaptionHint,
                              hintStyle:
                                  const TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ),

                    // Botão de trocar imagem
                    if (_type == 'image')
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: EdgeInsets.all(r.s(8)),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: r.s(20)),
                          ),
                        ),
                      ),

                    // Duração badge
                    Positioned(
                      top: r.s(12),
                      left: r.s(12),
                      child: GestureDetector(
                        onTap: () {
                          final idx =
                              _durationOptions.indexOf(_durationSeconds);
                          setState(() {
                            _durationSeconds = _durationOptions[
                                (idx + 1) % _durationOptions.length];
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(10), vertical: r.s(5)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(r.s(12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_rounded,
                                  color: Colors.white70, size: r.s(14)),
                              SizedBox(width: r.s(4)),
                              Text(
                                '${_durationSeconds}s',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: r.fs(12),
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Toolbar de texto (apenas para tipo texto) ──
            if (_type == 'text') ...[
              // Seletor de fonte
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                child: SizedBox(
                  height: r.s(36),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fontFamilies.length,
                    itemBuilder: (_, i) {
                      final isSelected = _selectedFontIndex == i;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedFontIndex = i),
                        child: Container(
                          margin: EdgeInsets.only(right: r.s(8)),
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(14), vertical: r.s(6)),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.nexusTheme.accentSecondary
                                    .withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(r.s(16)),
                            border: isSelected
                                ? Border.all(
                                    color: context.nexusTheme.accentSecondary
                                        .withValues(alpha: 0.5))
                                : null,
                          ),
                          child: Text(
                            _fontFamilies[i],
                            style: TextStyle(
                              color: isSelected
                                  ? context.nexusTheme.accentSecondary
                                  : Colors.grey[500],
                              fontSize: r.fs(12),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ).merge(_fontStyles[i]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: r.s(8)),

              // Tamanho de texto + alinhamento
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                child: Row(
                  children: [
                    Icon(Icons.text_decrease_rounded,
                        color: Colors.white54, size: r.s(16)),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 14,
                        max: 40,
                        activeColor: context.nexusTheme.accentSecondary,
                        inactiveColor:
                            Colors.white.withValues(alpha: 0.15),
                        onChanged: (v) =>
                            setState(() => _fontSize = v),
                      ),
                    ),
                    Icon(Icons.text_increase_rounded,
                        color: Colors.white54, size: r.s(16)),
                    SizedBox(width: r.s(12)),
                    // Alinhamento
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_textAlign == TextAlign.left) {
                            _textAlign = TextAlign.center;
                          } else if (_textAlign == TextAlign.center) {
                            _textAlign = TextAlign.right;
                          } else {
                            _textAlign = TextAlign.left;
                          }
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(r.s(8)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(r.s(8)),
                        ),
                        child: Icon(
                          _textAlign == TextAlign.left
                              ? Icons.format_align_left_rounded
                              : _textAlign == TextAlign.center
                                  ? Icons.format_align_center_rounded
                                  : Icons.format_align_right_rounded,
                          color: Colors.white70,
                          size: r.s(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.s(8)),
            ],

            // ── Color/gradient picker (apenas para tipo texto) ──
            if (_type == 'text')
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(4)),
                child: SizedBox(
                  height: r.s(40),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        _bgColors.length + _bgGradients.length + 1,
                    itemBuilder: (_, i) {
                      // Último item: botão de cor personalizada RGB
                      if (i == _bgColors.length + _bgGradients.length) {
                        return GestureDetector(
                          onTap: () async {
                            final currentColor = _selectedBgIndex < _bgColors.length
                                ? _bgColors[_selectedBgIndex]
                                : const Color(0xFF6C5CE7);
                            final picked = await showRGBColorPicker(
                              context,
                              initialColor: currentColor,
                              title: 'Cor de fundo',
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _bgColors.insert(0, picked);
                                _bgHexCodes.insert(0, '#${picked.r.round().toRadixString(16).padLeft(2, '0').toUpperCase()}${picked.g.round().toRadixString(16).padLeft(2, '0').toUpperCase()}${picked.b.round().toRadixString(16).padLeft(2, '0').toUpperCase()}');
                                _selectedBgIndex = 0;
                              });
                            }
                          },
                          child: Container(
                            width: r.s(36),
                            height: r.s(36),
                            margin: EdgeInsets.only(right: r.s(8)),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white38, width: 1.5),
                              gradient: const SweepGradient(
                                colors: [
                                  Color(0xFFE53935), Color(0xFFE91E63),
                                  Color(0xFF9C27B0), Color(0xFF3F51B5),
                                  Color(0xFF2196F3), Color(0xFF4CAF50),
                                  Color(0xFFFFEB3B), Color(0xFFFF9800),
                                  Color(0xFFE53935),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: r.s(18),
                            ),
                          ),
                        );
                      }
                      final isSelected = _selectedBgIndex == i;
                      final isGrad = i >= _bgColors.length;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedBgIndex = i),
                        child: Container(
                          width: r.s(36),
                          height: r.s(36),
                          margin: EdgeInsets.only(right: r.s(8)),
                          decoration: BoxDecoration(
                            color: isGrad
                                ? null
                                : _bgColors[i],
                            gradient: isGrad
                                ? LinearGradient(
                                    colors: _bgGradients[
                                        i - _bgColors.length],
                                  )
                                : null,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white,
                                    width: r.s(3))
                                : Border.all(
                                    color: Colors.white24,
                                    width: 1),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            SizedBox(height: r.s(8)),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends ConsumerWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(8)),
        decoration: BoxDecoration(
          color: isSelected
              ? context.nexusTheme.accentSecondary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(r.s(20)),
          border: isSelected
              ? Border.all(
                  color: context.nexusTheme.accentSecondary.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: r.s(16),
                color: isSelected
                    ? context.nexusTheme.accentSecondary
                    : Colors.grey[500]),
            SizedBox(width: r.s(6)),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? context.nexusTheme.accentSecondary
                    : Colors.grey[500],
                fontSize: r.fs(13),
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
