import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';

/// Widget de Enquete (Poll) para uso no PostDetailScreen.
///
/// Renderiza as opções de votação com barras de progresso,
/// percentuais e feedback visual após votar — estilo Amino.
class PollDetailWidget extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onVoted;

  const PollDetailWidget({super.key, required this.post, this.onVoted});

  @override
  State<PollDetailWidget> createState() => _PollDetailWidgetState();
}

class _PollDetailWidgetState extends State<PollDetailWidget> {
  int? _selectedOption;
  bool _hasVoted = false;
  List<Map<String, dynamic>> _options = [];
  int _totalVotes = 0;

  @override
  void initState() {
    super.initState();
    _loadPollData();
  }

  Future<void> _loadPollData() async {
    try {
      // Buscar opções do banco de dados
      final options = await SupabaseService.table('poll_options')
          .select('*')
          .eq('post_id', widget.post.id)
          .order('sort_order', ascending: true);

      // Verificar se o usuário já votou
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        final votes = await SupabaseService.table('poll_votes')
            .select('option_id')
            .eq('user_id', userId);

        final optionIds =
            (options as List).map((o) => o['id'] as String).toSet();
        for (final vote in (votes as List)) {
          if (optionIds.contains(vote['option_id'])) {
            _selectedOption = (options)
                .indexWhere((o) => o['id'] == vote['option_id']);
            _hasVoted = true;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _options = (options as List)
              .map((o) => Map<String, dynamic>.from(o as Map))
              .toList();
          _totalVotes =
              _options.fold(0, (sum, o) => sum + ((o['votes_count'] as int?) ?? 0));
        });
      }
    } catch (e) {
      // Fallback para pollData do modelo
      final pollData = widget.post.pollData;
      if (pollData != null && mounted) {
        final options = (pollData['options'] as List<dynamic>?) ?? [];
        setState(() {
          _options = options
              .map((o) => Map<String, dynamic>.from(o as Map))
              .toList();
          _totalVotes = (pollData['total_votes'] as int?) ??
              _options.fold(
                  0, (sum, o) => sum + ((o['votes'] as int?) ?? (o['votes_count'] as int?) ?? 0));
        });
      }
    }
  }

  Future<void> _vote(int index) async {
    if (_hasVoted || _selectedOption != null) return;

    setState(() {
      _selectedOption = index;
      _hasVoted = true;
      _totalVotes++;
      if (index < _options.length) {
        final current = (_options[index]['votes_count'] as int?) ??
            (_options[index]['votes'] as int?) ??
            0;
        _options[index]['votes_count'] = current + 1;
      }
    });

    try {
      if (_options.isNotEmpty && _options[index]['id'] != null) {
        await SupabaseService.table('poll_votes').insert({
          'option_id': _options[index]['id'],
          'user_id': SupabaseService.currentUserId,
        });
        // Incrementar contador na opção
        await SupabaseService.table('poll_options')
            .update({
              'votes_count': (_options[index]['votes_count'] as int?) ?? 1,
            })
            .eq('id', _options[index]['id']);
      }
      widget.onVoted?.call();
    } catch (e) {
      // Silenciar — voto já registrado visualmente
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_options.isEmpty) {
      // Fallback para pollData inline
      final pollData = widget.post.pollData;
      if (pollData == null) return const SizedBox.shrink();
      final opts = (pollData['options'] as List<dynamic>?) ?? [];
      if (opts.isEmpty) return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.poll_rounded, size: 18, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              const Text(
                'Enquete',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.accentColor,
                ),
              ),
              const Spacer(),
              Text(
                '$_totalVotes votos',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Opções
          ...List.generate(_options.length, (i) {
            final opt = _options[i];
            final text = (opt['text'] as String?) ??
                (opt['option_text'] as String?) ??
                'Opção ${i + 1}';
            final votes = (opt['votes_count'] as int?) ??
                (opt['votes'] as int?) ??
                0;
            final pct = _totalVotes > 0 ? votes / _totalVotes : 0.0;
            final isSelected = _selectedOption == i;

            return GestureDetector(
              onTap: () => _vote(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor
                        : context.dividerClr,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      // Barra de progresso
                      if (_hasVoted)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accentColor.withValues(alpha: 0.15)
                                    : context.textHint.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                        ),
                      // Conteúdo
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            if (!_hasVoted)
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.textHint,
                                    width: 1.5,
                                  ),
                                ),
                              )
                            else if (isSelected)
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentColor,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white),
                              )
                            else
                              const SizedBox(width: 30),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (_hasVoted)
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppTheme.accentColor
                                      : context.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Widget de Quiz para uso no PostDetailScreen.
///
/// Renderiza perguntas com opções, feedback de certo/errado
/// e score final — estilo Amino.
class QuizDetailWidget extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onCompleted;

  const QuizDetailWidget({super.key, required this.post, this.onCompleted});

  @override
  State<QuizDetailWidget> createState() => _QuizDetailWidgetState();
}

class _QuizDetailWidgetState extends State<QuizDetailWidget> {
  int _currentQuestion = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedOption;
  bool _completed = false;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    try {
      final questions = await SupabaseService.table('quiz_questions')
          .select('*, quiz_options(*)')
          .eq('post_id', widget.post.id)
          .order('sort_order', ascending: true);

      if (mounted && (questions as List).isNotEmpty) {
        setState(() {
          _questions = questions
              .map((q) => Map<String, dynamic>.from(q as Map))
              .toList();
        });
        return;
      }
    } catch (_) {}

    // Fallback para quizData inline
    final quizData = widget.post.quizData;
    if (quizData != null && mounted) {
      final qs = (quizData['questions'] as List<dynamic>?) ?? [];
      setState(() {
        _questions = qs
            .map((q) => Map<String, dynamic>.from(q as Map))
            .toList();
      });
    }
  }

  void _answer(int optionIndex) {
    if (_answered) return;

    final q = _questions[_currentQuestion];
    // Determinar resposta correta
    int correctIndex;
    if (q['quiz_options'] != null) {
      final opts = q['quiz_options'] as List<dynamic>;
      correctIndex = opts.indexWhere((o) => o['is_correct'] == true);
    } else {
      correctIndex = (q['correct_index'] as int?) ?? 0;
    }

    final isCorrect = optionIndex == correctIndex;

    setState(() {
      _selectedOption = optionIndex;
      _answered = true;
      if (isCorrect) _score++;
    });

    // Avançar automaticamente após 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentQuestion < _questions.length - 1) {
        setState(() {
          _currentQuestion++;
          _answered = false;
          _selectedOption = null;
        });
      } else {
        setState(() => _completed = true);
        _saveAttempt();
        widget.onCompleted?.call();
      }
    });
  }

  Future<void> _saveAttempt() async {
    try {
      await SupabaseService.table('quiz_attempts').upsert({
        'post_id': widget.post.id,
        'user_id': SupabaseService.currentUserId,
        'score': _score,
        'total_questions': _questions.length,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: _completed ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildResult() {
    final pct = _questions.isNotEmpty ? _score / _questions.length : 0.0;
    final emoji = pct >= 0.8
        ? '🎉'
        : pct >= 0.5
            ? '👍'
            : '📚';

    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          'Resultado: $_score/${_questions.length}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(pct * 100).toStringAsFixed(0)}% de acerto',
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _currentQuestion = 0;
                _score = 0;
                _answered = false;
                _selectedOption = null;
                _completed = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Tentar Novamente',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_currentQuestion];
    final questionText = (q['question_text'] as String?) ??
        (q['text'] as String?) ??
        'Pergunta ${_currentQuestion + 1}';

    // Obter opções
    List<dynamic> options;
    int correctIndex;
    if (q['quiz_options'] != null) {
      options = q['quiz_options'] as List<dynamic>;
      correctIndex = options.indexWhere((o) => o['is_correct'] == true);
    } else {
      options = (q['options'] as List<dynamic>?) ?? [];
      correctIndex = (q['correct_index'] as int?) ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.quiz_rounded, size: 18, color: AppTheme.accentColor),
            const SizedBox(width: 8),
            Text(
              'Quiz — Pergunta ${_currentQuestion + 1}/${_questions.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),

        // Progress bar
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentQuestion + 1) / _questions.length,
            backgroundColor: context.dividerClr,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
            minHeight: 4,
          ),
        ),

        const SizedBox(height: 16),

        // Pergunta
        Text(
          questionText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 14),

        // Opções
        ...List.generate(options.length, (i) {
          final opt = options[i];
          final optText = opt is Map
              ? ((opt['option_text'] as String?) ??
                  (opt['text'] as String?) ??
                  'Opção ${i + 1}')
              : opt.toString();
          final isCorrect = i == correctIndex;
          final isSelected = _selectedOption == i;

          Color bgColor = context.scaffoldBg;
          Color borderColor = context.dividerClr;
          IconData? trailingIcon;
          Color? trailingColor;

          if (_answered) {
            if (isCorrect) {
              bgColor = AppTheme.successColor.withValues(alpha: 0.12);
              borderColor = AppTheme.successColor;
              trailingIcon = Icons.check_circle_rounded;
              trailingColor = AppTheme.successColor;
            } else if (isSelected && !isCorrect) {
              bgColor = AppTheme.errorColor.withValues(alpha: 0.12);
              borderColor = AppTheme.errorColor;
              trailingIcon = Icons.cancel_rounded;
              trailingColor = AppTheme.errorColor;
            }
          }

          return GestureDetector(
            onTap: () => _answer(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: isSelected ? 1.5 : 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? (isCorrect
                              ? AppTheme.successColor
                              : AppTheme.errorColor)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : context.textHint,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isSelected && _answered
                          ? Icon(
                              trailingIcon ?? Icons.circle,
                              size: 14,
                              color: Colors.white,
                            )
                          : Text(
                              String.fromCharCode(65 + i), // A, B, C, D
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : context.textHint,
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      optText,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (_answered && trailingIcon != null)
                    Icon(trailingIcon, size: 20, color: trailingColor),
                ],
              ),
            ),
          );
        }),

        // Explicação
        if (_answered && q['explanation'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: AppTheme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      q['explanation'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
