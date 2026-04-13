// Fragmento de código para corrigir _answerQuiz em post_card.dart
// Este arquivo contém a implementação corrigida que deve substituir a função _answerQuiz

// ============================================================================
// FUNÇÃO CORRIGIDA: _answerQuiz
// ============================================================================
// Antes: Apenas atualizava UI local
// Depois: Persiste resposta no backend via RPC

Future<void> _answerQuiz(int optionIndex) async {
  if (_quizAnswered) return;
  if (optionIndex >= _post.quizData?['questions']?[0]?['options']?.length ?? 0) return;

  final s = ref.read(stringsProvider);
  
  try {
    // Obter dados necessários
    final quizData = _post.quizData;
    if (quizData == null) return;
    
    final questions = (quizData['questions'] as List<dynamic>?) ?? [];
    if (questions.isEmpty) return;
    
    final firstQuestion = questions[0] as Map<String, dynamic>;
    final questionId = firstQuestion['id'] as String?;
    
    if (questionId == null) {
      // Se não tiver ID, apenas atualizar UI
      setState(() {
        _selectedQuizOption = optionIndex;
        _quizAnswered = true;
      });
      return;
    }

    // Obter opção selecionada
    final options = (firstQuestion['options'] as List<dynamic>?) ?? [];
    if (optionIndex >= options.length) return;
    
    final selectedOption = options[optionIndex] as Map<String, dynamic>?;
    if (selectedOption == null) return;
    
    final optionId = selectedOption['id'] as String?;
    if (optionId == null) return;

    // Atualizar UI otimisticamente
    setState(() {
      _selectedQuizOption = optionIndex;
      _quizAnswered = true;
    });

    // Chamar RPC para persistir resposta
    try {
      final result = await SupabaseService.rpc(
        'answer_quiz',
        params: {
          'p_post_id': _post.id,
          'p_question_id': questionId,
          'p_option_id': optionId,
        },
      );

      if (result is Map<String, dynamic>) {
        final success = result['success'] == true;
        if (!success) {
          // Se falhar, reverter UI
          if (mounted) {
            setState(() {
              _selectedQuizOption = null;
              _quizAnswered = false;
            });
            
            final error = result['error'] as String?;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error ?? s.errorTryAgain),
                backgroundColor: context.nexusTheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Em caso de erro, manter UI atualizada mas mostrar erro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
    // Fallback: apenas atualizar UI
    setState(() {
      _selectedQuizOption = optionIndex;
      _quizAnswered = true;
    });
  }
}

// ============================================================================
// FUNÇÃO AUXILIAR: _loadQuizAttempt
// ============================================================================
// Carrega tentativa anterior do usuário se existir

Future<void> _loadQuizAttempt() async {
  try {
    final result = await SupabaseService.rpc(
      'get_quiz_attempt',
      params: {
        'p_post_id': _post.id,
      },
    );

    if (result is Map<String, dynamic>) {
      final attemptId = result['attempt_id'] as String?;
      final answeredQuestions = result['answered_questions'] as List?;
      
      if (attemptId != null && answeredQuestions != null && answeredQuestions.isNotEmpty) {
        // Usuário já respondeu
        if (mounted) {
          setState(() {
            _quizAnswered = true;
            
            // Encontrar qual opção foi selecionada
            final quizData = _post.quizData;
            if (quizData != null) {
              final questions = (quizData['questions'] as List<dynamic>?) ?? [];
              if (questions.isNotEmpty) {
                final firstQuestion = questions[0] as Map<String, dynamic>;
                final options = (firstQuestion['options'] as List<dynamic>?) ?? [];
                
                // Procurar a opção selecionada
                final firstAnswer = answeredQuestions[0] as Map<String, dynamic>?;
                if (firstAnswer != null) {
                  final selectedOptionId = firstAnswer['selected_option_id'] as String?;
                  
                  for (int i = 0; i < options.length; i++) {
                    final opt = options[i] as Map<String, dynamic>;
                    if (opt['id'] == selectedOptionId) {
                      _selectedQuizOption = i;
                      break;
                    }
                  }
                }
              }
            }
          });
        }
      }
    }
  } catch (e) {
    // Ignorar erro ao carregar tentativa anterior
  }
}

// ============================================================================
// INTEGRAÇÃO NO initState
// ============================================================================
// Adicionar no initState do PostCard:

@override
void initState() {
  super.initState();
  // ... código existente ...
  
  // Carregar tentativa anterior de quiz se existir
  if (_post.type == 'quiz') {
    Future.microtask(_loadQuizAttempt);
  }
}
