import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/services/supabase_service.dart';
import '../../chat/widgets/giphy_picker.dart';
import '../../../core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/draft_provider.dart';
import '../../../core/providers/post_provider.dart';
import '../../../core/models/post_model.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Editor de criação e edição de posts do tipo **normal** (texto genérico).
///
/// Para tipos especializados (Blog, Image, Link, Poll, Quiz, Question,
/// Story, Wiki, Chat Público) existem telas dedicadas.
///
/// Quando [editingPost] é fornecido, funciona como editor de edição,
/// pré-preenchendo todos os campos com os dados do post existente.
class CreatePostScreen extends ConsumerStatefulWidget {
  final String communityId;

  /// Tipo de post pré-selecionado (mantido para compatibilidade de rota).
  final String? initialType;

  /// Post existente para edição. Se não-nulo, o editor entra em modo de edição.
  final PostModel? editingPost;

  const CreatePostScreen({
    super.key,
    required this.communityId,
    this.initialType,
    this.editingPost,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _contentController = TextEditingController();
  final _backgroundUrlController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isSubmitting = false;
  final List<String> _mediaUrls = [];
  String? _coverImageUrl;

  // Visibilidade e controle
  String _postVisibility = 'public';
  bool _commentsBlocked = false;
  bool _isPinnedProfile = false;

  // GIF e Música
  String? _gifUrl;
  String? _musicUrl;
  String? _musicTitle;

  // Tags
  final List<String> _tags = [];

  // ── Personalização avançada ──
  Color _textColor = Colors.white;
  Color _bgColor = const Color(0xFF0D1B2A);
  String _fontFamily = 'Plus Jakarta Sans';
  double _bodyFontSize = 15.0;
  String _dividerStyle = 'solid';
  Color _dividerColor = Colors.white24;

  bool get _isEditing => widget.editingPost != null;

  // Fontes disponíveis
  static const _availableFonts = [
    'Plus Jakarta Sans',
    'Roboto',
    'Poppins',
    'Inter',
    'Lato',
    'Montserrat',
    'Open Sans',
    'Nunito',
    'Raleway',
    'Playfair Display',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromPost(widget.editingPost!);
    }
  }

  void _populateFromPost(PostModel post) {
    _titleController.text = post.title ?? '';
    _contentController.text = post.content;
    _coverImageUrl = post.coverImageUrl;
    _backgroundUrlController.text = post.backgroundUrl ?? '';
    _gifUrl = post.editorMetadata.extra['gif_url'] as String?;
    _musicUrl = post.editorMetadata.extra['music_url'] as String?;
    _musicTitle = post.editorMetadata.extra['music_title'] as String?;
    _postVisibility =
        post.editorMetadata.extra['visibility'] as String? ?? 'public';
    _commentsBlocked = post.editorMetadata.extra['comments_blocked'] == true;
    _isPinnedProfile = post.isPinnedProfile;

    // Mídia
    for (final media in post.mediaList) {
      if (media is Map && media['url'] != null) {
        _mediaUrls.add(media['url'] as String);
      }
    }

    // Tags
    if (post.tags.isNotEmpty) {
      _tags.addAll(post.tags);
    }

    // Personalização do editor metadata
    final meta = post.editorMetadata;
    _textColor = _parseColor(meta.bodyStyle.textColor) ?? Colors.white;
    _bgColor = _parseColor(meta.coverStyle.backgroundColor) ??
        const Color(0xFF0D1B2A);
    _fontFamily = meta.bodyStyle.fontFamily ?? 'Plus Jakarta Sans';
    _bodyFontSize = meta.bodyStyle.fontSize ?? 15.0;
    _dividerStyle = meta.dividerStyle.style;
    _dividerColor = _parseColor(meta.dividerStyle.color) ?? Colors.white24;
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      if (cleaned.length == 8) return Color(int.parse(cleaned, radix: 16));
    } catch (_) {}
    return null;
  }

  String _colorToHex(Color color) =>
      // ignore: deprecated_member_use
      '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  // ════════════════════════════════════════════════════════════════════════════
  // UPLOAD HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _pickImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      if (!mounted) return;
      final url = SupabaseService.storage.from('post-media').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _mediaUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(s.errorUploadTryAgain),
              backgroundColor: context.nexusTheme.error),
        );
      }
    }
  }

  Future<void> _pickCoverImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'covers/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      if (!mounted) return;
      final url = SupabaseService.storage.from('post-media').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _coverImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(s.errorUploadTryAgain),
              backgroundColor: context.nexusTheme.error),
        );
      }
    }
  }

  Future<void> _pickBackgroundImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'backgrounds/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      if (!mounted) return;
      final url = SupabaseService.storage.from('post-media').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _backgroundUrlController.text = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(s.errorUploadTryAgain),
              backgroundColor: context.nexusTheme.error),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAGS
  // ════════════════════════════════════════════════════════════════════════════

  void _addTag() {
    final tag = _tagsController.text.trim().toLowerCase().replaceAll(' ', '-');
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 10) {
      setState(() {
        _tags.add(tag);
        _tagsController.clear();
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // EDITOR METADATA
  // ════════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _buildEditorMetadata() {
    return {
      'editor_type': 'normal',
      'title_style': {
        'text_color': _colorToHex(_textColor),
        'font_family': _fontFamily,
        'font_size': 22.0,
        'bold': true,
      },
      'subtitle_style': {
        'text_color': _colorToHex(_textColor.withValues(alpha: 0.8)),
        'font_family': _fontFamily,
        'font_size': 16.0,
      },
      'body_style': {
        'text_color': _colorToHex(_textColor),
        'font_family': _fontFamily,
        'font_size': _bodyFontSize,
      },
      'divider_style': {
        'style': _dividerStyle,
        'color': _colorToHex(_dividerColor),
        'thickness': 1.0,
        'spacing': 20.0,
      },
      'cover_style': {
        if (_coverImageUrl != null) 'cover_image_url': _coverImageUrl,
        if (_backgroundUrlController.text.trim().isNotEmpty)
          'background_image_url': _backgroundUrlController.text.trim(),
        'background_color': _colorToHex(_bgColor),
      },
      'extra': {
        if (_gifUrl != null) 'gif_url': _gifUrl,
        if (_musicUrl != null) 'music_url': _musicUrl,
        if (_musicTitle != null) 'music_title': _musicTitle,
        'visibility': _postVisibility,
        'comments_blocked': _commentsBlocked,
        'pinned_profile': _isPinnedProfile,
      },
    };
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SUBMIT
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _submitPost() async {
    final s = getStrings();
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty &&
        _mediaUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(s.fillTitleOrContent),
            backgroundColor: context.nexusTheme.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      final contentText = _contentController.text.trim();
      final mediaList = _mediaUrls.isNotEmpty
          ? _mediaUrls.map((url) => {'url': url, 'type': 'image'}).toList()
          : <Map<String, dynamic>>[];
      final titleText = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null;
      final editorMetadata = _buildEditorMetadata();

      // ── Modo de EDIÇÃO ──
      if (_isEditing) {
        final postData = {
          'title': titleText ?? '',
          'content': contentText,
          'type': 'normal',
          'media_list': mediaList,
          'tags': _tags,
          'cover_image_url': _coverImageUrl,
          'background_url': _backgroundUrlController.text.trim().isNotEmpty
              ? _backgroundUrlController.text.trim()
              : null,
          'gif_url': _gifUrl,
          'music_url': _musicUrl,
          'music_title': _musicTitle,
          'visibility': _postVisibility,
          'comments_blocked': _commentsBlocked,
          'editor_type': 'normal',
          'editor_metadata': editorMetadata,
        };

        final success = await ref
            .read(communityFeedProvider(widget.communityId).notifier)
            .editPost(widget.editingPost!.id, postData);

        if (mounted) {
          if (success) {
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(s.postUpdated),
                  backgroundColor: context.nexusTheme.success),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(s.anErrorOccurredTryAgain),
                  backgroundColor: context.nexusTheme.error),
            );
          }
        }
        return;
      }

      // ── Modo de CRIAÇÃO ──
      final postId = await SupabaseService.rpc(
        'create_post_with_reputation',
        params: {
          'p_community_id': widget.communityId,
          'p_title': titleText ?? '',
          'p_content': contentText,
          'p_type': 'normal',
          'p_media_list': mediaList,
          'p_tags': _tags,
          'p_cover_image_url': _coverImageUrl,
          'p_background_url': _backgroundUrlController.text.trim().isNotEmpty
              ? _backgroundUrlController.text.trim()
              : null,
          'p_external_url': null,
          'p_gif_url': _gifUrl,
          'p_music_url': _musicUrl,
          'p_music_title': _musicTitle,
          'p_visibility': _postVisibility,
          'p_comments_blocked': _commentsBlocked,
          'p_editor_type': 'normal',
          'p_editor_metadata': editorMetadata,
        },
      ) as String?;

      // Atualizar campos extras
      if (postId != null) {
        try {
          await SupabaseService.table('posts').update({
            'editor_type': 'normal',
            'editor_metadata': editorMetadata,
            if (_isPinnedProfile) 'is_pinned_profile': true,
          }).eq('id', postId);
        } catch (_) {
          // best-effort
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(s.postCreatedSuccess),
              backgroundColor: context.nexusTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(s.anErrorOccurredTryAgain),
              backgroundColor: context.nexusTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TEXT FORMATTING
  // ════════════════════════════════════════════════════════════════════════════

  void _wrapSelection(String prefix, String suffix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (sel.isValid && sel.start != sel.end) {
      final selected = text.substring(sel.start, sel.end);
      final newText =
          text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start + prefix.length + selected.length + suffix.length,
        ),
      );
    } else {
      final pos = sel.isValid ? sel.start : text.length;
      final newText =
          '${text.substring(0, pos)}${prefix}texto${suffix}${text.substring(pos)}';
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: pos + prefix.length,
          extentOffset: pos + prefix.length + 5,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _contentController.dispose();
    _backgroundUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(s, r),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cover image ──
                  _buildCoverPicker(r, s),
                  SizedBox(height: r.s(16)),

                  // ── Título ──
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: r.fs(22),
                      fontWeight: FontWeight.w800,
                      color: _textColor,
                      fontFamily: _fontFamily,
                    ),
                    decoration: InputDecoration(
                      hintText: s.title,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: _textColor.withValues(alpha: 0.2),
                        fontSize: r.fs(22),
                        fontWeight: FontWeight.w800,
                        fontFamily: _fontFamily,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                  ),

                  // ── Subtítulo ──
                  TextField(
                    controller: _subtitleController,
                    style: TextStyle(
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w500,
                      color: _textColor.withValues(alpha: 0.7),
                      fontFamily: _fontFamily,
                    ),
                    decoration: InputDecoration(
                      hintText: s.subtitleHint,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: _textColor.withValues(alpha: 0.15),
                        fontSize: r.fs(16),
                        fontFamily: _fontFamily,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                  ),

                  // ── Divisor ──
                  _buildDividerPreview(r),
                  SizedBox(height: r.s(8)),

                  // ── Conteúdo principal ──
                  Container(
                    constraints: BoxConstraints(minHeight: r.s(200)),
                    decoration: BoxDecoration(
                      color: _textColor.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(
                          color: _textColor.withValues(alpha: 0.06)),
                    ),
                    padding: EdgeInsets.all(r.s(14)),
                    child: TextField(
                      controller: _contentController,
                      style: TextStyle(
                        fontSize: r.fs(_bodyFontSize),
                        height: 1.7,
                        color: _textColor,
                        fontFamily: _fontFamily,
                      ),
                      decoration: InputDecoration(
                        hintText: s.writeContentHere,
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                            color: _textColor.withValues(alpha: 0.2)),
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      minLines: 10,
                    ),
                  ),

                  // ── Contagem de caracteres ──
                  Padding(
                    padding: EdgeInsets.only(top: r.s(6)),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_contentController.text.length} caracteres',
                        style: TextStyle(
                          color: _textColor.withValues(alpha: 0.25),
                          fontSize: r.fs(11),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: r.s(12)),

                  // ── Imagens anexadas ──
                  if (_mediaUrls.isNotEmpty) ...[
                    Text(s.imagesLabel,
                        style: TextStyle(
                            color: _textColor.withValues(alpha: 0.5),
                            fontSize: r.fs(12),
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: r.s(8)),
                    _buildMediaGrid(r),
                    SizedBox(height: r.s(12)),
                  ],

                  // ── GIF preview ──
                  if (_gifUrl != null) ...[
                    _buildGifPreview(r),
                    SizedBox(height: r.s(12)),
                  ],

                  // ── Música preview ──
                  if (_musicUrl != null) ...[
                    _buildMusicPreview(r),
                    SizedBox(height: r.s(12)),
                  ],

                  // ── Tags ──
                  _buildTagsSection(r, s),
                  SizedBox(height: r.s(16)),

                  // ── Personalização ──
                  _buildCustomizationSection(r),
                  SizedBox(height: r.s(8)),

                  // ── Opções avançadas ──
                  _buildAdvancedOptions(r, s),
                  SizedBox(height: r.s(32)),
                ],
              ),
            ),
          ),

          // ── Bottom toolbar ──
          _buildToolbar(r, s),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ════════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(dynamic s, Responsive r) {
    return AppBar(
      backgroundColor: _bgColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: _textColor),
        onPressed: () => context.pop(),
      ),
      title: Text(
        _isEditing ? s.editPost : s.createPost,
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.w700,
          fontSize: r.fs(16),
        ),
      ),
      centerTitle: true,
      actions: [
        if (!_isEditing) ...[
          IconButton(
            icon: Icon(Icons.drafts_rounded,
                color: _textColor.withValues(alpha: 0.6), size: r.s(22)),
            tooltip: s.drafts,
            onPressed: () => context.push('/drafts'),
          ),
          IconButton(
            icon: Icon(Icons.save_outlined,
                color: _textColor.withValues(alpha: 0.6), size: r.s(22)),
            tooltip: s.saveDraft,
            onPressed: _saveDraft,
          ),
        ],
        Padding(
          padding: EdgeInsets.only(right: r.s(12)),
          child: GestureDetector(
            onTap: _isSubmitting ? null : _submitPost,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: _isSubmitting
                    ? context.nexusTheme.accentPrimary.withValues(alpha: 0.5)
                    : context.nexusTheme.accentPrimary,
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: r.s(16),
                      height: r.s(16),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEditing ? s.save : s.publish,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(14),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveDraft() async {
    final s = getStrings();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.nothingToSave)),
      );
      return;
    }
    try {
      await ref.read(postDraftsProvider.notifier).createDraft(
            communityId: widget.communityId,
            title: title.isNotEmpty ? title : null,
            content: content.isNotEmpty ? content : null,
            postType: 'normal',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(s.draftSaved),
              backgroundColor: context.nexusTheme.accentPrimary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.errorSavingTryAgain)),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // COVER PICKER
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCoverPicker(Responsive r, dynamic s) {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        width: double.infinity,
        height: r.s(160),
        decoration: BoxDecoration(
          color: _textColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(r.s(14)),
          border: Border.all(color: _textColor.withValues(alpha: 0.08)),
          image: _coverImageUrl != null
              ? DecorationImage(
                  image: NetworkImage(_coverImageUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: _coverImageUrl == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: _textColor.withValues(alpha: 0.3), size: r.s(36)),
                  SizedBox(height: r.s(8)),
                  Text(s.addCover,
                      style: TextStyle(
                          color: _textColor.withValues(alpha: 0.3),
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w500)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(r.s(10)),
                  child: GestureDetector(
                    onTap: () => setState(() => _coverImageUrl = null),
                    child: Container(
                      padding: EdgeInsets.all(r.s(6)),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: r.s(16)),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIVIDER PREVIEW
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDividerPreview(Responsive r) {
    if (_dividerStyle == 'none') return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(vertical: r.s(10)),
      width: double.infinity,
      height: 1,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _dividerColor, width: 1)),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MEDIA GRID
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildMediaGrid(Responsive r) {
    return Wrap(
      spacing: r.s(8),
      runSpacing: r.s(8),
      children: [
        ..._mediaUrls.asMap().entries.map((entry) {
          final url = entry.value;
          return Stack(
            children: [
              Container(
                width: r.s(90),
                height: r.s(90),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  image: DecorationImage(
                      image: NetworkImage(url), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _mediaUrls.remove(url)),
                  child: Container(
                    padding: EdgeInsets.all(r.s(4)),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white, size: r.s(14)),
                  ),
                ),
              ),
            ],
          );
        }),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: r.s(90),
            height: r.s(90),
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(color: _textColor.withValues(alpha: 0.1)),
            ),
            child: Icon(Icons.add_photo_alternate_rounded,
                color: _textColor.withValues(alpha: 0.3), size: r.s(28)),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // GIF PREVIEW
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildGifPreview(Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(10)),
      decoration: BoxDecoration(
        color: _textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(8)),
            child: Image.network(_gifUrl!, width: r.s(60), height: r.s(60),
                fit: BoxFit.cover),
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Text('GIF anexado',
                style: TextStyle(
                    color: _textColor.withValues(alpha: 0.6),
                    fontSize: r.fs(13))),
          ),
          GestureDetector(
            onTap: () => setState(() => _gifUrl = null),
            child: Icon(Icons.close_rounded,
                color: _textColor.withValues(alpha: 0.4), size: r.s(18)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MUSIC PREVIEW
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildMusicPreview(Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(10)),
      decoration: BoxDecoration(
        color: context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.s(12)),
        border:
            Border.all(color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.music_note_rounded,
              color: context.nexusTheme.accentPrimary, size: r.s(22)),
          SizedBox(width: r.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_musicTitle ?? 'Música',
                    style: TextStyle(
                        color: _textColor,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600)),
                if (_musicUrl != null)
                  Text(_musicUrl!,
                      style: TextStyle(
                          color: _textColor.withValues(alpha: 0.4),
                          fontSize: r.fs(11)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _musicUrl = null;
              _musicTitle = null;
            }),
            child: Icon(Icons.close_rounded,
                color: _textColor.withValues(alpha: 0.4), size: r.s(18)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAGS SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildTagsSection(Responsive r, dynamic s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.tags,
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.5),
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: r.s(6),
            runSpacing: r.s(6),
            children: _tags
                .map((tag) => Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(10), vertical: r.s(5)),
                      decoration: BoxDecoration(
                        color: context.nexusTheme.accentPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(r.s(16)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('#$tag',
                              style: TextStyle(
                                  color: context.nexusTheme.accentPrimary,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: r.s(4)),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _tags.remove(tag)),
                            child: Icon(Icons.close_rounded,
                                size: r.s(14),
                                color: context.nexusTheme.accentPrimary
                                    .withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        SizedBox(height: r.s(6)),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(r.s(10)),
                ),
                child: TextField(
                  controller: _tagsController,
                  style: TextStyle(
                      color: _textColor, fontSize: r.fs(13)),
                  decoration: InputDecoration(
                    hintText: s.addTag,
                    hintStyle: TextStyle(
                        color: _textColor.withValues(alpha: 0.2),
                        fontSize: r.fs(13)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.s(12), vertical: r.s(10)),
                    prefixIcon: Icon(Icons.tag_rounded,
                        size: r.s(16),
                        color: _textColor.withValues(alpha: 0.3)),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
            ),
            SizedBox(width: r.s(8)),
            GestureDetector(
              onTap: _addTag,
              child: Container(
                padding: EdgeInsets.all(r.s(10)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(10)),
                ),
                child: Icon(Icons.add_rounded,
                    color: context.nexusTheme.accentPrimary, size: r.s(18)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CUSTOMIZATION SECTION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCustomizationSection(Responsive r) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(Icons.palette_rounded,
                size: r.s(16), color: _textColor.withValues(alpha: 0.5)),
            SizedBox(width: r.s(8)),
            Text('Personalização',
                style: TextStyle(
                    fontSize: r.fs(13),
                    color: _textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600)),
          ],
        ),
        iconColor: _textColor.withValues(alpha: 0.4),
        collapsedIconColor: _textColor.withValues(alpha: 0.4),
        children: [
          // Cor do texto
          _buildColorRow('Cor do texto', _textColor,
              (c) => setState(() => _textColor = c), r),
          SizedBox(height: r.s(10)),

          // Cor de fundo
          _buildColorRow('Cor de fundo', _bgColor,
              (c) => setState(() => _bgColor = c), r),
          SizedBox(height: r.s(10)),

          // Imagem de fundo
          _buildBackgroundImagePicker(r),
          SizedBox(height: r.s(10)),

          // Fonte
          _buildFontSelector(r),
          SizedBox(height: r.s(10)),

          // Tamanho da fonte
          _buildFontSizeSlider(r),
          SizedBox(height: r.s(10)),

          // Estilo do divisor
          _buildDividerStyleSelector(r),
          SizedBox(height: r.s(16)),
        ],
      ),
    );
  }

  Widget _buildColorRow(
      String label, Color current, ValueChanged<Color> onChanged, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: _textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(r.s(10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: _textColor.withValues(alpha: 0.6),
                        fontSize: r.fs(12))),
                SizedBox(height: r.s(4)),
                Text(
                  '#${current.r.round().toRadixString(16).padLeft(2, '0').toUpperCase()}${current.g.round().toRadixString(16).padLeft(2, '0').toUpperCase()}${current.b.round().toRadixString(16).padLeft(2, '0').toUpperCase()}',
                  style: TextStyle(
                    color: current,
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          ColorPickerButton(
            color: current,
            title: label,
            size: 36,
            onColorChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundImagePicker(Responsive r) {
    return GestureDetector(
      onTap: _pickBackgroundImage,
      child: Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: _textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(r.s(10)),
        ),
        child: Row(
          children: [
            Icon(Icons.wallpaper_rounded,
                size: r.s(18), color: _textColor.withValues(alpha: 0.5)),
            SizedBox(width: r.s(10)),
            Expanded(
              child: Text(
                _backgroundUrlController.text.isNotEmpty
                    ? 'Imagem de fundo definida'
                    : 'Adicionar imagem de fundo',
                style: TextStyle(
                    color: _textColor.withValues(alpha: 0.6),
                    fontSize: r.fs(13)),
              ),
            ),
            if (_backgroundUrlController.text.isNotEmpty)
              GestureDetector(
                onTap: () =>
                    setState(() => _backgroundUrlController.clear()),
                child: Icon(Icons.close_rounded,
                    size: r.s(16),
                    color: _textColor.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSelector(Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: _textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(r.s(10)),
      ),
      child: Row(
        children: [
          Icon(Icons.font_download_rounded,
              size: r.s(18), color: _textColor.withValues(alpha: 0.5)),
          SizedBox(width: r.s(10)),
          Expanded(
            child: DropdownButton<String>(
              value: _fontFamily,
              dropdownColor: _bgColor,
              style: TextStyle(color: _textColor, fontSize: r.fs(13)),
              underline: const SizedBox.shrink(),
              isExpanded: true,
              items: _availableFonts
                  .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f, style: TextStyle(fontFamily: f))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _fontFamily = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeSlider(Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: _textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(r.s(10)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_size_rounded,
              size: r.s(18), color: _textColor.withValues(alpha: 0.5)),
          SizedBox(width: r.s(10)),
          Text('${_bodyFontSize.toInt()}',
              style: TextStyle(
                  color: _textColor.withValues(alpha: 0.6),
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: Slider(
              value: _bodyFontSize,
              min: 12,
              max: 28,
              divisions: 16,
              activeColor: context.nexusTheme.accentPrimary,
              inactiveColor: _textColor.withValues(alpha: 0.1),
              onChanged: (v) => setState(() => _bodyFontSize = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerStyleSelector(Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: _textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(r.s(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.horizontal_rule_rounded,
                  size: r.s(18), color: _textColor.withValues(alpha: 0.5)),
              SizedBox(width: r.s(10)),
              Text('Estilo do divisor',
                  style: TextStyle(
                      color: _textColor.withValues(alpha: 0.6),
                      fontSize: r.fs(13))),
            ],
          ),
          SizedBox(height: r.s(8)),
          Wrap(
            spacing: r.s(8),
            children: ['solid', 'dashed', 'dotted', 'none'].map((style) {
              final isSelected = _dividerStyle == style;
              return GestureDetector(
                onTap: () => setState(() => _dividerStyle = style),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(6)),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.nexusTheme.accentPrimary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(r.s(16)),
                    border: Border.all(
                      color: isSelected
                          ? context.nexusTheme.accentPrimary.withValues(alpha: 0.4)
                          : _textColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    style == 'solid'
                        ? 'Sólido'
                        : style == 'dashed'
                            ? 'Tracejado'
                            : style == 'dotted'
                                ? 'Pontilhado'
                                : 'Nenhum',
                    style: TextStyle(
                      fontSize: r.fs(11),
                      color: isSelected
                          ? context.nexusTheme.accentPrimary
                          : _textColor.withValues(alpha: 0.5),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ADVANCED OPTIONS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAdvancedOptions(Responsive r, dynamic s) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(s.advancedOptions,
            style: TextStyle(
                fontSize: r.fs(13),
                color: _textColor.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500)),
        iconColor: _textColor.withValues(alpha: 0.4),
        collapsedIconColor: _textColor.withValues(alpha: 0.4),
        children: [
          // Visibilidade
          Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: r.s(16),
                        color: _textColor.withValues(alpha: 0.5)),
                    SizedBox(width: r.s(8)),
                    Text(s.visibility,
                        style: TextStyle(
                            fontSize: r.fs(13),
                            color: _textColor.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: r.s(8)),
                Wrap(
                  spacing: r.s(8),
                  children: [
                    _visibilityChip(
                        'public', s.publicLabel, Icons.public_rounded, r),
                    _visibilityChip(
                        'followers', s.followers, Icons.people_rounded, r),
                    _visibilityChip(
                        'private', s.privateLabel, Icons.lock_rounded, r),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(8)),

          // Bloquear comentários
          GestureDetector(
            onTap: () =>
                setState(() => _commentsBlocked = !_commentsBlocked),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: _commentsBlocked
                    ? context.nexusTheme.error.withValues(alpha: 0.1)
                    : _textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(
                  color: _commentsBlocked
                      ? context.nexusTheme.error.withValues(alpha: 0.3)
                      : _textColor.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _commentsBlocked
                        ? Icons.comments_disabled_rounded
                        : Icons.comment_rounded,
                    size: r.s(16),
                    color: _commentsBlocked
                        ? context.nexusTheme.error
                        : _textColor.withValues(alpha: 0.5),
                  ),
                  SizedBox(width: r.s(8)),
                  Text(
                    _commentsBlocked ? s.commentsBlocked : s.allowComments,
                    style: TextStyle(
                      fontSize: r.fs(13),
                      color: _commentsBlocked
                          ? context.nexusTheme.error
                          : _textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: !_commentsBlocked,
                    onChanged: (v) =>
                        setState(() => _commentsBlocked = !v),
                    activeColor: context.nexusTheme.accentPrimary,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.s(8)),

          // Fixar no perfil
          GestureDetector(
            onTap: () =>
                setState(() => _isPinnedProfile = !_isPinnedProfile),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: _isPinnedProfile
                    ? context.nexusTheme.accentPrimary.withValues(alpha: 0.1)
                    : _textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(
                  color: _isPinnedProfile
                      ? context.nexusTheme.accentPrimary.withValues(alpha: 0.3)
                      : _textColor.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPinnedProfile
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: r.s(16),
                    color: _isPinnedProfile
                        ? context.nexusTheme.accentPrimary
                        : _textColor.withValues(alpha: 0.5),
                  ),
                  SizedBox(width: r.s(8)),
                  Text(
                    _isPinnedProfile
                        ? s.pinnedToProfile
                        : s.pinToProfile,
                    style: TextStyle(
                      fontSize: r.fs(13),
                      color: _isPinnedProfile
                          ? context.nexusTheme.accentPrimary
                          : _textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isPinnedProfile,
                    onChanged: (v) =>
                        setState(() => _isPinnedProfile = v),
                    activeColor: context.nexusTheme.accentPrimary,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.s(16)),
        ],
      ),
    );
  }

  Widget _visibilityChip(
      String value, String label, IconData icon, Responsive r) {
    final isSelected = _postVisibility == value;
    return GestureDetector(
      onTap: () => setState(() => _postVisibility = value),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(6)),
        decoration: BoxDecoration(
          color: isSelected
              ? context.nexusTheme.accentPrimary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(
            color: isSelected
                ? context.nexusTheme.accentPrimary.withValues(alpha: 0.4)
                : _textColor.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: r.s(13),
                color: isSelected
                    ? context.nexusTheme.accentPrimary
                    : _textColor.withValues(alpha: 0.4)),
            SizedBox(width: r.s(4)),
            Text(label,
                style: TextStyle(
                    fontSize: r.fs(12),
                    color: isSelected
                        ? context.nexusTheme.accentPrimary
                        : _textColor.withValues(alpha: 0.4),
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BOTTOM TOOLBAR
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildToolbar(Responsive r, dynamic s) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: r.s(8), horizontal: r.s(16)),
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border(
          top: BorderSide(color: _textColor.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ToolbarBtn(Icons.image_rounded, s.image2, _pickImage, _textColor),
            _ToolbarBtn(Icons.gif_rounded, s.gif, () async {
              final url = await GiphyPicker.show(context);
              if (url != null && mounted) {
                setState(() => _gifUrl = url);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(s.gifAddedToPost),
                      behavior: SnackBarBehavior.floating),
                );
              }
            }, _textColor),
            _ToolbarBtn(
                Icons.music_note_rounded, 'Music', _showMusicPicker, _textColor),
            _ToolbarBtn(Icons.format_bold_rounded, 'Bold',
                () => _wrapSelection('**', '**'), _textColor),
            _ToolbarBtn(Icons.format_italic_rounded, 'Italic',
                () => _wrapSelection('_', '_'), _textColor),
            _ToolbarBtn(Icons.format_strikethrough_rounded, s.strike,
                () => _wrapSelection('~~', '~~'), _textColor),
          ],
        ),
      ),
    );
  }

  void _showMusicPicker() {
    final r = context.r;
    final s = getStrings();
    final urlCtrl = TextEditingController(text: _musicUrl ?? '');
    final titleCtrl = TextEditingController(text: _musicTitle ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: r.s(20),
          right: r.s(20),
          top: r.s(20),
          bottom: MediaQuery.of(ctx).viewInsets.bottom + r.s(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.addMusicAction,
                style: TextStyle(
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w800,
                    color: context.nexusTheme.textPrimary)),
            SizedBox(height: r.s(16)),
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                hintText: s.songNameHint,
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.nexusTheme.surfacePrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.music_note_rounded,
                    color: context.nexusTheme.accentPrimary, size: r.s(18)),
              ),
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                hintText: s.audioFileUrl,
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.nexusTheme.surfacePrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.link_rounded,
                    color: Colors.grey[600], size: r.s(18)),
              ),
            ),
            SizedBox(height: r.s(16)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _musicUrl = urlCtrl.text.trim().isNotEmpty
                        ? urlCtrl.text.trim()
                        : null;
                    _musicTitle = titleCtrl.text.trim().isNotEmpty
                        ? titleCtrl.text.trim()
                        : null;
                  });
                  Navigator.pop(ctx);
                  if (_musicUrl != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(s.musicAddedToPost),
                          behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: context.nexusTheme.accentPrimary),
                child: Text(s.confirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TOOLBAR BUTTON
// ══════════════════════════════════════════════════════════════════════════════

class _ToolbarBtn extends ConsumerWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color textColor;

  const _ToolbarBtn(this.icon, this.tooltip, this.onTap, this.textColor);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(r.s(10)),
          child: Icon(icon,
              color: textColor.withValues(alpha: 0.4), size: r.s(20)),
        ),
      ),
    );
  }
}
