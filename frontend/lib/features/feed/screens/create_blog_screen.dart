import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/providers/draft_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/block_content_renderer.dart';
import '../widgets/block_editor.dart';

// =============================================================================
// CREATE BLOG SCREEN — Editor de post tipo "Blog" (texto rico com blocos)
// =============================================================================

class CreateBlogScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CreateBlogScreen({super.key, required this.communityId});

  @override
  ConsumerState<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends ConsumerState<CreateBlogScreen> {
  final _titleController = TextEditingController();

  List<ContentBlock> _blocks = [];
  bool _isSubmitting = false;
  bool _isSavingDraft = false;
  bool _restoringDraft = true;
  String _visibility = 'public';
  String? _draftId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_restoreLatestDraft);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _hasAnyContent {
    if (_titleController.text.trim().isNotEmpty) return true;
    for (final block in _blocks) {
      if (block.type == BlockType.divider) return true;
      if (block.isTextBased && (block.controller?.text.trim().isNotEmpty ?? false)) {
        return true;
      }
      if (block.type == BlockType.image && (block.imageUrl?.isNotEmpty ?? false)) {
        return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _serializeBlocks() {
    final serialized = <Map<String, dynamic>>[];

    for (final block in _blocks) {
      final data = block.toJson();
      final type = data['type'] as String? ?? 'text';
      final text = ((data['content'] ?? data['text']) as String? ?? '').trim();
      final imageUrl = ((data['url'] ?? data['image_url']) as String? ?? '').trim();

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
    return blocks
        .where((block) => block['type'] == 'image')
        .map((block) => (block['url'] ?? block['image_url']) as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
  }

  String _buildPlainContent(List<Map<String, dynamic>> blocks) {
    return blocks
        .where((block) => block['type'] == 'text' || block['type'] == 'heading' || block['type'] == 'quote')
        .map((block) => (block['content'] ?? block['text']) as String? ?? '')
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
  }

  Future<void> _restoreLatestDraft() async {
    final s = getStrings();
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
        final restoredBlocks = ((data['content_blocks'] as List?) ?? const [])
            .map((item) => ContentBlock.fromJson(Map<String, dynamic>.from(item as Map)))
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
            content: Text('Rascunho restaurado com sucesso.'),
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
      if (mounted) {
        setState(() => _restoringDraft = false);
      }
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
            content: const Text('Adicione um título ou conteúdo antes de salvar.'),
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
    } catch (_) {
      // Sem bloqueio: publicação já terá sido concluída.
    }
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
      if (cleaned.isNotEmpty) {
        parts.add(cleaned);
      }
    }

    addPart(message);
    addPart(details);
    addPart(hint);

    if (parts.isNotEmpty) {
      return parts.join(' | ');
    }

    final fallback = normalized.replaceAll(RegExp(r'\)+$'), '').trim();
    return fallback.isEmpty ? 'Falha desconhecida ao publicar o blog.' : fallback;
  }

  String _formatCreateAttemptError(String stage, dynamic error) {
    return '$stage: ${_extractErrorMessage(error)}';
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
    final coverImageUrl = mediaUrls.isNotEmpty ? mediaUrls.first : null;

    final params = {
      'p_community_id': widget.communityId,
      'p_title': title,
      'p_content': content,
      'p_type': 'blog',
      'p_media_list': mediaUrls,
      'p_cover_image_url': coverImageUrl,
      'p_visibility': _visibility,
      'p_comments_blocked': false,
      'p_content_blocks': contentBlocks,
      'p_is_pinned_profile': false,
    };

    try {
      return await SupabaseService.rpc('create_post_with_reputation', params: params);
    } catch (rpcError) {
      errors.add(_formatCreateAttemptError('RPC atual', rpcError));
    }

    try {
      final legacyParams = Map<String, dynamic>.from(params)
        ..remove('p_content_blocks')
        ..remove('p_is_pinned_profile');

      final legacyResult = await SupabaseService.rpc(
        'create_post_with_reputation',
        params: legacyParams,
      );

      final legacyPostId = _extractPostId(legacyResult);
      if (legacyPostId != null) {
        try {
          await SupabaseService.table('posts').update({
            'content_blocks': contentBlocks,
            'is_pinned_profile': false,
          }).eq('id', legacyPostId);
        } catch (legacyUpdateError) {
          errors.add(
            _formatCreateAttemptError(
              'Atualização complementar pós-RPC legada',
              legacyUpdateError,
            ),
          );
        }
      }

      return legacyResult;
    } catch (legacyRpcError) {
      errors.add(_formatCreateAttemptError('RPC legada', legacyRpcError));
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception(getStrings().notAuthenticated);
    }

    final insertAttempts = <Map<String, dynamic>>[
      {
        'label': 'Inserção direta completa',
        'payload': {
          'community_id': widget.communityId,
          'author_id': userId,
          'type': 'blog',
          'title': title,
          'content': content,
          'content_blocks': contentBlocks,
          'media_list': mediaUrls,
          'cover_image_url': coverImageUrl,
          'visibility': _visibility,
          'comments_blocked': false,
          'status': 'ok',
          'is_pinned_profile': false,
        },
      },
      {
        'label': 'Inserção direta compatível',
        'payload': {
          'community_id': widget.communityId,
          'author_id': userId,
          'type': 'blog',
          'title': title,
          'content': content,
          'media_list': mediaUrls,
          'cover_image_url': coverImageUrl,
          'visibility': _visibility,
          'comments_blocked': false,
          'status': 'ok',
        },
      },
      {
        'label': 'Inserção direta mínima',
        'payload': {
          'community_id': widget.communityId,
          'author_id': userId,
          'type': 'blog',
          'title': title,
          'content': content,
          'media_list': mediaUrls,
          'cover_image_url': coverImageUrl,
          'status': 'ok',
        },
      },
    ];

    for (final attempt in insertAttempts) {
      try {
        final payload = Map<String, dynamic>.from(
          attempt['payload'] as Map<String, dynamic>,
        );
        final inserted = await SupabaseService.table('posts')
            .insert(payload)
            .select('id')
            .single();

        return inserted['id'];
      } catch (insertError) {
        errors.add(
          _formatCreateAttemptError(attempt['label'] as String, insertError),
        );
      }
    }

    throw Exception(errors.join('\n'));
  }

  Future<void> _submit() async {
    final s = getStrings();
    final title = _titleController.text.trim();
    final contentBlocks = _serializeBlocks();
    final content = _buildPlainContent(contentBlocks);
    final mediaUrls = _extractMediaUrls(contentBlocks);

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

    if (contentBlocks.isEmpty) {
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
      await _createBlogPost(
        title: title,
        content: content,
        contentBlocks: contentBlocks,
        mediaUrls: mediaUrls,
      );

      await _deleteDraftIfNeeded();

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.blogPublishedSuccess),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      return;
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
              padding: EdgeInsets.fromLTRB(r.s(20), r.s(12), r.s(20), r.s(28)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: r.s(42),
                      height: r.s(4),
                      decoration: BoxDecoration(
                        color: context.dividerClr,
                        borderRadius: BorderRadius.circular(r.s(999)),
                      ),
                    ),
                  ),
                  SizedBox(height: r.s(20)),
                  Text(
                    title.isEmpty ? 'Pré-visualização do blog' : title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(24),
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          s.newBlog,
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
          IconButton(
            tooltip: 'Pré-visualizar',
            onPressed: _openPreview,
            icon: Icon(Icons.visibility_outlined, color: context.textPrimary),
          ),
          TextButton(
            onPressed: (_isSavingDraft || _isSubmitting) ? null : () => _saveDraft(),
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
                child: Text(s.publicLabel, style: TextStyle(color: context.textPrimary)),
              ),
              PopupMenuItem(
                value: 'followers',
                child: Text(s.followers, style: TextStyle(color: context.textPrimary)),
              ),
              PopupMenuItem(
                value: 'private',
                child: Text(s.privateLabel, style: TextStyle(color: context.textPrimary)),
              ),
            ],
          ),
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
                    s.publish,
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
          : SingleChildScrollView(
              padding: EdgeInsets.all(r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(r.s(12)),
                    decoration: BoxDecoration(
                      color: context.cardBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(color: context.dividerClr),
                    ),
                    child: Text(
                      _draftId == null
                          ? 'Escreva seu blog com blocos de texto, imagem e subtítulos. Você pode salvar rascunhos e visualizar antes de publicar.'
                          : 'Você está editando um rascunho salvo. As alterações podem ser salvas novamente a qualquer momento.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: r.fs(13),
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: r.s(16)),
                  TextField(
                    controller: _titleController,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(22),
                      fontWeight: FontWeight.w700,
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
                  Divider(color: context.dividerClr, height: r.s(24)),
                  BlockEditor(
                    initialBlocks: _blocks,
                    communityId: widget.communityId,
                    onChanged: (blocks) => setState(() => _blocks = blocks),
                  ),
                  SizedBox(height: r.s(80)),
                ],
              ),
            ),
    );
  }
}
