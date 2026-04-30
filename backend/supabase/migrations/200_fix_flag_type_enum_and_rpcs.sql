-- =============================================================================
-- Migration 200: Fix flag_type enum, get_security_settings and management logs
-- =============================================================================

-- =============================================================================
-- 1. Expand flag_type enum with new report categories
-- =============================================================================
-- Add new values to the existing flag_type enum
DO $$
BEGIN
  -- sexual_content
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'flag_type' AND e.enumlabel = 'sexual_content'
  ) THEN
    ALTER TYPE public.flag_type ADD VALUE 'sexual_content';
  END IF;

  -- hate_speech
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'flag_type' AND e.enumlabel = 'hate_speech'
  ) THEN
    ALTER TYPE public.flag_type ADD VALUE 'hate_speech';
  END IF;

  -- violence
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'flag_type' AND e.enumlabel = 'violence'
  ) THEN
    ALTER TYPE public.flag_type ADD VALUE 'violence';
  END IF;

  -- misinformation
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'flag_type' AND e.enumlabel = 'misinformation'
  ) THEN
    ALTER TYPE public.flag_type ADD VALUE 'misinformation';
  END IF;

  -- impersonation
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'flag_type' AND e.enumlabel = 'impersonation'
  ) THEN
    ALTER TYPE public.flag_type ADD VALUE 'impersonation';
  END IF;

  -- self_harm
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'flag_type' AND e.enumlabel = 'self_harm'
  ) THEN
    ALTER TYPE public.flag_type ADD VALUE 'self_harm';
  END IF;
END;
$$;

-- =============================================================================
-- 2. Fix get_security_settings: use totp_enabled instead of is_enabled
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_security_settings()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id          UUID := auth.uid();
  v_has_2fa          BOOLEAN := FALSE;
  v_email_verified   BOOLEAN := FALSE;
  v_security_level   INTEGER := 0;
  v_alert_login      BOOLEAN := TRUE;
  v_alert_suspicious BOOLEAN := TRUE;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  SELECT
    COALESCE(security_level, 0),
    COALESCE(email_verified, FALSE)
  INTO v_security_level, v_email_verified
  FROM public.profiles WHERE id = v_user_id;

  -- Check 2FA: use totp_enabled (correct column name)
  BEGIN
    SELECT COALESCE(totp_enabled, FALSE) INTO v_has_2fa
    FROM public.user_2fa_settings WHERE user_id = v_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN
    v_has_2fa := FALSE;
  END;

  RETURN jsonb_build_object(
    'has_2fa',               v_has_2fa,
    'email_verified',        v_email_verified,
    'security_level',        v_security_level,
    'alert_on_login',        v_alert_login,
    'alert_on_suspicious',   v_alert_suspicious,
    'recent_events_count',   (
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
-- 3. Fix get_management_logs_stats: also check is_team_admin correctly
--    The issue is COALESCE(is_team_admin, FALSE) might fail if column is NULL
--    Add explicit NULL handling and also allow access when p_community_id is NULL
--    for team admins (they can see all logs)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_management_logs_stats(
  p_community_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_id          UUID := auth.uid();
  v_is_team_admin      BOOLEAN := FALSE;
  v_is_community_staff BOOLEAN := FALSE;
  v_stats              JSONB;
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  -- Check team admin status
  SELECT COALESCE(is_team_admin, FALSE)
  INTO v_is_team_admin
  FROM public.profiles
  WHERE id = v_caller_id;

  -- Check community staff status (only if community_id provided)
  IF p_community_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = p_community_id
        AND user_id = v_caller_id
        AND role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
        AND is_banned IS NOT TRUE
    ) INTO v_is_community_staff;
  END IF;

  -- Team admins always have access; community staff only for their community
  IF NOT (v_is_team_admin OR v_is_community_staff) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  SELECT jsonb_build_object(
    'total_actions',   COUNT(*),
    'total_bans',      COUNT(*) FILTER (WHERE action::TEXT = 'ban'),
    'total_warnings',  COUNT(*) FILTER (WHERE action::TEXT = 'warn'),
    'total_mutes',     COUNT(*) FILTER (WHERE action::TEXT = 'mute'),
    'total_unbans',    COUNT(*) FILTER (WHERE action::TEXT = 'unban'),
    'total_removals',  COUNT(*) FILTER (WHERE action::TEXT IN ('remove_post','remove_comment','remove_wiki')),
    'pending_flags',   (
      SELECT COUNT(*) FROM public.flags
      WHERE (p_community_id IS NULL OR community_id = p_community_id)
        AND status = 'pending'
    ),
    'pending_appeals', (
      SELECT COUNT(*) FROM public.ban_appeals
      WHERE (p_community_id IS NULL OR community_id = p_community_id)
        AND status = 'pending'
    )
  )
  INTO v_stats
  FROM public.moderation_logs
  WHERE (p_community_id IS NULL OR community_id = p_community_id);

  RETURN v_stats;
END;
$$;

-- =============================================================================
-- 4. Fix get_management_logs: same is_team_admin fix
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_management_logs(
  p_community_id   UUID    DEFAULT NULL,
  p_action_filter  TEXT    DEFAULT 'all',
  p_actor_filter   UUID    DEFAULT NULL,
  p_limit          INTEGER DEFAULT 30,
  p_offset         INTEGER DEFAULT 0
)
RETURNS TABLE (
  id                UUID,
  action            TEXT,
  severity          TEXT,
  actor_id          UUID,
  actor_name        TEXT,
  actor_icon        TEXT,
  target_user_id    UUID,
  target_user_name  TEXT,
  target_user_icon  TEXT,
  target_post_id    UUID,
  target_comment_id UUID,
  target_wiki_id    UUID,
  target_story_id   UUID,
  target_chat_id    UUID,
  reason            TEXT,
  details           JSONB,
  duration_hours    INTEGER,
  expires_at        TIMESTAMPTZ,
  is_automated      BOOLEAN,
  flag_id           UUID,
  appeal_id         UUID,
  created_at        TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_id          UUID := auth.uid();
  v_is_team_admin      BOOLEAN := FALSE;
  v_is_community_staff BOOLEAN := FALSE;
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  SELECT COALESCE(is_team_admin, FALSE)
  INTO v_is_team_admin
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

  RETURN QUERY
  SELECT
    ml.id,
    ml.action::TEXT,
    ml.severity::TEXT,
    ml.actor_id,
    actor.nickname,
    actor.profile_picture,
    ml.target_user_id,
    target.nickname,
    target.profile_picture,
    ml.target_post_id,
    ml.target_comment_id,
    ml.target_wiki_id,
    ml.target_story_id,
    ml.target_chat_message_id,
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
  LEFT JOIN public.profiles target ON target.id = ml.target_user_id
  WHERE (p_community_id IS NULL OR ml.community_id = p_community_id)
    AND (p_action_filter = 'all' OR ml.action::TEXT = p_action_filter)
    AND (p_actor_filter IS NULL OR ml.actor_id = p_actor_filter)
  ORDER BY ml.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_security_settings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_management_logs_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_management_logs(UUID, TEXT, UUID, INTEGER, INTEGER) TO authenticated;
