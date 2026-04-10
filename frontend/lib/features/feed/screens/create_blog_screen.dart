import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/providers/draft_provider.dart';
import '../../../core/providers/post_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/models/post_model.dart';
import '../widgets/block_content_renderer.dart';
import '../widgets/block_editor.dart';

// =============================================================================
// CREATE BLOG SCREEN — Editor de post tipo "Blog" (texto rico com blocos)
//
// Melhorias:
//   - Imagem de capa (cover image) com upload
//   - Tags / categorias
//   - Personalização de cores (fundo do post, cor do texto do título)
//   - Seletor de fonte do título
//   - Barra de personalização expansível
//   - Preview melhorado com capa
//   - Rascunhos automáticos
//   - Indicador de contagem de palavras
// =============================================================================

class CreateBlogScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;

  const CreateBlogScreen({super.key, required this.communityId, this.editingPost});

  @override
  ConsumerState<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends ConsumerState<CreateBlogScreen> {
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();

  List<ContentBlock> _blocks = [];
  bool _isSubmitting = false;
  bool _isSavingDraft = false;
  bool _restoringDraft = true;
  bool _isUploadingCover = false;
  bool _showCustomization = false;
  String _visibility = 'public';
  String? _draftId;
  String? _coverImageUrl;
  final List<String> _tags = [];

  // Personalização
  Color _titleColor = Colors.white;
  Color _bgAccentColor = const Color(0xFF0D1B2A);
  String _titleFont = 'Default';
  bool _pinToProfile = false;

  bool get _isEditing => widget.editingPost != null;

  static const _titleFonts = [
    'Default',
    'Serif',
    'Monospace',
    'Cursive',
  ];

  static const _colorPresets = [
    Color(0xFF0D1B2A),
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
    Color(0xFF533483),
    Color(0xFF2C3333),
    Color(0xFF1B1A17),
    Color(0xFF3D0000),
    Color(0xFF0E4C92),
    Color(0xFF2D4059),
  ];

  static const _textColorPresets = [
    Colors.white,
    Color(0xFFE0E0E0),
    Color(0xFFFFC107),
    Color(0xFF4FC3F7),
    Color(0xFFAED581),
    Color(0xFFFF8A65),
    Color(0xFFCE93D8),
    Color(0xFFEF5350),
    Color(0xFF80CBC4),
    Color(0xFFFFF176),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromPost(widget.editingPost!);
      _restoringDraft = false;
    } else {
      Future.microtask(_restoreLatestDraft);
    }
  }

  void _populateFromPost(PostModel post) {
    _titleController.text = post.title ?? '';
    _coverImageUrl = post.coverImageUrl;
    _visibility = post.editorMetadata.extra['visibility'] as String? ?? 'public';
    _pinToProfile = post.isPinnedProfile;

    // Restaurar tags
    if (post.tags.isNotEmpty) {
      _tags.addAll(post.tags);
    }

    // Restaurar personalização do editor_metadata
    final meta = post.editorMetadata;
    final titleColorHex = meta.extra['title_color'] as String?;
    if (titleColorHex != null) {
      _titleColor = _parseHexColor(titleColorHex) ?? Colors.white;
    }
    final bgColorHex = meta.extra['bg_accent_color'] as String?;
    if (bgColorHex != null) {
      _bgAccentColor = _parseHexColor(bgColorHex) ?? const Color(0xFF0D1B2A);
    }
    _titleFont = meta.extra['title_font'] as String? ?? 'Default';

    // Restaurar blocos de conteúdo
    if (post.contentBlocks != null && post.contentBlocks!.isNotEmpty) {
      _blocks = post.contentBlocks!
          .map((b) => ContentBlock.fromJson(Map<String, dynamic>.from(b)))
          .toList();
    } else if (post.content.isNotEmpty) {
      _blocks = [ContentBlock(type: BlockType.text, text: post.content)];
    }
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) return Color(int.parse('FF\$cleaned', radix: 16));
      if (cleaned.length == 8) return Color(int.parse(cleaned, radix: 16));
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  bool get _hasAnyContent {
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_coverImageUrl != null) return true;
    for (final block in _blocks) {
      if (block.type == BlockType.divider) return true;
      if (block.isTextBased &&
          (block.controller?.text.trim().isNotEmpty ?? false)) {
        return true;
      }
      if (block.type == BlockType.image &&
          (block.imageUrl?.isNotEmpty ?? false)) {
        return true;
      }
    }
    return false;
  }

  int get _wordCount {
    int count = 0;
    final titleWords = _titleController.text.trim().split(RegExp(r'\s+'));
    if (titleWords.first.isNotEmpty) count += titleWords.length;
    for (final block in _blocks) {
      if (block.isTextBased) {
        final text = (block.controller?.text ?? block.text).trim();
        if (text.isNotEmpty) {
          count += text.split(RegExp(r'\s+')).length;
        }
      }
    }
    return count;
  }

  String _fontFamilyFromName(String name) {
    switch (name) {
      case 'Serif':
        return 'serif';
      case 'Monospace':
        return 'monospace';
      case 'Cursive':
        return 'cursive';
      default:
        return '';
    }
  }

  List<Map<String, dynamic>> _serializeBlocks() {
    final serialized = <Map<String, dynamic>>[];
    for (final block in _blocks) {
      final data = block.toJson();
      final type = data['type'] as String? ?? 'text';
      final text = ((data['content'] ?? data['text']) as String? ?? '').trim();
      final imageUrl =
          ((data['url'] ?? data['image_url']) as String? ?? '').trim();

      if (type == 'divider') {
        serialized.add({'type': 'divider'});
        continue;
      }
      if (type == 'image') {
        if (imageUrl.isEmpty) continue;
        serialized.add(data);
        continue;
      }
      if (text.isEmpty) continue;
      serialized.add(data);
    }
    return serialized;
  }

  List<String> _extractMediaUrls(List<Map<String, dynamic>> blocks) {
    final urls = blocks
        .where((block) => block['type'] == 'image')
        .map((block) => (block['url'] ?? block['image_url']) as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) {
      urls.insert(0, _coverImageUrl!);
    }
    return urls;
  }

  String _buildPlainContent(List<Map<String, dynamic>> blocks) {
    return blocks
        .where((block) =>
            block['type'] == 'text' ||
            block['type'] == 'heading' ||
            block['type'] == 'quote')
        .map((block) => (block['content'] ?? block['text']) as String? ?? '')
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
  }

  Future<void> _pickCoverImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isUploadingCover = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_cover_${image.name}';
      await SupabaseService.storage.from('post_media').uploadBinary(path, bytes);
      final url = SupabaseService.storage.from('post_media').getPublicUrl(path);
      if (mounted) setState(() => _coverImageUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.length >= 10 || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Future<void> _restoreLatestDraft() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _restoringDraft = false);
      return;
    }

    try {
      final result = await SupabaseService.table('post_drafts')
          .select()
          .eq('user_id', userId)
          .eq('community_id', widget.communityId)
          .eq('post_type', 'blog')
          .order('updated_at', ascending: false)
          .limit(1);

      if (!mounted) return;

      final list = (result as List?) ?? const [];
      if (list.isNotEmpty) {
        final data = Map<String, dynamic>.from(list.first as Map);
        final restoredBlocks =
            ((data['content_blocks'] as List?) ?? const [])
                .map((item) =>
                    ContentBlock.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList();

        setState(() {
          _draftId = data['id'] as String?;
          _titleController.text = (data['title'] as String?) ?? '';
          _visibility = (data['visibility'] as String?) ?? 'public';
          _coverImageUrl = data['cover_image_url'] as String?;
          _blocks = restoredBlocks.isNotEmpty
              ? restoredBlocks
              : [
                  ContentBlock(
                    type: BlockType.text,
                    text: (data['content'] as String?) ?? '',
                  ),
                ];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rascunho restaurado com sucesso.'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível restaurar o rascunho.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _restoringDraft = false);
    }
  }

  Future<void> _saveDraft({bool silent = false}) async {
    if (_isSavingDraft) return;

    final serializedBlocks = _serializeBlocks();
    final title = _titleController.text.trim();
    final content = _buildPlainContent(serializedBlocks);
    final mediaUrls = _extractMediaUrls(serializedBlocks);

    if (title.isEmpty && content.isEmpty && mediaUrls.isEmpty) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Adicione um título ou conteúdo antes de salvar.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isSavingDraft = true);

    try {
      final draftsNotifier = ref.read(postDraftsProvider.notifier);

      if (_draftId == null) {
        final created = await draftsNotifier.createDraft(
          communityId: widget.communityId,
          title: title,
          content: content,
          contentBlocks: serializedBlocks,
          mediaUrls: mediaUrls,
          postType: 'blog',
          visibility: _visibility,
        );
        _draftId = created?.id;
      } else {
        await draftsNotifier.updateDraft(
          _draftId!,
          communityId: widget.communityId,
          title: title,
          content: content,
          contentBlocks: serializedBlocks,
          mediaUrls: mediaUrls,
          postType: 'blog',
          visibility: _visibility,
        );
      }

      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rascunho salvo.'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível salvar o rascunho.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  Future<void> _deleteDraftIfNeeded() async {
    if (_draftId == null) return;
    try {
      await ref.read(postDraftsProvider.notifier).deleteDraft(_draftId!);
      _draftId = null;
    } catch (_) {}
  }

  Future<void> _handleClose() async {
    if (_hasAnyContent && !_isSubmitting) {
      await _saveDraft(silent: true);
    }
    if (mounted) context.pop();
  }

  String _extractErrorMessage(dynamic error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Falha desconhecida ao publicar o blog.';
    final normalized = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('PostgrestException(', '')
        .replaceFirst('AuthException(', '')
        .trim();

    String? extractField(String field) {
      final match = RegExp(
        '$field:\\s*(.*?)(?=,\\s*(?:message|details|hint|code):|\\)\$)',
        dotAll: true,
      ).firstMatch(normalized);
      return match?.group(1)?.trim();
    }

    final message = extractField('message');
    final details = extractField('details');
    final hint = extractField('hint');
    final parts = <String>[];

    void addPart(String? value) {
      if (value == null) return;
      final cleaned = value
          .replaceAll(RegExp(r'^null$'), '')
          .replaceAll(RegExp(r'\)+$'), '')
          .trim();
      if (cleaned.isNotEmpty) parts.add(cleaned);
    }

    addPart(message);
    addPart(details);
    addPart(hint);

    if (parts.isNotEmpty) return parts.join(' | ');
    final fallback = normalized.replaceAll(RegExp(r'\)+$'), '').trim();
    return fallback.isEmpty ? 'Falha desconhecida ao publicar o blog.' : fallback;
  }

  String? _extractPostId(dynamic result) {
    if (result is String && result.isNotEmpty) return result;
    if (result is Map<String, dynamic>) {
      final id = result['id'] ?? result['post_id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<dynamic> _createBlogPost({
    required String title,
    required String content,
    required List<Map<String, dynamic>> contentBlocks,
    required List<String> mediaUrls,
  }) async {
    final errors = <String>[];
    final coverUrl = _coverImageUrl ?? (mediaUrls.isNotEmpty ? mediaUrls.first : null);

    // Montar editor_metadata
    final editorMetadata = <String, dynamic>{
      'editor_type': 'blog',
      'title_color': '#${_titleColor.value.toRadixString(16).padLeft(8, '0')}',
      'bg_accent_color':
          '#${_bgAccentColor.value.toRadixString(16).padLeft(8, '0')}',
      'title_font': _titleFont,
      'tags': _tags,
      'pin_to_profile': _pinToProfile,
    };

    // Tentativa 1: RPC create_post_with_reputation
    try {
      final result =
          await SupabaseService.rpc('create_post_with_reputation', params: {
        'p_community_id': widget.communityId,
        'p_title': title,
        'p_content': content,
        'p_type': 'blog',
        'p_visibility': _visibility,
        'p_media_urls': mediaUrls,
        'p_cover_image_url': coverUrl,
        'p_content_blocks': contentBlocks,
        'p_editor_type': 'blog',
        'p_editor_metadata': editorMetadata,
        'p_is_pinned_profile': _pinToProfile,
      });
      return result;
    } catch (e) {
      errors.add('RPC: ${_extractErrorMessage(e)}');
    }

    // Tentativa 2: insert direto
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Não autenticado');

      final result = await SupabaseService.table('posts')
          .insert({
            'community_id': widget.communityId,
            'author_id': userId,
            'type': 'blog',
            'title': title,
            'content': content,
            'media_list':
                mediaUrls.map((url) => {'url': url, 'type': 'image'}).toList(),
            'cover_image_url': coverUrl,
            'visibility': _visibility,
            'content_blocks': contentBlocks,
            'editor_type': 'blog',
            'editor_metadata': editorMetadata,
            'is_pinned_profile': _pinToProfile,
          })
          .select()
          .single();

      try {
        await SupabaseService.rpc('add_reputation', params: {
          'p_user_id': userId,
          'p_community_id': widget.communityId,
          'p_action_type': 'post_create',
          'p_raw_amount': 20,
          'p_reference_id': result['id'],
        });
      } catch (_) {}

      return result;
    } catch (e) {
      errors.add('Insert: ${_extractErrorMessage(e)}');
    }

    throw Exception(errors.join('\n'));
  }

  Future<void> _submit() async {
    final s = getStrings();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.titleRequired),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final serializedBlocks = _serializeBlocks();
    final content = _buildPlainContent(serializedBlocks);
    final mediaUrls = _extractMediaUrls(serializedBlocks);

    if (serializedBlocks.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Adicione conteúdo ao blog antes de publicar.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ── Modo de EDIÇÃO ──
      if (_isEditing) {
        final coverUrl = _coverImageUrl ?? (mediaUrls.isNotEmpty ? mediaUrls.first : null);
        final editorMetadata = <String, dynamic>{
          'editor_type': 'blog',
          'title_color': '#${_titleColor.value.toRadixString(16).padLeft(8, '0')}',
          'bg_accent_color': '#${_bgAccentColor.value.toRadixString(16).padLeft(8, '0')}',
          'title_font': _titleFont,
          'tags': _tags,
          'pin_to_profile': _pinToProfile,
        };

        final postData = {
          'title': title,
          'content': content,
          'type': 'blog',
          'media_list': mediaUrls.map((url) => {'url': url, 'type': 'image'}).toList(),
          'tags': _tags,
          'cover_image_url': coverUrl,
          'visibility': _visibility,
          'content_blocks': serializedBlocks,
          'is_pinned_profile': _pinToProfile,
          'editor_type': 'blog',
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
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.anErrorOccurredTryAgain),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      // ── Modo de CRIAÇÃO ──
      await _createBlogPost(
        title: title,
        content: content,
        contentBlocks: serializedBlocks,
        mediaUrls: mediaUrls,
      );

      await _deleteDraftIfNeeded();

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.postPublishedSuccess),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final detailedMessage = _extractErrorMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.errorPublishing2}: $detailedMessage'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  void _openPreview() {
    final title = _titleController.text.trim();
    final blocks = _serializeBlocks();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      builder: (context) {
        final r = context.r;
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            builder: (_, controller) => SingleChildScrollView(
              controller: controller,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(top: r.s(12)),
                      width: r.s(42),
                      height: r.s(4),
                      decoration: BoxDecoration(
                        color: context.dividerClr,
                        borderRadius: BorderRadius.circular(r.s(999)),
                      ),
                    ),
                  ),
                  // Cover image preview
                  if (_coverImageUrl != null) ...[
                    SizedBox(height: r.s(16)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: Image.network(
                        _coverImageUrl!,
                        width: double.infinity,
                        height: r.s(200),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        r.s(20), r.s(20), r.s(20), r.s(28)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty
                              ? 'Pré-visualização do blog'
                              : title,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(24),
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            fontFamily: _fontFamilyFromName(_titleFont),
                          ),
                        ),
                        if (_tags.isNotEmpty) ...[
                          SizedBox(height: r.s(12)),
                          Wrap(
                            spacing: r.s(6),
                            runSpacing: r.s(4),
                            children: _tags
                                .map((tag) => Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(10),
                                          vertical: r.s(4)),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentColor
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(r.s(12)),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: TextStyle(
                                          color: AppTheme.accentColor,
                                          fontSize: r.fs(12),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                        SizedBox(height: r.s(20)),
                        if (blocks.isEmpty)
                          Text(
                            'Adicione conteúdo para visualizar o resultado antes de publicar.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: r.fs(14),
                            ),
                          )
                        else
                          BlockContentRenderer(
                            blocks: blocks,
                            horizontalPadding: 0,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          _isEditing ? s.editPost : s.newBlog,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.textPrimary),
          onPressed: _handleClose,
        ),
        actions: [
          // Preview
          IconButton(
            tooltip: 'Pré-visualizar',
            onPressed: _openPreview,
            icon: Icon(Icons.visibility_outlined, color: context.textPrimary),
          ),
          // Personalização toggle
          IconButton(
            tooltip: 'Personalização',
            onPressed: () =>
                setState(() => _showCustomization = !_showCustomization),
            icon: Icon(
              Icons.palette_outlined,
              color: _showCustomization
                  ? AppTheme.accentColor
                  : context.textPrimary,
            ),
          ),
          // Rascunho
          TextButton(
            onPressed:
                (_isSavingDraft || _isSubmitting) ? null : () => _saveDraft(),
            child: _isSavingDraft
                ? SizedBox(
                    width: r.s(18),
                    height: r.s(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Text(
                    'Rascunho',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          // Visibilidade
          PopupMenuButton<String>(
            initialValue: _visibility,
            onSelected: (value) => setState(() => _visibility = value),
            color: context.surfaceColor,
            icon: Icon(
              _visibility == 'public'
                  ? Icons.public_rounded
                  : _visibility == 'followers'
                      ? Icons.people_rounded
                      : Icons.lock_rounded,
              color: AppTheme.accentColor,
              size: r.s(20),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'public',
                child: Text(s.publicLabel,
                    style: TextStyle(color: context.textPrimary)),
              ),
              PopupMenuItem(
                value: 'followers',
                child: Text(s.followers,
                    style: TextStyle(color: context.textPrimary)),
              ),
              PopupMenuItem(
                value: 'private',
                child: Text(s.privateLabel,
                    style: TextStyle(color: context.textPrimary)),
              ),
            ],
          ),
          // Publicar
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    width: r.s(18),
                    height: r.s(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Text(
                    _isEditing ? s.save : s.publish,
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          SizedBox(width: r.s(4)),
        ],
      ),
      body: _restoringDraft
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.accentColor,
                strokeWidth: 2,
              ),
            )
          : Column(
              children: [
                // Barra de personalização expansível
                if (_showCustomization) _buildCustomizationBar(r),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(r.s(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover image
                        _buildCoverSection(r),
                        SizedBox(height: r.s(16)),

                        // Info card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(r.s(12)),
                          decoration: BoxDecoration(
                            color: context.cardBg.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(r.s(12)),
                            border: Border.all(color: context.dividerClr),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: context.textSecondary, size: r.s(16)),
                              SizedBox(width: r.s(8)),
                              Expanded(
                                child: Text(
                                  _draftId == null
                                      ? 'Escreva seu blog com blocos de texto, imagem e subtítulos.'
                                      : 'Editando rascunho salvo.',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: r.fs(12),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              // Word count
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(8), vertical: r.s(4)),
                                decoration: BoxDecoration(
                                  color: context.dividerClr
                                      .withValues(alpha: 0.3),
                                  borderRadius:
                                      BorderRadius.circular(r.s(8)),
                                ),
                                child: Text(
                                  '$_wordCount palavras',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: r.fs(10),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: r.s(16)),

                        // Título
                        TextField(
                          controller: _titleController,
                          maxLength: 120,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(22),
                            fontWeight: FontWeight.w700,
                            fontFamily: _fontFamilyFromName(_titleFont),
                          ),
                          decoration: InputDecoration(
                            hintText: s.blogTitleHint,
                            hintStyle: TextStyle(
                              color: context.textSecondary,
                              fontSize: r.fs(22),
                              fontWeight: FontWeight.w700,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),

                        // Tags
                        _buildTagsSection(r),

                        Divider(color: context.dividerClr, height: r.s(24)),

                        // Pin to profile toggle
                        Row(
                          children: [
                            Icon(Icons.push_pin_outlined,
                                color: context.textSecondary, size: r.s(16)),
                            SizedBox(width: r.s(8)),
                            Text(
                              'Fixar no perfil',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(13),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _pinToProfile,
                              onChanged: (v) =>
                                  setState(() => _pinToProfile = v),
                              activeColor: AppTheme.accentColor,
                            ),
                          ],
                        ),

                        Divider(color: context.dividerClr, height: r.s(16)),

                        // Block editor
                        BlockEditor(
                          initialBlocks: _blocks,
                          communityId: widget.communityId,
                          onChanged: (blocks) =>
                              setState(() => _blocks = blocks),
                        ),
                        SizedBox(height: r.s(80)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Cover Section ──────────────────────────────────────────────────────────
  Widget _buildCoverSection(Responsive r) {
    if (_coverImageUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(16)),
            child: Image.network(
              _coverImageUrl!,
              width: double.infinity,
              height: r.s(180),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: r.s(8),
            right: r.s(8),
            child: Row(
              children: [
                _coverButton(
                  icon: Icons.camera_alt_rounded,
                  onTap: _pickCoverImage,
                  r: r,
                ),
                SizedBox(width: r.s(8)),
                _coverButton(
                  icon: Icons.close_rounded,
                  onTap: () => setState(() => _coverImageUrl = null),
                  r: r,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _isUploadingCover ? null : _pickCoverImage,
      child: Container(
        height: r.s(120),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(r.s(16)),
          border:
              Border.all(color: context.dividerClr.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: _isUploadingCover
              ? CircularProgressIndicator(
                  color: AppTheme.primaryColor, strokeWidth: 2)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: AppTheme.primaryColor, size: r.s(36)),
                    SizedBox(height: r.s(6)),
                    Text(
                      'Adicionar capa do blog',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: r.fs(13),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _coverButton(
      {required IconData icon,
      required VoidCallback onTap,
      required Responsive r}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(r.s(6)),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: r.s(18)),
      ),
    );
  }

  // ─── Tags Section ───────────────────────────────────────────────────────────
  Widget _buildTagsSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: r.s(6),
            runSpacing: r.s(4),
            children: _tags
                .map((tag) => Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(10), vertical: r.s(4)),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$tag',
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: r.s(4)),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _tags.remove(tag)),
                            child: Icon(Icons.close_rounded,
                                color: AppTheme.accentColor, size: r.s(14)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: r.s(8)),
        ],
        if (_tags.length < 10)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: TextStyle(
                      color: context.textPrimary, fontSize: r.fs(13)),
                  decoration: InputDecoration(
                    hintText: 'Adicionar tag...',
                    hintStyle: TextStyle(
                        color: context.textSecondary, fontSize: r.fs(13)),
                    border: InputBorder.none,
                    isDense: true,
                    prefixIcon: Icon(Icons.tag_rounded,
                        color: context.textSecondary, size: r.s(16)),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(6)),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text(
                    'Adicionar',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ─── Customization Bar ──────────────────────────────────────────────────────
  Widget _buildCustomizationBar(Responsive r) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          bottom: BorderSide(color: context.dividerClr),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fonte do título
          Text(
            'Fonte do título',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(8)),
          SizedBox(
            height: r.s(32),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _titleFonts.length,
              itemBuilder: (_, i) {
                final font = _titleFonts[i];
                final isSelected = _titleFont == font;
                return GestureDetector(
                  onTap: () => setState(() => _titleFont = font),
                  child: Container(
                    margin: EdgeInsets.only(right: r.s(8)),
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(14), vertical: r.s(6)),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentColor.withValues(alpha: 0.2)
                          : context.cardBg,
                      borderRadius: BorderRadius.circular(r.s(16)),
                      border: isSelected
                          ? Border.all(
                              color:
                                  AppTheme.accentColor.withValues(alpha: 0.5))
                          : Border.all(
                              color:
                                  context.dividerClr.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      font,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accentColor
                            : context.textPrimary,
                        fontSize: r.fs(12),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontFamily: _fontFamilyFromName(font),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: r.s(12)),

          // Cor do título
          Text(
            'Cor do título',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(8)),
          SizedBox(
            height: r.s(28),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _textColorPresets.length,
              itemBuilder: (_, i) {
                final color = _textColorPresets[i];
                final isSelected = _titleColor.value == color.value;
                return GestureDetector(
                  onTap: () => setState(() => _titleColor = color),
                  child: Container(
                    width: r.s(28),
                    height: r.s(28),
                    margin: EdgeInsets.only(right: r.s(6)),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.accentColor, width: r.s(2.5))
                          : Border.all(
                              color: Colors.white24, width: 1),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
