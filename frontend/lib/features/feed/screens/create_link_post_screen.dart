import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/post_model.dart';
import '../../../core/providers/post_provider.dart';
import '../../../core/providers/draft_provider.dart';
import 'dart:async';
import '../../../core/services/og_tags_service.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/core/widgets/nexus_media_picker.dart';

// =============================================================================
// CREATE LINK POST SCREEN — Post com URL externa
//
// Melhorias:
//   - Preview visual do link (card com título, domínio e thumbnail)
//   - Upload de thumbnail customizada
//   - Tags
//   - Validação de URL em tempo real com indicador visual
//   - Suporte a editor_metadata
// =============================================================================

class CreateLinkPostScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;
  const CreateLinkPostScreen({super.key, required this.communityId, this.editingPost});

  @override
  ConsumerState<CreateLinkPostScreen> createState() =>
      _CreateLinkPostScreenState();
}

class _CreateLinkPostScreenState extends ConsumerState<CreateLinkPostScreen> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  bool _isSubmitting = false;
  bool _isUploadingThumb = false;
  String _visibility = 'public';
  String? _thumbnailUrl;
  bool _urlValid = false;
  bool _isFetchingOg = false;
  OgTagsData? _ogData;
  Timer? _ogDebounceTimer;

  bool get _isEditing => widget.editingPost != null;

  // ── Rascunhos automáticos ──
  String? _draftId;
  bool _isSavingDraft = false;
  Timer? _autoDraftTimer;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    if (_isEditing) {
      _populateFromPost(widget.editingPost!);
    } else {
      Future.microtask(_restoreLatestDraft);
      _startAutoDraftTimer();
    }
  }

  void _populateFromPost(PostModel post) {
    _titleController.text = post.title ?? '';
    _descriptionController.text = post.content;
    _visibility = post.editorMetadata.extra['visibility'] as String? ?? 'public';

    // Restaurar URL
    final linkUrl = post.externalUrl ??
        post.editorMetadata.extra['link_url'] as String? ?? '';
    _urlController.text = linkUrl;

    // Restaurar thumbnail
    _thumbnailUrl = post.coverImageUrl;

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
          .eq('post_type', 'link')
          .order('updated_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      final list = (result as List?) ?? const [];
      if (list.isNotEmpty) {
        final data = Map<String, dynamic>.from(list.first as Map);
        setState(() {
          _draftId = data['id'] as String?;
          _titleController.text = (data['title'] as String?) ?? '';
          _descriptionController.text = (data['content'] as String?) ?? '';
          _urlController.text = (data['external_url'] as String?) ?? '';
          _thumbnailUrl = data['cover_image_url'] as String?;
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
    if (!(_titleController.text.trim().isNotEmpty || _urlController.text.trim().isNotEmpty)) {
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
          postType: 'link',
          title: _titleController.text.trim(),
          content: _descriptionController.text.trim(),
          externalUrl: _urlController.text.trim(),
          coverImageUrl: _thumbnailUrl,
          tags: _tags,
          visibility: _visibility,
        );
        _draftId = created?.id;
      } else {
        await draftsNotifier.updateDraft(
          _draftId!,
          communityId: widget.communityId,
          postType: 'link',
          title: _titleController.text.trim(),
          content: _descriptionController.text.trim(),
          externalUrl: _urlController.text.trim(),
          coverImageUrl: _thumbnailUrl,
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
    _autoDraftTimer?.cancel();
    _ogDebounceTimer?.cancel();
    _titleController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _titleController.text.trim().isNotEmpty ||
      _urlController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _tags.isNotEmpty;

  Future<void> _onWillPop() async {
    if (_hasContent && !_isEditing) {
      await _saveDraft(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getStrings().draftSaved),
            backgroundColor: context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    if (mounted) context.pop();
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    final valid = Uri.tryParse(url)?.hasAbsolutePath == true &&
        (url.startsWith('http://') || url.startsWith('https://'));
    if (valid != _urlValid) setState(() => _urlValid = valid);

    // Debounce OG fetch — espera 800ms após parar de digitar
    _ogDebounceTimer?.cancel();
    if (valid) {
      _ogDebounceTimer = Timer(const Duration(milliseconds: 800), () {
        _fetchOgTags(url);
      });
    } else {
      setState(() => _ogData = null);
    }
  }

  Future<void> _fetchOgTags(String url) async {
    if (_isFetchingOg) return;
    setState(() => _isFetchingOg = true);

    try {
      final data = await OgTagsService.fetch(url);
      if (!mounted) return;

      setState(() {
        _ogData = data;
        _isFetchingOg = false;

        // Auto-preencher campos vazios com dados OG
        if (!data.isEmpty) {
          if (_titleController.text.trim().isEmpty && data.title != null) {
            _titleController.text = data.title!;
          }
          if (_descriptionController.text.trim().isEmpty &&
              data.description != null) {
            _descriptionController.text = data.description!;
          }
          if (_thumbnailUrl == null && data.image != null) {
            _thumbnailUrl = data.image;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isFetchingOg = false);
    }
  }

  String? _extractDomain(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return null;
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

  Future<void> _pickThumbnail() async {
    final s = getStrings();
    final _pickedFiles_image = await showNexusMediaPicker(
  context,
  maxSelect: 1,
  mode: NexusPickerMode.imageOnly,
);
if (_pickedFiles_image.isEmpty) return;
final image = _pickedFiles_image.first.file;
    if (image == null || !mounted) return;

    setState(() => _isUploadingThumb = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_thumb_${image.path.split('/').last}';
      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      final url =
          SupabaseService.storage.from('post-media').getPublicUrl(path);
      if (mounted) setState(() => _thumbnailUrl = url);
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
      if (mounted) setState(() => _isUploadingThumb = false);
    }
  }

  Future<void> _submit() async {
    final s = getStrings();
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();

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
    if (url.isEmpty || !_urlValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.enterValidLink),
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
          'editor_type': 'link',
          'tags': _tags,
          'link_url': url,
          'domain': _extractDomain(url),
        };

        final postData = {
          'title': title,
          'content': _descriptionController.text.trim(),
          'type': 'link',
          'external_url': url,
          'media_list': _thumbnailUrl != null ? [{'url': _thumbnailUrl!, 'type': 'image'}] : [],
          'tags': _tags,
          'cover_image_url': _thumbnailUrl,
          'visibility': _visibility,
          'editor_type': 'link',
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
        'editor_type': 'link',
        'tags': _tags,
        'link_url': url,
        'domain': _extractDomain(url),
      };

      // Tentar RPC primeiro
      try {
        await SupabaseService.rpc('create_post_with_reputation', params: {
          'p_community_id': widget.communityId,
          'p_title': title,
          'p_content': _descriptionController.text.trim(),
          'p_type': 'link',
          'p_visibility': _visibility,
          'p_media_urls': _thumbnailUrl != null ? [_thumbnailUrl!] : <String>[],
          'p_cover_image_url': _thumbnailUrl,
          'p_editor_type': 'link',
          'p_editor_metadata': editorMetadata,
        });
      } catch (_) {
        // Fallback: insert direto
        final result = await SupabaseService.table('posts')
            .insert({
              'community_id': widget.communityId,
              'author_id': userId,
              'type': 'link',
              'title': title,
              'content': _descriptionController.text.trim(),
              'external_url': url,
              'media_list': _thumbnailUrl != null
                  ? [
                      {'url': _thumbnailUrl!, 'type': 'image'}
                    ]
                  : [],
              'cover_image_url': _thumbnailUrl,
              'visibility': _visibility,
              'comments_blocked': false,
              'editor_type': 'link',
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
            content: Text(s.linkSharedSuccess),
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
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          _isEditing ? s.editPost : s.shareLinkTitle,
          style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(17),
              fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.nexusTheme.textPrimary),
          onPressed: _onWillPop,
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
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(r.s(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card de URL com validação visual
              Container(
                padding: EdgeInsets.all(r.s(16)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.surfacePrimary,
                  borderRadius: BorderRadius.circular(r.s(16)),
                  border: Border.all(
                      color: _urlValid
                          ? context.nexusTheme.success.withValues(alpha: 0.4)
                          : context.dividerClr.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(r.s(8)),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(r.s(8)),
                          ),
                          child: Icon(Icons.link_rounded,
                              color: const Color(0xFF2563EB), size: r.s(20)),
                        ),
                        SizedBox(width: r.s(10)),
                        Text(
                          'URL do Link',
                          style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontSize: r.fs(14),
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (_urlValid)
                          Icon(Icons.check_circle_rounded,
                              color: context.nexusTheme.success, size: r.s(18)),
                      ],
                    ),
                    SizedBox(height: r.s(12)),
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      style: TextStyle(
                          color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        hintStyle: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(14)),
                        filled: true,
                        fillColor: context.nexusTheme.backgroundPrimary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.s(10)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.s(10)),
                          borderSide: BorderSide(
                              color: _urlValid
                                  ? context.nexusTheme.success
                                  : const Color(0xFF2563EB),
                              width: 1.5),
                        ),
                        prefixIcon: Icon(Icons.language_rounded,
                            color: context.nexusTheme.textSecondary, size: r.s(18)),
                      ),
                    ),
                  ],
                ),
              ),
  
              // Preview do link
              if (_urlValid) ...[
                SizedBox(height: r.s(12)),
                _buildLinkPreview(r),
              ],
  
              SizedBox(height: r.s(16)),
  
              // Título
              TextField(
                controller: _titleController,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(20),
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: s.postTitleHint,
                  hintStyle: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(20),
                      fontWeight: FontWeight.w700),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
              Divider(color: context.dividerClr),
              SizedBox(height: r.s(8)),
  
              // Descrição
              TextField(
                controller: _descriptionController,
                maxLength: 500,
                maxLines: 5,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style:
                    TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(15)),
                decoration: InputDecoration(
                  hintText: s.describeLinkHint,
                  hintStyle: TextStyle(
                      color: context.nexusTheme.textSecondary, fontSize: r.fs(15)),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
              SizedBox(height: r.s(16)),
  
              // Thumbnail customizada
              Divider(color: context.dividerClr),
              SizedBox(height: r.s(12)),
              Text(
                'Thumbnail (opcional)',
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: r.s(8)),
              _buildThumbnailSection(r),
              SizedBox(height: r.s(16)),
  
              // Tags
              Divider(color: context.dividerClr),
              SizedBox(height: r.s(12)),
              Text(
                'Tags',
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: r.s(8)),
              _buildTagsSection(r),
  
              SizedBox(height: r.s(80)),
            ],
          ),
        )
      ),
    );
  }

  Widget _buildLinkPreview(Responsive r) {
    final domain = _extractDomain(_urlController.text.trim());
    final displayTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : _ogData?.title ?? domain ?? 'Link externo';
    final displayDesc = _ogData?.description;
    final displayDomain = _ogData?.siteName ?? domain ?? _urlController.text.trim();

    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r.s(48),
                height: r.s(48),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
                child: _isFetchingOg
                    ? Center(
                        child: SizedBox(
                          width: r.s(20),
                          height: r.s(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      )
                    : _thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(8)),
                            child: Image.network(_thumbnailUrl!,
                                fit: BoxFit.cover,
                                width: r.s(48),
                                height: r.s(48)),
                          )
                        : Icon(Icons.language_rounded,
                            color: const Color(0xFF2563EB), size: r.s(24)),
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      displayDomain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF2563EB),
                        fontSize: r.fs(11),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded,
                  color: context.nexusTheme.textSecondary, size: r.s(16)),
            ],
          ),
          // Mostrar descrição OG se disponível
          if (displayDesc != null && displayDesc.isNotEmpty) ...[
            SizedBox(height: r.s(8)),
            Text(
              displayDesc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(11),
              ),
            ),
          ],
          // Indicador de carregamento OG
          if (_isFetchingOg) ...[
            SizedBox(height: r.s(6)),
            Text(
              'Buscando informa\u00e7\u00f5es do link...',
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(10),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnailSection(Responsive r) {
    if (_thumbnailUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(12)),
            child: Image.network(
              _thumbnailUrl!,
              width: double.infinity,
              height: r.s(140),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: r.s(8),
            right: r.s(8),
            child: Row(
              children: [
                _circleButton(
                  icon: Icons.camera_alt_rounded,
                  onTap: _pickThumbnail,
                  r: r,
                ),
                SizedBox(width: r.s(8)),
                _circleButton(
                  icon: Icons.close_rounded,
                  onTap: () => setState(() => _thumbnailUrl = null),
                  r: r,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _isUploadingThumb ? null : _pickThumbnail,
      child: Container(
        height: r.s(72),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(12)),
          border:
              Border.all(color: context.dividerClr.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: _isUploadingThumb
              ? CircularProgressIndicator(
                  color: context.nexusTheme.accentPrimary, strokeWidth: 2)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: context.nexusTheme.textSecondary, size: r.s(20)),
                    SizedBox(width: r.s(8)),
                    Text(
                      'Adicionar thumbnail',
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

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    required Responsive r,
  }) {
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
                        color:
                            context.nexusTheme.accentSecondary.withValues(alpha: 0.15),
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
        if (_tags.length < 10)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary, fontSize: r.fs(13)),
                  decoration: InputDecoration(
                    hintText: 'Adicionar tag...',
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
                    color:
                        context.nexusTheme.accentSecondary.withValues(alpha: 0.15),
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
}
