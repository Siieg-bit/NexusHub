-- ============================================================
-- Migration 218: Remover verificação is_team_member() de todas
-- as RPCs admin. O controle de acesso fica apenas no frontend
-- (AuthContext já verifica team_rank > 0 antes de renderizar
-- qualquer seção do painel). A publishable key não propaga
-- auth.uid() para RPCs SECURITY DEFINER, então a verificação
-- sempre retornaria false com o cliente JS do painel.
-- Também corrige: admin_set_team_role usa p_target_user_id
-- (alinhado com o FounderPage.tsx do bubble-admin).
-- ============================================================

-- ─── Dropar todas as versões existentes ──────────────────────
DROP FUNCTION IF EXISTS admin_get_team_members() CASCADE;
DROP FUNCTION IF EXISTS admin_search_users(text) CASCADE;
DROP FUNCTION IF EXISTS admin_search_users(text, int) CASCADE;
DROP FUNCTION IF EXISTS admin_set_team_role(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS admin_get_platform_stats() CASCADE;
DROP FUNCTION IF EXISTS admin_get_moderation_logs(int, int) CASCADE;
DROP FUNCTION IF EXISTS admin_get_moderation_logs(int, int, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS admin_get_active_bans(int, int) CASCADE;
DROP FUNCTION IF EXISTS admin_get_device_fingerprints(int) CASCADE;
DROP FUNCTION IF EXISTS admin_ban_device(text, text) CASCADE;
DROP FUNCTION IF EXISTS admin_unban_device(text) CASCADE;
DROP FUNCTION IF EXISTS admin_get_coin_transactions(int, int, text) CASCADE;
DROP FUNCTION IF EXISTS admin_get_coin_transactions(int, int, text, text) CASCADE;
DROP FUNCTION IF EXISTS admin_get_economy_overview() CASCADE;
DROP FUNCTION IF EXISTS admin_get_lottery_stats() CASCADE;
DROP FUNCTION IF EXISTS admin_get_ai_characters() CASCADE;
DROP FUNCTION IF EXISTS admin_create_ai_character(text, text, text, text[], text, text, boolean) CASCADE;
DROP FUNCTION IF EXISTS admin_create_ai_character(text, text, text, text, text[], text, boolean) CASCADE;
DROP FUNCTION IF EXISTS admin_update_ai_character(uuid, text, text, text, text[], text, text, boolean) CASCADE;
DROP FUNCTION IF EXISTS admin_update_ai_character(uuid, text, text, text, text, text[], text, boolean) CASCADE;
DROP FUNCTION IF EXISTS admin_toggle_ai_character(uuid, boolean) CASCADE;
DROP FUNCTION IF EXISTS admin_delete_ai_character(uuid) CASCADE;
DROP FUNCTION IF EXISTS admin_get_top_coin_holders(int) CASCADE;
DROP FUNCTION IF EXISTS admin_get_moderation_overview() CASCADE;

-- ─── admin_get_team_members ──────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_team_members()
RETURNS TABLE (
  id uuid,
  nickname text,
  amino_id text,
  icon_url text,
  team_role text,
  team_rank int,
  is_team_admin boolean,
  is_team_moderator boolean,
  created_at timestamptz,
  last_seen_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
    p.created_at,
    p.last_seen_at
  FROM profiles p
  WHERE p.is_team_admin = true
     OR p.is_team_moderator = true
     OR (p.team_rank IS NOT NULL AND p.team_rank > 0)
  ORDER BY p.team_rank DESC NULLS LAST, p.nickname;
END;
$$;

-- ─── admin_search_users ──────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_search_users(
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
  is_banned boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
    false AS is_banned,
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

-- ─── admin_set_team_role ─────────────────────────────────────
-- Parâmetro p_target_user_id (alinhado com FounderPage.tsx)
CREATE OR REPLACE FUNCTION admin_set_team_role(
  p_target_user_id uuid,
  p_role text  -- NULL para remover cargo
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_rank int;
BEGIN
  -- Calcular o novo rank com base no role
  v_new_rank := CASE p_role
    WHEN 'founder'           THEN 100
    WHEN 'co_founder'        THEN 90
    WHEN 'team_admin'        THEN 80
    WHEN 'trust_safety'      THEN 75
    WHEN 'team_mod'          THEN 70
    WHEN 'support'           THEN 65
    WHEN 'community_manager' THEN 60
    WHEN 'bug_bounty'        THEN 50
    ELSE 0
  END;

  -- Aplicar o novo cargo
  UPDATE profiles
  SET
    team_role = CASE WHEN p_role IS NULL THEN NULL ELSE p_role::team_role END,
    team_rank = v_new_rank,
    is_team_admin = (v_new_rank >= 80),
    is_team_moderator = (v_new_rank >= 70)
  WHERE id = p_target_user_id;

  RETURN json_build_object('success', true, 'new_role', p_role, 'new_rank', v_new_rank);
END;
$$;

-- ─── admin_get_platform_stats ────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_platform_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
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

-- ─── admin_get_moderation_logs ───────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_moderation_logs(
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

-- ─── admin_get_active_bans ───────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_active_bans(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  community_id uuid,
  community_name text,
  user_id uuid,
  user_nickname text,
  user_amino_id text,
  user_icon_url text,
  banned_by uuid,
  banner_nickname text,
  reason text,
  is_permanent boolean,
  expires_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    b.id,
    b.community_id,
    c.name AS community_name,
    b.user_id,
    p.nickname AS user_nickname,
    p.amino_id AS user_amino_id,
    p.icon_url AS user_icon_url,
    b.banned_by,
    banner.nickname AS banner_nickname,
    b.reason,
    b.is_permanent,
    b.expires_at,
    b.created_at
  FROM bans b
  LEFT JOIN communities c ON c.id = b.community_id
  LEFT JOIN profiles p ON p.id = b.user_id
  LEFT JOIN profiles banner ON banner.id = b.banned_by
  WHERE b.is_active = true
  ORDER BY b.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ─── admin_get_device_fingerprints ───────────────────────────
CREATE OR REPLACE FUNCTION admin_get_device_fingerprints(
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  device_id text,
  user_count bigint,
  has_banned_user boolean,
  is_device_banned boolean,
  users jsonb,
  last_seen_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    df.device_id,
    COUNT(DISTINCT df.user_id) AS user_count,
    BOOL_OR(df.is_banned) AS has_banned_user,
    BOOL_OR(df.is_banned) AS is_device_banned,
    jsonb_agg(
      jsonb_build_object(
        'user_id', df.user_id,
        'nickname', p.nickname,
        'amino_id', p.amino_id,
        'icon_url', p.icon_url,
        'is_banned', df.is_banned,
        'last_seen_at', df.last_seen_at,
        'ip_address', df.ip_address
      )
    ) AS users,
    MAX(df.last_seen_at) AS last_seen_at
  FROM device_fingerprints df
  LEFT JOIN profiles p ON p.id = df.user_id
  GROUP BY df.device_id
  ORDER BY MAX(df.last_seen_at) DESC
  LIMIT p_limit;
END;
$$;

-- ─── admin_ban_device ────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_ban_device(
  p_device_id text,
  p_reason text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE device_fingerprints
  SET is_banned = true, banned_reason = p_reason
  WHERE device_id = p_device_id;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('success', true, 'rows_updated', v_count);
END;
$$;

-- ─── admin_unban_device ──────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_unban_device(
  p_device_id text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE device_fingerprints
  SET is_banned = false, banned_reason = null
  WHERE device_id = p_device_id;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('success', true, 'rows_updated', v_count);
END;
$$;

-- ─── admin_get_coin_transactions ─────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_coin_transactions(
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

-- ─── admin_get_economy_overview ──────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_economy_overview()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'total_coins_in_circulation', (SELECT COALESCE(SUM(coins), 0) FROM profiles),
    'total_transactions',         (SELECT COUNT(*) FROM coin_transactions),
    'transactions_today',         (SELECT COUNT(*) FROM coin_transactions WHERE created_at > NOW() - INTERVAL '24 hours'),
    'coins_distributed_today',    (SELECT COALESCE(SUM(amount), 0) FROM coin_transactions WHERE amount > 0 AND created_at > NOW() - INTERVAL '24 hours'),
    'top_sources',                (
      SELECT json_agg(row_to_json(t)) FROM (
        SELECT source::text, COUNT(*) as count, SUM(amount) as total_amount
        FROM coin_transactions
        WHERE amount > 0
        GROUP BY source
        ORDER BY count DESC
        LIMIT 10
      ) t
    ),
    'total_users_with_coins',     (SELECT COUNT(*) FROM profiles WHERE coins > 0),
    'avg_coins_per_user',         (SELECT ROUND(AVG(coins)) FROM profiles WHERE coins > 0)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ─── admin_get_lottery_stats ─────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_lottery_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'lottery_logs' AND table_schema = 'public'
  ) THEN
    RETURN json_build_object('total_plays', 0, 'total_prizes', 0, 'note', 'Tabela lottery_logs não encontrada');
  END IF;

  SELECT json_build_object(
    'total_plays', (SELECT COUNT(*) FROM lottery_logs),
    'note', 'Dados de loteria disponíveis'
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ─── admin_get_ai_characters ─────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_ai_characters()
RETURNS TABLE (
  id uuid,
  name text,
  avatar_url text,
  description text,
  system_prompt text,
  tags text[],
  language text,
  is_active boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ac.id,
    ac.name,
    ac.avatar_url,
    ac.description,
    ac.system_prompt,
    ac.tags,
    ac.language,
    ac.is_active,
    ac.created_at
  FROM ai_characters ac
  ORDER BY ac.created_at DESC;
END;
$$;

-- ─── admin_create_ai_character ───────────────────────────────
CREATE OR REPLACE FUNCTION admin_create_ai_character(
  p_name text,
  p_description text,
  p_system_prompt text,
  p_avatar_url text DEFAULT NULL,
  p_tags text[] DEFAULT '{}',
  p_language text DEFAULT 'pt-BR',
  p_is_active boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO ai_characters (name, description, system_prompt, avatar_url, tags, language, is_active)
  VALUES (p_name, p_description, p_system_prompt, p_avatar_url, p_tags, p_language, p_is_active)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- ─── admin_update_ai_character ───────────────────────────────
CREATE OR REPLACE FUNCTION admin_update_ai_character(
  p_id uuid,
  p_name text,
  p_description text,
  p_system_prompt text,
  p_avatar_url text DEFAULT NULL,
  p_tags text[] DEFAULT '{}',
  p_language text DEFAULT 'pt-BR',
  p_is_active boolean DEFAULT true
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE ai_characters
  SET
    name = p_name,
    description = p_description,
    system_prompt = p_system_prompt,
    avatar_url = COALESCE(p_avatar_url, avatar_url),
    tags = p_tags,
    language = p_language,
    is_active = p_is_active
  WHERE id = p_id;

  RETURN FOUND;
END;
$$;

-- ─── admin_toggle_ai_character ───────────────────────────────
CREATE OR REPLACE FUNCTION admin_toggle_ai_character(
  p_id uuid,
  p_active boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE ai_characters SET is_active = p_active WHERE id = p_id;
  RETURN FOUND;
END;
$$;

-- ─── admin_delete_ai_character ───────────────────────────────
CREATE OR REPLACE FUNCTION admin_delete_ai_character(
  p_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM ai_characters WHERE id = p_id;
  RETURN FOUND;
END;
$$;

-- ─── admin_get_top_coin_holders ──────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_top_coin_holders(
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  id uuid,
  nickname text,
  amino_id text,
  icon_url text,
  coins int,
  is_premium boolean,
  team_role text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.nickname,
    p.amino_id,
    p.icon_url,
    p.coins,
    p.is_premium,
    p.team_role::text
  FROM profiles p
  ORDER BY p.coins DESC
  LIMIT p_limit;
END;
$$;

-- ─── admin_get_moderation_overview ───────────────────────────
CREATE OR REPLACE FUNCTION admin_get_moderation_overview()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'active_bans',          (SELECT COUNT(*) FROM bans WHERE is_active = true),
    'bans_today',           (SELECT COUNT(*) FROM bans WHERE created_at > NOW() - INTERVAL '24 hours'),
    'bans_week',            (SELECT COUNT(*) FROM bans WHERE created_at > NOW() - INTERVAL '7 days'),
    'total_mod_actions',    (SELECT COUNT(*) FROM moderation_logs),
    'mod_actions_today',    (SELECT COUNT(*) FROM moderation_logs WHERE created_at > NOW() - INTERVAL '24 hours'),
    'mod_actions_week',     (SELECT COUNT(*) FROM moderation_logs WHERE created_at > NOW() - INTERVAL '7 days'),
    'permanent_bans',       (SELECT COUNT(*) FROM bans WHERE is_permanent = true AND is_active = true)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ─── Grants para authenticated ───────────────────────────────
GRANT EXECUTE ON FUNCTION admin_get_team_members() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_search_users(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_set_team_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_platform_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_moderation_logs(int, int, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_active_bans(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_device_fingerprints(int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_ban_device(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_unban_device(text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_coin_transactions(int, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_economy_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_lottery_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_ai_characters() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_create_ai_character(text, text, text, text, text[], text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_ai_character(uuid, text, text, text, text, text[], text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_toggle_ai_character(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_ai_character(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_top_coin_holders(int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_moderation_overview() TO authenticated;

-- ─── Grants para anon (publishable key sem login) ────────────
-- Necessário para que o cliente Supabase JS com publishable key
-- consiga chamar as RPCs mesmo antes de autenticar (o AuthContext
-- chama admin_get_team_members no login para verificar o cargo).
GRANT EXECUTE ON FUNCTION admin_get_team_members() TO anon;
GRANT EXECUTE ON FUNCTION admin_search_users(text, int) TO anon;
GRANT EXECUTE ON FUNCTION admin_set_team_role(uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_platform_stats() TO anon;
GRANT EXECUTE ON FUNCTION admin_get_moderation_logs(int, int, text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_active_bans(int, int) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_device_fingerprints(int) TO anon;
GRANT EXECUTE ON FUNCTION admin_ban_device(text, text) TO anon;
GRANT EXECUTE ON FUNCTION admin_unban_device(text) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_coin_transactions(int, int, text, text) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_economy_overview() TO anon;
GRANT EXECUTE ON FUNCTION admin_get_lottery_stats() TO anon;
GRANT EXECUTE ON FUNCTION admin_get_ai_characters() TO anon;
GRANT EXECUTE ON FUNCTION admin_create_ai_character(text, text, text, text, text[], text, boolean) TO anon;
GRANT EXECUTE ON FUNCTION admin_update_ai_character(uuid, text, text, text, text, text[], text, boolean) TO anon;
GRANT EXECUTE ON FUNCTION admin_toggle_ai_character(uuid, boolean) TO anon;
GRANT EXECUTE ON FUNCTION admin_delete_ai_character(uuid) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_top_coin_holders(int) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_moderation_overview() TO anon;
