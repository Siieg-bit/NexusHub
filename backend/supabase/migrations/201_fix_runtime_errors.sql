-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 201: Corrigir erros de runtime identificados via logs
-- 1. _capture_chat_snapshot: sender_id → author_id (campo real em chat_messages)
-- 2. get_security_overview: COALESCE(security_level, 0) — enum vs integer
-- 3. get_management_logs: target_chat_message_id não existe em moderation_logs
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Corrigir _capture_chat_snapshot: sender_id → author_id
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._capture_chat_snapshot(
  p_flag_id    UUID,
  p_message_id UUID,
  p_capturer   UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snapshot_id UUID;
  v_msg         RECORD;
  v_sender      RECORD;
BEGIN
  SELECT m.* INTO v_msg
    FROM public.chat_messages m
   WHERE m.id = p_message_id;

  IF NOT FOUND THEN
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_chat_message_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'chat_message', p_message_id,
      jsonb_build_object('error', 'message_not_found', 'message_id', p_message_id),
      p_capturer
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  -- Corrigido: author_id (não sender_id)
  SELECT nickname, icon_url INTO v_sender
    FROM public.profiles WHERE id = v_msg.author_id;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_chat_message_id, original_user_id,
    snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'chat_message', p_message_id, v_msg.author_id,
    jsonb_build_object(
      'content',         v_msg.content,
      'media_url',       v_msg.media_url,
      'author_id',       v_msg.author_id,
      'sender_nickname', COALESCE(v_sender.nickname, 'Desconhecido'),
      'sender_avatar',   v_sender.icon_url,
      'thread_id',       v_msg.thread_id,
      'created_at',      v_msg.created_at,
      'captured_at',     NOW()
    ),
    p_capturer
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Corrigir get_security_overview: COALESCE(security_level, 0) — enum vs int
--    security_level é do tipo account_security_level (enum: 'ok','warning','danger')
--    Convertemos para inteiro: ok=1, warning=2, danger=3, NULL=0
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_security_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id         UUID    := auth.uid();
  v_has_2fa         BOOLEAN := FALSE;
  v_email_verified  BOOLEAN := FALSE;
  v_security_level  INTEGER := 0;
  v_raw_level       public.account_security_level;
  v_recent_events   JSONB;
  v_active_sessions JSONB;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  -- Buscar nível de segurança e email_verified do perfil
  SELECT security_level, COALESCE(email_verified, FALSE)
  INTO v_raw_level, v_email_verified
  FROM public.profiles WHERE id = v_user_id;

  -- Converter enum para inteiro
  v_security_level := CASE v_raw_level
    WHEN 'ok'      THEN 1
    WHEN 'warning' THEN 2
    WHEN 'danger'  THEN 3
    ELSE 0
  END;

  -- Verificar 2FA
  SELECT COALESCE(totp_enabled, FALSE)
  INTO v_has_2fa
  FROM public.user_2fa_settings
  WHERE user_id = v_user_id
  LIMIT 1;

  -- Últimos 10 eventos de segurança
  SELECT COALESCE(jsonb_agg(e ORDER BY e.created_at DESC), '[]'::jsonb)
  INTO v_recent_events
  FROM (
    SELECT se.id, se.event_type, se.ip_address, se.device_info, se.location, se.created_at
    FROM public.security_events se
    WHERE se.user_id = v_user_id
    ORDER BY se.created_at DESC
    LIMIT 10
  ) e;

  -- Sessões ativas
  SELECT COALESCE(jsonb_agg(s ORDER BY s.last_active DESC), '[]'::jsonb)
  INTO v_active_sessions
  FROM (
    SELECT us.id, us.device_name, us.device_type, us.ip_address, us.location,
           us.is_current, us.last_active
    FROM public.user_sessions us
    WHERE us.user_id = v_user_id
    ORDER BY us.last_active DESC
    LIMIT 10
  ) s;

  RETURN jsonb_build_object(
    'security_level',   v_security_level,
    'has_2fa',          v_has_2fa,
    'email_verified',   v_email_verified,
    'recent_events',    v_recent_events,
    'active_sessions',  v_active_sessions
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Corrigir get_management_logs: remover target_chat_message_id (não existe
--    em moderation_logs) e qualificar todas as colunas com alias de tabela
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_management_logs(UUID, TEXT, UUID, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.get_management_logs(
  p_community_id  UUID    DEFAULT NULL,
  p_action_filter TEXT    DEFAULT 'all',
  p_actor_filter  UUID    DEFAULT NULL,
  p_limit         INTEGER DEFAULT 50,
  p_offset        INTEGER DEFAULT 0
)
RETURNS TABLE (
  log_id              UUID,
  action              TEXT,
  severity            TEXT,
  actor_id            UUID,
  actor_nickname      TEXT,
  actor_avatar        TEXT,
  target_user_id      UUID,
  target_nickname     TEXT,
  target_avatar       TEXT,
  target_post_id      UUID,
  target_comment_id   UUID,
  target_wiki_id      UUID,
  target_story_id     UUID,
  reason              TEXT,
  details             JSONB,
  duration_hours      INTEGER,
  expires_at          TIMESTAMPTZ,
  is_automated        BOOLEAN,
  flag_id             UUID,
  appeal_id           UUID,
  created_at          TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id          UUID    := auth.uid();
  v_is_team_admin      BOOLEAN := FALSE;
  v_is_community_staff BOOLEAN := FALSE;
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  SELECT COALESCE(p.is_team_admin, FALSE)
  INTO v_is_team_admin
  FROM public.profiles p WHERE p.id = v_caller_id;

  IF p_community_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.community_members cm
      WHERE cm.community_id = p_community_id
        AND cm.user_id = v_caller_id
        AND cm.role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
        AND cm.is_banned IS NOT TRUE
    ) INTO v_is_community_staff;
  END IF;

  IF NOT (v_is_team_admin OR v_is_community_staff) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  RETURN QUERY
  SELECT
    ml.id           AS log_id,
    ml.action::TEXT,
    ml.severity::TEXT,
    ml.actor_id,
    actor.nickname  AS actor_nickname,
    actor.profile_picture AS actor_avatar,
    ml.target_user_id,
    tgt.nickname    AS target_nickname,
    tgt.profile_picture AS target_avatar,
    ml.target_post_id,
    ml.target_comment_id,
    ml.target_wiki_id,
    ml.target_story_id,
    ml.reason,
    ml.details,
    ml.duration_hours,
    ml.expires_at,
    ml.is_automated,
    ml.flag_id,
    ml.appeal_id,
    ml.created_at
  FROM public.moderation_logs ml
  LEFT JOIN public.profiles actor ON actor.id = ml.actor_id
  LEFT JOIN public.profiles tgt   ON tgt.id   = ml.target_user_id
  WHERE (p_community_id IS NULL OR ml.community_id = p_community_id)
    AND (p_action_filter = 'all' OR ml.action::TEXT = p_action_filter)
    AND (p_actor_filter IS NULL OR ml.actor_id = p_actor_filter)
  ORDER BY ml.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
