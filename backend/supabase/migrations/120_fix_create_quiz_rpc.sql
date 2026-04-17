-- =============================================================================
-- MIGRATION 120 — Fix create_quiz_with_questions RPC
-- Corrige o erro: column "status" does not exist na tabela community_members.
-- A tabela community_members não possui coluna "status" — usa is_banned=false
-- para verificar se o membro está ativo.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_quiz_with_questions(
  p_community_id UUID,
  p_title TEXT,
  p_content TEXT DEFAULT '',
  p_media_urls JSONB DEFAULT '[]'::jsonb,
  p_questions JSONB DEFAULT '[]'::jsonb,
  p_allow_comments BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_post_id    UUID;
  v_question   JSONB;
  v_question_id UUID;
  v_option     JSONB;
  v_correct_idx INTEGER;
  i            INTEGER;
  j            INTEGER;
BEGIN
  -- Autenticação
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar membership na comunidade (community_members não tem coluna "status")
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = false
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_community_member');
  END IF;

  -- Criar o post do tipo quiz
  INSERT INTO public.posts (
    community_id, author_id, type, title, content,
    media_list, allow_comments
  )
  VALUES (
    p_community_id, v_user_id, 'quiz', p_title, p_content,
    p_media_urls, p_allow_comments
  )
  RETURNING id INTO v_post_id;

  -- Criar perguntas e opções
  FOR i IN 0 .. jsonb_array_length(p_questions) - 1
  LOOP
    v_question    := p_questions->i;
    v_correct_idx := COALESCE((v_question->>'correct_option_index')::int, 0);

    INSERT INTO public.quiz_questions (post_id, question_text, sort_order)
    VALUES (v_post_id, v_question->>'question_text', i)
    RETURNING id INTO v_question_id;

    -- Inserir opções da pergunta
    FOR j IN 0 .. jsonb_array_length(v_question->'options') - 1
    LOOP
      v_option := (v_question->'options')->j;
      INSERT INTO public.quiz_options (question_id, text, is_correct, sort_order)
      VALUES (
        v_question_id,
        v_option->>'text',
        j = v_correct_idx,
        j
      );
    END LOOP;
  END LOOP;

  -- Adicionar reputação
  PERFORM public.add_reputation(v_user_id, p_community_id, 'post_quiz', 5);

  RETURN jsonb_build_object(
    'success', true,
    'post_id', v_post_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_quiz_with_questions(UUID, TEXT, TEXT, JSONB, JSONB, BOOLEAN) TO authenticated;
