import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// CREATE QUIZ SCREEN — Quiz interativo com perguntas e respostas corretas
//
// Melhorias:
//   - Imagem por pergunta (opcional)
//   - Explicação da resposta correta
//   - Timer configurável por pergunta (10s, 15s, 20s, 30s, 60s, sem limite)
//   - Imagem de capa do quiz
//   - Tags de categoria
//   - Dificuldade (fácil, médio, difícil)
//   - Suporte a editor_metadata
// =============================================================================

class _QuizOption {
  final TextEditingController controller;
  _QuizOption() : controller = TextEditingController();
  void dispose() => controller.dispose();
}

class _QuizQuestion {
  final TextEditingController questionController;
  final TextEditingController explanationController;
  final List<_QuizOption> options;
  int correctIndex;
  String? imageUrl;
  int timerSeconds; // 0 = sem limite

  _QuizQuestion()
      : questionController = TextEditingController(),
        explanationController = TextEditingController(),
        options = [_QuizOption(), _QuizOption(), _QuizOption(), _QuizOption()],
        correctIndex = 0,
        timerSeconds = 0;

  void dispose() {
    questionController.dispose();
    explanationController.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

class CreateQuizScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CreateQuizScreen({super.key, required this.communityId});

  @override
  ConsumerState<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends ConsumerState<CreateQuizScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final List<_QuizQuestion> _questions = [_QuizQuestion()];
  final List<String> _tags = [];
  bool _isSubmitting = false;
  String _visibility = 'public';
  String _difficulty = 'medium';
  String? _coverImageUrl;
  bool _isUploadingCover = false;
  bool _shuffleQuestions = false;

  static const _timerOptions = {
    0: 'Sem limite',
    10: '10s',
    15: '15s',
    20: '20s',
    30: '30s',
    60: '60s',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    if (_questions.length >= 20) return;
    setState(() => _questions.add(_QuizQuestion()));
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    final q = _questions.removeAt(index);
    q.dispose();
    setState(() {});
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.length >= 5 || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagController.clear();
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
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_quiz_cover_${image.name}';
      await SupabaseService.storage
          .from('post_media')
          .uploadBinary(path, bytes);
      final url =
          SupabaseService.storage.from('post_media').getPublicUrl(path);
      if (mounted) setState(() => _coverImageUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _pickQuestionImage(int qi) async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      final path =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_quiz_q${qi}_${image.name}';
      await SupabaseService.storage
          .from('post_media')
          .uploadBinary(path, bytes);
      final url =
          SupabaseService.storage.from('post_media').getPublicUrl(path);
      if (mounted) setState(() => _questions[qi].imageUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: AppTheme.errorColor,
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
          content: Text(s.quizTitleRequired),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final validQuestions = _questions
        .where((q) => q.questionController.text.trim().isNotEmpty)
        .toList();
    if (validQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.addAtLeastOneQuestion),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      final questions = validQuestions
          .map((q) => {
                'question_text': q.questionController.text.trim(),
                'correct_option_index': q.correctIndex,
                'explanation': q.explanationController.text.trim(),
                'image_url': q.imageUrl,
                'timer_seconds': q.timerSeconds,
                'options': q.options
                    .where((o) => o.controller.text.trim().isNotEmpty)
                    .map((o) => {'text': o.controller.text.trim()})
                    .toList(),
              })
          .toList();

      final editorMetadata = <String, dynamic>{
        'editor_type': 'quiz',
        'difficulty': _difficulty,
        'tags': _tags,
        'shuffle_questions': _shuffleQuestions,
        'total_questions': questions.length,
      };

      await SupabaseService.rpc('create_quiz_with_questions', params: {
        'p_community_id': widget.communityId,
        'p_title': title,
        'p_content': _descriptionController.text.trim(),
        'p_media_urls': <dynamic>[],
        'p_questions': questions,
        'p_allow_comments': true,
      });

      // Atualizar editor_metadata e cover no post criado
      try {
        final posts = await SupabaseService.table('posts')
            .select('id')
            .eq('community_id', widget.communityId)
            .eq('author_id', userId)
            .eq('type', 'quiz')
            .order('created_at', ascending: false)
            .limit(1);
        if (posts.isNotEmpty) {
          await SupabaseService.table('posts').update({
            'editor_metadata': editorMetadata,
            'editor_type': 'quiz',
            if (_coverImageUrl != null) 'cover_image_url': _coverImageUrl,
          }).eq('id', posts[0]['id']);
        }
      } catch (_) {}

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.quizCreatedSuccess),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorCreatingQuiz),
            backgroundColor: AppTheme.errorColor,
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
    final accent = const Color(0xFFDB2777);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          s.newQuiz,
          style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(17),
              fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.textPrimary),
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
              color: AppTheme.accentColor,
              size: r.s(20),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'public',
                  child: Text(s.publicLabel,
                      style: TextStyle(color: context.textPrimary))),
              PopupMenuItem(
                  value: 'followers',
                  child: Text(s.followers,
                      style: TextStyle(color: context.textPrimary))),
              PopupMenuItem(
                  value: 'private',
                  child: Text(s.privateLabel,
                      style: TextStyle(color: context.textPrimary))),
            ],
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    width: r.s(18),
                    height: r.s(18),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor),
                  )
                : Text(
                    s.publish,
                    style: TextStyle(
                        color: AppTheme.primaryColor,
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
                child: Icon(Icons.checklist_rounded,
                    color: accent, size: r.s(32)),
              ),
            ),
            SizedBox(height: r.s(16)),

            // Capa do quiz
            _buildCoverSection(r, accent),
            SizedBox(height: r.s(20)),

            // Título
            _buildLabel(s.quizTitle, r),
            SizedBox(height: r.s(8)),
            _buildTextField(
                controller: _titleController,
                hint: s.quizExampleHint,
                maxLength: 120,
                r: r,
                accent: accent),
            SizedBox(height: r.s(16)),
            _buildLabel(s.descriptionOptional2, r),
            SizedBox(height: r.s(8)),
            _buildTextField(
                controller: _descriptionController,
                hint: 'Contexto do quiz...',
                maxLength: 300,
                maxLines: 3,
                r: r,
                accent: accent),

            SizedBox(height: r.s(16)),
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(12)),

            // Dificuldade
            _buildLabel('Dificuldade', r),
            SizedBox(height: r.s(8)),
            Row(
              children: [
                _buildDifficultyChip('easy', 'Fácil', Colors.green, r),
                SizedBox(width: r.s(8)),
                _buildDifficultyChip(
                    'medium', 'Médio', Colors.orange, r),
                SizedBox(width: r.s(8)),
                _buildDifficultyChip(
                    'hard', 'Difícil', Colors.red, r),
              ],
            ),

            SizedBox(height: r.s(16)),

            // Tags
            _buildLabel('Tags', r),
            SizedBox(height: r.s(4)),
            _buildTagsSection(r),

            SizedBox(height: r.s(8)),

            // Toggle embaralhar
            Row(
              children: [
                Icon(Icons.shuffle_rounded,
                    color: context.textSecondary, size: r.s(20)),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Embaralhar perguntas',
                          style: TextStyle(
                              color: context.textPrimary,
                              fontSize: r.fs(13),
                              fontWeight: FontWeight.w600)),
                      Text('Ordem aleatória para cada participante',
                          style: TextStyle(
                              color: context.textSecondary,
                              fontSize: r.fs(11))),
                    ],
                  ),
                ),
                Switch(
                  value: _shuffleQuestions,
                  onChanged: (v) =>
                      setState(() => _shuffleQuestions = v),
                  activeColor: accent,
                ),
              ],
            ),

            SizedBox(height: r.s(16)),
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(12)),

            // Perguntas
            Row(
              children: [
                Text(
                  'Perguntas',
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${_questions.length}/20',
                  style: TextStyle(
                      color: context.textSecondary, fontSize: r.fs(12)),
                ),
              ],
            ),
            SizedBox(height: r.s(12)),
            ...List.generate(_questions.length, (qi) {
              final q = _questions[qi];
              return _buildQuestionCard(qi, q, r, accent);
            }),
            if (_questions.length < 20)
              Padding(
                padding: EdgeInsets.only(top: r.s(8)),
                child: TextButton.icon(
                  onPressed: _addQuestion,
                  icon: Icon(Icons.add_rounded,
                      color: AppTheme.primaryColor, size: r.s(18)),
                  label: Text(
                    s.addQuestion,
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(14)),
                  ),
                ),
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
          color: context.cardBg,
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
                        color: context.textSecondary, size: r.s(20)),
                    SizedBox(width: r.s(8)),
                    Text(
                      'Adicionar capa do quiz',
                      style: TextStyle(
                          color: context.textSecondary,
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

  Widget _buildDifficultyChip(
      String value, String label, Color color, Responsive r) {
    final selected = _difficulty == value;
    return GestureDetector(
      onTap: () => setState(() => _difficulty = value),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(14), vertical: r.s(8)),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : context.cardBg,
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(
            color: selected
                ? color
                : context.dividerClr.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : context.textSecondary,
            fontSize: r.fs(12),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
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
                        color: AppTheme.accentColor
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('#$tag',
                              style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: r.s(4)),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _tags.remove(tag)),
                            child: Icon(Icons.close_rounded,
                                color: AppTheme.accentColor,
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
                      color: context.textPrimary, fontSize: r.fs(13)),
                  decoration: InputDecoration(
                    hintText: 'Ex: ciência, história...',
                    hintStyle: TextStyle(
                        color: context.textSecondary,
                        fontSize: r.fs(13)),
                    border: InputBorder.none,
                    isDense: true,
                    prefixIcon: Icon(Icons.tag_rounded,
                        color: context.textSecondary, size: r.s(16)),
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
                    color: AppTheme.accentColor
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text('Adicionar',
                      style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildQuestionCard(
      int qi, _QuizQuestion q, Responsive r, Color accent) {
    final s = getStrings();
    return Container(
      margin: EdgeInsets.only(bottom: r.s(16)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.cardBg,
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
                  'Pergunta ${qi + 1}',
                  style: TextStyle(
                      color: accent,
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              // Timer
              PopupMenuButton<int>(
                initialValue: q.timerSeconds,
                onSelected: (v) =>
                    setState(() => q.timerSeconds = v),
                color: context.surfaceColor,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(8), vertical: r.s(4)),
                  decoration: BoxDecoration(
                    color: q.timerSeconds > 0
                        ? accent.withValues(alpha: 0.1)
                        : context.scaffoldBg,
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_rounded,
                          color: q.timerSeconds > 0
                              ? accent
                              : context.textSecondary,
                          size: r.s(14)),
                      SizedBox(width: r.s(4)),
                      Text(
                        _timerOptions[q.timerSeconds] ?? 'Sem limite',
                        style: TextStyle(
                            color: q.timerSeconds > 0
                                ? accent
                                : context.textSecondary,
                            fontSize: r.fs(11)),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (_) => _timerOptions.entries
                    .map((e) => PopupMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              style: TextStyle(
                                  color: context.textPrimary)),
                        ))
                    .toList(),
              ),
              if (_questions.length > 1) ...[
                SizedBox(width: r.s(8)),
                GestureDetector(
                  onTap: () => _removeQuestion(qi),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.errorColor, size: r.s(18)),
                ),
              ],
            ],
          ),
          SizedBox(height: r.s(10)),

          // Imagem da pergunta
          if (q.imageUrl != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  child: Image.network(
                    q.imageUrl!,
                    width: double.infinity,
                    height: r.s(120),
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: r.s(4),
                  right: r.s(4),
                  child: _circleBtn(Icons.close_rounded,
                      () => setState(() => q.imageUrl = null), r),
                ),
              ],
            ),
            SizedBox(height: r.s(8)),
          ] else ...[
            GestureDetector(
              onTap: () => _pickQuestionImage(qi),
              child: Container(
                height: r.s(40),
                decoration: BoxDecoration(
                  color: context.scaffoldBg,
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
                          color: context.textSecondary, size: r.s(16)),
                      SizedBox(width: r.s(6)),
                      Text(
                        'Adicionar imagem',
                        style: TextStyle(
                            color: context.textSecondary,
                            fontSize: r.fs(11)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: r.s(8)),
          ],

          // Texto da pergunta
          TextField(
            controller: q.questionController,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
                color: context.textPrimary, fontSize: r.fs(14)),
            decoration: InputDecoration(
              hintText: s.typeQuestionHint,
              hintStyle: TextStyle(
                  color: context.textSecondary, fontSize: r.fs(14)),
              filled: true,
              fillColor: context.scaffoldBg,
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
          SizedBox(height: r.s(10)),

          // Opções
          Text(
            s.optionsMarkCorrect,
            style: TextStyle(
                color: context.textSecondary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: r.s(8)),
          ...List.generate(q.options.length, (oi) {
            final isCorrect = q.correctIndex == oi;
            return Padding(
              padding: EdgeInsets.only(bottom: r.s(6)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => q.correctIndex = oi),
                    child: Container(
                      width: r.s(22),
                      height: r.s(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCorrect
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        border: Border.all(
                          color: isCorrect
                              ? AppTheme.primaryColor
                              : context.dividerClr,
                          width: 2,
                        ),
                      ),
                      child: isCorrect
                          ? Icon(Icons.check_rounded,
                              color: Colors.white, size: r.s(13))
                          : null,
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: TextField(
                      controller: q.options[oi].controller,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(13)),
                      decoration: InputDecoration(
                        hintText: s.optionNumber(oi + 1),
                        hintStyle: TextStyle(
                            color: context.textSecondary,
                            fontSize: r.fs(13)),
                        filled: true,
                        fillColor: context.scaffoldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.s(8)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.s(8)),
                          borderSide: BorderSide(
                              color: isCorrect
                                  ? AppTheme.primaryColor
                                  : accent,
                              width: 1.5),
                        ),
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: r.s(10), vertical: r.s(8)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          SizedBox(height: r.s(8)),

          // Explicação da resposta correta
          TextField(
            controller: q.explanationController,
            maxLength: 300,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
                color: context.textPrimary, fontSize: r.fs(12)),
            decoration: InputDecoration(
              hintText: 'Explicação da resposta correta (opcional)',
              hintStyle: TextStyle(
                  color: context.textSecondary, fontSize: r.fs(12)),
              filled: true,
              fillColor: AppTheme.primaryColor.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(8)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(8)),
                borderSide: BorderSide(
                    color: AppTheme.primaryColor, width: 1),
              ),
              counterText: '',
              prefixIcon: Icon(Icons.lightbulb_outline_rounded,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  size: r.s(16)),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: r.s(10), vertical: r.s(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Responsive r) => Text(
        text,
        style: TextStyle(
            color: context.textPrimary,
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
        style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: context.textSecondary, fontSize: r.fs(14)),
          filled: true,
          fillColor: context.cardBg,
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
