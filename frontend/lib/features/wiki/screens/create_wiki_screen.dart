import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
// CREATE WIKI SCREEN — Entrada de Wiki/Enciclopédia da comunidade
//
// Features:
//   - Título e subtítulo
//   - Imagem de capa
//   - Seções dinâmicas (título + conteúdo + imagem opcional)
//   - Sumário automático gerado a partir das seções
//   - Referências/fontes
//   - Tags de categoria
//   - Visibilidade e editor_metadata
// =============================================================================

class _WikiSection {
  final TextEditingController titleController;
  final TextEditingController contentController;
  String? imageUrl;

  _WikiSection()
      : titleController = TextEditingController(),
        contentController = TextEditingController();

  void dispose() {
    titleController.dispose();
    contentController.dispose();
  }
}

class CreateWikiScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;
  const CreateWikiScreen({super.key, required this.communityId, this.editingPost});

  @override
  ConsumerState<CreateWikiScreen> createState() => _CreateWikiScreenState();
}

class _CreateWikiScreenState extends ConsumerState<CreateWikiScreen> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _tagController = TextEditingController();
  final _referenceController = TextEditingController();
  final List<_WikiSection> _sections = [_WikiSection()];
  final List<String> _tags = [];
  final List<String> _references = [];
  bool _isSubmitting = false;
  bool _isUploadingCover = false;
  String _visibility = 'public';
  String? _coverImageUrl;

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
    _titleController.text = post.title ?? '';
    _visibility = post.editorMetadata.extra['visibility'] as String? ?? 'public';
    _coverImageUrl = post.coverImageUrl;

    // Restaurar subtítulo
    final subtitle = post.editorMetadata.extra['subtitle'] as String?;
    if (subtitle != null) _subtitleController.text = subtitle;

    // Restaurar tags
    if (post.tags.isNotEmpty) {
      _tags.addAll(post.tags);
    }

    // Restaurar referências
    final refs = post.editorMetadata.extra['references'] as List?;
    if (refs != null) {
      _references.addAll(refs.map((r) => r.toString()));
    }

    // Restaurar seções do editor_metadata
    final sections = post.editorMetadata.extra['sections'] as List?;
    if (sections != null && sections.isNotEmpty) {
      // Limpar seção padrão
      for (final s in _sections) {
        s.dispose();
      }
      _sections.clear();

      for (final secData in sections) {
        if (secData is Map) {
          final sec = _WikiSection();
          sec.titleController.text = (secData['title'] as String?) ?? '';
          sec.contentController.text = (secData['content'] as String?) ?? '';
          sec.imageUrl = secData['image_url'] as String?;
          _sections.add(sec);
        }
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
          .eq('post_type', 'wiki')
          .order('updated_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      final list = (result as List?) ?? const [];
      if (list.isNotEmpty) {
        final data = Map<String, dynamic>.from(list.first as Map);
        setState(() {
          _draftId = data['id'] as String?;
          _titleController.text = (data['title'] as String?) ?? '';
          _subtitleController.text = (data['subtitle'] as String?) ?? '';
          _coverImageUrl = data['cover_image_url'] as String?;
          _visibility = (data['visibility'] as String?) ?? 'public';
          final tags = (data['tags'] as List?) ?? [];
          _tags.addAll(tags.map((t) => t.toString()));
          final wd = data['wiki_data'] as Map?;
          if (wd != null) {
            final refs = wd['references'] as List?;
            if (refs != null) _references.addAll(refs.map((r) => r.toString()));
            final sections = wd['sections'] as List?;
            if (sections != null && sections.isNotEmpty) {
              for (final s in _sections) { s.dispose(); }
              _sections.clear();
              for (final secData in sections) {
                if (secData is Map) {
                  final sec = _WikiSection();
                  sec.titleController.text = (secData['title'] as String?) ?? '';
                  sec.contentController.text = (secData['content'] as String?) ?? '';
                  sec.imageUrl = secData['image_url'] as String?;
                  _sections.add(sec);
                }
              }
            }
          }
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
    if (!(_titleController.text.trim().isNotEmpty || _sections.any((s) => s.titleController.text.trim().isNotEmpty || s.contentController.text.trim().isNotEmpty))) {
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
          postType: 'wiki',
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          coverImageUrl: _coverImageUrl,
          tags: _tags,
          visibility: _visibility,
          wikiData: {
            'sections': _sections
                .map((s) => {
                      'title': s.titleController.text.trim(),
                      'content': s.contentController.text.trim(),
                      'image_url': s.imageUrl,
                    })
                .toList(),
            'references': _references,
          },
        );
        _draftId = created?.id;
      } else {
        await draftsNotifier.updateDraft(
          _draftId!,
          communityId: widget.communityId,
          postType: 'wiki',
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          coverImageUrl: _coverImageUrl,
          tags: _tags,
          visibility: _visibility,
          wikiData: {
            'sections': _sections
                .map((s) => {
                      'title': s.titleController.text.trim(),
                      'content': s.contentController.text.trim(),
                      'image_url': s.imageUrl,
                    })
                .toList(),
            'references': _references,
          },
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
    _subtitleController.dispose();
    _tagController.dispose();
    _referenceController.dispose();
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSection() {
    if (_sections.length >= 20) return;
    setState(() => _sections.add(_WikiSection()));
  }

  void _removeSection(int index) {
    if (_sections.length <= 1) return;
    final s = _sections.removeAt(index);
    s.dispose();
    setState(() {});
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.length >= 8 || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  void _addReference() {
    final ref = _referenceController.text.trim();
    if (ref.isEmpty || _references.length >= 10) return;
    setState(() {
      _references.add(ref);
      _referenceController.clear();
    });
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
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_wiki_cover_${image.name}';
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

  Future<void> _pickSectionImage(int index) async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_wiki_s${index}_${image.name}';
      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      final url =
          SupabaseService.storage.from('post-media').getPublicUrl(path);
      if (mounted) setState(() => _sections[index].imageUrl = url);
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
    }
  }

  Future<void> _submit() async {
    final s = getStrings();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.wikiTitleRequired),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final validSections = _sections
        .where((sec) =>
            sec.titleController.text.trim().isNotEmpty ||
            sec.contentController.text.trim().isNotEmpty)
        .toList();
    if (validSections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.wikiNeedOneSection),
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
        // Montar conteúdo como markdown-like
        final contentBuffer = StringBuffer();
        if (_subtitleController.text.trim().isNotEmpty) {
          contentBuffer.writeln(_subtitleController.text.trim());
          contentBuffer.writeln();
        }
        for (final sec in validSections) {
          if (sec.titleController.text.trim().isNotEmpty) {
            contentBuffer.writeln('## ${sec.titleController.text.trim()}');
          }
          if (sec.contentController.text.trim().isNotEmpty) {
            contentBuffer.writeln(sec.contentController.text.trim());
          }
          contentBuffer.writeln();
        }

        final sectionsJson = validSections
            .map((sec) => {
                  'title': sec.titleController.text.trim(),
                  'content': sec.contentController.text.trim(),
                  'image_url': sec.imageUrl,
                })
            .toList();

        final editorMetadata = <String, dynamic>{
          'editor_type': 'wiki',
          'tags': _tags,
          'references': _references,
          'sections': sectionsJson,
          'subtitle': _subtitleController.text.trim(),
        };

        final mediaUrls = <String>[];
        if (_coverImageUrl != null) mediaUrls.add(_coverImageUrl!);
        for (final sec in validSections) {
          if (sec.imageUrl != null) mediaUrls.add(sec.imageUrl!);
        }

        final postData = {
          'title': title,
          'content': contentBuffer.toString().trim(),
          'type': 'wiki',
          'media_list': mediaUrls.map((url) => {'url': url, 'type': 'image'}).toList(),
          'tags': _tags,
          'cover_image_url': _coverImageUrl,
          'visibility': _visibility,
          'editor_type': 'wiki',
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
      // Montar conteúdo como markdown-like
      final contentBuffer = StringBuffer();
      if (_subtitleController.text.trim().isNotEmpty) {
        contentBuffer.writeln(_subtitleController.text.trim());
        contentBuffer.writeln();
      }
      for (final sec in validSections) {
        if (sec.titleController.text.trim().isNotEmpty) {
          contentBuffer.writeln('## ${sec.titleController.text.trim()}');
        }
        if (sec.contentController.text.trim().isNotEmpty) {
          contentBuffer.writeln(sec.contentController.text.trim());
        }
        contentBuffer.writeln();
      }

      // Montar seções como JSON para wiki_data
      final sectionsJson = validSections
          .map((sec) => {
                'title': sec.titleController.text.trim(),
                'content': sec.contentController.text.trim(),
                'image_url': sec.imageUrl,
              })
          .toList();

      final editorMetadata = <String, dynamic>{
        'editor_type': 'wiki',
        'tags': _tags,
        'references': _references,
        'sections': sectionsJson,
        'subtitle': _subtitleController.text.trim(),
      };

      // Coletar todas as imagens de seções
      final mediaUrls = <String>[];
      if (_coverImageUrl != null) mediaUrls.add(_coverImageUrl!);
      for (final sec in validSections) {
        if (sec.imageUrl != null) mediaUrls.add(sec.imageUrl!);
      }

      // Usar RPC específica para wiki com validações
      try {
        final result = await SupabaseService.rpc('create_wiki_entry', params: {
          'p_community_id': widget.communityId,
          'p_title': title,
          'p_content': contentBuffer.toString().trim(),
          'p_cover_image_url': _coverImageUrl,
          'p_media_list': mediaUrls
              .map((url) => {'url': url, 'type': 'image'})
              .toList(),
          'p_tags': _tags,
          'p_visibility': _visibility,
          'p_wiki_data': {
            'sections': sectionsJson,
            'subtitle': _subtitleController.text.trim(),
            'references': _references,
          },
          'p_editor_metadata': editorMetadata,
        });

        if (result is! Map<String, dynamic> || result['success'] != true) {
          throw Exception(result is Map ? result['message'] ?? s.errorPublishing2 : s.errorPublishing2);
        }
      } catch (e) {
        // Fallback: tentar com create_post_with_reputation
        try {
          await SupabaseService.rpc('create_post_with_reputation', params: {
            'p_community_id': widget.communityId,
            'p_title': title,
            'p_content': contentBuffer.toString().trim(),
            'p_type': 'wiki',
            'p_visibility': _visibility,
            'p_media_list': mediaUrls
                .map((url) => {'url': url, 'type': 'image'})
                .toList(),
            'p_tags': _tags,
            'p_cover_image_url': _coverImageUrl,
            'p_editor_type': 'wiki',
            'p_editor_metadata': editorMetadata,
            'p_wiki_data': {
              'sections': sectionsJson,
              'subtitle': _subtitleController.text.trim(),
              'references': _references,
            },
          });
        } catch (fallbackError) {
          // Último fallback: insert direto
          final result = await SupabaseService.table('posts')
              .insert({
                'community_id': widget.communityId,
                'author_id': userId,
                'type': 'wiki',
                'title': title,
                'content': contentBuffer.toString().trim(),
                'media_list': mediaUrls
                    .map((url) => {'url': url, 'type': 'image'})
                    .toList(),
                'cover_image_url': _coverImageUrl,
                'visibility': _visibility,
                'comments_blocked': false,
                'editor_type': 'wiki',
                'editor_metadata': editorMetadata,
                'wiki_data': {
                  'sections': sectionsJson,
                  'subtitle': _subtitleController.text.trim(),
                  'references': _references,
                },
              })
              .select()
              .single();

          try {
            await SupabaseService.rpc('add_reputation', params: {
              'p_user_id': userId,
              'p_community_id': widget.communityId,
              'p_action_type': 'post_create',
              'p_raw_amount': 25,
              'p_reference_id': result['id'],
            });
          } catch (_) {}
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.wikiPublishedSuccess),
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
    final accent = const Color(0xFF059669);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          _isEditing ? s.editPost : s.wikiEntry,
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
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
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
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      color: accent, size: r.s(32)),
                ),
              ),
              SizedBox(height: r.s(8)),
              Center(
                child: Text(
                  s.wikiDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.nexusTheme.textSecondary, fontSize: r.fs(12)),
                ),
              ),
              SizedBox(height: r.s(20)),
  
              // Imagem de capa
              _buildCoverSection(r, accent),
              SizedBox(height: r.s(20)),
  
              // Título
              _buildLabel('Título do artigo', r),
              SizedBox(height: r.s(8)),
              _buildTextField(
                controller: _titleController,
                hint: 'Ex: História da Comunidade',
                maxLength: 200,
                r: r,
                accent: accent,
              ),
              SizedBox(height: r.s(16)),
  
              // Subtítulo
              _buildLabel('Subtítulo (opcional)', r),
              SizedBox(height: r.s(8)),
              _buildTextField(
                controller: _subtitleController,
                hint: 'Resumo breve do artigo...',
                maxLength: 300,
                maxLines: 2,
                r: r,
                accent: accent,
              ),
  
              SizedBox(height: r.s(16)),
              Divider(color: context.dividerClr),
              SizedBox(height: r.s(12)),
  
              // Tags
              _buildLabel('Categorias', r),
              SizedBox(height: r.s(4)),
              _buildTagsSection(r),
  
              SizedBox(height: r.s(16)),
              Divider(color: context.dividerClr),
              SizedBox(height: r.s(12)),
  
              // Sumário automático
              if (_sections.any(
                  (sec) => sec.titleController.text.trim().isNotEmpty)) ...[
                Container(
                  padding: EdgeInsets.all(r.s(12)),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list_rounded,
                              color: accent, size: r.s(16)),
                          SizedBox(width: r.s(6)),
                          Text(
                            'Sumário',
                            style: TextStyle(
                                color: accent,
                                fontSize: r.fs(13),
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      SizedBox(height: r.s(8)),
                      ...List.generate(_sections.length, (i) {
                        final title =
                            _sections[i].titleController.text.trim();
                        if (title.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(
                              left: r.s(8), bottom: r.s(4)),
                          child: Text(
                            '${i + 1}. $title',
                            style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontSize: r.fs(12)),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                SizedBox(height: r.s(16)),
              ],
  
              // Seções
              Row(
                children: [
                  Text(
                    'Seções',
                    style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${_sections.length}/20',
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary, fontSize: r.fs(12)),
                  ),
                ],
              ),
              SizedBox(height: r.s(12)),
              ...List.generate(_sections.length, (i) {
                return _buildSectionCard(i, _sections[i], r, accent);
              }),
              if (_sections.length < 20)
                Padding(
                  padding: EdgeInsets.only(top: r.s(8)),
                  child: TextButton.icon(
                    onPressed: _addSection,
                    icon: Icon(Icons.add_rounded,
                        color: accent, size: r.s(18)),
                    label: Text(
                      'Adicionar seção',
                      style: TextStyle(
                          color: accent, fontSize: r.fs(14)),
                    ),
                  ),
                ),
  
              SizedBox(height: r.s(16)),
              Divider(color: context.dividerClr),
              SizedBox(height: r.s(12)),
  
              // Referências
              _buildLabel('Referências e fontes', r),
              SizedBox(height: r.s(4)),
              Text(
                'Adicione links ou citações de fontes',
                style: TextStyle(
                    color: context.nexusTheme.textSecondary, fontSize: r.fs(11)),
              ),
              SizedBox(height: r.s(8)),
              if (_references.isNotEmpty) ...[
                ...List.generate(_references.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: r.s(4)),
                    child: Row(
                      children: [
                        Text(
                          '[${i + 1}]',
                          style: TextStyle(
                              color: accent,
                              fontSize: r.fs(11),
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(width: r.s(6)),
                        Expanded(
                          child: Text(
                            _references[i],
                            style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontSize: r.fs(12)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(
                              () => _references.removeAt(i)),
                          child: Icon(Icons.close_rounded,
                              color: context.nexusTheme.error,
                              size: r.s(14)),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: r.s(8)),
              ],
              if (_references.length < 10)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _referenceController,
                        style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(12)),
                        decoration: InputDecoration(
                          hintText: 'URL ou citação...',
                          hintStyle: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(12)),
                          border: InputBorder.none,
                          isDense: true,
                          prefixIcon: Icon(Icons.link_rounded,
                              color: context.nexusTheme.textSecondary,
                              size: r.s(16)),
                        ),
                        onSubmitted: (_) => _addReference(),
                      ),
                    ),
                    GestureDetector(
                      onTap: _addReference,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(12), vertical: r.s(6)),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(8)),
                        ),
                        child: Text('Adicionar',
                            style: TextStyle(
                                color: accent,
                                fontSize: r.fs(12),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
  
              SizedBox(height: r.s(80)),
            ],
          ),
        )
      ),
    );
  }

  Widget _buildCoverSection(Responsive r, Color accent) {
    if (_coverImageUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(12)),
            child: Image.network(
              _coverImageUrl!,
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
                _circleBtn(Icons.camera_alt_rounded, _pickCoverImage, r),
                SizedBox(width: r.s(8)),
                _circleBtn(Icons.close_rounded,
                    () => setState(() => _coverImageUrl = null), r),
              ],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _isUploadingCover ? null : _pickCoverImage,
      child: Container(
        height: r.s(80),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(12)),
          border:
              Border.all(color: context.dividerClr.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: _isUploadingCover
              ? CircularProgressIndicator(color: accent, strokeWidth: 2)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: context.nexusTheme.textSecondary, size: r.s(20)),
                    SizedBox(width: r.s(8)),
                    Text(
                      'Adicionar imagem de capa',
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

  Widget _buildSectionCard(
      int index, _WikiSection section, Responsive r, Color accent) {
    return Container(
      margin: EdgeInsets.only(bottom: r.s(16)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(14)),
        border:
            Border.all(color: context.dividerClr.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(10), vertical: r.s(4)),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(20)),
                ),
                child: Text(
                  'Seção ${index + 1}',
                  style: TextStyle(
                      color: accent,
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (_sections.length > 1)
                GestureDetector(
                  onTap: () => _removeSection(index),
                  child: Icon(Icons.delete_outline_rounded,
                      color: context.nexusTheme.error, size: r.s(18)),
                ),
            ],
          ),
          SizedBox(height: r.s(10)),

          // Título da seção
          TextField(
            controller: section.titleController,
            maxLength: 150,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}), // Atualizar sumário
            style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(15),
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Título da seção',
              hintStyle: TextStyle(
                  color: context.nexusTheme.textSecondary,
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w600),
              filled: true,
              fillColor: context.nexusTheme.backgroundPrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(10)),
            ),
          ),
          SizedBox(height: r.s(8)),

          // Conteúdo da seção
          TextField(
            controller: section.contentController,
            maxLength: 5000,
            maxLines: 8,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(14),
                height: 1.5),
            decoration: InputDecoration(
              hintText: 'Conteúdo da seção...',
              hintStyle: TextStyle(
                  color: context.nexusTheme.textSecondary, fontSize: r.fs(14)),
              filled: true,
              fillColor: context.nexusTheme.backgroundPrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
                borderSide: BorderSide(color: accent, width: 1),
              ),
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(10)),
            ),
          ),
          SizedBox(height: r.s(8)),

          // Imagem da seção
          if (section.imageUrl != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  child: Image.network(
                    section.imageUrl!,
                    width: double.infinity,
                    height: r.s(120),
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: r.s(4),
                  right: r.s(4),
                  child: _circleBtn(Icons.close_rounded,
                      () => setState(() => section.imageUrl = null), r),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: () => _pickSectionImage(index),
              child: Container(
                height: r.s(40),
                decoration: BoxDecoration(
                  color: context.nexusTheme.backgroundPrimary,
                  borderRadius: BorderRadius.circular(r.s(8)),
                  border: Border.all(
                      color:
                          context.dividerClr.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_rounded,
                          color: context.nexusTheme.textSecondary, size: r.s(16)),
                      SizedBox(width: r.s(6)),
                      Text(
                        'Adicionar imagem à seção',
                        style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(11)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
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
        if (_tags.length < 8)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary, fontSize: r.fs(13)),
                  decoration: InputDecoration(
                    hintText: 'Ex: lore, personagem, evento...',
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

  Widget _buildLabel(String text, Responsive r) => Text(
        text,
        style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(13),
            fontWeight: FontWeight.w600),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
    required Responsive r,
    required Color accent,
  }) =>
      TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: context.nexusTheme.textSecondary, fontSize: r.fs(14)),
          filled: true,
          fillColor: context.nexusTheme.surfacePrimary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
          counterText: '',
          contentPadding:
              EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
        ),
      );
}
