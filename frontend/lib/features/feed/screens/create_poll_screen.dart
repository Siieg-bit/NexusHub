import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/post_editor_model.dart';
import '../../../core/providers/post_provider.dart';
import '../../../core/providers/draft_provider.dart';
import 'dart:async';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// CREATE POLL SCREEN — Enquete com múltiplas opções
//
// Melhorias:
//   - Duração configurável (1h, 6h, 12h, 1d, 3d, 7d, sem limite)
//   - Toggle de múltipla escolha
//   - Imagem de capa opcional
//   - Reordenação de opções via drag
//   - Ícone/emoji por opção
//   - Suporte a editor_metadata
// =============================================================================

class CreatePollScreen extends ConsumerStatefulWidget {
  final String communityId;
  final PostModel? editingPost;
  const CreatePollScreen({super.key, required this.communityId, this.editingPost});

  @override
  ConsumerState<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends ConsumerState<CreatePollScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _isSubmitting = false;
  bool _isUploadingCover = false;
  bool _allowMultipleChoice = false;
  bool _anonymousVotes = false;
  String _visibility = 'public';
  String? _coverImageUrl;
  String _duration = '3d'; // Duração padrão

  bool get _isEditing => widget.editingPost != null;

  // ── Rascunhos automáticos ──
  String? _draftId;
  bool _isSavingDraft = false;
  Timer? _autoDraftTimer;

  static const _durations = {
    '1h': '1 hora',
    '6h': '6 horas',
    '12h': '12 horas',
    '1d': '1 dia',
    '3d': '3 dias',
    '7d': '7 dias',
    'none': 'Sem limite',
  };

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
    _descriptionController.text = post.content;
    _visibility = post.editorMetadata.extra['visibility'] as String? ?? 'public';
    _coverImageUrl = post.coverImageUrl;
    _allowMultipleChoice = post.editorMetadata.extra['allow_multiple_choice'] == true;
    _anonymousVotes = post.editorMetadata.extra['anonymous_votes'] == true;
    _duration = post.editorMetadata.extra['duration'] as String? ?? '3d';

    // Restaurar opções da enquete
    if (post.pollData != null) {
      final options = post.pollData!['options'] as List?;
      if (options != null && options.isNotEmpty) {
        // Limpar opções padrão
        for (final c in _options) {
          c.dispose();
        }
        _options.clear();

        for (final opt in options) {
          final controller = TextEditingController();
          if (opt is Map) {
            controller.text = (opt['text'] as String?) ?? '';
          }
          _options.add(controller);
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
          .eq('post_type', 'poll')
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
          _coverImageUrl = data['cover_image_url'] as String?;
          _visibility = (data['visibility'] as String?) ?? 'public';
          final meta = data['editor_metadata'] as Map?;
          if (meta != null) {
            _allowMultipleChoice = meta['extra']?['allow_multiple_choice'] == true;
            _anonymousVotes = meta['extra']?['anonymous_votes'] == true;
            _duration = (meta['extra']?['duration'] as String?) ?? '3d';
            final opts = meta['extra']?['options'] as List?;
            if (opts != null && opts.isNotEmpty) {
              for (final c in _options) { c.dispose(); }
              _options.clear();
              for (final opt in opts) {
                _options.add(TextEditingController(text: opt.toString()));
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
    if (!(_titleController.text.trim().isNotEmpty)) {
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
          postType: 'poll',
          title: _titleController.text.trim(),
          content: _descriptionController.text.trim(),
          coverImageUrl: _coverImageUrl,
          visibility: _visibility,
          editorMetadata: PostEditorModel(extra: {
            'allow_multiple_choice': _allowMultipleChoice,
            'anonymous_votes': _anonymousVotes,
            'duration': _duration,
            'options': _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
          }),
        );
        _draftId = created?.id;
      } else {
        await draftsNotifier.updateDraft(
          _draftId!,
          communityId: widget.communityId,
          postType: 'poll',
          title: _titleController.text.trim(),
          content: _descriptionController.text.trim(),
          coverImageUrl: _coverImageUrl,
          visibility: _visibility,
          editorMetadata: PostEditorModel(extra: {
            'allow_multiple_choice': _allowMultipleChoice,
            'anonymous_votes': _anonymousVotes,
            'duration': _duration,
            'options': _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
          }),
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
    _descriptionController.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 10) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    final c = _options.removeAt(index);
    c.dispose();
    setState(() {});
  }

  void _reorderOptions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _options.removeAt(oldIndex);
      _options.insert(newIndex, item);
    });
  }

  DateTime? _getExpiresAt() {
    final now = DateTime.now().toUtc();
    switch (_duration) {
      case '1h':
        return now.add(const Duration(hours: 1));
      case '6h':
        return now.add(const Duration(hours: 6));
      case '12h':
        return now.add(const Duration(hours: 12));
      case '1d':
        return now.add(const Duration(days: 1));
      case '3d':
        return now.add(const Duration(days: 3));
      case '7d':
        return now.add(const Duration(days: 7));
      default:
        return null;
    }
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
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_poll_cover_${image.name}';
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

  Future<void> _submit() async {
    final s = getStrings();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.pollQuestionRequired),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final validOptions =
        _options.where((c) => c.text.trim().isNotEmpty).toList();
    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.addAtLeast2Options),
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

      final pollOpts =
          validOptions.map((c) => {'text': c.text.trim()}).toList();

      final expiresAt = _getExpiresAt();

      // ── Modo de EDIÇÃO ──
      if (_isEditing) {
        final editorMetadata = <String, dynamic>{
          'editor_type': 'poll',
          'allow_multiple_choice': _allowMultipleChoice,
          'anonymous_votes': _anonymousVotes,
          'duration': _duration,
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        };

        final postData = {
          'title': title,
          'content': _descriptionController.text.trim(),
          'type': 'poll',
          'poll_options': pollOpts,
          'cover_image_url': _coverImageUrl,
          'visibility': _visibility,
          'editor_type': 'poll',
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
        'editor_type': 'poll',
        'allow_multiple_choice': _allowMultipleChoice,
        'anonymous_votes': _anonymousVotes,
        'duration': _duration,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      };

      await SupabaseService.rpc('create_post_with_reputation', params: {
        'p_community_id': widget.communityId,
        'p_title': title,
        'p_content': _descriptionController.text.trim(),
        'p_type': 'poll',
        'p_visibility': _visibility,
        'p_poll_options': pollOpts,
        'p_cover_image_url': _coverImageUrl,
        'p_editor_type': 'poll',
        'p_editor_metadata': editorMetadata,
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.pollCreatedSuccess),
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
            content: Text(s.errorCreatingPoll),
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
    final accent = const Color(0xFF0891B2);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          _isEditing ? s.editPost : s.newPoll,
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
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bar_chart_rounded,
                    color: accent, size: r.s(32)),
              ),
            ),
            SizedBox(height: r.s(20)),

            // Imagem de capa (opcional)
            _buildCoverSection(r, accent),
            SizedBox(height: r.s(16)),

            // Pergunta
            Text(
              s.question,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: r.s(8)),
            _buildField(
              controller: _titleController,
              hint: s.pollExampleHint,
              maxLength: 200,
              maxLines: 3,
              r: r,
              accent: accent,
            ),
            SizedBox(height: r.s(16)),

            // Descrição
            Text(
              s.descriptionOptional2,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: r.s(8)),
            _buildField(
              controller: _descriptionController,
              hint: 'Contexto adicional...',
              maxLength: 500,
              maxLines: 3,
              r: r,
              accent: accent,
            ),
            SizedBox(height: r.s(24)),

            // Opções com reordenação
            Row(
              children: [
                Text(
                  s.optionsLabel,
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_options.length}/10',
                  style: TextStyle(
                      color: context.nexusTheme.textSecondary, fontSize: r.fs(12)),
                ),
                if (_options.length > 2) ...[
                  SizedBox(width: r.s(8)),
                  Text(
                    'Segure para reordenar',
                    style: TextStyle(
                      color: context.nexusTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: r.fs(10),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: r.s(8)),

            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _reorderOptions,
              itemCount: _options.length,
              itemBuilder: (ctx, i) {
                return ReorderableDragStartListener(
                  key: ValueKey('option_$i'),
                  index: i,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: r.s(8)),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(28),
                          height: r.s(28),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        SizedBox(width: r.s(8)),
                        Expanded(
                          child: TextField(
                            controller: _options[i],
                            maxLength: 100,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontSize: r.fs(14)),
                            decoration: InputDecoration(
                              hintText: s.optionNumber(i + 1),
                              hintStyle: TextStyle(
                                  color: context.nexusTheme.textSecondary,
                                  fontSize: r.fs(14)),
                              filled: true,
                              fillColor: context.nexusTheme.surfacePrimary,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(r.s(10)),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(r.s(10)),
                                borderSide:
                                    BorderSide(color: accent, width: 1.5),
                              ),
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: r.s(12), vertical: r.s(10)),
                            ),
                          ),
                        ),
                        if (_options.length > 2) ...[
                          SizedBox(width: r.s(4)),
                          GestureDetector(
                            onTap: () => _removeOption(i),
                            child: Icon(Icons.remove_circle_outline_rounded,
                                color: context.nexusTheme.error, size: r.s(20)),
                          ),
                        ],
                        SizedBox(width: r.s(4)),
                        Icon(Icons.drag_handle_rounded,
                            color: context.nexusTheme.textSecondary, size: r.s(18)),
                      ],
                    ),
                  ),
                );
              },
            ),

            if (_options.length < 10)
              TextButton.icon(
                onPressed: _addOption,
                icon: Icon(Icons.add_rounded,
                    color: context.nexusTheme.accentPrimary, size: r.s(18)),
                label: Text(
                  s.addOption,
                  style: TextStyle(
                      color: context.nexusTheme.accentPrimary, fontSize: r.fs(14)),
                ),
              ),

            SizedBox(height: r.s(16)),
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(12)),

            // Duração
            Text(
              'Duração da enquete',
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: r.s(8)),
            Wrap(
              spacing: r.s(8),
              runSpacing: r.s(6),
              children: _durations.entries.map((e) {
                final selected = _duration == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _duration = e.key),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(14), vertical: r.s(8)),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.2)
                          : context.nexusTheme.surfacePrimary,
                      borderRadius: BorderRadius.circular(r.s(20)),
                      border: Border.all(
                        color: selected
                            ? accent
                            : context.dividerClr.withValues(alpha: 0.4),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: selected ? accent : context.nexusTheme.textSecondary,
                        fontSize: r.fs(12),
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: r.s(16)),
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(8)),

            // Toggles
            _buildToggleRow(
              icon: Icons.check_box_rounded,
              label: 'Múltipla escolha',
              subtitle: 'Permitir selecionar mais de uma opção',
              value: _allowMultipleChoice,
              onChanged: (v) => setState(() => _allowMultipleChoice = v),
              color: accent,
              r: r,
            ),
            _buildToggleRow(
              icon: Icons.visibility_off_rounded,
              label: 'Votos anônimos',
              subtitle: 'Não mostrar quem votou em cada opção',
              value: _anonymousVotes,
              onChanged: (v) => setState(() => _anonymousVotes = v),
              color: context.nexusTheme.textSecondary,
              r: r,
            ),

            SizedBox(height: r.s(80)),
          ],
        ),
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
              height: r.s(140),
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
        height: r.s(64),
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

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required int maxLines,
    required Responsive r,
    required Color accent,
  }) {
    return TextField(
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
