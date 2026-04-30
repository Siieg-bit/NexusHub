-- ============================================================
-- Migration 213: RPCs SECURITY DEFINER para o painel admin
-- Permite que o bubble-admin acesse dados sensíveis sem expor
-- a service_role key no frontend.
-- Todas as funções verificam is_team_admin ou is_team_moderator
-- do usuário autenticado antes de retornar dados.
-- ============================================================

-- ─── Helper: verificar se o caller é team member ──────────────────────────────
CREATE OR REPLACE FUNCTION is_team_member()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (is_team_admin = true OR is_team_moderator = true)
  );
$$;

-- ─── AI Characters: listar TODOS (inclusive inativos) ─────────────────────────
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
  created_at timestamptz,
  total_messages bigint
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
    ac.id,
    ac.name,
    ac.avatar_url,
    ac.description,
    ac.system_prompt,
    ac.tags,
    ac.language,
    ac.is_active,
    ac.created_at,
    0::bigint AS total_messages  -- sem tabela ai_messages ainda
  FROM ai_characters ac
  ORDER BY ac.created_at DESC;
END;
$$;

-- ─── AI Characters: criar ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_create_ai_character(
  p_name text,
  p_description text,
  p_system_prompt text,
  p_tags text[],
  p_language text,
  p_avatar_url text DEFAULT NULL,
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
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  INSERT INTO ai_characters (name, description, system_prompt, tags, language, avatar_url, is_active)
  VALUES (p_name, p_description, p_system_prompt, p_tags, p_language, p_avatar_url, p_is_active)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- ─── AI Characters: atualizar ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_update_ai_character(
  p_id uuid,
  p_name text,
  p_description text,
  p_system_prompt text,
  p_tags text[],
  p_language text,
  p_avatar_url text,
  p_is_active boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  UPDATE ai_characters
  SET
    name = p_name,
    description = p_description,
    system_prompt = p_system_prompt,
    tags = p_tags,
    language = p_language,
    avatar_url = COALESCE(p_avatar_url, avatar_url),
    is_active = p_is_active
  WHERE id = p_id;
END;
$$;

-- ─── AI Characters: deletar ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_delete_ai_character(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Apenas team_admin pode deletar
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_team_admin = true) THEN
    RAISE EXCEPTION 'Apenas Team Admin pode deletar personagens';
  END IF;

  DELETE FROM ai_characters WHERE id = p_id;
END;
$$;

-- ─── AI Characters: toggle ativo/inativo ─────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_toggle_ai_character(p_id uuid, p_active boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  UPDATE ai_characters SET is_active = p_active WHERE id = p_id;
END;
$$;

-- ─── Device Fingerprints: listar com dados do usuário ─────────────────────────
CREATE OR REPLACE FUNCTION admin_get_device_fingerprints()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  device_id text,
  device_model text,
  os_version text,
  app_version text,
  ip_address text,
  is_banned boolean,
  banned_reason text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  -- dados do perfil
  nickname text,
  amino_id text,
  avatar_url text,
  profile_is_banned boolean,
  team_role text,
  -- contas no mesmo device_id
  accounts_on_device bigint
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
    df.id,
    df.user_id,
    df.device_id,
    df.device_model,
    df.os_version,
    df.app_version,
    df.ip_address,
    df.is_banned,
    df.banned_reason,
    df.first_seen_at,
    df.last_seen_at,
    p.nickname,
    p.amino_id,
    p.avatar_url,
    p.is_banned AS profile_is_banned,
    p.team_role::text,
    (SELECT COUNT(*) FROM device_fingerprints df2 WHERE df2.device_id = df.device_id) AS accounts_on_device
  FROM device_fingerprints df
  LEFT JOIN profiles p ON df.user_id = p.id
  ORDER BY df.last_seen_at DESC;
END;
$$;

-- ─── Device Fingerprints: banir dispositivo ───────────────────────────────────
CREATE OR REPLACE FUNCTION admin_ban_device(
  p_device_id text,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  UPDATE device_fingerprints
  SET is_banned = true, banned_reason = p_reason
  WHERE device_id = p_device_id;
END;
$$;

-- ─── Device Fingerprints: desbanir dispositivo ────────────────────────────────
CREATE OR REPLACE FUNCTION admin_unban_device(p_device_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_team_member() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  UPDATE device_fingerprints
  SET is_banned = false, banned_reason = NULL
  WHERE device_id = p_device_id;
END;
$$;

-- ─── Economy: visão geral ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_economy_overview()
RETURNS TABLE (
  source text,
  total_transactions bigint,
  total_coins bigint,
  avg_per_transaction numeric,
  last_transaction_at timestamptz
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
    ct.source,
    COUNT(*)::bigint AS total_transactions,
    SUM(ct.amount)::bigint AS total_coins,
    ROUND(AVG(ct.amount), 2) AS avg_per_transaction,
    MAX(ct.created_at) AS last_transaction_at
  FROM coin_transactions ct
  GROUP BY ct.source
  ORDER BY COUNT(*) DESC;
END;
$$;

-- ─── Economy: listar transações com dados do usuário ─────────────────────────
CREATE OR REPLACE FUNCTION admin_get_coin_transactions(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_source text DEFAULT NULL,
  p_user_search text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  nickname text,
  amino_id text,
  avatar_url text,
  amount integer,
  balance_after integer,
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
    p.nickname,
    p.amino_id,
    p.avatar_url,
    ct.amount,
    ct.balance_after,
    ct.source,
    ct.description,
    ct.created_at
  FROM coin_transactions ct
  LEFT JOIN profiles p ON ct.user_id = p.id
  WHERE
    (p_source IS NULL OR ct.source = p_source)
    AND (p_user_search IS NULL OR p.nickname ILIKE '%' || p_user_search || '%' OR p.amino_id ILIKE '%' || p_user_search || '%')
  ORDER BY ct.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ─── Economy: top usuários por saldo ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_top_coin_holders(p_limit int DEFAULT 20)
RETURNS TABLE (
  user_id uuid,
  nickname text,
  amino_id text,
  avatar_url text,
  coin_balance integer,
  total_earned bigint,
  total_spent bigint
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
    p.id AS user_id,
    p.nickname,
    p.amino_id,
    p.avatar_url,
    p.coin_balance,
    COALESCE(SUM(CASE WHEN ct.amount > 0 THEN ct.amount ELSE 0 END), 0)::bigint AS total_earned,
    COALESCE(ABS(SUM(CASE WHEN ct.amount < 0 THEN ct.amount ELSE 0 END)), 0)::bigint AS total_spent
  FROM profiles p
  LEFT JOIN coin_transactions ct ON ct.user_id = p.id
  WHERE p.coin_balance > 0
  GROUP BY p.id, p.nickname, p.amino_id, p.avatar_url, p.coin_balance
  ORDER BY p.coin_balance DESC
  LIMIT p_limit;
END;
$$;

-- ─── Economy: estatísticas de loteria ────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_lottery_stats()
RETURNS TABLE (
  award_type text,
  total_plays bigint,
  total_coins_won bigint
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
    ll.award_type::text,
    COUNT(*)::bigint AS total_plays,
    COALESCE(SUM(ll.coins_won), 0)::bigint AS total_coins_won
  FROM lottery_logs ll
  GROUP BY ll.award_type
  ORDER BY total_plays DESC;
END;
$$;

-- ─── Moderation Logs: listar com dados completos ─────────────────────────────
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
  duration_hours integer,
  expires_at timestamptz,
  is_automated boolean,
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
    ml.duration_hours,
    ml.expires_at,
    ml.is_automated,
    ml.created_at
  FROM moderation_logs ml
  LEFT JOIN communities c ON ml.community_id = c.id
  LEFT JOIN profiles mod ON ml.moderator_id = mod.id
  LEFT JOIN profiles tgt ON ml.target_user_id = tgt.id
  WHERE
    (p_action IS NULL OR ml.action::text = p_action)
    AND (p_community_id IS NULL OR ml.community_id = p_community_id)
  ORDER BY ml.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ─── Grants para usuários autenticados ───────────────────────────────────────
GRANT EXECUTE ON FUNCTION admin_get_ai_characters() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_create_ai_character(text, text, text, text[], text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_ai_character(uuid, text, text, text, text[], text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_ai_character(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_toggle_ai_character(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_device_fingerprints() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_ban_device(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_unban_device(text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_economy_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_coin_transactions(int, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_top_coin_holders(int) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_lottery_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_moderation_logs(int, int, text, uuid) TO authenticated;
