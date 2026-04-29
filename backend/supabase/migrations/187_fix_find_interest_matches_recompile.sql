-- 187_fix_find_interest_matches_recompile.sql
-- A função find_interest_matches foi compilada antes das colunas status_emoji
-- e status_text existirem na tabela profiles. O plano de execução em cache
-- do PostgreSQL ficou inválido, causando o erro:
--   "column p.status_emoji does not exist" (code: 42703)
-- mesmo com as colunas já existindo.
-- Solução: DROP + CREATE para forçar recompilação completa.

DROP FUNCTION IF EXISTS public.find_interest_matches(INT);

CREATE FUNCTION public.find_interest_matches(p_limit INT DEFAULT 10)
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
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
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
    AND (
      SELECT COUNT(*)
      FROM (
        SELECT unnest(v_my_interests)
        INTERSECT
        SELECT jsonb_array_elements_text(p.selected_interests)
      ) t
    ) > 0
  ORDER BY score DESC, p.created_at DESC
  LIMIT p_limit;
END;
$$;

-- Permissão de execução para usuários autenticados
GRANT EXECUTE ON FUNCTION public.find_interest_matches(INT) TO authenticated;

-- Recarregar schema cache do PostgREST
NOTIFY pgrst, 'reload schema';
