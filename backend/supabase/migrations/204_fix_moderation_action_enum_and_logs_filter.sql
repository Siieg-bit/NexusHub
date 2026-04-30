-- Migration 204: Adiciona valores faltantes ao enum moderation_action
-- e atualiza a RPC get_management_logs para suportar todos os filtros.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Adicionar valores faltantes ao enum moderation_action
-- ─────────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  ALTER TYPE moderation_action ADD VALUE IF NOT EXISTS 'unmute';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE moderation_action ADD VALUE IF NOT EXISTS 'approve_flag';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE moderation_action ADD VALUE IF NOT EXISTS 'dismiss_flag';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE moderation_action ADD VALUE IF NOT EXISTS 'accept_appeal';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE moderation_action ADD VALUE IF NOT EXISTS 'reject_appeal';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Recriar a RPC get_management_logs com suporte a todos os filtros
--    (incluindo os novos valores do enum)
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_management_logs(uuid, text, uuid, integer, integer);

CREATE OR REPLACE FUNCTION public.get_management_logs(
  p_community_id  uuid    DEFAULT NULL,
  p_action_filter text    DEFAULT 'all',
  p_actor_filter  uuid    DEFAULT NULL,
  p_limit         integer DEFAULT 50,
  p_offset        integer DEFAULT 0
)
RETURNS TABLE(
  log_id           uuid,
  action           text,
  severity         text,
  actor_id         uuid,
  actor_nickname   text,
  actor_avatar     text,
  target_user_id   uuid,
  target_nickname  text,
  target_avatar    text,
  target_post_id   uuid,
  target_comment_id uuid,
  target_wiki_id   uuid,
  target_story_id  uuid,
  reason           text,
  details          jsonb,
  duration_hours   integer,
  expires_at       timestamp with time zone,
  is_automated     boolean,
  flag_id          uuid,
  appeal_id        uuid,
  created_at       timestamp with time zone
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
    ml.id                                          AS log_id,
    ml.action::TEXT,
    ml.severity::TEXT,
    COALESCE(ml.actor_id, ml.moderator_id)         AS actor_id,
    actor.nickname                                 AS actor_nickname,
    actor.icon_url                                 AS actor_avatar,
    ml.target_user_id,
    tgt.nickname                                   AS target_nickname,
    tgt.icon_url                                   AS target_avatar,
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
  LEFT JOIN public.profiles actor ON actor.id = COALESCE(ml.actor_id, ml.moderator_id)
  LEFT JOIN public.profiles tgt   ON tgt.id   = ml.target_user_id
  WHERE (p_community_id IS NULL OR ml.community_id = p_community_id)
    AND (p_action_filter = 'all' OR ml.action::TEXT = p_action_filter)
    AND (p_actor_filter  IS NULL
         OR COALESCE(ml.actor_id, ml.moderator_id) = p_actor_filter)
  ORDER BY ml.created_at DESC
  LIMIT  p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_management_logs(uuid, text, uuid, integer, integer) TO authenticated;
