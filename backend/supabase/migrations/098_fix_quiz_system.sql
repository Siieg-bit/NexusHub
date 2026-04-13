-- NexusHub — Migração 098: Corrigir Sistema de Quiz
-- ===================================================
-- Objetivo: Adicionar suporte completo a respostas de quiz com persistência
-- Adiciona tabela quiz_answers e RPC answer_quiz

-- ========================
-- 1. CRIAR TABELA QUIZ_ANSWERS
-- ========================

CREATE TABLE IF NOT EXISTS public.quiz_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_attempt_id UUID NOT NULL REFERENCES public.quiz_attempts(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES public.quiz_questions(id) ON DELETE CASCADE,
  selected_option_id UUID NOT NULL REFERENCES public.quiz_options(id) ON DELETE CASCADE,
  is_correct BOOLEAN NOT NULL,
  answered_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Índices para performance
  UNIQUE(quiz_attempt_id, question_id)
);

CREATE INDEX idx_quiz_answers_attempt ON public.quiz_answers(quiz_attempt_id);
CREATE INDEX idx_quiz_answers_question ON public.quiz_answers(question_id);
CREATE INDEX idx_quiz_answers_option ON public.quiz_answers(selected_option_id);

-- ========================
-- 2. HABILITAR RLS
-- ========================

ALTER TABLE public.quiz_answers ENABLE ROW LEVEL SECURITY;

-- Qualquer um pode ver respostas de quiz público
CREATE POLICY "quiz_answers_select_public" ON public.quiz_answers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.quiz_attempts qa
      JOIN public.posts p ON qa.post_id = p.id
      WHERE qa.id = quiz_attempt_id
        AND p.visibility = 'public'
    )
  );

-- Usuário pode ver suas próprias respostas
CREATE POLICY "quiz_answers_select_own" ON public.quiz_answers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.quiz_attempts qa
      WHERE qa.id = quiz_attempt_id
        AND qa.user_id = auth.uid()
    )
  );

-- Usuário autenticado pode inserir suas próprias respostas
CREATE POLICY "quiz_answers_insert_own" ON public.quiz_answers
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.quiz_attempts qa
      WHERE qa.id = quiz_attempt_id
        AND qa.user_id = auth.uid()
    )
  );

-- ========================
-- 3. RPC ANSWER_QUIZ
-- ========================

CREATE OR REPLACE FUNCTION public.answer_quiz(
  p_post_id UUID,
  p_question_id UUID,
  p_option_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_attempt_id UUID;
  v_is_correct BOOLEAN;
  v_score INTEGER := 0;
  v_total_questions INTEGER := 0;
  v_attempt_score INTEGER := 0;
  v_result jsonb;
BEGIN
  -- Validar autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Validar que post existe e é quiz
  IF NOT EXISTS (
    SELECT 1 FROM public.posts
    WHERE id = p_post_id AND type = 'quiz'
  ) THEN
    RAISE EXCEPTION 'Post não encontrado ou não é um quiz';
  END IF;

  -- Validar que questão pertence ao quiz
  IF NOT EXISTS (
    SELECT 1 FROM public.quiz_questions
    WHERE id = p_question_id AND post_id = p_post_id
  ) THEN
    RAISE EXCEPTION 'Questão não encontrada neste quiz';
  END IF;

  -- Validar que opção pertence à questão
  IF NOT EXISTS (
    SELECT 1 FROM public.quiz_options
    WHERE id = p_option_id AND question_id = p_question_id
  ) THEN
    RAISE EXCEPTION 'Opção não encontrada nesta questão';
  END IF;

  -- Obter ou criar tentativa de quiz
  SELECT id INTO v_attempt_id FROM public.quiz_attempts
  WHERE post_id = p_post_id AND user_id = v_user_id
  LIMIT 1;

  IF v_attempt_id IS NULL THEN
    -- Contar total de questões
    SELECT COUNT(*) INTO v_total_questions
    FROM public.quiz_questions
    WHERE post_id = p_post_id;

    -- Criar nova tentativa
    INSERT INTO public.quiz_attempts (post_id, user_id, total_questions)
    VALUES (p_post_id, v_user_id, v_total_questions)
    RETURNING id INTO v_attempt_id;
  END IF;

  -- Verificar se usuário já respondeu esta questão
  IF EXISTS (
    SELECT 1 FROM public.quiz_answers
    WHERE quiz_attempt_id = v_attempt_id AND question_id = p_question_id
  ) THEN
    RAISE EXCEPTION 'Você já respondeu esta questão';
  END IF;

  -- Verificar se opção é correta
  SELECT is_correct INTO v_is_correct
  FROM public.quiz_options
  WHERE id = p_option_id;

  -- Inserir resposta
  INSERT INTO public.quiz_answers (
    quiz_attempt_id,
    question_id,
    selected_option_id,
    is_correct
  ) VALUES (
    v_attempt_id,
    p_question_id,
    p_option_id,
    v_is_correct
  );

  -- Calcular score da tentativa
  SELECT COUNT(*) INTO v_attempt_score
  FROM public.quiz_answers
  WHERE quiz_attempt_id = v_attempt_id AND is_correct = true;

  -- Atualizar tentativa com novo score
  UPDATE public.quiz_attempts
  SET score = v_attempt_score
  WHERE id = v_attempt_id;

  -- Retornar resultado
  v_result := jsonb_build_object(
    'success', true,
    'attempt_id', v_attempt_id,
    'is_correct', v_is_correct,
    'current_score', v_attempt_score,
    'total_questions', (
      SELECT total_questions FROM public.quiz_attempts WHERE id = v_attempt_id
    )
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.answer_quiz(UUID, UUID, UUID) TO authenticated;

-- ========================
-- 4. RPC GET_QUIZ_ATTEMPT
-- ========================

CREATE OR REPLACE FUNCTION public.get_quiz_attempt(
  p_post_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_attempt_id UUID;
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Obter tentativa do usuário
  SELECT id INTO v_attempt_id
  FROM public.quiz_attempts
  WHERE post_id = p_post_id AND user_id = v_user_id
  LIMIT 1;

  IF v_attempt_id IS NULL THEN
    RETURN jsonb_build_object(
      'attempt_id', NULL,
      'answered_questions', '[]'::jsonb,
      'score', 0,
      'total_questions', (
        SELECT COUNT(*) FROM public.quiz_questions WHERE post_id = p_post_id
      )
    );
  END IF;

  -- Retornar tentativa com respostas
  v_result := jsonb_build_object(
    'attempt_id', v_attempt_id,
    'answered_questions', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'question_id', qa.question_id,
          'selected_option_id', qa.selected_option_id,
          'is_correct', qa.is_correct
        )
      )
      FROM public.quiz_answers qa
      WHERE qa.quiz_attempt_id = v_attempt_id
    ),
    'score', (
      SELECT score FROM public.quiz_attempts WHERE id = v_attempt_id
    ),
    'total_questions', (
      SELECT total_questions FROM public.quiz_attempts WHERE id = v_attempt_id
    )
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_quiz_attempt(UUID) TO authenticated;

-- ========================
-- 5. ÍNDICES ADICIONAIS
-- ========================

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_post ON public.quiz_attempts(user_id, post_id);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_post ON public.quiz_questions(post_id);
CREATE INDEX IF NOT EXISTS idx_quiz_options_question ON public.quiz_options(question_id);

-- ========================
-- 6. COMENTÁRIOS
-- ========================

COMMENT ON TABLE public.quiz_answers IS 'Armazena respostas de usuários para questões de quiz';
COMMENT ON COLUMN public.quiz_answers.is_correct IS 'Indica se a resposta selecionada é a correta';
COMMENT ON FUNCTION public.answer_quiz(UUID, UUID, UUID) IS 'Registra resposta de usuário para questão de quiz';
COMMENT ON FUNCTION public.get_quiz_attempt(UUID) IS 'Obtém tentativa de quiz do usuário para um post específico';
