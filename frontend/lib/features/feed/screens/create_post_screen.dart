import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/block_editor.dart';
import '../widgets/crosspost_picker.dart';

/// Editor rico de criação de posts — estilo Amino Apps.
/// Suporta os 9 tipos exatos do Amino:
/// Normal (0), Crosspost (1), Repost (2), Q&A (3), Poll (4),
/// Link Externo (5), Quiz Interativo (6), Imagem (7), Post Externo (8).
class CreatePostScreen extends StatefulWidget {
  final String communityId;
  const CreatePostScreen({super.key, required this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  String _selectedType = 'normal';
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
  final _blockEditorKey = GlobalKey<_BlockEditorState>();

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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);

      final url =
          SupabaseService.storage.from('post-media').getPublicUrl(path);

      setState(() => _mediaUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload: $e'),
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
      final bytes = await image.readAsBytes();

      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);

      final url =
          SupabaseService.storage.from('post-media').getPublicUrl(path);

      setState(() => _coverImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload: $e'),
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
        'content_blocks': _useBlogEditor
            ? _contentBlocks.map((b) => b.toJson()).toList()
            : null,
        'media_urls': _mediaUrls.isNotEmpty ? _mediaUrls : [],
        'cover_image_url': _coverImageUrl,
        'external_url': _linkController.text.trim().isNotEmpty
            ? _linkController.text.trim()
            : null,
        'background_url': _backgroundUrlController.text.trim().isNotEmpty
            ? _backgroundUrlController.text.trim()
            : null,
        if (_selectedType == 'crosspost' && _crosspostCommunity != null)
          'crosspost_community_id': _crosspostCommunity!['id'],
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
          'p_community_id': widget.communityId,
          'p_user_id': userId,
          'p_action': repType,
          'p_source_id': result['id'],
        });
      } catch (_) {
        // Reputação é best-effort, não bloqueia criação do post
      }

      final postId = result['id'] as String;

      // Criar opções de enquete
      if (_selectedType == 'poll') {
        final options = _pollOptions
            .where((c) => c.text.trim().isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((e) => {
                  'post_id': postId,
                  'option_text': e.value.text.trim(),
                  'position': e.key,
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
                'position': i,
              })
              .select()
              .single();

          final qId = qResult['id'] as String;
          final opts = q.options
              .asMap()
              .entries
              .where((e) => e.value.text.trim().isNotEmpty)
              .map((e) => {
                    'question_id': qId,
                    'option_text': e.value.text.trim(),
                    'is_correct': e.key == q.correctIndex,
                    'position': e.key,
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
            content: Text('Erro: $e'),
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
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      // ── AppBar estilo Amino (escuro, minimalista) ──
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Criar Post',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _isSubmitting ? null : _submitPost,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _isSubmitting
                      ? AppTheme.primaryColor.withValues(alpha: 0.5)
                      : AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Postar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
            height: 48,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _postTypes.length,
              itemBuilder: (context, index) {
                final type = _postTypes[index];
                final isSelected = _selectedType == type.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type.value),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
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
                            size: 14,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          type.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey[600],
                            fontSize: 12,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image picker
                  GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
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
                                    color: Colors.grey[600], size: 28),
                                const SizedBox(height: 4),
                                Text('Adicionar Capa',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11)),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title (borderless, large)
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
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
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _useBlogEditor = !_useBlogEditor),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _useBlogEditor
                                ? AppTheme.accentColor.withValues(alpha: 0.15)
                                : AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: _useBlogEditor
                                ? Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.dashboard_customize_rounded,
                                size: 14,
                                color: _useBlogEditor ? AppTheme.accentColor : Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Editor de Blocos',
                                style: TextStyle(
                                  fontSize: 12,
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
                        fontSize: 15,
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
                  const SizedBox(height: 16),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Opções Avançadas',
                          style: TextStyle(
                              fontSize: 13,
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
                        const SizedBox(height: 16),
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
  // AMINO INPUT FIELD (estilo escuro, sem borda visível)
  // ========================================================================
  Widget _buildAminoInput({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
          prefixIcon:
              icon != null ? Icon(icon, size: 18, color: Colors.grey[600]) : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ========================================================================
  // POLL EDITOR
  // ========================================================================
  Widget _buildPollEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        const SizedBox(height: 12),
        Text('Poll Options',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(_pollOptions.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
                    icon: const Icon(Icons.remove_circle_rounded,
                        color: AppTheme.errorColor, size: 18),
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
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text('Adicionar Opção',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        const SizedBox(height: 12),
        Text('Quiz Questions',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(_quizQuestions.length, (qi) {
          final q = _quizQuestions[qi];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Question ${qi + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.textPrimary)),
                    const Spacer(),
                    if (_quizQuestions.length > 1)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _quizQuestions[qi].dispose();
                            _quizQuestions.removeAt(qi);
                          });
                        },
                        child: const Icon(Icons.delete_rounded,
                            color: AppTheme.errorColor, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: q.questionController,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type the question...',
                    hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(q.options.length, (oi) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
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
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Option ${oi + 1}',
                              hintStyle: TextStyle(
                                  color: Colors.grey[700], fontSize: 12),
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
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text('Option',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 11,
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
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text('Adicionar Pergunta',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        const SizedBox(height: 12),
        Text('External Link',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        const SizedBox(height: 12),
        Text('Images',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._mediaUrls.map((url) => Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
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
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                )),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Icon(Icons.add_photo_alternate_rounded,
                    color: Colors.grey[600], size: 24),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
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
            _ToolbarButton(Icons.gif_rounded, 'GIF', () {
              // GIF picker - abre busca de GIFs
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('GIFs em breve!'), behavior: SnackBarBehavior.floating),
              );
            }),
            _ToolbarButton(
                Icons.music_note_rounded, 'Music', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('M\u00fasica em breve!'), behavior: SnackBarBehavior.floating),
              );
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.grey[500], size: 20),
        ),
      ),
    );
  }
}
