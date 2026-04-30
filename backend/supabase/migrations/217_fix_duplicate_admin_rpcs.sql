-- ============================================================
-- Migration 217: Corrigir funções admin duplicadas e enum
-- content_status na admin_get_platform_stats
-- ============================================================

-- ─── Dropar todas as versões duplicadas ──────────────────────
DROP FUNCTION IF EXISTS admin_get_coin_transactions(int, int, text) CASCADE;
DROP FUNCTION IF EXISTS admin_get_coin_transactions(int, int, text, text) CASCADE;
DROP FUNCTION IF EXISTS admin_get_moderation_logs(int, int) CASCADE;
DROP FUNCTION IF EXISTS admin_get_moderation_logs(int, int, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS admin_search_users(text) CASCADE;
DROP FUNCTION IF EXISTS admin_search_users(text, int) CASCADE;
DROP FUNCTION IF EXISTS admin_get_platform_stats() CASCADE;

-- ─── admin_get_platform_stats (corrigido: enum content_status) ─
CREATE OR REPLACE FUNCTION admin_get_platform_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  SELECT json_build_object(
    'total_users',        (SELECT COUNT(*) FROM profiles),
    'active_today',       (SELECT COUNT(*) FROM profiles WHERE last_seen_at > NOW() - INTERVAL '24 hours'),
    'active_week',        (SELECT COUNT(*) FROM profiles WHERE last_seen_at > NOW() - INTERVAL '7 days'),
    'premium_users',      (SELECT COUNT(*) FROM profiles WHERE is_premium = true),
    'total_communities',  (SELECT COUNT(*) FROM communities),
    'active_communities', (SELECT COUNT(*) FROM communities WHERE status = 'ok'),
    'total_posts',        (SELECT COUNT(*) FROM posts),
    'total_coins_in_circulation', (SELECT COALESCE(SUM(coins), 0) FROM profiles),
    'team_members',       (SELECT COUNT(*) FROM profiles WHERE team_rank > 0),
    'total_bans',         (SELECT COUNT(*) FROM bans WHERE is_active = true),
    'total_transactions', (SELECT COUNT(*) FROM coin_transactions)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ─── admin_search_users (versão única com p_limit opcional) ──
CREATE FUNCTION admin_search_users(
  p_query text,
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  id uuid,
  nickname text,
  amino_id text,
  icon_url text,
  team_role text,
  team_rank int,
  is_team_admin boolean,
  is_team_moderator boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.nickname,
    p.amino_id,
    p.icon_url::text,
    p.team_role::text,
    p.team_rank,
    p.is_team_admin,
    p.is_team_moderator,
    p.created_at
  FROM profiles p
  WHERE
    (p_query IS NOT NULL AND p_query != '' AND (
      p.amino_id ILIKE '%' || p_query || '%'
      OR p.nickname ILIKE '%' || p_query || '%'
    ))
  ORDER BY p.team_rank DESC NULLS LAST, p.nickname
  LIMIT p_limit;
END;
$$;

-- ─── admin_get_moderation_logs (versão única) ────────────────
CREATE FUNCTION admin_get_moderation_logs(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_action text DEFAULT NULL,
  p_community_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  community_id uuid,
  community_name text,
  moderator_id uuid,
  moderator_nickname text,
  moderator_amino_id text,
  target_user_id uuid,
  target_nickname text,
  target_amino_id text,
  action text,
  severity text,
  reason text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;
  RETURN QUERY
  SELECT
    ml.id,
    ml.community_id,
    c.name AS community_name,
    ml.moderator_id,
    mod.nickname AS moderator_nickname,
    mod.amino_id AS moderator_amino_id,
    ml.target_user_id,
    tgt.nickname AS target_nickname,
    tgt.amino_id AS target_amino_id,
    ml.action::text,
    ml.severity::text,
    ml.reason,
    ml.created_at
  FROM moderation_logs ml
  LEFT JOIN communities c ON c.id = ml.community_id
  LEFT JOIN profiles mod ON mod.id = ml.moderator_id
  LEFT JOIN profiles tgt ON tgt.id = ml.target_user_id
  WHERE
    (p_action IS NULL OR ml.action::text = p_action)
    AND (p_community_id IS NULL OR ml.community_id = p_community_id)
  ORDER BY ml.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ─── admin_get_coin_transactions (versão única) ──────────────
CREATE FUNCTION admin_get_coin_transactions(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_source text DEFAULT NULL,
  p_user_search text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  user_nickname text,
  user_amino_id text,
  user_icon_url text,
  amount int,
  balance_after int,
  source text,
  description text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;
  RETURN QUERY
  SELECT
    ct.id,
    ct.user_id,
    p.nickname AS user_nickname,
    p.amino_id AS user_amino_id,
    p.icon_url AS user_icon_url,
    ct.amount,
    ct.balance_after,
    ct.source::text,
    ct.description,
    ct.created_at
  FROM coin_transactions ct
  LEFT JOIN profiles p ON p.id = ct.user_id
  WHERE
    (p_source IS NULL OR ct.source::text = p_source)
    AND (p_user_search IS NULL OR p.nickname ILIKE '%' || p_user_search || '%' OR p.amino_id ILIKE '%' || p_user_search || '%')
  ORDER BY ct.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;
