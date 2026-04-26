-- Migration 164: Rankings Expandidos
-- Adiciona RPCs para ranking de posts curtidos, comentaristas e doadores de coins.

-- 1. Ranking: Usuários com mais posts curtidos na comunidade
CREATE OR REPLACE FUNCTION public.get_top_liked_authors(
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

-- 2. Ranking: Usuários com mais comentários na comunidade
CREATE OR REPLACE FUNCTION public.get_top_commenters(
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
  JOIN public.posts p ON p.id = c.post_id
  WHERE p.community_id = p_community_id
    AND c.status = 'ok'
  GROUP BY c.author_id, pr.nickname, pr.icon_url, pr.amino_id, pr.is_nickname_verified
  ORDER BY comment_count DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_top_commenters(UUID, INT) TO authenticated;

-- 3. Ranking: Usuários que mais doaram coins (tips) na comunidade
CREATE OR REPLACE FUNCTION public.get_top_tippers(
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
    t.from_user_id                               AS user_id,
    pr.nickname,
    pr.icon_url,
    pr.amino_id,
    pr.is_nickname_verified                      AS is_verified,
    COALESCE(SUM(t.amount), 0)                   AS total_tips
  FROM public.coin_transactions t
  JOIN public.profiles pr ON pr.id = t.from_user_id
  WHERE t.community_id = p_community_id
    AND t.type = 'tip'
  GROUP BY t.from_user_id, pr.nickname, pr.icon_url, pr.amino_id, pr.is_nickname_verified
  ORDER BY total_tips DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_top_tippers(UUID, INT) TO authenticated;
