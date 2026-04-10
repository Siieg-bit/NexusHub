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
// CREATE BLOG SCREEN — Editor profissional de blogs com blocos ricos
//
// Design inspirado em Medium / Notion:
//   - Layout imersivo com capa hero
//   - AppBar minimalista (fechar, preview, configurações, publicar)
//   - Título grande e limpo sem bordas
//   - Editor de blocos como área principal
//   - Painel de configurações avançadas via bottom sheet
//   - Contagem de palavras e tempo de leitura discretos
//   - Rascunhos automáticos e modo de edição
// =============================================================================

class CreateBlogScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;

  const CreateBlogScreen({
    super.key,
    required this.communityId,
    this.editingPost,
  });

  @override
  ConsumerState<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends ConsumerState<CreateBlogScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();
  final _scrollController = ScrollController();

  List<ContentBlock> _blocks = [];
  bool _isSubmitting = false;
  bool _isSavingDraft = false;
  bool _restoringDraft = true;
  bool _isUploadingCover = false;
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

  static const _titleFonts = ['Default', 'Serif', 'Monospace', 'Cursive'];

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
    _visibility =
        post.editorMetadata.extra['visibility'] as String? ?? 'public';
    _pinToProfile = post.isPinnedProfile;

    if (post.tags.isNotEmpty) _tags.addAll(post.tags);

    final meta = post.editorMetadata;
    final titleColorHex = meta.extra['title_color'] as String?;
    if (titleColorHex != null) {
      _titleColor = _parseHexColor(titleColorHex) ?? Colors.white;
    }
    final bgColorHex = meta.extra['bg_accent_color'] as String?;
    if (bgColorHex != null) {
      _bgAccentColor =
          _parseHexColor(bgColorHex) ?? const Color(0xFF0D1B2A);
    }
    _titleFont = meta.extra['title_font'] as String? ?? 'Default';

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
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      if (cleaned.length == 8) return Color(int.parse(cleaned, radix: 16));
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

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
        if (text.isNotEmpty) count += text.split(RegExp(r'\s+')).length;
      }
    }
    return count;
  }

  String get _readingTime {
    final minutes = (_wordCount / 200).ceil();
    if (minutes <= 0) return '';
    return '$minutes min de leitura';
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
        .map((block) =>
            (block['url'] ?? block['image_url']) as String? ?? '')
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
        .map((block) =>
            (block['content'] ?? block['text']) as String? ?? '')
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COVER IMAGE
  // ═══════════════════════════════════════════════════════════════════════════

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
      await SupabaseService.storage
          .from('post_media')
          .uploadBinary(path, bytes);
      final url =
          SupabaseService.storage.from('post_media').getPublicUrl(path);
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

  // ═══════════════════════════════════════════════════════════════════════════
  // DRAFTS
  // ═══════════════════════════════════════════════════════════════════════════

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
                .map((item) => ContentBlock.fromJson(
                    Map<String, dynamic>.from(item as Map)))
                .toList();

        setState(() {
          _draftId = data['id'] as String?;
          _titleController.text = (data['title'] as String?) ?? '';
          _visibility = (data['visibility'] as String?) ?? 'public';
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
            content: const Text('Rascunho restaurado'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // Silently fail
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
            content: const Text(
                'Adicione um título ou conteúdo antes de salvar.'),
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
          content: const Text('Rascunho salvo'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBMIT
  // ═══════════════════════════════════════════════════════════════════════════

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
    return fallback.isEmpty
        ? 'Falha desconhecida ao publicar o blog.'
        : fallback;
  }

  Map<String, dynamic> _buildEditorMetadata() {
    return {
      'editor_type': 'blog',
      'title_color':
          '#${_titleColor.value.toRadixString(16).padLeft(8, '0')}',
      'bg_accent_color':
          '#${_bgAccentColor.value.toRadixString(16).padLeft(8, '0')}',
      'title_font': _titleFont,
      'tags': _tags,
      'pin_to_profile': _pinToProfile,
    };
  }

  Future<dynamic> _createBlogPost({
    required String title,
    required String content,
    required List<Map<String, dynamic>> contentBlocks,
    required List<String> mediaUrls,
  }) async {
    final errors = <String>[];
    final coverUrl =
        _coverImageUrl ?? (mediaUrls.isNotEmpty ? mediaUrls.first : null);
    final editorMetadata = _buildEditorMetadata();

    // Tentativa 1: RPC
    try {
      final result = await SupabaseService.rpc(
          'create_post_with_reputation',
          params: {
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

    // Tentativa 2: Insert direto
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
            'media_list': mediaUrls
                .map((url) => {'url': url, 'type': 'image'})
                .toList(),
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
          content:
              const Text('Adicione conteúdo ao blog antes de publicar.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isEditing) {
        final coverUrl = _coverImageUrl ??
            (mediaUrls.isNotEmpty ? mediaUrls.first : null);
        final editorMetadata = _buildEditorMetadata();

        final postData = {
          'title': title,
          'content': content,
          'type': 'blog',
          'media_list': mediaUrls
              .map((url) => {'url': url, 'type': 'image'})
              .toList(),
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

      // Modo de criação
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PREVIEW
  // ═══════════════════════════════════════════════════════════════════════════

  void _openPreview() {
    final title = _titleController.text.trim();
    final blocks = _serializeBlocks();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final r = context.r;
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: context.scaffoldBg,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(r.s(20)),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: r.s(12)),
                width: r.s(40),
                height: r.s(4),
                decoration: BoxDecoration(
                  color: context.dividerClr,
                  borderRadius: BorderRadius.circular(r.s(2)),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(20), vertical: r.s(12)),
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined,
                        color: context.textSecondary, size: r.s(18)),
                    SizedBox(width: r.s(8)),
                    Text(
                      'Pré-visualização',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              Divider(color: context.dividerClr, height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_coverImageUrl != null)
                        Image.network(
                          _coverImageUrl!,
                          width: double.infinity,
                          height: r.s(220),
                          fit: BoxFit.cover,
                        ),
                      Padding(
                        padding: EdgeInsets.all(r.s(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? 'Sem título' : title,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(26),
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                fontFamily:
                                    _fontFamilyFromName(_titleFont),
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
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    r.s(20)),
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
                            if (_readingTime.isNotEmpty) ...[
                              SizedBox(height: r.s(12)),
                              Text(
                                '$_wordCount palavras  ·  $_readingTime',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: r.fs(12),
                                ),
                              ),
                            ],
                            SizedBox(height: r.s(24)),
                            if (blocks.isEmpty)
                              Text(
                                'Adicione conteúdo para visualizar.',
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
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════════════════

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final r = ctx.r;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: ctx.scaffoldBg,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(r.s(20)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    margin: EdgeInsets.only(top: r.s(12)),
                    width: r.s(40),
                    height: r.s(4),
                    decoration: BoxDecoration(
                      color: ctx.dividerClr,
                      borderRadius: BorderRadius.circular(r.s(2)),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(20), vertical: r.s(12)),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            color: ctx.textSecondary, size: r.s(18)),
                        SizedBox(width: r.s(8)),
                        Text(
                          'Configurações do blog',
                          style: TextStyle(
                            color: ctx.textPrimary,
                            fontSize: r.fs(16),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded,
                              color: ctx.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: ctx.dividerClr, height: 1),
                  // Settings content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(r.s(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Tags ──
                          _SettingsSection(
                            icon: Icons.tag_rounded,
                            title: 'Tags',
                            subtitle:
                                '${_tags.length}/10 tags adicionadas',
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (_tags.isNotEmpty) ...[
                                  Wrap(
                                    spacing: r.s(6),
                                    runSpacing: r.s(6),
                                    children: _tags
                                        .map((tag) => _TagChip(
                                              tag: tag,
                                              onRemove: () {
                                                setState(() =>
                                                    _tags.remove(tag));
                                                setModalState(() {});
                                              },
                                            ))
                                        .toList(),
                                  ),
                                  SizedBox(height: r.s(10)),
                                ],
                                if (_tags.length < 10)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _tagController,
                                          style: TextStyle(
                                            color: ctx.textPrimary,
                                            fontSize: r.fs(13),
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Adicionar tag...',
                                            hintStyle: TextStyle(
                                              color:
                                                  ctx.textSecondary,
                                              fontSize: r.fs(13),
                                            ),
                                            filled: true,
                                            fillColor:
                                                ctx.surfaceColor,
                                            border:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          r.s(10)),
                                              borderSide:
                                                  BorderSide.none,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: r.s(12),
                                              vertical: r.s(10),
                                            ),
                                            isDense: true,
                                          ),
                                          onSubmitted: (_) {
                                            _addTag();
                                            setModalState(() {});
                                          },
                                        ),
                                      ),
                                      SizedBox(width: r.s(8)),
                                      _SmallButton(
                                        label: 'Adicionar',
                                        onTap: () {
                                          _addTag();
                                          setModalState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          SizedBox(height: r.s(20)),

                          // ── Visibilidade ──
                          _SettingsSection(
                            icon: Icons.visibility_outlined,
                            title: 'Visibilidade',
                            child: Row(
                              children: [
                                _VisibilityChip(
                                  label: 'Público',
                                  icon: Icons.public_rounded,
                                  isSelected:
                                      _visibility == 'public',
                                  onTap: () {
                                    setState(() =>
                                        _visibility = 'public');
                                    setModalState(() {});
                                  },
                                ),
                                SizedBox(width: r.s(8)),
                                _VisibilityChip(
                                  label: 'Seguidores',
                                  icon: Icons.people_rounded,
                                  isSelected:
                                      _visibility == 'followers',
                                  onTap: () {
                                    setState(() =>
                                        _visibility = 'followers');
                                    setModalState(() {});
                                  },
                                ),
                                SizedBox(width: r.s(8)),
                                _VisibilityChip(
                                  label: 'Privado',
                                  icon: Icons.lock_rounded,
                                  isSelected:
                                      _visibility == 'private',
                                  onTap: () {
                                    setState(() =>
                                        _visibility = 'private');
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: r.s(20)),

                          // ── Fonte do título ──
                          _SettingsSection(
                            icon: Icons.text_fields_rounded,
                            title: 'Fonte do título',
                            child: SizedBox(
                              height: r.s(40),
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _titleFonts.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(width: r.s(8)),
                                itemBuilder: (_, i) {
                                  final font = _titleFonts[i];
                                  final isSelected =
                                      _titleFont == font;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() =>
                                          _titleFont = font);
                                      setModalState(() {});
                                    },
                                    child: Container(
                                      padding:
                                          EdgeInsets.symmetric(
                                        horizontal: r.s(16),
                                        vertical: r.s(8),
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                                .withValues(
                                                    alpha: 0.15)
                                            : ctx.surfaceColor,
                                        borderRadius:
                                            BorderRadius.circular(
                                                r.s(10)),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme
                                                  .primaryColor
                                              : ctx.dividerClr,
                                          width: isSelected
                                              ? 1.5
                                              : 1,
                                        ),
                                      ),
                                      child: Text(
                                        font,
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppTheme
                                                  .primaryColor
                                              : ctx.textPrimary,
                                          fontSize: r.fs(13),
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontFamily:
                                              _fontFamilyFromName(
                                                  font),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          SizedBox(height: r.s(20)),

                          // ── Cor do título ──
                          _SettingsSection(
                            icon: Icons.format_color_text_rounded,
                            title: 'Cor do título',
                            child: _ColorPaletteRow(
                              colors: _textColorPresets,
                              selected: _titleColor,
                              onSelect: (c) {
                                setState(() => _titleColor = c);
                                setModalState(() {});
                              },
                            ),
                          ),

                          SizedBox(height: r.s(20)),

                          // ── Cor de fundo ──
                          _SettingsSection(
                            icon: Icons.palette_outlined,
                            title: 'Cor de destaque',
                            child: _ColorPaletteRow(
                              colors: _colorPresets,
                              selected: _bgAccentColor,
                              onSelect: (c) {
                                setState(
                                    () => _bgAccentColor = c);
                                setModalState(() {});
                              },
                            ),
                          ),

                          SizedBox(height: r.s(20)),

                          // ── Fixar no perfil ──
                          _SettingsSection(
                            icon: Icons.push_pin_outlined,
                            title: 'Fixar no perfil',
                            subtitle:
                                'Destaque este blog no topo do seu perfil',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _pinToProfile
                                        ? 'Ativado'
                                        : 'Desativado',
                                    style: TextStyle(
                                      color: _pinToProfile
                                          ? AppTheme.primaryColor
                                          : ctx.textSecondary,
                                      fontSize: r.fs(13),
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _pinToProfile,
                                  onChanged: (v) {
                                    setState(
                                        () => _pinToProfile = v);
                                    setModalState(() {});
                                  },
                                  activeColor:
                                      AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: r.s(20)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      // ── AppBar minimalista ──
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: context.surfaceColor,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.textPrimary),
          onPressed: _handleClose,
          tooltip: 'Fechar',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_draftId != null) ...[
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(8), vertical: r.s(3)),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(r.s(6)),
                ),
                child: Text(
                  'Rascunho',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: r.fs(11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Salvar rascunho
          IconButton(
            tooltip: 'Salvar rascunho',
            onPressed: (_isSavingDraft || _isSubmitting)
                ? null
                : () => _saveDraft(),
            icon: _isSavingDraft
                ? SizedBox(
                    width: r.s(18),
                    height: r.s(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.textSecondary,
                    ),
                  )
                : Icon(Icons.save_outlined,
                    color: context.textSecondary, size: r.s(22)),
          ),
          // Preview
          IconButton(
            tooltip: 'Pré-visualizar',
            onPressed: _openPreview,
            icon: Icon(Icons.visibility_outlined,
                color: context.textSecondary, size: r.s(22)),
          ),
          // Configurações
          IconButton(
            tooltip: 'Configurações',
            onPressed: _openSettings,
            icon: Icon(Icons.tune_rounded,
                color: context.textSecondary, size: r.s(22)),
          ),
          // Publicar
          Padding(
            padding: EdgeInsets.only(right: r.s(8)),
            child: _isSubmitting
                ? Padding(
                    padding: EdgeInsets.all(r.s(12)),
                    child: SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _submit,
                    style: TextButton.styleFrom(
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(10)),
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(8)),
                    ),
                    child: Text(
                      _isEditing ? s.save : s.publish,
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: _restoringDraft
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppTheme.accentColor,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: r.s(12)),
                  Text(
                    'Carregando...',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: r.fs(13),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cover Image (Hero) ──
                  _buildCoverSection(r),

                  // ── Área de edição principal ──
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.s(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: r.s(20)),

                        // Título
                        TextField(
                          controller: _titleController,
                          maxLength: 120,
                          textCapitalization:
                              TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                            color: _titleColor,
                            fontSize: r.fs(26),
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            fontFamily:
                                _fontFamilyFromName(_titleFont),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Título do seu blog...',
                            hintStyle: TextStyle(
                              color: context.textSecondary
                                  .withValues(alpha: 0.5),
                              fontSize: r.fs(26),
                              fontWeight: FontWeight.w800,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),

                        // Tags preview (inline, compacto)
                        if (_tags.isNotEmpty) ...[
                          SizedBox(height: r.s(8)),
                          Wrap(
                            spacing: r.s(6),
                            runSpacing: r.s(4),
                            children: _tags
                                .map((tag) => Text(
                                      '#$tag',
                                      style: TextStyle(
                                        color: AppTheme.accentColor
                                            .withValues(alpha: 0.7),
                                        fontSize: r.fs(13),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],

                        // Stats discretos
                        if (_wordCount > 0) ...[
                          SizedBox(height: r.s(12)),
                          Row(
                            children: [
                              Text(
                                '$_wordCount palavras',
                                style: TextStyle(
                                  color: context.textSecondary
                                      .withValues(alpha: 0.6),
                                  fontSize: r.fs(12),
                                ),
                              ),
                              if (_readingTime.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(6)),
                                  child: Text(
                                    '·',
                                    style: TextStyle(
                                      color: context.textSecondary
                                          .withValues(alpha: 0.4),
                                      fontSize: r.fs(12),
                                    ),
                                  ),
                                ),
                                Text(
                                  _readingTime,
                                  style: TextStyle(
                                    color: context.textSecondary
                                        .withValues(alpha: 0.6),
                                    fontSize: r.fs(12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        SizedBox(height: r.s(16)),
                        Divider(
                          color:
                              context.dividerClr.withValues(alpha: 0.3),
                          height: 1,
                        ),
                        SizedBox(height: r.s(16)),

                        // ── Block Editor ──
                        BlockEditor(
                          initialBlocks: _blocks,
                          communityId: widget.communityId,
                          onChanged: (blocks) =>
                              setState(() => _blocks = blocks),
                        ),

                        SizedBox(height: r.s(100)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COVER SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCoverSection(Responsive r) {
    if (_coverImageUrl != null) {
      return Stack(
        children: [
          Image.network(
            _coverImageUrl!,
            width: double.infinity,
            height: r.s(220),
            fit: BoxFit.cover,
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    context.scaffoldBg.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
          // Action buttons
          Positioned(
            top: r.s(12),
            right: r.s(12),
            child: Row(
              children: [
                _CoverActionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Trocar',
                  onTap: _pickCoverImage,
                ),
                SizedBox(width: r.s(8)),
                _CoverActionButton(
                  icon: Icons.close_rounded,
                  label: 'Remover',
                  onTap: () => setState(() => _coverImageUrl = null),
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
        margin: EdgeInsets.fromLTRB(r.s(20), r.s(8), r.s(20), 0),
        height: r.s(140),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: context.dividerClr.withValues(alpha: 0.3),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Center(
          child: _isUploadingCover
              ? CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(r.s(12)),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor
                            .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppTheme.primaryColor
                            .withValues(alpha: 0.7),
                        size: r.s(28),
                      ),
                    ),
                    SizedBox(height: r.s(10)),
                    Text(
                      'Adicionar capa',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      'Recomendado: 1200 x 630px',
                      style: TextStyle(
                        color: context.textSecondary
                            .withValues(alpha: 0.5),
                        fontSize: r.fs(11),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGETS AUXILIARES
// =============================================================================

class _CoverActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CoverActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(6)),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(r.s(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: r.s(14)),
            SizedBox(width: r.s(4)),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: r.fs(11),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SettingsSection({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: context.textSecondary, size: r.s(16)),
            SizedBox(width: r.s(8)),
            Text(
              title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(14),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const Spacer(),
              Text(
                subtitle!,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: r.fs(11),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: r.s(12)),
        child,
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;

  const _TagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(5)),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(8)),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
        ),
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
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                color: AppTheme.accentColor.withValues(alpha: 0.6),
                size: r.s(14)),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(10)),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(r.s(10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: r.fs(13),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisibilityChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.s(10)),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                : context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(10)),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : context.dividerClr,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : context.textSecondary,
                size: r.s(18),
              ),
              SizedBox(height: r.s(4)),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : context.textSecondary,
                  fontSize: r.fs(11),
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPaletteRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;

  const _ColorPaletteRow({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return SizedBox(
      height: r.s(36),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, __) => SizedBox(width: r.s(8)),
        itemBuilder: (_, i) {
          final color = colors[i];
          final isSelected = color.value == selected.value;
          return GestureDetector(
            onTap: () => onSelect(color),
            child: Container(
              width: r.s(36),
              height: r.s(36),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded,
                      color: Colors.white, size: r.s(16))
                  : null,
            ),
          );
        },
      ),
    );
  }
}
