import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Widget de Enquete (Poll) para uso no PostDetailScreen.
///
/// Renderiza as opções de votação com barras de progresso,
/// percentuais e feedback visual após votar — estilo Amino.
class PollDetailWidget extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onVoted;

  const PollDetailWidget({super.key, required this.post, this.onVoted});

  @override
  ConsumerState<PollDetailWidget> createState() => _PollDetailWidgetState();
}

class _PollDetailWidgetState extends ConsumerState<PollDetailWidget> {
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
        if (!mounted) return;

        final optionIds =
            (options as List? ?? []).map((o) => o['id'] as String?).toSet();
        for (final vote in ((votes as List? ?? []))) {
          if (optionIds.contains(vote['option_id']) == true) {
            _selectedOption =
                (options).indexWhere((o) => o['id'] == vote['option_id']);
            _hasVoted = true;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _options = (options as List? ?? [])
              .map((o) => Map<String, dynamic>.from(o as Map))
              .toList();
          _totalVotes = _options.fold(
              0, (sum, o) => sum + ((o['votes_count'] as int?) ?? 0));
        });
      }
    } catch (e) {
      // Fallback para pollData do modelo
      final pollData = widget.post.pollData;
      if (pollData != null && mounted) {
        final options = (pollData['options'] as List<dynamic>?) ?? [];
        setState(() {
          _options =
              options.map((o) => Map<String, dynamic>.from(o as Map)).toList();
          _totalVotes = (pollData['total_votes'] as int?) ??
              _options.fold(
                  0,
                  (sum, o) =>
                      sum +
                      ((o['votes'] as int?) ??
                          (o['votes_count'] as int?) ??
                          0));
        });
      }
    }
  }

  Future<void> _vote(int index) async {
    if (_hasVoted || _selectedOption != null) return;
    if (index >= _options.length || _options[index]['id'] == null) return;

    final previousSelectedOption = _selectedOption;
    final previousHasVoted = _hasVoted;
    final previousTotalVotes = _totalVotes;
    final previousOptions =
        _options.map((option) => Map<String, dynamic>.from(option)).toList();

    setState(() {
      _selectedOption = index;
      _hasVoted = true;
      _totalVotes++;
      final current = (_options[index]['votes_count'] as int?) ??
          (_options[index]['votes'] as int?) ??
          0;
      _options[index]['votes_count'] = current + 1;
    });

    try {
      final result = await SupabaseService.rpc(
        'vote_on_poll',
        params: {
          'p_option_id': _options[index]['id'],
        },
      );

      final response = Map<String, dynamic>.from(result as Map);
      final success = response['success'] == true;
      final error = response['error'] as String?;
      final serverOptionId = response['option_id'] as String?;
      final serverTotalVotes = response['total_votes'] as int?;
      final serverOptionVotes = response['option_votes'] as int?;

      if (!mounted) return;

      if (success) {
        setState(() {
          if (serverTotalVotes != null) {
            _totalVotes = serverTotalVotes;
          }
          if (serverOptionVotes != null) {
            _options[index]['votes_count'] = serverOptionVotes;
          }
        });
        widget.onVoted?.call();
        return;
      }

      if (error == 'already_voted') {
        final selectedIndex = serverOptionId == null
            ? index
            : _options.indexWhere((option) => option['id'] == serverOptionId);
        setState(() {
          _hasVoted = true;
          _selectedOption = selectedIndex >= 0 ? selectedIndex : index;
          _options = previousOptions;
          if (_selectedOption != null && _selectedOption! < _options.length) {
            final current =
                (_options[_selectedOption!]['votes_count'] as int?) ??
                    (_options[_selectedOption!]['votes'] as int?) ??
                    0;
            _options[_selectedOption!]['votes_count'] = current;
          }
          if (serverTotalVotes != null) {
            _totalVotes = serverTotalVotes;
          }
        });
        widget.onVoted?.call();
        return;
      }

      setState(() {
        _selectedOption = previousSelectedOption;
        _hasVoted = previousHasVoted;
        _totalVotes = previousTotalVotes;
        _options = previousOptions;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedOption = previousSelectedOption;
        _hasVoted = previousHasVoted;
        _totalVotes = previousTotalVotes;
        _options = previousOptions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    if (_options.isEmpty) {
      // Fallback para pollData inline
      final pollData = widget.post.pollData;
      if (pollData == null) return const SizedBox.shrink();
      final opts = (pollData['options'] as List<dynamic>?) ?? [];
      if (opts.isEmpty) return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(
          color: context.nexusTheme.accentSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.poll_rounded,
                  size: r.s(18), color: context.nexusTheme.accentSecondary),
              SizedBox(width: r.s(8)),
              Text(
                s.poll,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(14),
                  color: context.nexusTheme.accentSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '$_totalVotes votos',
                style: TextStyle(
                  fontSize: r.fs(12),
                  color: context.nexusTheme.textHint,
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(14)),

          // Opções
          ...List.generate(_options.length, (i) {
            final opt = _options[i];
            final text = (opt['text'] as String?) ??
                (opt['option_text'] as String?) ??
                s.optionNumber(i + 1);
            final votes =
                (opt['votes_count'] as int?) ?? (opt['votes'] as int?) ?? 0;
            final pct = _totalVotes > 0 ? votes / _totalVotes : 0.0;
            final isSelected = _selectedOption == i;

            return GestureDetector(
              onTap: () => _vote(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(bottom: r.s(8)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  border: Border.all(
                    color:
                        isSelected ? context.nexusTheme.accentSecondary : context.dividerClr,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r.s(10)),
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
                                    ? context.nexusTheme.accentSecondary
                                        .withValues(alpha: 0.15)
                                    : context.nexusTheme.textHint.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                        ),
                      // Conteúdo
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(14), vertical: r.s(12)),
                        child: Row(
                          children: [
                            if (!_hasVoted)
                              Container(
                                width: r.s(20),
                                height: r.s(20),
                                margin: EdgeInsets.only(right: r.s(10)),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.nexusTheme.textHint,
                                    width: 1.5,
                                  ),
                                ),
                              )
                            else if (isSelected)
                              Container(
                                width: r.s(20),
                                height: r.s(20),
                                margin: EdgeInsets.only(right: r.s(10)),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.nexusTheme.accentSecondary,
                                ),
                                child: Icon(Icons.check_rounded,
                                    size: r.s(14), color: Colors.white),
                              )
                            else
                              SizedBox(width: r.s(30)),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: r.fs(14),
                                  color: context.nexusTheme.textPrimary,
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
                                  fontSize: r.fs(13),
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? context.nexusTheme.accentSecondary
                                      : context.nexusTheme.textSecondary,
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
class QuizDetailWidget extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onCompleted;

  const QuizDetailWidget({super.key, required this.post, this.onCompleted});

  @override
  ConsumerState<QuizDetailWidget> createState() => _QuizDetailWidgetState();
}

class _QuizDetailWidgetState extends ConsumerState<QuizDetailWidget> {
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

      if (mounted && (questions as List?)?.isNotEmpty == true) {
        setState(() {
          _questions = questions
              .map((q) => Map<String, dynamic>.from(q as Map))
              .toList();
        });
        return;
      }
    } catch (e) {
      debugPrint('[poll_quiz_widget] Erro: $e');
    }

    // Fallback para quizData inline
    final quizData = widget.post.quizData;
    if (quizData != null && mounted) {
      final qs = (quizData['questions'] as List<dynamic>?) ?? [];
      setState(() {
        _questions =
            qs.map((q) => Map<String, dynamic>.from(q as Map)).toList();
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
      await SupabaseService.rpc('answer_quiz', params: {
        'p_post_id': widget.post.id,
        'p_score': _score,
        'p_total': _questions.length,
      });
    } catch (e) {
      debugPrint('[poll_quiz_widget] Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (_questions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(
          color: context.nexusTheme.accentSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: _completed ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildResult() {
    final r = context.r;
    final pct = _questions.isNotEmpty ? _score / _questions.length : 0.0;
    final emoji = pct >= 0.8
        ? '🎉'
        : pct >= 0.5
            ? '👍'
            : '📚';

    return Column(
      children: [
        Text(emoji, style: TextStyle(fontSize: r.fs(48))),
        SizedBox(height: r.s(12)),
        Text(
          'Resultado: $_score/${_questions.length}',
          style: TextStyle(
            fontSize: r.fs(22),
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
        SizedBox(height: r.s(8)),
        Text(
          '${(pct * 100).toStringAsFixed(0)}% de acerto',
          style: TextStyle(
            fontSize: r.fs(14),
            color: context.nexusTheme.textSecondary,
          ),
        ),
        SizedBox(height: r.s(16)),
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
              backgroundColor: context.nexusTheme.accentSecondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
              ),
              padding: EdgeInsets.symmetric(vertical: r.s(12)),
            ),
            child: const Text('Tentar Novamente',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final s = ref.read(stringsProvider);
    final r = context.r;
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
            Icon(Icons.quiz_rounded,
                size: r.s(18), color: context.nexusTheme.accentSecondary),
            SizedBox(width: r.s(8)),
            Text(
              'Quiz — Pergunta ${_currentQuestion + 1}/${_questions.length}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: r.fs(13),
                color: context.nexusTheme.accentSecondary,
              ),
            ),
          ],
        ),

        // Progress bar
        SizedBox(height: r.s(10)),
        ClipRRect(
          borderRadius: BorderRadius.circular(r.s(4)),
          child: LinearProgressIndicator(
            value: (_currentQuestion + 1) / _questions.length,
            backgroundColor: context.dividerClr,
            valueColor:
                AlwaysStoppedAnimation<Color>(context.nexusTheme.accentSecondary),
            minHeight: 4,
          ),
        ),

        SizedBox(height: r.s(16)),

        // Pergunta
        Text(
          questionText,
          style: TextStyle(
            fontSize: r.fs(16),
            fontWeight: FontWeight.w700,
            color: context.nexusTheme.textPrimary,
            height: 1.4,
          ),
        ),

        SizedBox(height: r.s(14)),

        // Opções
        ...List.generate(options.length, (i) {
          final opt = options[i];
          final optText = opt is Map
              ? ((opt['option_text'] as String?) ??
                  (opt['text'] as String?) ??
                  s.optionNumber(i + 1))
              : opt.toString();
          final isCorrect = i == correctIndex;
          final isSelected = _selectedOption == i;

          Color bgColor = context.nexusTheme.backgroundPrimary;
          Color borderColor = context.dividerClr;
          IconData? trailingIcon;
          Color? trailingColor;

          if (_answered) {
            if (isCorrect) {
              bgColor = context.nexusTheme.success.withValues(alpha: 0.12);
              borderColor = context.nexusTheme.success;
              trailingIcon = Icons.check_circle_rounded;
              trailingColor = context.nexusTheme.success;
            } else if (isSelected && !isCorrect) {
              bgColor = context.nexusTheme.error.withValues(alpha: 0.12);
              borderColor = context.nexusTheme.error;
              trailingIcon = Icons.cancel_rounded;
              trailingColor = context.nexusTheme.error;
            }
          }

          return GestureDetector(
            onTap: () => _answer(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(bottom: r.s(8)),
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(
                    color: borderColor, width: isSelected ? 1.5 : 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: r.s(24),
                    height: r.s(24),
                    margin: EdgeInsets.only(right: r.s(12)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? (isCorrect
                              ? context.nexusTheme.success
                              : context.nexusTheme.error)
                          : Colors.transparent,
                      border: Border.all(
                        color:
                            isSelected ? Colors.transparent : context.nexusTheme.textHint,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isSelected && _answered
                          ? Icon(
                              trailingIcon ?? Icons.circle,
                              size: r.s(14),
                              color: Colors.white,
                            )
                          : Text(
                              String.fromCharCode(65 + i), // A, B, C, D
                              style: TextStyle(
                                fontSize: r.fs(12),
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : context.nexusTheme.textHint,
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      optText,
                      style: TextStyle(
                        fontSize: r.fs(14),
                        color: context.nexusTheme.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (_answered && trailingIcon != null)
                    Icon(trailingIcon, size: r.s(20), color: trailingColor),
                ],
              ),
            ),
          );
        }),

        // Explicação
        if (_answered && q['explanation'] != null)
          Padding(
            padding: EdgeInsets.only(top: r.s(8)),
            child: Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: r.s(16), color: context.nexusTheme.accentSecondary),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      q['explanation'] as String? ?? '',
                      style: TextStyle(
                        fontSize: r.fs(12),
                        color: context.nexusTheme.textSecondary,
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
