import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// Create Story Screen — Criação de stories estilo Amino/Instagram.
///
/// Suporta 3 tipos:
///   - image: foto da galeria com texto overlay opcional
///   - text: texto puro com background colorido
///   - video: vídeo curto (placeholder para futura implementação)
class CreateStoryScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CreateStoryScreen({super.key, required this.communityId});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  String _type = 'text'; // text, image, video
  final _textController = TextEditingController();
  String? _mediaUrl;
  bool _isSubmitting = false;
  int _selectedBgIndex = 0;
  VideoPlayerController? _videoPreviewController;

  static const _bgColors = [
    Color(0xFF0D1B2A),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF2196F3),
    Color(0xFF00BCD4),
    Color(0xFF4CAF50),
    Color(0xFFFF5722),
    Color(0xFFFF9800),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  static const _bgHexCodes = [
    '#0D1B2A',
    '#E91E63',
    '#9C27B0',
    '#2196F3',
    '#00BCD4',
    '#4CAF50',
    '#FF5722',
    '#FF9800',
    '#795548',
    '#607D8B',
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (image == null) return;

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await image.readAsBytes();
      final path =
          'stories/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await SupabaseService.client.storage
          .from('post_media')
          .uploadBinary(path, bytes);
      if (!mounted) return;
      final url =
          SupabaseService.client.storage.from('post_media').getPublicUrl(path);

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
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (!mounted) return;
    if (video == null) return;

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await video.readAsBytes();
      final path =
          'stories/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${video.name}';
      await SupabaseService.client.storage.from('post_media').uploadBinary(
          path, bytes,
          fileOptions: const FileOptions(contentType: 'video/mp4'));
      final url =
          SupabaseService.client.storage.from('post_media').getPublicUrl(path);

      // Inicializar preview do vídeo
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
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitStory() async {
    if (_type == 'text' && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(s.writeStoryHint),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (_type == 'image' && _mediaUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(s.selectImage2),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      // RPC atômica: cria story + reputação + validação de membro
      await SupabaseService.rpc('create_story', params: {
        'p_community_id': widget.communityId,
        'p_media_url': _mediaUrl ?? '',
        'p_media_type': _type,
        'p_caption': _textController.text.trim().isNotEmpty
            ? _textController.text.trim()
            : null,
        'p_background_color':
            _type == 'text' ? _bgHexCodes[_selectedBgIndex] : '#000000',
        'p_duration_seconds': _type == 'text' ? 5 : 7,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(s.storyPublished),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    'Criar Story',
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
                            ? AppTheme.accentColor.withValues(alpha: 0.5)
                            : AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(r.s(20)),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: r.s(16),
                              height: r.s(16),
                              child: CircularProgressIndicator(
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
                      ? _bgColors[_selectedBgIndex]
                      : context.cardBg,
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
                              fontSize: r.fs(22),
                              fontWeight: FontWeight.w800,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: s.writePost,
                              hintStyle: TextStyle(
                                  color: Colors.white38, fontSize: r.fs(22)),
                              border: InputBorder.none,
                            ),
                            textAlign: TextAlign.center,
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
                            decoration: const InputDecoration(
                              hintText: s.addCaptionHint,
                              hintStyle: TextStyle(color: Colors.white54),
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
                  ],
                ),
              ),
            ),

            // ── Color picker (apenas para tipo texto) ──
            if (_type == 'text')
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                child: SizedBox(
                  height: r.s(40),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _bgColors.length,
                    itemBuilder: (_, i) {
                      final isSelected = _selectedBgIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedBgIndex = i),
                        child: Container(
                          width: r.s(36),
                          height: r.s(36),
                          margin: EdgeInsets.only(right: r.s(8)),
                          decoration: BoxDecoration(
                            color: _bgColors[i],
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: r.s(3))
                                : Border.all(color: Colors.white24, width: 1),
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
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(8)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(r.s(20)),
          border: isSelected
              ? Border.all(color: AppTheme.accentColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: r.s(16),
                color: isSelected ? AppTheme.accentColor : Colors.grey[500]),
            SizedBox(width: r.s(6)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accentColor : Colors.grey[500],
                fontSize: r.fs(13),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
