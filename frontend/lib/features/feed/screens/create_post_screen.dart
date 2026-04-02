import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/block_editor.dart';
import '../../chat/widgets/giphy_picker.dart';
import '../widgets/crosspost_picker.dart';
import '../../../core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/draft_provider.dart';

/// Editor rico de criação de posts — estilo Amino Apps.
/// Suporta os 9 tipos exatos do Amino:
/// Normal (0), Crosspost (1), Repost (2), Q&A (3), Poll (4),
/// Link Externo (5), Quiz Interativo (6), Imagem (7), Post Externo (8).
class CreatePostScreen extends ConsumerStatefulWidget {
  final String communityId;
  /// Tipo de post pré-selecionado ao abrir (ex: 'image', 'poll', 'quiz', 'link', 'qa', 'normal').
  final String? initialType;
  const CreatePostScreen({
    super.key,
    required this.communityId,
    this.initialType,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  late String _selectedType;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _linkController = TextEditingController();
  final _backgroundUrlController = TextEditingController();
  bool _isSubmitting = false;
  final List<String> _mediaUrls = [];
  String? _coverImageUrl;

  // Block Editor para modo Blog
  List<ContentBlock> _contentBlocks = [];
  bool _useBlogEditor = false;
  // ignore: unused_field
  final _blockEditorKey = GlobalKey();

  // Poll
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Quiz
  final List<_QuizQuestion> _quizQuestions = [_QuizQuestion()];

  // Q&A
  // ignore: unused_field
  bool _isQaClosed = false;

  // Crosspost
  Map<String, dynamic>? _crosspostCommunity;
  // Visibilidade e controle de comentários
  String _postVisibility = 'public'; // public, followers, private
  bool _commentsBlocked = false;
  // GIF e Música
  String? _gifUrl;
  String? _musicUrl;
  String? _musicTitle;

  static const _postTypes = [
    _PostTypeOption('normal', 'Blog', Icons.article_rounded),
    _PostTypeOption('image', 'Imagem', Icons.image_rounded),
    _PostTypeOption('poll', 'Enquete', Icons.poll_rounded),
    _PostTypeOption('quiz', 'Quiz', Icons.quiz_rounded),
    _PostTypeOption('qa', 'Q&A', Icons.question_answer_rounded),
    _PostTypeOption('link', 'Link', Icons.link_rounded),
    _PostTypeOption('crosspost', 'Crosspost', Icons.share_rounded),
    _PostTypeOption('repost', 'Repost', Icons.repeat_rounded),
    _PostTypeOption('external', 'Externo', Icons.open_in_new_rounded),
  ];

  @override
  void initState() {
    super.initState();
    // Usa o tipo inicial passado pelo menu de criação, ou 'normal' como padrão
    _selectedType = widget.initialType ?? 'normal';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      // Comprimir imagem antes do upload
      final bytes = await MediaUtils.compressImage(rawBytes);

      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      if (!mounted) return;

      final url =
          SupabaseService.storage.from('post-media').getPublicUrl(path);

      if (!mounted) return;
      setState(() => _mediaUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'covers/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      // Comprimir imagem antes do upload
      final bytes = await MediaUtils.compressImage(rawBytes);

      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      if (!mounted) return;

      final url =
          SupabaseService.storage.from('post-media').getPublicUrl(path);

      if (!mounted) return;
      setState(() => _coverImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty &&
        _selectedType != 'image') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o título ou conteúdo'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Validar crosspost
    if (_selectedType == 'crosspost' && _crosspostCommunity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a comunidade destino para o crosspost'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Não autenticado');

      final postData = {
        'community_id': widget.communityId,
        'author_id': userId,
        'type': _selectedType,
        'title': _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        'content': _useBlogEditor
            ? _contentBlocks
                .where((b) => b.type == BlockType.text || b.type == BlockType.heading)
                .map((b) => b.controller?.text ?? b.text)
                .where((t) => t.isNotEmpty)
                .join('\n\n')
            : _contentController.text.trim(),
        'media_list': _mediaUrls.isNotEmpty
            ? _mediaUrls.map((url) => {'url': url, 'type': 'image'}).toList()
            : [],
        'cover_image_url': _coverImageUrl,
        'external_url': _linkController.text.trim().isNotEmpty
            ? _linkController.text.trim()
            : null,
        'background_url': _backgroundUrlController.text.trim().isNotEmpty
            ? _backgroundUrlController.text.trim()
            : null,
        'visibility': _postVisibility,
        'comments_blocked': _commentsBlocked,
        if (_gifUrl != null) 'gif_url': _gifUrl,
        if (_musicUrl != null) 'music_url': _musicUrl,
        if (_musicTitle != null) 'music_title': _musicTitle,
        if (_selectedType == 'crosspost' && _crosspostCommunity != null) ...{
          'original_community_id': _crosspostCommunity!['id'],
        },
      };

      // Criar post e ganhar reputação
      final result = await SupabaseService.table('posts')
          .insert(postData)
          .select()
          .single();

      // Adicionar reputação por criar post
      try {
        final repType = (_selectedType == 'poll' || _selectedType == 'quiz')
            ? 'poll_create'
            : 'post_create';
        await SupabaseService.rpc('add_reputation', params: {
          'p_user_id': userId,
          'p_community_id': widget.communityId,
          'p_action_type': repType,
          'p_raw_amount': 15,
          'p_reference_id': result['id'],
        });
      } catch (_) {
        // Reputação é best-effort, não bloqueia criação do post
      }

      final postId = result['id'] as String?;

      // Crosspost: criar post-espelho na comunidade destino
      if (_selectedType == 'crosspost' && _crosspostCommunity != null) {
        try {
          await SupabaseService.table('posts').insert({
            'community_id': _crosspostCommunity!['id'],
            'author_id': userId,
            'type': 'crosspost',
            'title': _titleController.text.trim().isNotEmpty
                ? _titleController.text.trim()
                : null,
            'content': _useBlogEditor
                ? _contentBlocks
                    .where((b) => b.type == BlockType.text || b.type == BlockType.heading)
                    .map((b) => b.controller?.text ?? b.text)
                    .where((t) => t.isNotEmpty)
                    .join('\n\n')
                : _contentController.text.trim(),
            'media_list': _mediaUrls.isNotEmpty
                ? _mediaUrls.map((url) => {'url': url, 'type': 'image'}).toList()
                : [],
            'cover_image_url': _coverImageUrl,
            'original_post_id': postId,
            'original_community_id': widget.communityId,
          });
        } catch (_) {
          // Crosspost espelho é best-effort
        }
      }

      // Criar opções de enquete
      if (_selectedType == 'poll') {
        final options = _pollOptions
            .where((c) => c.text.trim().isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((e) => {
                  'post_id': postId,
                  'text': e.value.text.trim(),
                  'sort_order': e.key,
                })
            .toList();
        if (options.isNotEmpty) {
          await SupabaseService.table('poll_options').insert(options);
        }
      }

      // Criar perguntas de quiz
      if (_selectedType == 'quiz') {
        for (int i = 0; i < _quizQuestions.length; i++) {
          final q = _quizQuestions[i];
          if (q.questionController.text.trim().isEmpty) continue;

          final qResult = await SupabaseService.table('quiz_questions')
              .insert({
                'post_id': postId,
                'question_text': q.questionController.text.trim(),
                'sort_order': i,
              })
              .select()
              .single();

          final qId = qResult['id'] as String?;
          final opts = q.options
              .asMap()
              .entries
              .where((e) => e.value.text.trim().isNotEmpty)
              .map((e) => {
                    'question_id': qId,
                    'text': e.value.text.trim(),
                    'is_correct': e.key == q.correctIndex,
                    'sort_order': e.key,
                  })
              .toList();
          if (opts.isNotEmpty) {
            await SupabaseService.table('quiz_options').insert(opts);
          }
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post criado com sucesso!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ocorreu um erro. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _wrapSelection(String prefix, String suffix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (sel.isValid && sel.start != sel.end) {
      final selected = text.substring(sel.start, sel.end);
      final newText = text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start + prefix.length + selected.length + suffix.length,
        ),
      );
    } else {
      // Sem seleção: insere placeholder
      final pos = sel.isValid ? sel.start : text.length;
      final newText = '${text.substring(0, pos)}${prefix}texto${suffix}${text.substring(pos)}';
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
    _contentController.dispose();
    _linkController.dispose();
    _backgroundUrlController.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    for (final q in _quizQuestions) {
      q.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      // ── AppBar estilo Amino (escuro, minimalista) ──
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Criar Post',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: r.fs(16),
          ),
        ),
        centerTitle: true,
        actions: [
          // Botão de rascunhos
          IconButton(
            icon: Icon(Icons.drafts_rounded, color: context.textSecondary, size: r.s(22)),
            tooltip: 'Rascunhos',
            onPressed: () => context.push('/drafts'),
          ),
          // Botão de salvar como rascunho
          IconButton(
            icon: Icon(Icons.save_outlined, color: context.textSecondary, size: r.s(22)),
            tooltip: 'Salvar rascunho',
            onPressed: () async {
              final title = _titleController.text.trim();
              final content = _contentController.text.trim();
              if (title.isEmpty && content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nada para salvar')),
                );
                return;
              }
              try {
                await ref.read(postDraftsProvider.notifier).createDraft(
                  communityId: widget.communityId,
                  title: title.isNotEmpty ? title : null,
                  content: content.isNotEmpty ? content : null,
                  postType: _selectedType,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Rascunho salvo!'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar. Tente novamente.')),
                  );
                }
              }
            },
          ),
          Padding(
            padding: EdgeInsets.only(right: r.s(12)),
            child: GestureDetector(
              onTap: _isSubmitting ? null : _submitPost,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(8)),
                decoration: BoxDecoration(
                  color: _isSubmitting
                      ? AppTheme.primaryColor.withValues(alpha: 0.5)
                      : AppTheme.primaryColor,
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
                        'Postar',
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
      ),
      body: Column(
        children: [
          // ── Type selector (horizontal scroll) ──
          Container(
            height: r.s(48),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: r.s(12)),
              itemCount: _postTypes.length,
              itemBuilder: (context, index) {
                final type = _postTypes[index];
                final isSelected = _selectedType == type.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type.value),
                  child: Container(
                    margin: EdgeInsets.only(right: r.s(6)),
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(12), vertical: r.s(8)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(r.s(20)),
                      border: isSelected
                          ? Border.all(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type.icon,
                            size: r.s(14),
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey[600]),
                        SizedBox(width: r.s(6)),
                        Text(
                          type.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey[600],
                            fontSize: r.fs(12),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image picker
                  GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      width: double.infinity,
                      height: r.s(120),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(r.s(12)),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                        image: _coverImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_coverImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _coverImageUrl == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded,
                                    color: Colors.grey[600], size: r.s(28)),
                                SizedBox(height: r.s(4)),
                                Text('Adicionar Capa',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: r.fs(11))),
                              ],
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: r.s(16)),

                  // Title (borderless, large)
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: r.fs(20),
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Título...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w700),
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 1,
                  ),

                  // Toggle Blog Editor
                  if (_selectedType == 'normal')
                    Padding(
                      padding: EdgeInsets.only(bottom: r.s(8)),
                      child: GestureDetector(
                        onTap: () => setState(() => _useBlogEditor = !_useBlogEditor),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
                          decoration: BoxDecoration(
                            color: _useBlogEditor
                                ? AppTheme.accentColor.withValues(alpha: 0.15)
                                : context.cardBg,
                            borderRadius: BorderRadius.circular(r.s(20)),
                            border: _useBlogEditor
                                ? Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.dashboard_customize_rounded,
                                size: r.s(14),
                                color: _useBlogEditor ? AppTheme.accentColor : Colors.grey[600],
                              ),
                              SizedBox(width: r.s(6)),
                              Text(
                                'Editor de Blocos',
                                style: TextStyle(
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600,
                                  color: _useBlogEditor ? AppTheme.accentColor : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Content — Block Editor ou TextField simples
                  if (_useBlogEditor && _selectedType == 'normal')
                    BlockEditor(
                      communityId: widget.communityId,
                      initialBlocks: _contentBlocks.isEmpty
                          ? [ContentBlock(type: BlockType.text)]
                          : _contentBlocks,
                      onChanged: (blocks) => _contentBlocks = blocks,
                    )
                  else
                    TextField(
                      controller: _contentController,
                      style: TextStyle(
                        fontSize: r.fs(15),
                        height: 1.6,
                        color: Colors.grey[300],
                      ),
                      decoration: InputDecoration(
                        hintText: 'Escreva seu conteúdo aqui...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      minLines: 6,
                    ),

                  // Type-specific editors
                  if (_selectedType == 'poll') _buildPollEditor(),
                  if (_selectedType == 'quiz') _buildQuizEditor(),
                  if (_selectedType == 'link' || _selectedType == 'external')
                    _buildLinkEditor(),
                  if (_selectedType == 'image') _buildImageEditor(),
                  if (_selectedType == 'crosspost')
                    CrosspostPicker(
                      currentCommunityId: widget.communityId,
                      selectedCommunity: _crosspostCommunity,
                      onCommunitySelected: (c) {
                        setState(() => _crosspostCommunity = c);
                      },
                    ),

                  // Advanced options
                  SizedBox(height: r.s(16)),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Opções Avançadas',
                          style: TextStyle(
                              fontSize: r.fs(13),
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500)),
                      iconColor: Colors.grey[600],
                      collapsedIconColor: Colors.grey[600],
                      children: [
                        _buildAminoInput(
                          controller: _backgroundUrlController,
                          hint: 'Custom background URL',
                          icon: Icons.wallpaper_rounded,
                        ),
                        SizedBox(height: r.s(12)),
                        // Visibilidade do post
                        Container(
                          padding: EdgeInsets.all(r.s(12)),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(r.s(10)),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: r.s(16), color: Colors.grey[600]),
                                  SizedBox(width: r.s(8)),
                                  Text('Visibilidade', style: TextStyle(fontSize: r.fs(13), color: Colors.grey[400], fontWeight: FontWeight.w600)),
                                ],
                              ),
                              SizedBox(height: r.s(8)),
                              Wrap(
                                spacing: r.s(8),
                                children: [
                                  _visibilityChip('public', 'Público', Icons.public_rounded),
                                  _visibilityChip('followers', 'Seguidores', Icons.people_rounded),
                                  _visibilityChip('private', 'Privado', Icons.lock_rounded),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: r.s(8)),
                        // Bloquear comentários
                        GestureDetector(
                          onTap: () => setState(() => _commentsBlocked = !_commentsBlocked),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(10)),
                            decoration: BoxDecoration(
                              color: _commentsBlocked
                                  ? AppTheme.errorColor.withValues(alpha: 0.1)
                                  : context.cardBg,
                              borderRadius: BorderRadius.circular(r.s(10)),
                              border: Border.all(
                                color: _commentsBlocked
                                    ? AppTheme.errorColor.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _commentsBlocked ? Icons.comments_disabled_rounded : Icons.comment_rounded,
                                  size: r.s(16),
                                  color: _commentsBlocked ? AppTheme.errorColor : Colors.grey[600],
                                ),
                                SizedBox(width: r.s(8)),
                                Text(
                                  _commentsBlocked ? 'Comentários bloqueados' : 'Permitir comentários',
                                  style: TextStyle(
                                    fontSize: r.fs(13),
                                    color: _commentsBlocked ? AppTheme.errorColor : Colors.grey[400],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: !_commentsBlocked,
                                  onChanged: (v) => setState(() => _commentsBlocked = !v),
                                  activeColor: AppTheme.primaryColor,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom toolbar ──
          _buildToolbar(),
        ],
      ),
    );
  }

  // ========================================================================
  // VISIBILITY CHIP HELPER
  // ========================================================================
  Widget _visibilityChip(String value, String label, IconData icon) {
    final r = context.r;
    final isSelected = _postVisibility == value;
    return GestureDetector(
      onTap: () => setState(() => _postVisibility = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(6)),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: r.s(13), color: isSelected ? AppTheme.primaryColor : Colors.grey[500]),
            SizedBox(width: r.s(4)),
            Text(label, style: TextStyle(fontSize: r.fs(12), color: isSelected ? AppTheme.primaryColor : Colors.grey[500], fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // AMINO INPUT FIELD (estilo escuro, sem borda visível)
  // ========================================================================
  Widget _buildAminoInput({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
      final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: r.fs(13), color: context.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[700], fontSize: r.fs(13)),
          prefixIcon:
              icon != null ? Icon(icon, size: r.s(18), color: Colors.grey[600]) : null,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(12)),
        ),
      ),
    );
  }

  // ========================================================================
  // POLL EDITOR
  // ========================================================================
  Widget _buildPollEditor() {
      final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        SizedBox(height: r.s(12)),
        Text('Poll Options',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        ...List.generate(_pollOptions.length, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: r.s(8)),
            child: Row(
              children: [
                Expanded(
                  child: _buildAminoInput(
                    controller: _pollOptions[i],
                    hint: 'Option ${i + 1}',
                    icon: Icons.circle_outlined,
                  ),
                ),
                if (_pollOptions.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_rounded,
                        color: AppTheme.errorColor, size: r.s(18)),
                    onPressed: () {
                      setState(() {
                        _pollOptions[i].dispose();
                        _pollOptions.removeAt(i);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        GestureDetector(
          onTap: () =>
              setState(() => _pollOptions.add(TextEditingController())),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: r.s(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    size: r.s(16), color: AppTheme.primaryColor),
                SizedBox(width: r.s(6)),
                Text('Adicionar Opção',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // QUIZ EDITOR
  // ========================================================================
  Widget _buildQuizEditor() {
      final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        SizedBox(height: r.s(12)),
        Text('Quiz Questions',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        ...List.generate(_quizQuestions.length, (qi) {
          final q = _quizQuestions[qi];
          return Container(
            margin: EdgeInsets.only(bottom: r.s(12)),
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Question ${qi + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(13),
                            color: context.textPrimary)),
                    const Spacer(),
                    if (_quizQuestions.length > 1)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _quizQuestions[qi].dispose();
                            _quizQuestions.removeAt(qi);
                          });
                        },
                        child: Icon(Icons.delete_rounded,
                            color: AppTheme.errorColor, size: r.s(18)),
                      ),
                  ],
                ),
                SizedBox(height: r.s(8)),
                TextField(
                  controller: q.questionController,
                  style: TextStyle(
                      fontSize: r.fs(13), color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type the question...',
                    hintStyle: TextStyle(color: Colors.grey[700], fontSize: r.fs(13)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(height: r.s(8)),
                ...List.generate(q.options.length, (oi) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: r.s(4)),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: oi,
                          groupValue: q.correctIndex,
                          onChanged: (v) {
                            setState(() => q.correctIndex = v ?? 0);
                          },
                          activeColor: AppTheme.successColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: TextField(
                            controller: q.options[oi],
                            style: TextStyle(
                                fontSize: r.fs(12), color: context.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Option ${oi + 1}',
                              hintStyle: TextStyle(
                                  color: Colors.grey[700], fontSize: r.fs(12)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => setState(
                      () => q.options.add(TextEditingController())),
                  child: Padding(
                    padding: EdgeInsets.only(top: r.s(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: r.s(14), color: AppTheme.primaryColor),
                        SizedBox(width: r.s(4)),
                        Text('Option',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        GestureDetector(
          onTap: () => setState(() => _quizQuestions.add(_QuizQuestion())),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: r.s(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    size: r.s(16), color: AppTheme.primaryColor),
                SizedBox(width: r.s(6)),
                Text('Adicionar Pergunta',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // LINK EDITOR
  // ========================================================================
  Widget _buildLinkEditor() {
      final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        SizedBox(height: r.s(12)),
        Text('External Link',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        _buildAminoInput(
          controller: _linkController,
          hint: 'https://...',
          icon: Icons.link_rounded,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  // ========================================================================
  // IMAGE EDITOR
  // ========================================================================
  Widget _buildImageEditor() {
      final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        SizedBox(height: r.s(12)),
        Text('Images',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._mediaUrls.map((url) => Stack(
                  children: [
                    Container(
                      width: r.s(80),
                      height: r.s(80),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r.s(10)),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _mediaUrls.remove(url)),
                        child: Container(
                          padding: EdgeInsets.all(r.s(3)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded,
                              color: Colors.white, size: r.s(12)),
                        ),
                      ),
                    ),
                  ],
                )),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: r.s(80),
                height: r.s(80),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(r.s(10)),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Icon(Icons.add_photo_alternate_rounded,
                    color: Colors.grey[600], size: r.s(24)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ========================================================================
  // BOTTOM TOOLBAR — Estilo Amino (flutuante, escuro)
  // ========================================================================
  Widget _buildToolbar() {
      final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(vertical: r.s(8), horizontal: r.s(16)),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ToolbarButton(Icons.image_rounded, 'Image', _pickImage),
            _ToolbarButton(Icons.gif_rounded, 'GIF', () async {
              final url = await GiphyPicker.show(context);
              if (url != null && mounted) {
                setState(() => _gifUrl = url);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('GIF adicionado ao post!'), behavior: SnackBarBehavior.floating),
                );
              }
            }),
            _ToolbarButton(
                Icons.music_note_rounded, 'Music', () {
              _showMusicPicker();
            }),
            _ToolbarButton(
                Icons.format_bold_rounded, 'Bold', () => _wrapSelection('**', '**')),
            _ToolbarButton(
                Icons.format_italic_rounded, 'Italic', () => _wrapSelection('_', '_')),
            _ToolbarButton(Icons.format_strikethrough_rounded, 'Strike',
                () => _wrapSelection('~~', '~~')),
          ],
        ),
      ),
    );
  }

  void _showMusicPicker() {
    final r = context.r;
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
          left: r.s(20), right: r.s(20), top: r.s(20),
          bottom: MediaQuery.of(ctx).viewInsets.bottom + r.s(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adicionar Música',
                style: TextStyle(fontSize: r.fs(18), fontWeight: FontWeight.w800, color: context.textPrimary)),
            SizedBox(height: r.s(16)),
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nome da música (ex: Artist - Song)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.music_note_rounded, color: AppTheme.primaryColor, size: r.s(18)),
              ),
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'URL do arquivo de áudio (.mp3, .ogg)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.link_rounded, color: Colors.grey[600], size: r.s(18)),
              ),
            ),
            SizedBox(height: r.s(16)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _musicUrl = urlCtrl.text.trim().isNotEmpty ? urlCtrl.text.trim() : null;
                    _musicTitle = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : null;
                  });
                  Navigator.pop(ctx);
                  if (_musicUrl != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Música adicionada ao post!'), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('Confirmar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS E MODELOS AUXILIARES
// ============================================================================

class _PostTypeOption {
  final String value;
  final String label;
  final IconData icon;
  const _PostTypeOption(this.value, this.label, this.icon);
}

class _QuizQuestion {
  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> options = [
    TextEditingController(),
    TextEditingController(),
  ];
  int correctIndex = 0;

  void dispose() {
    questionController.dispose();
    for (final c in options) {
      c.dispose();
    }
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton(this.icon, this.tooltip, this.onTap);

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(r.s(10)),
          child: Icon(icon, color: Colors.grey[500], size: r.s(20)),
        ),
      ),
    );
  }
}
