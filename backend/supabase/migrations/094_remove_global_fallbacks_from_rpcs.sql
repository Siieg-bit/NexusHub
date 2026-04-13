-- =============================================================================
-- Migration 094: Remover fallbacks para perfil global nas RPCs
--
-- Após a migration 093, todo membro tem local_nickname e local_icon_url
-- preenchidos desde o join. Não há mais necessidade de COALESCE com o global.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. get_community_leaderboard — remover COALESCE(local_nickname, p.nickname)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
  p_community_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  user_id    UUID,
  nickname   TEXT,
  icon_url   TEXT,
  level      INTEGER,
  reputation INTEGER,
  role       TEXT
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cm.user_id,
    cm.local_nickname                                          AS nickname,
    cm.local_icon_url                                         AS icon_url,
    COALESCE(cm.local_level, public.calculate_level(cm.local_reputation)) AS level,
    COALESCE(cm.local_reputation, 0)                          AS reputation,
    cm.role::text                                             AS role
  FROM public.community_members cm
  WHERE cm.community_id = p_community_id
    AND cm.is_banned = FALSE
  ORDER BY cm.local_reputation DESC NULLS LAST
  LIMIT p_limit;
END;
$$;
