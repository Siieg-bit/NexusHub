-- ============================================================================
-- Migration 108: Criar RPCs faltando e correções adicionais
-- ============================================================================

-- ========================
-- 1. create_poll_post — RPC chamada pelo quick_poll_voter.dart
-- Cria um post do tipo 'poll' com opções de enquete atomicamente
-- ========================
CREATE OR REPLACE FUNCTION public.create_poll_post(
  p_community_id UUID,
  p_question     TEXT,
  p_options      JSONB  -- array de strings: ["Opção 1", "Opção 2", ...]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_post_id  UUID;
  v_option   TEXT;
  v_idx      INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Validar que o usuário é membro da comunidade
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Você não é membro desta comunidade';
  END IF;

  -- Validar opções (mínimo 2)
  IF jsonb_array_length(p_options) < 2 THEN
    RAISE EXCEPTION 'A enquete precisa de pelo menos 2 opções';
  END IF;

  -- Criar o post
  INSERT INTO public.posts (
    community_id,
    author_id,
    type,
    title,
    content,
    poll_data
  ) VALUES (
    p_community_id,
    v_user_id,
    'poll'::post_type,
    p_question,
    p_question,
    jsonb_build_object('question', p_question, 'options_count', jsonb_array_length(p_options))
  )
  RETURNING id INTO v_post_id;

  -- Criar as opções da enquete
  FOR v_idx IN 0..jsonb_array_length(p_options) - 1 LOOP
    v_option := p_options->>v_idx;
    INSERT INTO public.poll_options (post_id, text, sort_order, votes_count)
    VALUES (v_post_id, v_option, v_idx, 0);
  END LOOP;

  -- Adicionar reputação ao autor
  PERFORM public.add_reputation(v_user_id, p_community_id, 'post_created', 5);

  RETURN v_post_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_poll_post(UUID, TEXT, JSONB) TO authenticated;

-- ========================
-- 2. get_server_time — RPC chamada pelo community_shared_providers.dart
-- Retorna o horário atual do servidor (UTC)
-- ========================
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOW();
$$;

GRANT EXECUTE ON FUNCTION public.get_server_time() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_server_time() TO anon;
