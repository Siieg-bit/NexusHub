-- ============================================================================
-- 081_fix_call_sessions_host_id_compat.sql
-- Restores compatibility with the live mixed call_sessions schema.
-- The table still requires host_id and still carries legacy call_type/is_active
-- fields, while newer RPCs were only writing creator_id/type/status.
-- This migration makes the RPCs populate both representations and backfills
-- creator_id from host_id where needed.
-- ============================================================================

-- Backfill creator_id for legacy rows so creator-based RPCs keep working.
UPDATE public.call_sessions
SET creator_id = host_id
WHERE creator_id IS NULL
  AND host_id IS NOT NULL;

DROP FUNCTION IF EXISTS public.create_call_session(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.create_call_session(
  p_thread_id UUID,
  p_type TEXT DEFAULT 'voice'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session_id UUID;
  v_call_type INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_type NOT IN ('voice', 'video', 'screening_room') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_call_type');
  END IF;

  IF p_type = 'voice' THEN
    v_call_type := 1;
  ELSIF p_type = 'video' THEN
    v_call_type := 2;
  ELSE
    v_call_type := 4;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id = v_user_id
      AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.call_sessions
    WHERE thread_id = p_thread_id
      AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'call_already_active');
  END IF;

  INSERT INTO public.call_sessions (
    thread_id,
    call_type,
    host_id,
    creator_id,
    type,
    status,
    is_active,
    started_at,
    created_at
  )
  VALUES (
    p_thread_id,
    v_call_type,
    v_user_id,
    v_user_id,
    p_type,
    'active',
    TRUE,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_session_id;

  INSERT INTO public.call_participants (call_session_id, user_id, status, joined_at)
  VALUES (v_session_id, v_user_id, 'connected', NOW())
  ON CONFLICT (call_session_id, user_id)
  DO UPDATE SET
    status = 'connected',
    joined_at = NOW(),
    left_at = NULL;

  RETURN jsonb_build_object('success', true, 'session_id', v_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_call_session(UUID, TEXT) TO authenticated;

DROP FUNCTION IF EXISTS public.end_call_session(UUID);
CREATE OR REPLACE FUNCTION public.end_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_owner_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(creator_id, host_id)
    INTO v_owner_id
  FROM public.call_sessions
  WHERE id = p_session_id
    AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active';

  IF v_owner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  IF v_owner_id <> v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_the_creator');
  END IF;

  UPDATE public.call_participants
  SET status = 'disconnected',
      left_at = NOW()
  WHERE call_session_id = p_session_id
    AND status = 'connected';

  UPDATE public.call_sessions
  SET status = 'ended',
      is_active = FALSE,
      ended_at = NOW()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.end_call_session(UUID) TO authenticated;

DROP FUNCTION IF EXISTS public.leave_call_session(UUID);
CREATE OR REPLACE FUNCTION public.leave_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_remaining INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  UPDATE public.call_participants
  SET status = 'disconnected',
      left_at = NOW()
  WHERE call_session_id = p_session_id
    AND user_id = v_user_id;

  SELECT COUNT(*)
    INTO v_remaining
  FROM public.call_participants
  WHERE call_session_id = p_session_id
    AND status = 'connected';

  IF v_remaining = 0 THEN
    UPDATE public.call_sessions
    SET status = 'ended',
        is_active = FALSE,
        ended_at = NOW()
    WHERE id = p_session_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'session_ended', v_remaining = 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_call_session(UUID) TO authenticated;
