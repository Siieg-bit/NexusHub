-- Moderation tools for Screening Room
-- Adds a SECURITY DEFINER RPC so hosts/co-hosts can remove a participant
-- without direct client-side table mutation.

DROP FUNCTION IF EXISTS public.moderate_screening_participant(uuid, uuid, text);

CREATE OR REPLACE FUNCTION public.moderate_screening_participant(
  p_session_id uuid,
  p_target_user_id uuid,
  p_action text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_thread_id uuid;
  v_session_host uuid;
  v_thread_host uuid;
  v_co_hosts jsonb;
  v_allowed boolean := false;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT cs.thread_id, COALESCE(cs.host_user_id, cs.creator_id, cs.host_id)
    INTO v_thread_id, v_session_host
  FROM public.call_sessions cs
  WHERE cs.id = p_session_id
    AND cs.status = 'active';

  IF v_thread_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  SELECT ct.host_id,
         COALESCE(ct.co_hosts, '[]'::jsonb)
    INTO v_thread_host, v_co_hosts
  FROM public.chat_threads ct
  WHERE ct.id = v_thread_id;

  v_allowed := v_actor = v_session_host
    OR v_actor = v_thread_host
    OR v_co_hosts ? v_actor::text;

  IF NOT v_allowed THEN
    RETURN jsonb_build_object('success', false, 'error', 'permission_denied');
  END IF;

  IF p_target_user_id = v_session_host THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_moderate_host');
  END IF;

  IF p_action = 'kick' THEN
    UPDATE public.call_participants
       SET status = 'disconnected', left_at = now()
     WHERE call_session_id = p_session_id
       AND user_id = p_target_user_id;

    RETURN jsonb_build_object('success', true, 'action', 'kick');
  ELSIF p_action = 'mute' THEN
    -- Mute is enforced through Realtime broadcast on the client. The RPC still
    -- validates moderator permission and provides an auditable permission gate.
    RETURN jsonb_build_object('success', true, 'action', 'mute');
  END IF;

  RETURN jsonb_build_object('success', false, 'error', 'invalid_action');
END;
$$;

GRANT EXECUTE ON FUNCTION public.moderate_screening_participant(uuid, uuid, text) TO authenticated;
