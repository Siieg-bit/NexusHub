-- ============================================================================
-- Migration 227: fix_find_interest_matches_is_banned
--
-- Problema:
--   A função find_interest_matches referencia p.is_banned na tabela profiles,
--   mas essa coluna não existe em profiles — ela existe em chat_members e bans.
--   O banimento global de usuários é registrado na tabela public.bans.
--
-- Correção:
--   Substituir o filtro `p.is_banned = false` por uma subconsulta que verifica
--   se o usuário não possui um ban global ativo na tabela public.bans
--   (community_id IS NULL AND is_active = TRUE).
-- ============================================================================

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
    -- Não possui ban global ativo (profiles não tem coluna is_banned)
    AND NOT EXISTS (
      SELECT 1 FROM public.bans b
      WHERE b.user_id = p.id
        AND b.community_id IS NULL
        AND b.is_active = TRUE
        AND (b.expires_at IS NULL OR b.expires_at > NOW())
    )
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
