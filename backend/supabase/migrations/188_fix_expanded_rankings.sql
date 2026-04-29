-- 188_fix_expanded_rankings.sql
-- A migration 166 nunca foi aplicada em produção.
-- Além disso, o get_top_tippers usava coin_transactions com colunas inexistentes
-- (from_user_id, community_id, type). A tabela real é 'tips' com sender_id e post_id.
-- Esta migration aplica os 3 RPCs corrigidos para o schema real do banco.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Ranking: Usuários com mais curtidas em posts da comunidade
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_top_liked_authors(UUID, INT);

CREATE FUNCTION public.get_top_liked_authors(
  p_community_id UUID,
  p_limit        INT DEFAULT 50
)
RETURNS TABLE (
  user_id        UUID,
  nickname       TEXT,
  icon_url       TEXT,
  amino_id       TEXT,
  is_verified    BOOLEAN,
  total_likes    BIGINT,
  post_count     BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.author_id                                  AS user_id,
    pr.nickname,
    pr.icon_url,
    pr.amino_id,
    pr.is_nickname_verified                      AS is_verified,
    COALESCE(SUM(p.likes_count), 0)              AS total_likes,
    COUNT(p.id)                                  AS post_count
  FROM public.posts p
  JOIN public.profiles pr ON pr.id = p.author_id
  WHERE p.community_id = p_community_id
    AND p.status = 'ok'
  GROUP BY p.author_id, pr.nickname, pr.icon_url, pr.amino_id, pr.is_nickname_verified
  ORDER BY total_likes DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_top_liked_authors(UUID, INT) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Ranking: Usuários com mais comentários na comunidade
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_top_commenters(UUID, INT);

CREATE FUNCTION public.get_top_commenters(
  p_community_id UUID,
  p_limit        INT DEFAULT 50
)
RETURNS TABLE (
  user_id         UUID,
  nickname        TEXT,
  icon_url        TEXT,
  amino_id        TEXT,
  is_verified     BOOLEAN,
  comment_count   BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.author_id                                  AS user_id,
    pr.nickname,
    pr.icon_url,
    pr.amino_id,
    pr.is_nickname_verified                      AS is_verified,
    COUNT(c.id)                                  AS comment_count
  FROM public.comments c
  JOIN public.profiles pr ON pr.id = c.author_id
  WHERE c.community_id = p_community_id
    AND c.status = 'ok'
  GROUP BY c.author_id, pr.nickname, pr.icon_url, pr.amino_id, pr.is_nickname_verified
  ORDER BY comment_count DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_top_commenters(UUID, INT) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Ranking: Usuários que mais doaram coins (tips) na comunidade
-- A tabela 'tips' não tem community_id direta — filtramos via posts.community_id
-- para tips de posts, e incluímos tips de chat (sem filtro de comunidade específica,
-- usando post_id IS NULL como fallback para tips diretas).
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_top_tippers(UUID, INT);

CREATE FUNCTION public.get_top_tippers(
  p_community_id UUID,
  p_limit        INT DEFAULT 50
)
RETURNS TABLE (
  user_id       UUID,
  nickname      TEXT,
  icon_url      TEXT,
  amino_id      TEXT,
  is_verified   BOOLEAN,
  total_tips    BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    t.sender_id                                  AS user_id,
    pr.nickname,
    pr.icon_url,
    pr.amino_id,
    pr.is_nickname_verified                      AS is_verified,
    COALESCE(SUM(t.amount), 0)                   AS total_tips
  FROM public.tips t
  JOIN public.profiles pr ON pr.id = t.sender_id
  -- Filtra tips de posts que pertencem à comunidade
  LEFT JOIN public.posts p ON p.id = t.post_id
  WHERE (
    -- Tip em post da comunidade
    (t.post_id IS NOT NULL AND p.community_id = p_community_id)
    OR
    -- Tip de chat (sem post associado) — incluir se o sender for membro da comunidade
    (t.post_id IS NULL AND EXISTS (
      SELECT 1 FROM public.community_members cm
      WHERE cm.user_id = t.sender_id
        AND cm.community_id = p_community_id
        AND cm.is_banned = false
    ))
  )
  GROUP BY t.sender_id, pr.nickname, pr.icon_url, pr.amino_id, pr.is_nickname_verified
  ORDER BY total_tips DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_top_tippers(UUID, INT) TO authenticated;

-- Recarregar schema cache do PostgREST
NOTIFY pgrst, 'reload schema';
