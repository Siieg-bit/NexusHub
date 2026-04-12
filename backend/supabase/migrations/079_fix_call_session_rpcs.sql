-- ============================================================================
-- 079_fix_call_session_rpcs.sql
-- Corrige RPCs de call para o schema atual da tabela call_sessions
-- (usa creator_id em vez de created_by).
-- ============================================================================

DROP FUNCTION IF EXISTS public.create_call_session(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.create_call_session(
  p_thread_id UUID,
  p_type TEXT DEFAULT 'voice'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session_id UUID;
  v_existing_session_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_type NOT IN ('voice', 'video', 'screening_room') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_call_type');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.chat_participants
    WHERE thread_id = p_thread_id
      AND user_id = v_user_id
      AND left_at IS NULL
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  SELECT id INTO v_existing_session_id
  FROM public.call_sessions
  WHERE thread_id = p_thread_id
    AND type = p_type
    AND status = 'active'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing_session_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'call_already_active',
      'session_id', v_existing_session_id
    );
  END IF;

  INSERT INTO public.call_sessions (thread_id, creator_id, type, status)
  VALUES (p_thread_id, v_user_id, p_type, 'active')
  RETURNING id INTO v_session_id;

  INSERT INTO public.call_participants (call_session_id, user_id, status, joined_at)
  VALUES (v_session_id, v_user_id, 'connected', NOW())
  ON CONFLICT (call_session_id, user_id)
  DO UPDATE SET
    status = 'connected',
    joined_at = NOW(),
    left_at = NULL;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'type', p_type
  );
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
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_creator_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT creator_id INTO v_creator_id
  FROM public.call_sessions
  WHERE id = p_session_id
    AND status = 'active';

  IF v_creator_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  IF v_creator_id <> v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_the_creator');
  END IF;

  UPDATE public.call_participants
  SET status = 'disconnected',
      left_at = NOW()
  WHERE call_session_id = p_session_id
    AND status = 'connected';

  UPDATE public.call_sessions
  SET status = 'ended',
      ended_at = NOW()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.end_call_session(UUID) TO authenticated;
