-- ============================================================================
-- Migration 226: fix_find_interest_matches
--
-- Problemas corrigidos:
--   1. find_interest_matches não filtrava usuários com quem já existe DM ativo
--   2. find_interest_matches não filtrava usuários bloqueados/que bloquearam
--   3. Adiciona get_or_create_dm_thread como alias de send_dm_invite para
--      compatibilidade retroativa (caso algum cliente antigo ainda use)
-- ============================================================================

-- ── 1. Corrigir find_interest_matches ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.find_interest_matches(p_limit INT DEFAULT 20)
RETURNS TABLE (
  user_id          UUID,
  nickname         TEXT,
  icon_url         TEXT,
  bio              TEXT,
  status_emoji     TEXT,
  status_text      TEXT,
  common_interests TEXT[],
  score            INT,
  is_following     BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_my_interests TEXT[];
BEGIN
  -- Buscar interesses do usuário atual
  SELECT ARRAY(
    SELECT jsonb_array_elements_text(selected_interests)
    FROM public.profiles WHERE id = v_user_id
  ) INTO v_my_interests;

  -- Se o usuário não tem interesses cadastrados, retornar vazio
  IF v_my_interests IS NULL OR array_length(v_my_interests, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    p.id                                       AS user_id,
    p.nickname,
    p.icon_url,
    p.bio,
    p.status_emoji,
    p.status_text,
    -- Interesses em comum
    ARRAY(
      SELECT unnest(v_my_interests)
      INTERSECT
      SELECT jsonb_array_elements_text(p.selected_interests)
    )                                          AS common_interests,
    -- Score = número de interesses em comum
    (
      SELECT COUNT(*)::INT
      FROM (
        SELECT unnest(v_my_interests)
        INTERSECT
        SELECT jsonb_array_elements_text(p.selected_interests)
      ) t
    )                                          AS score,
    -- Já segue?
    EXISTS(
      SELECT 1 FROM public.follows
      WHERE follower_id = v_user_id AND following_id = p.id
    )                                          AS is_following
  FROM public.profiles p
  WHERE
    p.id != v_user_id
    AND p.is_banned = false
    -- Pelo menos 1 interesse em comum
    AND (
      SELECT COUNT(*)
      FROM (
        SELECT unnest(v_my_interests)
        INTERSECT
        SELECT jsonb_array_elements_text(p.selected_interests)
      ) t
    ) > 0
    -- Não está bloqueado pelo usuário atual nem bloqueou
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = v_user_id AND b.blocked_id = p.id)
         OR (b.blocker_id = p.id      AND b.blocked_id = v_user_id)
    )
    -- Não tem DM ativo entre os dois (evitar sugerir quem já é contato)
    AND NOT EXISTS (
      SELECT 1
      FROM public.chat_threads ct
      JOIN public.chat_members cm1 ON cm1.thread_id = ct.id AND cm1.user_id = v_user_id
      JOIN public.chat_members cm2 ON cm2.thread_id = ct.id AND cm2.user_id = p.id
      WHERE ct.type = 'dm'
    )
  ORDER BY score DESC, p.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.find_interest_matches(INT) TO authenticated;

-- ── 2. Criar get_or_create_dm_thread como wrapper de send_dm_invite ──────────
-- Compatibilidade retroativa: retorna UUID direto (thread_id)
CREATE OR REPLACE FUNCTION public.get_or_create_dm_thread(p_other_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_thread_id UUID;
BEGIN
  SELECT public.send_dm_invite(p_other_user_id) INTO v_result;

  v_thread_id := (v_result->>'thread_id')::UUID;

  IF v_thread_id IS NULL THEN
    RAISE EXCEPTION 'Erro ao criar ou encontrar DM: %', v_result->>'error'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_thread_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_dm_thread(UUID) TO authenticated;
