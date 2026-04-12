import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/post_model.dart';
import '../../../core/providers/post_provider.dart';
import '../../../core/providers/draft_provider.dart';
import 'dart:async';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// CREATE QUESTION SCREEN — Post tipo Q&A (pergunta aberta para a comunidade)
//
// Melhorias:
//   - Tags de categoria para classificar a pergunta
//   - Imagem de referência (opcional)
//   - Toggle de pergunta anônima
//   - Urgência da pergunta (normal, urgente)
//   - Suporte a editor_metadata
// =============================================================================

class CreateQuestionScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;
  const CreateQuestionScreen({super.key, required this.communityId, this.editingPost});

  @override
  ConsumerState<CreateQuestionScreen> createState() =>
      _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends ConsumerState<CreateQuestionScreen> {
  final _questionController = TextEditingController();
  final _contextController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _isAnonymous = false;
  bool _isUrgent = false;
  String _visibility = 'public';
  String? _referenceImageUrl;

  bool get _isEditing => widget.editingPost != null;

  // ── Rascunhos automáticos ──
  String? _draftId;
  bool _isSavingDraft = false;
  Timer? _autoDraftTimer;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromPost(widget.editingPost!);
    } else {
      Future.microtask(_restoreLatestDraft);
      _startAutoDraftTimer();
    }
  }

  void _populateFromPost(PostModel post) {
    _questionController.text = post.title ?? '';
    _contextController.text = post.content;
    _visibility = post.editorMetadata.extra['visibility'] as String? ?? 'public';
    _isAnonymous = post.editorMetadata.extra['is_anonymous'] == true;
    _isUrgent = post.editorMetadata.extra['is_urgent'] == true;

    // Restaurar imagem de referência
    _referenceImageUrl = post.coverImageUrl;

    // Restaurar tags
    if (post.tags.isNotEmpty) {
      _tags.addAll(post.tags);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // RASCUNHOS AUTOMÁTICOS
  // ════════════════════════════════════════════════════════════════════════════

  void _startAutoDraftTimer() {
    _autoDraftTimer?.cancel();
    _autoDraftTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _saveDraft(silent: true),
    );
  }

  Future<void> _restoreLatestDraft() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final result = await SupabaseService.table('post_drafts')
          .select()
          .eq('user_id', userId)
          .eq('community_id', widget.communityId)
          .eq('post_type', 'qa')
          .order('updated_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      final list = (result as List?) ?? const [];
      if (list.isNotEmpty) {
        final data = Map<String, dynamic>.from(list.first as Map);
        setState(() {
          _draftId = data['id'] as String?;
          _questionController.text = (data['title'] as String?) ?? '';
          _contextController.text = (data['content'] as String?) ?? '';
          _referenceImageUrl = data['cover_image_url'] as String?;
          _visibility = (data['visibility'] as String?) ?? 'public';
          final tags = (data['tags'] as List?) ?? [];
          _tags.addAll(tags.map((t) => t.toString()));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rascunho restaurado.'),
            backgroundColor: context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveDraft({bool silent = false}) async {
    if (_isSavingDraft || _isEditing) return;
    if (!(_questionController.text.trim().isNotEmpty)) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Adicione conteúdo antes de salvar.'),
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
          postType: 'qa',
          title: _questionController.text.trim(),
          content: _contextController.text.trim(),
          coverImageUrl: _referenceImageUrl,
          tags: _tags,
          visibility: _visibility,
        );
        _draftId = created?.id;
      } else {
        await draftsNotifier.updateDraft(
          _draftId!,
          communityId: widget.communityId,
          postType: 'qa',
          title: _questionController.text.trim(),
          content: _contextController.text.trim(),
          coverImageUrl: _referenceImageUrl,
          tags: _tags,
          visibility: _visibility,
        );
      }

      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rascunho salvo.'),
          backgroundColor: context.nexusTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao salvar rascunho.'),
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
      final draftsNotifier = ref.read(postDraftsProvider.notifier);
      await draftsNotifier.deleteDraft(_draftId!);
    } catch (_) {}
  }

  @override
  void dispose() {
    _questionController.dispose();
    _contextController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.length >= 5 || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Future<void> _pickReferenceImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isUploadingImage = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_ref_${image.name}';
      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      final url =
          SupabaseService.storage.from('post-media').getPublicUrl(path);
      if (mounted) setState(() => _referenceImageUrl = url);
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
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _submit() async {
    final s = getStrings();
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.questionRequired),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await _deleteDraftIfNeeded();
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      // ── Modo de EDIÇÃO ──
      if (_isEditing) {
        final editorMetadata = <String, dynamic>{
          'editor_type': 'qa',
          'tags': _tags,
          'is_anonymous': _isAnonymous,
          'is_urgent': _isUrgent,
        };

        final postData = {
          'title': question,
          'content': _contextController.text.trim(),
          'type': 'qa',
          'media_list': _referenceImageUrl != null ? [{'url': _referenceImageUrl!, 'type': 'image'}] : [],
          'tags': _tags,
          'cover_image_url': _referenceImageUrl,
          'visibility': _visibility,
          'editor_type': 'qa',
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

      // ── Modo de CRIAÇÃO ──
      final editorMetadata = <String, dynamic>{
        'editor_type': 'qa',
        'tags': _tags,
        'is_anonymous': _isAnonymous,
        'is_urgent': _isUrgent,
      };

      final mediaUrls = <String>[];
      if (_referenceImageUrl != null) mediaUrls.add(_referenceImageUrl!);

      // Tentar RPC primeiro
      try {
        await SupabaseService.rpc('create_post_with_reputation', params: {
          'p_community_id': widget.communityId,
          'p_title': question,
          'p_content': _contextController.text.trim(),
          'p_type': 'qa',
          'p_visibility': _visibility,
          'p_media_urls': mediaUrls,
          'p_cover_image_url': _referenceImageUrl,
          'p_editor_type': 'qa',
          'p_editor_metadata': editorMetadata,
        });
      } catch (_) {
        // Fallback: insert direto
        final result = await SupabaseService.table('posts')
            .insert({
              'community_id': widget.communityId,
              'author_id': userId,
              'type': 'qa',
              'title': question,
              'content': _contextController.text.trim(),
              'media_list': _referenceImageUrl != null
                  ? [
                      {'url': _referenceImageUrl!, 'type': 'image'}
                    ]
                  : [],
              'cover_image_url': _referenceImageUrl,
              'visibility': _visibility,
              'comments_blocked': false,
              'editor_type': 'qa',
              'editor_metadata': editorMetadata,
            })
            .select()
            .single();

        try {
          await SupabaseService.rpc('add_reputation', params: {
            'p_user_id': userId,
            'p_community_id': widget.communityId,
            'p_action_type': 'post_create',
            'p_raw_amount': 15,
            'p_reference_id': result['id'],
          });
        } catch (_) {}
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.questionPublishedSuccess),
            backgroundColor: context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorPublishing2),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final accentOrange = const Color(0xFFEA580C);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          _isEditing ? s.editPost : 'Fazer Pergunta',
          style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(17),
              fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.nexusTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _visibility,
            onSelected: (v) => setState(() => _visibility = v),
            color: context.surfaceColor,
            icon: Icon(
              _visibility == 'public'
                  ? Icons.public_rounded
                  : _visibility == 'followers'
                      ? Icons.people_rounded
                      : Icons.lock_rounded,
              color: context.nexusTheme.accentSecondary,
              size: r.s(20),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'public',
                  child: Text(s.publicLabel,
                      style: TextStyle(color: context.nexusTheme.textPrimary))),
              PopupMenuItem(
                  value: 'followers',
                  child: Text(s.followers,
                      style: TextStyle(color: context.nexusTheme.textPrimary))),
              PopupMenuItem(
                  value: 'private',
                  child: Text(s.privateLabel,
                      style: TextStyle(color: context.nexusTheme.textPrimary))),
            ],
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    width: r.s(18),
                    height: r.s(18),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.nexusTheme.accentPrimary),
                  )
                : Text(
                    _isEditing ? s.save : s.publish,
                    style: TextStyle(
                        color: context.nexusTheme.accentPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w700),
                  ),
          ),
          SizedBox(width: r.s(4)),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone decorativo
            Center(
              child: Container(
                width: r.s(64),
                height: r.s(64),
                decoration: BoxDecoration(
                  color: accentOrange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.help_rounded,
                    color: accentOrange, size: r.s(32)),
              ),
            ),
            SizedBox(height: r.s(8)),
            Center(
              child: Text(
                s.askCommunity,
                style: TextStyle(
                    color: context.nexusTheme.textSecondary, fontSize: r.fs(13)),
              ),
            ),
            SizedBox(height: r.s(24)),

            // Pergunta
            TextField(
              controller: _questionController,
              maxLength: 300,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: s.whatDoYouWantToKnow,
                hintStyle: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(20),
                    fontWeight: FontWeight.w600),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            Divider(color: context.dividerClr, height: r.s(24)),

            // Contexto adicional
            TextField(
              controller: _contextController,
              maxLength: 1000,
              maxLines: 8,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style:
                  TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(15)),
              decoration: InputDecoration(
                hintText: s.addContextHint,
                hintStyle: TextStyle(
                    color: context.nexusTheme.textSecondary, fontSize: r.fs(15)),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            SizedBox(height: r.s(16)),

            // Imagem de referência
            _buildReferenceImageSection(r, accentOrange),
            SizedBox(height: r.s(16)),

            // Tags de categoria
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(12)),
            Text(
              'Categorias',
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: r.s(4)),
            Text(
              'Adicione tags para classificar sua pergunta',
              style: TextStyle(
                  color: context.nexusTheme.textSecondary, fontSize: r.fs(11)),
            ),
            SizedBox(height: r.s(8)),
            _buildTagsSection(r),
            SizedBox(height: r.s(16)),

            // Toggles
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(8)),
            _buildToggleRow(
              icon: Icons.priority_high_rounded,
              label: 'Pergunta urgente',
              subtitle: 'Destacar como urgente para a comunidade',
              value: _isUrgent,
              onChanged: (v) => setState(() => _isUrgent = v),
              color: context.nexusTheme.error,
              r: r,
            ),
            _buildToggleRow(
              icon: Icons.person_off_rounded,
              label: 'Perguntar anonimamente',
              subtitle: 'Seu nome não será exibido',
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              color: context.nexusTheme.textSecondary,
              r: r,
            ),
            SizedBox(height: r.s(16)),

            // Dica
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: accentOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: accentOrange.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: accentOrange, size: r.s(16)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      'Perguntas claras e específicas recebem mais respostas. '
                      'Inclua detalhes relevantes no contexto.',
                      style: TextStyle(
                          color:
                              context.nexusTheme.textPrimary.withValues(alpha: 0.7),
                          fontSize: r.fs(12),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(80)),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceImageSection(Responsive r, Color accent) {
    if (_referenceImageUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(12)),
            child: Image.network(
              _referenceImageUrl!,
              width: double.infinity,
              height: r.s(160),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: r.s(8),
            right: r.s(8),
            child: Row(
              children: [
                _circleBtn(Icons.camera_alt_rounded, _pickReferenceImage, r),
                SizedBox(width: r.s(8)),
                _circleBtn(Icons.close_rounded,
                    () => setState(() => _referenceImageUrl = null), r),
              ],
            ),
          ),
          Positioned(
            bottom: r.s(8),
            left: r.s(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(8), vertical: r.s(4)),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(r.s(6)),
              ),
              child: Text(
                'Imagem de referência',
                style: TextStyle(
                    color: Colors.white, fontSize: r.fs(10)),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _isUploadingImage ? null : _pickReferenceImage,
      child: Container(
        height: r.s(64),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
              color: context.dividerClr.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: _isUploadingImage
              ? CircularProgressIndicator(
                  color: accent, strokeWidth: 2)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: context.nexusTheme.textSecondary, size: r.s(20)),
                    SizedBox(width: r.s(8)),
                    Text(
                      'Adicionar imagem de referência',
                      style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(13)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, Responsive r) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(r.s(6)),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: r.s(16)),
      ),
    );
  }

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
                        color: context.nexusTheme.accentSecondary
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('#$tag',
                              style: TextStyle(
                                  color: context.nexusTheme.accentSecondary,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: r.s(4)),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _tags.remove(tag)),
                            child: Icon(Icons.close_rounded,
                                color: context.nexusTheme.accentSecondary,
                                size: r.s(14)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: r.s(8)),
        ],
        if (_tags.length < 5)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary, fontSize: r.fs(13)),
                  decoration: InputDecoration(
                    hintText: 'Ex: ajuda, dúvida, tutorial...',
                    hintStyle: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(13)),
                    border: InputBorder.none,
                    isDense: true,
                    prefixIcon: Icon(Icons.tag_rounded,
                        color: context.nexusTheme.textSecondary, size: r.s(16)),
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
                    color: context.nexusTheme.accentSecondary
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text('Adicionar',
                      style: TextStyle(
                          color: context.nexusTheme.accentSecondary,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
    required Responsive r,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.s(4)),
      child: Row(
        children: [
          Icon(icon, color: color, size: r.s(20)),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(11))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }
}
