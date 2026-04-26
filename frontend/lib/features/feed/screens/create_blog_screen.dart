import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/community_model.dart';
import '../../../core/providers/draft_provider.dart';
import '../../../core/providers/post_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/models/post_model.dart';
import '../../communities/providers/community_detail_providers.dart'
    as community_providers;
import '../widgets/block_content_renderer.dart';
import '../widgets/block_editor.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/haptic_service.dart';

// =============================================================================
// CREATE BLOG SCREEN — Editor de blogs estilo Amino
// =============================================================================

class CreateBlogScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;
  final String? draftId;

  const CreateBlogScreen({
    super.key,
    required this.communityId,
    this.editingPost,
    this.draftId,
  });

  @override
  ConsumerState<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends ConsumerState<CreateBlogScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();
  final _scrollController = ScrollController();
  final _contentFocusNode = FocusNode();
  final _blockEditorKey = GlobalKey<BlockEditorState>();

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

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromPost(widget.editingPost!);
      _restoringDraft = false;
    } else {
      // Só restaurar rascunho automaticamente quando um draftId específico é fornecido
      // (via tela de rascunhos). Ao criar novo, não restaurar automaticamente.
      if (widget.draftId != null) {
        Future.microtask(_restoreLatestDraft);
      } else {
        _restoringDraft = false;
      }
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

  /// Converte uma [Color] para string hexadecimal ARGB (#AARRGGBB).
  String _colorToHex(Color c) {
    final a = (c.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$a$r$g$b';
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
    _contentFocusNode.dispose();
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
        serialized.add({
          'type': 'divider',
          'divider_style': data['divider_style'] ?? 'dots',
        });
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
          .from('post-media')
          .uploadBinary(path, bytes);
      final url =
          SupabaseService.storage.from('post-media').getPublicUrl(path);
      if (mounted) setState(() => _coverImageUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: context.nexusTheme.error,
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
      final query = SupabaseService.table('post_drafts')
          .select()
          .eq('user_id', userId)
          .eq('community_id', widget.communityId);
      final result = widget.draftId != null
          ? await query.eq('id', widget.draftId!).limit(1)
          : await query
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
            backgroundColor: context.nexusTheme.success,
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
            backgroundColor: context.nexusTheme.error,
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
          backgroundColor: context.nexusTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível salvar o rascunho.'),
          backgroundColor: context.nexusTheme.error,
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
      'title_color': _colorToHex(_titleColor),
      'bg_accent_color': _colorToHex(_bgAccentColor),
      'title_font': _titleFont,
      'tags': _tags,
      'pin_to_profile': _pinToProfile,
    };
  }

  Future<bool> _createBlogPost({
    required String title,
    required String content,
    required List<Map<String, dynamic>> contentBlocks,
    required List<String> mediaUrls,
  }) async {
    final coverUrl =
        _coverImageUrl ?? (mediaUrls.isNotEmpty ? mediaUrls.first : null);
    final editorMetadata = _buildEditorMetadata();
    final mediaList = mediaUrls
        .map((url) => {'url': url, 'type': 'image'})
        .toList();

    // Usar o provider que já lida com todos os parâmetros corretamente
    final postData = {
      'title': title,
      'content': content,
      'type': 'blog',
      'media_list': mediaList,
      'tags': _tags,
      'cover_image_url': coverUrl,
      'visibility': _visibility,
      'content_blocks': contentBlocks,
      'is_pinned_profile': _pinToProfile,
      'editor_type': 'blog',
      'editor_metadata': editorMetadata,
    };

    final success = await ref
        .read(communityFeedProvider(widget.communityId).notifier)
        .createPost(postData);

    if (!success) {
      throw Exception('Erro ao publicar. Tente novamente.');
    }

    return success;
  }

  Future<void> _submit() async {
    HapticService.action(); // Feedback tátil ao publicar
    final s = getStrings();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.titleRequired),
          backgroundColor: context.nexusTheme.error,
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
          backgroundColor: context.nexusTheme.error,
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
                backgroundColor: context.nexusTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.anErrorOccurredTryAgain),
                backgroundColor: context.nexusTheme.error,
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
            backgroundColor: context.nexusTheme.success,
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
          backgroundColor: context.nexusTheme.error,
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
            color: context.nexusTheme.backgroundPrimary,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(r.s(16)),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: r.s(10)),
                width: r.s(36),
                height: r.s(4),
                decoration: BoxDecoration(
                  color: context.dividerClr,
                  borderRadius: BorderRadius.circular(r.s(2)),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(10)),
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined,
                        color: context.nexusTheme.textSecondary, size: r.s(16)),
                    SizedBox(width: r.s(6)),
                    Text(
                      'Pré-visualização',
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: context.nexusTheme.textSecondary, size: r.s(20)),
                    ),
                  ],
                ),
              ),
              Divider(color: context.dividerClr, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_coverImageUrl != null)
                        Image.network(
                          _coverImageUrl!,
                          width: double.infinity,
                          height: r.s(180),
                          fit: BoxFit.cover,
                        ),
                      Padding(
                        padding: EdgeInsets.all(r.s(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? 'Sem título' : title,
                              style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontSize: r.fs(22),
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                fontFamily:
                                    _fontFamilyFromName(_titleFont),
                              ),
                            ),
                            if (_tags.isNotEmpty) ...[
                              SizedBox(height: r.s(10)),
                              Wrap(
                                spacing: r.s(6),
                                runSpacing: r.s(4),
                                children: _tags
                                    .map((tag) => Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: r.s(8),
                                              vertical: r.s(3)),
                                          decoration: BoxDecoration(
                                            color: context.nexusTheme.accentSecondary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    r.s(6)),
                                          ),
                                          child: Text(
                                            '#$tag',
                                            style: TextStyle(
                                              color: context.nexusTheme.accentSecondary,
                                              fontSize: r.fs(11),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                            SizedBox(height: r.s(16)),
                            if (blocks.isEmpty)
                              Text(
                                'Nenhum conteúdo ainda.',
                                style: TextStyle(
                                  color: context.nexusTheme.textHint,
                                  fontSize: r.fs(13),
                                  fontStyle: FontStyle.italic,
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
                  top: Radius.circular(r.s(16)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: r.s(10)),
                    width: r.s(36),
                    height: r.s(4),
                    decoration: BoxDecoration(
                      color: ctx.dividerClr,
                      borderRadius: BorderRadius.circular(r.s(2)),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(10)),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            color: ctx.textSecondary, size: r.s(16)),
                        SizedBox(width: r.s(6)),
                        Text(
                          'Configurações',
                          style: TextStyle(
                            color: ctx.textPrimary,
                            fontSize: r.fs(15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded,
                              color: ctx.textSecondary, size: r.s(20)),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: ctx.dividerClr, height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(r.s(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Capa do Blog ──
                          _SettingsSection(
                            icon: Icons.photo_library_outlined,
                            title: 'Capa do blog',
                            subtitle: _isUploadingCover
                                ? 'Enviando capa...'
                                : _coverImageUrl != null
                                    ? 'Capa definida'
                                    : 'Sem capa',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isUploadingCover)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: r.s(8)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(r.s(4)),
                                      child: LinearProgressIndicator(
                                        backgroundColor: Colors.white12,
                                        color: context.nexusTheme.accentPrimary,
                                      ),
                                    ),
                                  ),
                                if (_coverImageUrl != null) ...[
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(r.s(10)),
                                    child: Image.network(
                                      _coverImageUrl!,
                                      width: double.infinity,
                                      height: r.s(120),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(height: r.s(8)),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SmallButton(
                                          label: 'Trocar capa',
                                          onTap: () {
                                            _pickCoverImage();
                                            Navigator.pop(ctx);
                                          },
                                        ),
                                      ),
                                      SizedBox(width: r.s(8)),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() =>
                                                _coverImageUrl = null);
                                            setModalState(() {});
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: r.s(12),
                                                vertical: r.s(8)),
                                            decoration: BoxDecoration(
                                              color: context.nexusTheme.error
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      r.s(8)),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Remover',
                                                style: TextStyle(
                                                  color:
                                                      context.nexusTheme.error,
                                                  fontSize: r.fs(12),
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else
                                  _SmallButton(
                                    label: 'Adicionar capa',
                                    onTap: () {
                                      _pickCoverImage();
                                      Navigator.pop(ctx);
                                    },
                                  ),
                              ],
                            ),
                          ),

                          SizedBox(height: r.s(16)),

                          // ── Tags ──
                          _SettingsSection(
                            icon: Icons.tag_rounded,
                            title: 'Tags',
                            subtitle:
                                '${_tags.length}/10',
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
                                  SizedBox(height: r.s(8)),
                                ],
                                if (_tags.length < 10)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _tagController,
                                          style: TextStyle(
                                            color: ctx.textPrimary,
                                            fontSize: r.fs(12),
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Adicionar tag...',
                                            hintStyle: TextStyle(
                                              color:
                                                  ctx.textSecondary,
                                              fontSize: r.fs(12),
                                            ),
                                            filled: true,
                                            fillColor:
                                                ctx.surfaceColor,
                                            border:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          r.s(8)),
                                              borderSide:
                                                  BorderSide.none,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: r.s(10),
                                              vertical: r.s(8),
                                            ),
                                            isDense: true,
                                          ),
                                          onSubmitted: (_) {
                                            _addTag();
                                            setModalState(() {});
                                          },
                                        ),
                                      ),
                                      SizedBox(width: r.s(6)),
                                      _SmallButton(
                                        label: '+',
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

                          SizedBox(height: r.s(16)),

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
                                SizedBox(width: r.s(6)),
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
                                SizedBox(width: r.s(6)),
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

                          SizedBox(height: r.s(16)),

                          // ── Fonte do título ──
                          _SettingsSection(
                            icon: Icons.text_fields_rounded,
                            title: 'Fonte do título',
                            child: SizedBox(
                              height: r.s(36),
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _titleFonts.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(width: r.s(6)),
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
                                        horizontal: r.s(14),
                                        vertical: r.s(6),
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? context.nexusTheme.accentPrimary
                                                .withValues(
                                                    alpha: 0.12)
                                            : ctx.surfaceColor,
                                        borderRadius:
                                            BorderRadius.circular(
                                                r.s(8)),
                                        border: Border.all(
                                          color: isSelected
                                              ? context.nexusTheme.accentPrimary
                                              : ctx.dividerClr,
                                          width: isSelected
                                              ? 1.5
                                              : 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          font,
                                          style: TextStyle(
                                            color: isSelected
                                                ? context.nexusTheme.accentPrimary
                                                : ctx.textPrimary,
                                            fontSize: r.fs(12),
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontFamily:
                                                _fontFamilyFromName(
                                                    font),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          SizedBox(height: r.s(16)),

                          // ── Cor do título ──
                          _SettingsSection(
                            icon: Icons.format_color_text_rounded,
                            title: 'Cor do título',
                            child: ColorPickerButton(
                              color: _titleColor,
                              title: 'Cor do título',
                              size: 36,
                              onColorChanged: (c) {
                                setState(() => _titleColor = c);
                                setModalState(() {});
                              },
                            ),
                          ),

                          SizedBox(height: r.s(16)),

                          // ── Cor de fundo ──
                          _SettingsSection(
                            icon: Icons.palette_outlined,
                            title: 'Cor de destaque',
                            child: ColorPickerButton(
                              color: _bgAccentColor,
                              title: 'Cor de destaque',
                              size: 36,
                              onColorChanged: (c) {
                                setState(() => _bgAccentColor = c);
                                setModalState(() {});
                              },
                            ),
                          ),

                          SizedBox(height: r.s(16)),

                          // ── Fixar no perfil ──
                          _SettingsSection(
                            icon: Icons.push_pin_outlined,
                            title: 'Fixar no perfil',
                            subtitle:
                                'Destaque no topo do perfil',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _pinToProfile
                                        ? 'Ativado'
                                        : 'Desativado',
                                    style: TextStyle(
                                      color: _pinToProfile
                                          ? context.nexusTheme.accentPrimary
                                          : ctx.textSecondary,
                                      fontSize: r.fs(12),
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
                                      context.nexusTheme.accentPrimary,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: r.s(16)),
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
  // INSERT BLOCKS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════════════════

  void _showInsertBlockSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final r = ctx.r;
        final s = getStrings();
        return Container(
          decoration: BoxDecoration(
            color: ctx.scaffoldBg,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(r.s(16)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: r.s(10)),
                width: r.s(36),
                height: r.s(4),
                decoration: BoxDecoration(
                  color: ctx.dividerClr,
                  borderRadius: BorderRadius.circular(r.s(2)),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(10)),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        color: ctx.textSecondary, size: r.s(16)),
                    SizedBox(width: r.s(6)),
                    Text(
                      'Inserir bloco',
                      style: TextStyle(
                        color: ctx.textPrimary,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded,
                          color: ctx.textSecondary, size: r.s(20)),
                    ),
                  ],
                ),
              ),
              Divider(color: ctx.dividerClr, height: 1),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _InsertBlockOption(
                      icon: Icons.text_fields_rounded,
                      label: s.text,
                      color: const Color(0xFF4CAF50),
                      onTap: () {
                        Navigator.pop(ctx);
                        _blockEditorKey.currentState?.addBlock(BlockType.text);
                      },
                    ),
                    _InsertBlockOption(
                      icon: Icons.title_rounded,
                      label: 'Subtítulo',
                      color: const Color(0xFFFF9800),
                      onTap: () {
                        Navigator.pop(ctx);
                        _blockEditorKey.currentState?.addBlock(BlockType.heading);
                      },
                    ),
                    _InsertBlockOption(
                      icon: Icons.format_quote_rounded,
                      label: 'Citação',
                      color: const Color(0xFF9C27B0),
                      onTap: () {
                        Navigator.pop(ctx);
                        _blockEditorKey.currentState?.addBlock(BlockType.quote);
                      },
                    ),
                    _InsertBlockOption(
                      icon: Icons.horizontal_rule_rounded,
                      label: s.divider,
                      color: const Color(0xFF607D8B),
                      onTap: () {
                        Navigator.pop(ctx);
                        _blockEditorKey.currentState?.addBlock(BlockType.divider);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.s(8)),
            ],
          ),
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

    final communityAsync =
        ref.watch(community_providers.communityDetailProvider(widget.communityId));

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: SafeArea(
        bottom: true,
        child: _restoringDraft
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: CircularProgressIndicator(
                        color: context.nexusTheme.accentSecondary,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(height: r.s(8)),
                    Text(
                      'Carregando...',
                      style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(12),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // ── Header Amino ──
                  _buildAminoHeader(r, communityAsync),
  
                  // ── Área de edição ──
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            _blockEditorKey.currentState?.focusLastTextBlock();
                          },
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                            SizedBox(height: r.s(12)),
  
                            // ── Título (direto, sem card) ──
                            TextField(
                              controller: _titleController,
                              focusNode: null,
                              maxLength: 120,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontSize: r.fs(18),
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                fontFamily:
                                    _fontFamilyFromName(_titleFont),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Título',
                                hintStyle: TextStyle(
                                  color: context.nexusTheme.textHint
                                      .withValues(alpha: 0.5),
                                  fontSize: r.fs(18),
                                  fontWeight: FontWeight.w700,
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
  
                            // Linha separadora fina
                            Container(
                              margin: EdgeInsets.symmetric(vertical: r.s(8)),
                              height: 0.5,
                              color: context.dividerClr.withValues(alpha: 0.25),
                            ),
  
                            // ── Block Editor (sem barra de adicionar) ──
                            BlockEditor(
                              key: _blockEditorKey,
                              initialBlocks: _blocks,
                              communityId: widget.communityId,
                              showAddBar: false,
                              placeholder:
                                  'Compartilhe seus pensamentos e ideias, escreva resenhas, publique imagens e GIFs, e muito mais.',
                              onChanged: (blocks) =>
                                  setState(() => _blocks = blocks),
                            ),
  
                            // ── Stats discretos ──
                            if (_wordCount > 0) ...[
                              SizedBox(height: r.s(12)),
                              Row(
                                children: [
                                  Text(
                                    '$_wordCount palavras',
                                    style: TextStyle(
                                      color: context.nexusTheme.textSecondary
                                          .withValues(alpha: 0.5),
                                      fontSize: r.fs(10),
                                    ),
                                  ),
                                  if (_readingTime.isNotEmpty) ...[
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(4)),
                                      child: Text(
                                        '·',
                                        style: TextStyle(
                                          color: context.nexusTheme.textSecondary
                                              .withValues(alpha: 0.3),
                                          fontSize: r.fs(10),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _readingTime,
                                      style: TextStyle(
                                        color: context.nexusTheme.textSecondary
                                            .withValues(alpha: 0.5),
                                        fontSize: r.fs(10),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
  
                                SizedBox(height: r.s(80)),
                              ],
                            ),
                          ),
                        ),
                      );
                      },
                    ),
                  ),
  
                  // ── Barra fixa inferior ──
                  _buildBottomToolbar(r, s),
                ],
              )
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AMINO HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAminoHeader(
      Responsive r, AsyncValue<CommunityModel> communityAsync) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = r.s(44) + topPadding;

    String? bannerUrl;
    Color themeColor = const Color(0xFF1A1A2E);

    communityAsync.whenData((community) {
      bannerUrl = community.bannerUrl;
      final parsed = _parseHexColor(community.themeColor);
      if (parsed != null) themeColor = parsed;
    });

    return Container(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo
          if (bannerUrl != null && bannerUrl!.isNotEmpty)
            Image.network(
              bannerUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [themeColor, themeColor.withValues(alpha: 0.7)],
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [themeColor, themeColor.withValues(alpha: 0.7)],
                ),
              ),
            ),

          // Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),

          // Conteúdo
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: topPadding,
            child: Row(
              children: [
                // Voltar
                IconButton(
                  onPressed: _handleClose,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: r.s(20),
                  ),
                  padding: EdgeInsets.all(r.s(8)),
                  constraints: const BoxConstraints(),
                ),

                // Título
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isEditing ? 'Editar Blog' : 'Novo Blog',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (_draftId != null) ...[
                        SizedBox(height: r.s(2)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(6), vertical: r.s(1)),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(r.s(3)),
                          ),
                          child: Text(
                            'Rascunho',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: r.fs(9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Publicar
                _isSubmitting
                    ? Padding(
                        padding: EdgeInsets.all(r.s(8)),
                        child: SizedBox(
                          width: r.s(18),
                          height: r.s(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: _submit,
                        icon: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: r.s(22),
                        ),
                        padding: EdgeInsets.all(r.s(8)),
                        constraints: const BoxConstraints(),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomToolbar(Responsive r, dynamic s) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: r.s(6),
        right: r.s(6),
        top: r.s(6),
        bottom: r.s(6) + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(
            color: context.dividerClr.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Câmera — inserir imagem
          _BottomToolbarButton(
            icon: Icons.camera_alt_outlined,
            tooltip: 'Inserir imagem',
            onTap: () {
              _blockEditorKey.currentState?.insertImageBlock();
            },
          ),

          SizedBox(width: r.s(2)),

          // Capa
          _BottomToolbarButton(
            icon: Icons.photo_library_outlined,
            tooltip: 'Capa do blog',
            badge: _coverImageUrl != null,
            onTap: () {
              if (_coverImageUrl != null) {
                _openSettings();
              } else {
                _pickCoverImage();
              }
            },
          ),

          SizedBox(width: r.s(2)),

          // Inserir blocos
          _BottomToolbarButton(
            icon: Icons.add_circle_outline_rounded,
            tooltip: 'Inserir bloco',
            onTap: _showInsertBlockSheet,
          ),

          SizedBox(width: r.s(2)),

          // Preview
          _BottomToolbarButton(
            icon: Icons.visibility_outlined,
            tooltip: 'Pré-visualizar',
            onTap: _openPreview,
          ),

          SizedBox(width: r.s(2)),

          // Rascunho
          _BottomToolbarButton(
            icon: Icons.save_outlined,
            tooltip: 'Salvar rascunho',
            isLoading: _isSavingDraft,
            onTap: (_isSavingDraft || _isSubmitting)
                ? null
                : () => _saveDraft(),
          ),

          const Spacer(),

          // Opções
          GestureDetector(
            onTap: _openSettings,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                color: context.nexusTheme.surfacePrimary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(r.s(6)),
                border: Border.all(
                  color: context.dividerClr.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: context.nexusTheme.textSecondary,
                    size: r.s(14),
                  ),
                  SizedBox(width: r.s(4)),
                  Text(
                    'Opções',
                    style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGETS AUXILIARES
// =============================================================================

class _BottomToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool badge;
  final bool isLoading;

  const _BottomToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.badge = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.s(6)),
        child: Container(
          width: r.s(36),
          height: r.s(36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.s(6)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: r.s(16),
                  height: r.s(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: context.nexusTheme.textSecondary,
                  ),
                )
              else
                Icon(
                  icon,
                  color: onTap != null
                      ? context.nexusTheme.textSecondary
                      : context.nexusTheme.textHint,
                  size: r.s(20),
                ),
              if (badge)
                Positioned(
                  top: r.s(3),
                  right: r.s(3),
                  child: Container(
                    width: r.s(6),
                    height: r.s(6),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.accentPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.surfaceColor,
                        width: 1,
                      ),
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

class _InsertBlockOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InsertBlockOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(44),
            height: r.s(44),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Icon(icon, color: color, size: r.s(20)),
          ),
          SizedBox(height: r.s(4)),
          Text(
            label,
            style: TextStyle(
              color: context.nexusTheme.textSecondary,
              fontSize: r.fs(10),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            Icon(icon, color: context.nexusTheme.textSecondary, size: r.s(14)),
            SizedBox(width: r.s(6)),
            Text(
              title,
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const Spacer(),
              Text(
                subtitle!,
                style: TextStyle(
                  color: context.nexusTheme.textSecondary,
                  fontSize: r.fs(10),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: r.s(10)),
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
          EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: context.nexusTheme.accentSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.s(6)),
        border: Border.all(
          color: context.nexusTheme.accentSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: TextStyle(
              color: context.nexusTheme.accentSecondary,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: r.s(3)),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                color: context.nexusTheme.accentSecondary.withValues(alpha: 0.5),
                size: r.s(12)),
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
            EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
        decoration: BoxDecoration(
          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.s(8)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: context.nexusTheme.accentPrimary,
              fontSize: r.fs(12),
              fontWeight: FontWeight.w600,
            ),
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
          padding: EdgeInsets.symmetric(vertical: r.s(8)),
          decoration: BoxDecoration(
            color: isSelected
                ? context.nexusTheme.accentPrimary.withValues(alpha: 0.1)
                : context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(8)),
            border: Border.all(
              color: isSelected
                  ? context.nexusTheme.accentPrimary
                  : context.dividerClr,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? context.nexusTheme.accentPrimary
                    : context.nexusTheme.textSecondary,
                size: r.s(16),
              ),
              SizedBox(height: r.s(3)),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? context.nexusTheme.accentPrimary
                      : context.nexusTheme.textSecondary,
                  fontSize: r.fs(10),
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


