-- =============================================================================
-- Migration 199: Fix permissions and add get_security_settings
-- 
-- Fixes:
-- 1. get_management_logs / get_management_logs_stats: allow is_team_admin
-- 2. get_security_settings: create missing function (was get_security_overview)
-- 3. revoke_session: create missing function
-- =============================================================================

-- =============================================================================
-- 1. Fix get_management_logs — allow is_team_admin users
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_management_logs(UUID, TEXT, UUID, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION public.get_management_logs(
  p_community_id  UUID,
  p_action_filter TEXT    DEFAULT 'all',
  p_actor_filter  UUID    DEFAULT NULL,
  p_limit         INTEGER DEFAULT 30,
  p_offset        INTEGER DEFAULT 0
)
RETURNS TABLE (
  id                  UUID,
  action              TEXT,
  severity            TEXT,
  actor_id            UUID,
  actor_name          TEXT,
  actor_icon          TEXT,
  target_user_id      UUID,
  target_user_name    TEXT,
  target_user_icon    TEXT,
  target_post_id      UUID,
  target_comment_id   UUID,
  target_wiki_id      UUID,
  target_story_id     UUID,
  target_chat_id      UUID,
  reason              TEXT,
  details             JSONB,
  duration_hours      INTEGER,
  expires_at          TIMESTAMP WITH TIME ZONE,
  is_automated        BOOLEAN,
  flag_id             UUID,
  appeal_id           UUID,
  created_at          TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_is_team_admin BOOLEAN := FALSE;
  v_is_community_staff BOOLEAN := FALSE;
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  -- Check if team admin
  SELECT COALESCE(is_team_admin, FALSE) INTO v_is_team_admin
  FROM public.profiles WHERE id = v_caller_id;

  -- Check if community staff
  IF p_community_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = p_community_id
        AND user_id = v_caller_id
        AND role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
        AND is_banned IS NOT TRUE
    ) INTO v_is_community_staff;
  END IF;

  IF NOT (v_is_team_admin OR v_is_community_staff) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  RETURN QUERY
  SELECT
    ml.id,
    ml.action::TEXT,
    ml.severity::TEXT,
    ml.moderator_id AS actor_id,
    COALESCE(actor_p.nickname, actor_p.amino_id, 'Desconhecido') AS actor_name,
    actor_p.avatar_url AS actor_icon,
    ml.target_user_id,
    COALESCE(target_p.nickname, target_p.amino_id, 'Desconhecido') AS target_user_name,
    target_p.avatar_url AS target_user_icon,
    ml.target_post_id,
    ml.target_comment_id,
    ml.target_wiki_id,
    ml.target_story_id,
    ml.target_chat_thread_id AS target_chat_id,
    ml.reason,
    ml.details,
    ml.duration_hours,
    ml.expires_at,
    COALESCE(ml.is_automated, FALSE) AS is_automated,
    ml.flag_id,
    NULL::UUID AS appeal_id,
    ml.created_at
  FROM public.moderation_logs ml
  LEFT JOIN public.profiles actor_p ON actor_p.id = ml.moderator_id
  LEFT JOIN public.profiles target_p ON target_p.id = ml.target_user_id
  WHERE (p_community_id IS NULL OR ml.community_id = p_community_id)
    AND (p_action_filter = 'all' OR ml.action::TEXT = p_action_filter)
    AND (p_actor_filter IS NULL OR ml.moderator_id = p_actor_filter)
  ORDER BY ml.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- =============================================================================
-- 2. Fix get_management_logs_stats — allow is_team_admin users
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_management_logs_stats(UUID);
CREATE OR REPLACE FUNCTION public.get_management_logs_stats(p_community_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_is_team_admin BOOLEAN := FALSE;
  v_is_community_staff BOOLEAN := FALSE;
  v_stats JSONB;
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  SELECT COALESCE(is_team_admin, FALSE) INTO v_is_team_admin
  FROM public.profiles WHERE id = v_caller_id;

  IF p_community_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = p_community_id
        AND user_id = v_caller_id
        AND role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
        AND is_banned IS NOT TRUE
    ) INTO v_is_community_staff;
  END IF;

  IF NOT (v_is_team_admin OR v_is_community_staff) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  SELECT jsonb_build_object(
    'total_actions',    COUNT(*),
    'total_bans',       COUNT(*) FILTER (WHERE action::TEXT = 'ban'),
    'total_warnings',   COUNT(*) FILTER (WHERE action::TEXT = 'warn'),
    'total_mutes',      COUNT(*) FILTER (WHERE action::TEXT = 'mute'),
    'total_unbans',     COUNT(*) FILTER (WHERE action::TEXT = 'unban'),
    'total_removals',   COUNT(*) FILTER (WHERE action::TEXT IN ('remove_post','remove_comment','remove_wiki')),
    'pending_flags',    (SELECT COUNT(*) FROM public.flags WHERE community_id = p_community_id AND status = 'pending'),
    'pending_appeals',  (SELECT COUNT(*) FROM public.ban_appeals WHERE community_id = p_community_id AND status = 'pending')
  )
  INTO v_stats
  FROM public.moderation_logs
  WHERE (p_community_id IS NULL OR community_id = p_community_id);

  RETURN v_stats;
END;
$$;

-- =============================================================================
-- 3. Create get_security_settings (alias/wrapper for get_security_overview)
--    The Flutter screen calls 'get_security_settings' but the function is
--    named 'get_security_overview'. Create the alias.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_security_settings()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_has_2fa        BOOLEAN := FALSE;
  v_email_verified BOOLEAN := FALSE;
  v_security_level INTEGER := 0;
  v_alert_login    BOOLEAN := TRUE;
  v_alert_suspicious BOOLEAN := TRUE;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  SELECT
    COALESCE(security_level, 0),
    COALESCE(email_verified, FALSE)
  INTO v_security_level, v_email_verified
  FROM public.profiles WHERE id = v_user_id;

  -- Check 2FA from user_2fa_settings if exists
  BEGIN
    SELECT COALESCE(is_enabled, FALSE) INTO v_has_2fa
    FROM public.user_2fa_settings WHERE user_id = v_user_id;
  EXCEPTION WHEN undefined_table THEN
    v_has_2fa := FALSE;
  END;

  RETURN jsonb_build_object(
    'has_2fa',             v_has_2fa,
    'email_verified',      v_email_verified,
    'security_level',      v_security_level,
    'alert_on_login',      v_alert_login,
    'alert_on_suspicious', v_alert_suspicious,
    'recent_events_count', (
      SELECT COUNT(*) FROM public.security_events
      WHERE user_id = v_user_id
        AND created_at > NOW() - INTERVAL '30 days'
    ),
    'active_sessions_count', (
      SELECT COUNT(*) FROM public.user_sessions
      WHERE user_id = v_user_id
    )
  );
END;
$$;

-- =============================================================================
-- 4. Create revoke_session function (called by security center)
-- =============================================================================
DROP FUNCTION IF EXISTS public.revoke_session(UUID);
CREATE OR REPLACE FUNCTION public.revoke_session(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  DELETE FROM public.user_sessions
  WHERE id = p_session_id AND user_id = auth.uid();
END;
$$;

-- =============================================================================
-- 5. Create revoke_all_sessions function (called by security center)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.revoke_all_sessions()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  DELETE FROM public.user_sessions
  WHERE user_id = auth.uid() AND is_current IS NOT TRUE;
END;
$$;

-- =============================================================================
-- 6. Fix moderation_logs RLS — also allow is_team_admin
-- =============================================================================
DROP POLICY IF EXISTS "moderation_logs_select_staff" ON public.moderation_logs;
CREATE POLICY "moderation_logs_select_staff" ON public.moderation_logs
  FOR SELECT USING (
    -- Team admins can see all logs
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_team_admin = TRUE)
    OR
    -- Community staff can see their community logs
    EXISTS (
      SELECT 1 FROM public.community_members cm
      WHERE cm.community_id = moderation_logs.community_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
        AND cm.is_banned IS NOT TRUE
    )
  );
