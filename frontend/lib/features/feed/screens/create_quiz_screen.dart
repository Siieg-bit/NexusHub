import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// CREATE QUIZ SCREEN — Quiz interativo com perguntas e respostas corretas
// =============================================================================

class _QuizOption {
  final TextEditingController controller;
  _QuizOption() : controller = TextEditingController();
  void dispose() => controller.dispose();
}

class _QuizQuestion {
  final TextEditingController questionController;
  final List<_QuizOption> options;
  int correctIndex;

  _QuizQuestion()
      : questionController = TextEditingController(),
        options = [_QuizOption(), _QuizOption(), _QuizOption(), _QuizOption()],
        correctIndex = 0;

  void dispose() {
    questionController.dispose();
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
  final List<_QuizQuestion> _questions = [_QuizQuestion()];
  bool _isSubmitting = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(s.quizTitleRequired),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    final validQuestions = _questions
        .where((q) => q.questionController.text.trim().isNotEmpty)
        .toList();
    if (validQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(s.addAtLeastOneQuestion),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      // Montar perguntas com opções como JSON para a RPC
      final questions = validQuestions
          .map((q) => {
                'question_text': q.questionController.text.trim(),
                'correct_option_index': q.correctIndex,
                'options': q.options
                    .where((o) => o.controller.text.trim().isNotEmpty)
                    .map((o) => {'text': o.controller.text.trim()})
                    .toList(),
              })
          .toList();

      // RPC atômica: cria post + questions + options + reputação
      await SupabaseService.rpc('create_quiz_with_questions', params: {
        'p_community_id': widget.communityId,
        'p_title': title,
        'p_content': _descriptionController.text.trim(),
        'p_media_urls': <dynamic>[],
        'p_questions': questions,
        'p_allow_comments': true,
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(s.quizCreatedSuccess),
            backgroundColor: AppTheme.successColor,
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
                  color: const Color(0xFFDB2777).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.checklist_rounded,
                    color: const Color(0xFFDB2777), size: r.s(32)),
              ),
            ),
            SizedBox(height: r.s(20)),
            // Título
            _buildLabel(s.quizTitle, r),
            SizedBox(height: r.s(8)),
            _buildTextField(
                controller: _titleController,
                hint: s.quizExampleHint,
                maxLength: 120,
                r: r),
            SizedBox(height: r.s(16)),
            _buildLabel(s.descriptionOptional2, r),
            SizedBox(height: r.s(8)),
            _buildTextField(
                controller: _descriptionController,
                hint: 'Contexto do quiz...',
                maxLength: 300,
                maxLines: 3,
                r: r),
            SizedBox(height: r.s(24)),
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
              return _buildQuestionCard(qi, q, r);
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
                        color: AppTheme.primaryColor, fontSize: r.fs(14)),
                  ),
                ),
              ),
            SizedBox(height: r.s(80)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int qi, _QuizQuestion q, Responsive r) {
    return Container(
      margin: EdgeInsets.only(bottom: r.s(16)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(color: context.dividerClr.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
                decoration: BoxDecoration(
                  color: const Color(0xFFDB2777).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(20)),
                ),
                child: Text(
                  'Pergunta ${qi + 1}',
                  style: TextStyle(
                      color: const Color(0xFFDB2777),
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (_questions.length > 1)
                GestureDetector(
                  onTap: () => _removeQuestion(qi),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.errorColor, size: r.s(18)),
                ),
            ],
          ),
          SizedBox(height: r.s(10)),
          TextField(
            controller: q.questionController,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
            decoration: InputDecoration(
              hintText: s.typeQuestionHint,
              hintStyle:
                  TextStyle(color: context.textSecondary, fontSize: r.fs(14)),
              filled: true,
              fillColor: context.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
                borderSide:
                    BorderSide(color: const Color(0xFFDB2777), width: 1.5),
              ),
              counterText: '',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(10)),
            ),
          ),
          SizedBox(height: r.s(10)),
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
                    onTap: () => setState(() => q.correctIndex = oi),
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
                          color: context.textPrimary, fontSize: r.fs(13)),
                      decoration: InputDecoration(
                        hintText: s.optionNumber(oi + 1),
                        hintStyle: TextStyle(
                            color: context.textSecondary, fontSize: r.fs(13)),
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
                                  : const Color(0xFFDB2777),
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
            borderSide: BorderSide(color: const Color(0xFFDB2777), width: 1.5),
          ),
          counterText: '',
          contentPadding:
              EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
        ),
      );
}
