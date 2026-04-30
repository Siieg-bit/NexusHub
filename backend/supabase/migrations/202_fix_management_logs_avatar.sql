-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 202: corrige get_management_logs
--   actor.profile_picture → actor.icon_url
--   tgt.profile_picture   → tgt.icon_url
--
-- A coluna real em public.profiles é icon_url, não profile_picture.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_management_logs(
  p_community_id   UUID    DEFAULT NULL,
  p_action_filter  TEXT    DEFAULT 'all',
  p_actor_filter   UUID    DEFAULT NULL,
  p_limit          INTEGER DEFAULT 50,
  p_offset         INTEGER DEFAULT 0
)
RETURNS TABLE (
  log_id            UUID,
  action            TEXT,
  severity          TEXT,
  actor_id          UUID,
  actor_nickname    TEXT,
  actor_avatar      TEXT,
  target_user_id    UUID,
  target_nickname   TEXT,
  target_avatar     TEXT,
  target_post_id    UUID,
  target_comment_id UUID,
  target_wiki_id    UUID,
  target_story_id   UUID,
  reason            TEXT,
  details           JSONB,
  duration_hours    INTEGER,
  expires_at        TIMESTAMPTZ,
  is_automated      BOOLEAN,
  flag_id           UUID,
  appeal_id         UUID,
  created_at        TIMESTAMPTZ
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
         AND cm.user_id      = v_caller_id
         AND cm.role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
         AND cm.is_banned IS NOT TRUE
    ) INTO v_is_community_staff;
  END IF;

  IF NOT (v_is_team_admin OR v_is_community_staff) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  RETURN QUERY
  SELECT
    ml.id               AS log_id,
    ml.action::TEXT,
    ml.severity::TEXT,
    ml.actor_id,
    actor.nickname      AS actor_nickname,
    actor.icon_url      AS actor_avatar,
    ml.target_user_id,
    tgt.nickname        AS target_nickname,
    tgt.icon_url        AS target_avatar,
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
    AND (p_actor_filter  IS NULL OR ml.actor_id     = p_actor_filter)
  ORDER BY ml.created_at DESC
  LIMIT  p_limit
  OFFSET p_offset;
END;
$$;
