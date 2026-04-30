-- ============================================================
-- Migration 214: RPCs admin faltantes para o bubble-admin
-- ============================================================

-- ─── Verificação de team member ───────────────────────────────────────────────
-- (já existe em 213, mas garantimos aqui)
CREATE OR REPLACE FUNCTION is_team_member()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (SELECT is_team_admin OR is_team_moderator FROM profiles WHERE id = auth.uid()),
    false
  );
$$;

-- ─── admin_get_active_bans ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_active_bans(
  p_limit int DEFAULT 100,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  community_id uuid,
  reason text,
  is_permanent boolean,
  is_active boolean,
  created_at timestamptz,
  device_id text,
  nickname text,
  amino_id text,
  avatar_url text,
  community_name text,
  banned_by_nickname text
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.user_id,
    b.community_id,
    b.reason,
    b.is_permanent,
    b.is_active,
    b.created_at,
    b.device_id,
    p.nickname,
    p.amino_id,
    p.avatar_url::text,
    c.name AS community_name,
    pb.nickname AS banned_by_nickname
  FROM bans b
  LEFT JOIN profiles p ON p.id = b.user_id
  LEFT JOIN communities c ON c.id = b.community_id
  LEFT JOIN profiles pb ON pb.id = b.banned_by
  WHERE b.is_active = true
  ORDER BY b.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ─── admin_get_team_members ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_team_members()
RETURNS TABLE (
  id uuid,
  nickname text,
  amino_id text,
  avatar_url text,
  team_role text,
  team_rank int,
  is_team_admin boolean,
  is_team_moderator boolean,
  created_at timestamptz,
  last_seen_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.nickname,
    p.amino_id,
    p.avatar_url::text,
    p.team_role::text,
    p.team_rank,
    p.is_team_admin,
    p.is_team_moderator,
    p.created_at,
    p.last_seen_at
  FROM profiles p
  WHERE p.is_team_admin = true OR p.is_team_moderator = true OR p.team_role IS NOT NULL
  ORDER BY p.team_rank DESC NULLS LAST, p.nickname;
END;
$$;

-- ─── admin_set_team_role ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_set_team_role(
  p_target_user_id uuid,
  p_role text  -- null para remover cargo
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_rank int;
  v_target_rank int;
  v_new_rank int;
BEGIN
  -- Verificar se o caller é team member
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- Obter rank do caller
  SELECT team_rank INTO v_caller_rank FROM profiles WHERE id = auth.uid();
  v_caller_rank := COALESCE(v_caller_rank, 0);

  -- Obter rank atual do alvo
  SELECT team_rank INTO v_target_rank FROM profiles WHERE id = p_target_user_id;
  v_target_rank := COALESCE(v_target_rank, 0);

  -- Não pode modificar alguém de rank igual ou superior
  IF v_target_rank >= v_caller_rank THEN
    RAISE EXCEPTION 'Você não pode modificar o cargo de alguém com rank igual ou superior ao seu';
  END IF;

  -- Calcular novo rank baseado no role
  v_new_rank := CASE p_role
    WHEN 'founder'            THEN 100
    WHEN 'co_founder'         THEN 90
    WHEN 'team_admin'         THEN 80
    WHEN 'trust_and_safety'   THEN 75
    WHEN 'team_mod'           THEN 70
    WHEN 'support'            THEN 65
    WHEN 'community_manager'  THEN 60
    WHEN 'bug_bounty'         THEN 50
    ELSE 0
  END;

  -- Não pode atribuir rank igual ou superior ao seu
  IF v_new_rank >= v_caller_rank THEN
    RAISE EXCEPTION 'Você não pode atribuir um cargo de rank igual ou superior ao seu';
  END IF;

  UPDATE profiles SET
    team_role = p_role::team_role,
    team_rank = v_new_rank,
    is_team_admin = (v_new_rank >= 80),
    is_team_moderator = (v_new_rank >= 70)
  WHERE id = p_target_user_id;
END;
$$;

-- ─── admin_search_users ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_search_users(p_query text, p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  nickname text,
  amino_id text,
  avatar_url text,
  team_role text,
  team_rank int,
  is_team_admin boolean,
  is_team_moderator boolean,
  is_banned boolean,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.nickname,
    p.amino_id,
    p.avatar_url::text,
    p.team_role::text,
    p.team_rank,
    p.is_team_admin,
    p.is_team_moderator,
    p.is_banned,
    p.created_at
  FROM profiles p
  WHERE
    p.amino_id ILIKE '%' || p_query || '%'
    OR p.nickname ILIKE '%' || p_query || '%'
  ORDER BY
    CASE WHEN p.amino_id ILIKE p_query || '%' THEN 0 ELSE 1 END,
    p.nickname
  LIMIT p_limit;
END;
$$;

-- ─── admin_get_platform_stats ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_platform_stats()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER AS $$
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
    'new_today',          (SELECT COUNT(*) FROM profiles WHERE created_at > NOW() - INTERVAL '24 hours'),
    'new_week',           (SELECT COUNT(*) FROM profiles WHERE created_at > NOW() - INTERVAL '7 days'),
    'total_communities',  (SELECT COUNT(*) FROM communities),
    'active_communities', (SELECT COUNT(*) FROM communities WHERE is_active = true),
    'total_posts',        (SELECT COUNT(*) FROM posts WHERE deleted_at IS NULL),
    'posts_today',        (SELECT COUNT(*) FROM posts WHERE created_at > NOW() - INTERVAL '24 hours' AND deleted_at IS NULL),
    'total_bans',         (SELECT COUNT(*) FROM bans WHERE is_active = true),
    'team_members',       (SELECT COUNT(*) FROM profiles WHERE is_team_admin = true OR is_team_moderator = true),
    'total_coins',        (SELECT COALESCE(SUM(coin_balance), 0) FROM profiles),
    'total_transactions', (SELECT COUNT(*) FROM coin_transactions)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ─── admin_get_moderation_overview ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_moderation_overview()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result json;
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  SELECT json_build_object(
    'active_bans',          (SELECT COUNT(*) FROM bans WHERE is_active = true),
    'permanent_bans',       (SELECT COUNT(*) FROM bans WHERE is_active = true AND is_permanent = true),
    'community_bans',       (SELECT COUNT(*) FROM bans WHERE is_active = true AND community_id IS NOT NULL),
    'global_bans',          (SELECT COUNT(*) FROM bans WHERE is_active = true AND community_id IS NULL),
    'bans_today',           (SELECT COUNT(*) FROM bans WHERE created_at > NOW() - INTERVAL '24 hours'),
    'bans_week',            (SELECT COUNT(*) FROM bans WHERE created_at > NOW() - INTERVAL '7 days'),
    'moderation_logs_week', (SELECT COUNT(*) FROM moderation_logs WHERE created_at > NOW() - INTERVAL '7 days'),
    'banned_devices',       (SELECT COUNT(DISTINCT device_id) FROM device_fingerprints WHERE is_banned = true)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ─── Grants ───────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION admin_get_active_bans(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_team_members() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_set_team_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_search_users(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_platform_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_moderation_overview() TO authenticated;
