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
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

// =============================================================================
// CREATE IMAGE POST SCREEN — Post com galeria de imagens
//
// Melhorias:
//   - Reordenação de imagens via drag & drop (long press)
//   - Legenda individual por imagem
//   - Tags
//   - Toggle NSFW / Spoiler
//   - Indicador de contagem de imagens (máx. 20)
//   - Preview em tela cheia ao tocar na imagem
//   - Suporte a editor_metadata para personalização
// =============================================================================

class _ImageItem {
  final String url;
  String caption;
  _ImageItem({required this.url, this.caption = ''});
}

class CreateImagePostScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;
  const CreateImagePostScreen({super.key, required this.communityId, this.editingPost});

  @override
  ConsumerState<CreateImagePostScreen> createState() =>
      _CreateImagePostScreenState();
}

class _CreateImagePostScreenState extends ConsumerState<CreateImagePostScreen> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _tagController = TextEditingController();
  final List<_ImageItem> _images = [];
  final List<String> _tags = [];
  bool _isSubmitting = false;
  bool _isUploading = false;
  bool _isNsfw = false;
  bool _isSpoiler = false;
  String _visibility = 'public';

  bool get _isEditing => widget.editingPost != null;

  // ── Rascunhos automáticos ──
  String? _draftId;
  bool _isSavingDraft = false;
  Timer? _autoDraftTimer;

  static const int _maxImages = 20;

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
    _titleController.text = post.title ?? '';
    _captionController.text = post.content;
    _visibility = post.editorMetadata.extra['visibility'] as String? ?? 'public';
    _isNsfw = post.editorMetadata.extra['is_nsfw'] == true;
    _isSpoiler = post.editorMetadata.extra['is_spoiler'] == true;

    // Restaurar tags
    if (post.tags.isNotEmpty) {
      _tags.addAll(post.tags);
    }

    // Restaurar imagens da media_list
    for (final media in post.mediaList) {
      if (media is Map && media['url'] != null) {
        _images.add(_ImageItem(
          url: media['url'] as String,
          caption: (media['caption'] as String?) ?? '',
        ));
      }
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
          .eq('post_type', 'image')
          .order('updated_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      final list = (result as List?) ?? const [];
      if (list.isNotEmpty) {
        final data = Map<String, dynamic>.from(list.first as Map);
        setState(() {
          _draftId = data['id'] as String?;
          _titleController.text = (data['title'] as String?) ?? '';
          _captionController.text = (data['content'] as String?) ?? '';
          _visibility = (data['visibility'] as String?) ?? 'public';
          final urls = (data['media_urls'] as List?) ?? [];
          for (final url in urls) {
            _images.add(_ImageItem(url: url.toString()));
          }
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
    if (!(_titleController.text.trim().isNotEmpty || _images.isNotEmpty)) {
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
          postType: 'image',
          title: _titleController.text.trim(),
          content: _captionController.text.trim(),
          mediaUrls: _images.map((img) => img.url).toList(),
          coverImageUrl: _images.isNotEmpty ? _images.first.url : null,
          tags: _tags,
          visibility: _visibility,
        );
        _draftId = created?.id;
      } else {
        await draftsNotifier.updateDraft(
          _draftId!,
          communityId: widget.communityId,
          postType: 'image',
          title: _titleController.text.trim(),
          content: _captionController.text.trim(),
          mediaUrls: _images.map((img) => img.url).toList(),
          coverImageUrl: _images.isNotEmpty ? _images.first.url : null,
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
    _titleController.dispose();
    _captionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.length >= 10 || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Future<void> _pickImages() async {
    final s = getStrings();
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Máximo de $_maxImages imagens atingido'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final selected = await picker.pickMultiImage();
    if (selected.isEmpty || !mounted) return;

    final remaining = _maxImages - _images.length;
    final toUpload = selected.take(remaining).toList();

    setState(() => _isUploading = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      for (final image in toUpload) {
        final rawBytes = await image.readAsBytes();
        final bytes = await MediaUtils.compressImage(rawBytes);
        final path =
            'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        await SupabaseService.storage
            .from('post-media')
            .uploadBinary(path, bytes);
        final url =
            SupabaseService.storage.from('post-media').getPublicUrl(path);
        if (mounted) setState(() => _images.add(_ImageItem(url: url)));
      }
    } catch (e) {
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
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  void _showImagePreview(int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_images[index].url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCaptionDialog(int index) {
    final controller = TextEditingController(text: _images[index].caption);
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Legenda da imagem ${index + 1}',
            style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(16))),
        content: TextField(
          controller: controller,
          maxLength: 200,
          maxLines: 3,
          style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
          decoration: InputDecoration(
            hintText: 'Descreva esta imagem...',
            hintStyle:
                TextStyle(color: context.nexusTheme.textSecondary, fontSize: r.fs(14)),
            filled: true,
            fillColor: context.nexusTheme.surfacePrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(10)),
              borderSide: BorderSide.none,
            ),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: context.nexusTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              setState(
                  () => _images[index].caption = controller.text.trim());
              Navigator.pop(ctx);
            },
            child: Text('Salvar',
                style: TextStyle(color: context.nexusTheme.accentPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final s = getStrings();
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.addAtLeastOneImage),
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

      final mediaUrls = _images.map((img) => img.url).toList();

      // ── Modo de EDIÇÃO ──
      if (_isEditing) {
        final mediaList = _images
            .map((img) => {
                  'url': img.url,
                  'type': 'image',
                  if (img.caption.isNotEmpty) 'caption': img.caption,
                })
            .toList();

        final editorMetadata = <String, dynamic>{
          'editor_type': 'image',
          'tags': _tags,
          'is_nsfw': _isNsfw,
          'is_spoiler': _isSpoiler,
          'image_count': _images.length,
        };

        final postData = {
          'title': _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
          'content': _captionController.text.trim(),
          'type': 'image',
          'media_list': mediaList,
          'tags': _tags,
          'cover_image_url': mediaUrls.isNotEmpty ? mediaUrls.first : null,
          'visibility': _visibility,
          'editor_type': 'image',
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
      final mediaList = _images
          .map((img) => {
                'url': img.url,
                'type': 'image',
                if (img.caption.isNotEmpty) 'caption': img.caption,
              })
          .toList();

      final editorMetadata = <String, dynamic>{
        'editor_type': 'image',
        'tags': _tags,
        'is_nsfw': _isNsfw,
        'is_spoiler': _isSpoiler,
        'image_count': _images.length,
      };

      // Tentar RPC primeiro
      try {
        await SupabaseService.rpc('create_post_with_reputation', params: {
          'p_community_id': widget.communityId,
          'p_title': _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : null,
          'p_content': _captionController.text.trim(),
          'p_type': 'image',
          'p_visibility': _visibility,
          'p_media_urls': mediaUrls,
          'p_cover_image_url': mediaUrls.first,
          'p_editor_type': 'image',
          'p_editor_metadata': editorMetadata,
        });
      } catch (_) {
        // Fallback: insert direto
        final result = await SupabaseService.table('posts')
            .insert({
              'community_id': widget.communityId,
              'author_id': userId,
              'type': 'image',
              'title': _titleController.text.trim().isNotEmpty
                  ? _titleController.text.trim()
                  : null,
              'content': _captionController.text.trim(),
              'media_list': mediaList,
              'cover_image_url': mediaUrls.first,
              'visibility': _visibility,
              'comments_blocked': false,
              'editor_type': 'image',
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
            content: Text(s.postPublishedSuccess),
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
          _isEditing ? s.editPost : 'Post de Imagem',
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
            // Contador de imagens
            Row(
              children: [
                Icon(Icons.photo_library_rounded,
                    color: context.nexusTheme.accentPrimary, size: r.s(20)),
                SizedBox(width: r.s(8)),
                Text(
                  '${_images.length}/$_maxImages imagens',
                  style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_images.length > 1)
                  Text(
                    'Segure para reordenar',
                    style: TextStyle(
                      color: context.nexusTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: r.fs(11),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            SizedBox(height: r.s(12)),

            // Galeria de imagens com reordenação
            _buildImageGrid(r),
            SizedBox(height: r.s(20)),

            // Título (opcional)
            TextField(
              controller: _titleController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(18),
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: s.titleOptionalHint,
                hintStyle:
                    TextStyle(color: context.nexusTheme.textSecondary, fontSize: r.fs(18)),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(8)),

            // Legenda geral
            TextField(
              controller: _captionController,
              maxLength: 500,
              maxLines: 5,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(15)),
              decoration: InputDecoration(
                hintText: s.writeCaptionHint,
                hintStyle:
                    TextStyle(color: context.nexusTheme.textSecondary, fontSize: r.fs(15)),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            SizedBox(height: r.s(16)),

            // Tags
            _buildTagsSection(r),
            SizedBox(height: r.s(16)),

            // Toggles NSFW / Spoiler
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(8)),
            _buildToggleRow(
              icon: Icons.warning_amber_rounded,
              label: 'Conteúdo NSFW',
              subtitle: 'Marcar como conteúdo adulto',
              value: _isNsfw,
              onChanged: (v) => setState(() => _isNsfw = v),
              color: context.nexusTheme.error,
              r: r,
            ),
            _buildToggleRow(
              icon: Icons.visibility_off_rounded,
              label: 'Spoiler',
              subtitle: 'Esconder imagens até o usuário tocar',
              value: _isSpoiler,
              onChanged: (v) => setState(() => _isSpoiler = v),
              color: context.nexusTheme.accentSecondary,
              r: r,
            ),

            SizedBox(height: r.s(80)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(Responsive r) {
    if (_images.isEmpty) {
      return GestureDetector(
        onTap: _isUploading ? null : _pickImages,
        child: Container(
          height: r.s(200),
          decoration: BoxDecoration(
            color: context.nexusTheme.surfacePrimary,
            borderRadius: BorderRadius.circular(r.s(16)),
            border:
                Border.all(color: context.dividerClr.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isUploading)
                  CircularProgressIndicator(
                      color: context.nexusTheme.accentPrimary, strokeWidth: 2)
                else ...[
                  Icon(Icons.add_photo_alternate_rounded,
                      color: context.nexusTheme.accentPrimary, size: r.s(48)),
                  SizedBox(height: r.s(8)),
                  Text(
                    'Toque para adicionar imagens',
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary, fontSize: r.fs(14)),
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    'Até $_maxImages imagens',
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary.withValues(alpha: 0.6),
                        fontSize: r.fs(12)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: _reorderImages,
          itemCount: _images.length,
          itemBuilder: (ctx, index) {
            final img = _images[index];
            return ReorderableDragStartListener(
              key: ValueKey(img.url),
              index: index,
              child: Container(
                margin: EdgeInsets.only(bottom: r.s(8)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.surfacePrimary,
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: Border.all(
                      color: context.dividerClr.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    GestureDetector(
                      onTap: () => _showImagePreview(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(r.s(12))),
                        child: Image.network(
                          img.url,
                          width: r.s(80),
                          height: r.s(80),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(12)),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Imagem ${index + 1}',
                            style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontSize: r.fs(13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (img.caption.isNotEmpty) ...[
                            SizedBox(height: r.s(2)),
                            Text(
                              img.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(11),
                              ),
                            ),
                          ],
                          SizedBox(height: r.s(4)),
                          GestureDetector(
                            onTap: () => _showCaptionDialog(index),
                            child: Text(
                              img.caption.isEmpty
                                  ? 'Adicionar legenda'
                                  : 'Editar legenda',
                              style: TextStyle(
                                color: context.nexusTheme.accentSecondary,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Actions
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: context.nexusTheme.error, size: r.s(18)),
                      onPressed: () => _removeImage(index),
                    ),
                    Icon(Icons.drag_handle_rounded,
                        color: context.nexusTheme.textSecondary, size: r.s(20)),
                    SizedBox(width: r.s(8)),
                  ],
                ),
              ),
            );
          },
        ),
        // Botão adicionar mais
        if (_images.length < _maxImages)
          GestureDetector(
            onTap: _isUploading ? null : _pickImages,
            child: Container(
              height: r.s(56),
              decoration: BoxDecoration(
                color: context.nexusTheme.surfacePrimary,
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: _isUploading
                    ? CircularProgressIndicator(
                        color: context.nexusTheme.accentPrimary, strokeWidth: 2)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              color: context.nexusTheme.accentPrimary, size: r.s(20)),
                          SizedBox(width: r.s(8)),
                          Text(
                            'Adicionar mais imagens',
                            style: TextStyle(
                              color: context.nexusTheme.accentPrimary,
                              fontSize: r.fs(14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
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
                        color: context.nexusTheme.accentSecondary.withValues(alpha: 0.15),
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
                            onTap: () => setState(() => _tags.remove(tag)),
                            child: Icon(Icons.close_rounded,
                                color: context.nexusTheme.accentSecondary, size: r.s(14)),
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
                        color: context.nexusTheme.textSecondary, fontSize: r.fs(13)),
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
                    color: context.nexusTheme.accentSecondary.withValues(alpha: 0.15),
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
                        color: context.nexusTheme.textSecondary, fontSize: r.fs(11))),
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
