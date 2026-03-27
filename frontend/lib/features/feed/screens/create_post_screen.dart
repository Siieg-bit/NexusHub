import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Editor rico de criação de posts — suporta os 9 tipos exatos do Amino:
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
      final path = 'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);

      final url = SupabaseService.storage
          .from('post-media')
          .getPublicUrl(path);

      setState(() => _mediaUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no upload: $e')),
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
      final path = 'covers/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);

      final url = SupabaseService.storage
          .from('post-media')
          .getPublicUrl(path);

      setState(() => _coverImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no upload: $e')),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty &&
        _selectedType != 'image') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o título ou conteúdo')),
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
        'content': _contentController.text.trim(),
        'media_url': _mediaUrls.isNotEmpty ? _mediaUrls.first : null,
        'media_list': _mediaUrls.length > 1 ? _mediaUrls.sublist(1) : [],
        'cover_image_url': _coverImageUrl,
        'external_url':
            _linkController.text.trim().isNotEmpty ? _linkController.text.trim() : null,
        'background_url': _backgroundUrlController.text.trim().isNotEmpty
            ? _backgroundUrlController.text.trim()
            : null,
      };

      final result = await SupabaseService.table('posts')
          .insert(postData)
          .select()
          .single();

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
          const SnackBar(content: Text('Post criado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      appBar: AppBar(
        title: const Text('Criar Post',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Publicar'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // SELETOR DE TIPO
            // ============================================================
            Text('Tipo de Post',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _postTypes.length,
                itemBuilder: (context, index) {
                  final type = _postTypes[index];
                  final isSelected = _selectedType == type.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type.value),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                            : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.dividerColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(type.icon,
                              size: 16,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            type.label,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ============================================================
            // CAMPOS COMUNS
            // ============================================================
            // Cover image
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dividerColor),
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
                        children: const [
                          Icon(Icons.add_photo_alternate_rounded,
                              color: AppTheme.textHint, size: 32),
                          SizedBox(height: 4),
                          Text('Adicionar Capa',
                              style: TextStyle(
                                  color: AppTheme.textHint, fontSize: 12)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Título
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Título do post...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppTheme.textHint),
              ),
              maxLines: 1,
            ),

            // Conteúdo
            TextField(
              controller: _contentController,
              style: const TextStyle(fontSize: 15, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'Escreva seu conteúdo aqui...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppTheme.textHint),
              ),
              maxLines: null,
              minLines: 6,
            ),

            // ============================================================
            // CAMPOS ESPECÍFICOS POR TIPO
            // ============================================================
            if (_selectedType == 'poll') _buildPollEditor(),
            if (_selectedType == 'quiz') _buildQuizEditor(),
            if (_selectedType == 'link' || _selectedType == 'external')
              _buildLinkEditor(),
            if (_selectedType == 'image') _buildImageEditor(),

            const SizedBox(height: 16),

            // ============================================================
            // TOOLBAR DE FORMATAÇÃO
            // ============================================================
            _buildToolbar(),

            // Background URL
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Opções Avançadas',
                  style: TextStyle(fontSize: 14)),
              children: [
                TextField(
                  controller: _backgroundUrlController,
                  decoration: const InputDecoration(
                    hintText: 'URL do background customizado',
                    prefixIcon: Icon(Icons.wallpaper_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
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
        const Divider(),
        Text('Opções da Enquete',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(_pollOptions.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pollOptions[i],
                    decoration: InputDecoration(
                      hintText: 'Opção ${i + 1}',
                      prefixIcon:
                          Icon(Icons.circle_outlined, size: 16, color: AppTheme.textHint),
                    ),
                  ),
                ),
                if (_pollOptions.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_rounded,
                        color: AppTheme.errorColor, size: 20),
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
        TextButton.icon(
          onPressed: () {
            setState(() => _pollOptions.add(TextEditingController()));
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Adicionar Opção'),
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
        const Divider(),
        Text('Perguntas do Quiz',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(_quizQuestions.length, (qi) {
          final q = _quizQuestions[qi];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Pergunta ${qi + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_quizQuestions.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_rounded,
                            color: AppTheme.errorColor, size: 20),
                        onPressed: () {
                          setState(() {
                            _quizQuestions[qi].dispose();
                            _quizQuestions.removeAt(qi);
                          });
                        },
                      ),
                  ],
                ),
                TextField(
                  controller: q.questionController,
                  decoration: const InputDecoration(
                    hintText: 'Digite a pergunta...',
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
                        ),
                        Expanded(
                          child: TextField(
                            controller: q.options[oi],
                            decoration: InputDecoration(
                              hintText: 'Opção ${oi + 1}',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(
                        () => q.options.add(TextEditingController()));
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Opção', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() => _quizQuestions.add(_QuizQuestion()));
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Adicionar Pergunta'),
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
        const Divider(),
        Text('Link Externo',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _linkController,
          decoration: const InputDecoration(
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link_rounded),
          ),
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
        const Divider(),
        Text('Imagens',
            style: Theme.of(context).textTheme.titleMedium),
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
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _mediaUrls.remove(url)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 14),
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
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: const Icon(Icons.add_photo_alternate_rounded,
                    color: AppTheme.textHint),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ========================================================================
  // TOOLBAR DE FORMATAÇÃO
  // ========================================================================
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(Icons.image_rounded, 'Imagem', _pickImage),
          _ToolbarButton(Icons.gif_rounded, 'GIF', () {/* TODO: Giphy */}),
          _ToolbarButton(
              Icons.music_note_rounded, 'Música', () {/* TODO: SoundCloud */}),
          _ToolbarButton(
              Icons.format_bold_rounded, 'Negrito', () {/* TODO: Bold */}),
          _ToolbarButton(
              Icons.format_italic_rounded, 'Itálico', () {/* TODO: Italic */}),
          _ToolbarButton(Icons.format_strikethrough_rounded, 'Riscado',
              () {/* TODO: Strikethrough */}),
        ],
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
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppTheme.textSecondary, size: 22),
        ),
      ),
    );
  }
}
