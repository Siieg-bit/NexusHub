-- =============================================================================
-- Migration 230: RPC force_end_my_call_sessions
--
-- Problema: quando o host fecha o app sem encerrar a call, a sessão fica presa
-- com status='active' no banco. Ao reabrir o app, o CallService.activeCall é
-- null (estado local perdido), então endCall() não consegue encerrar.
--
-- Solução: RPC que encerra TODAS as sessões ativas onde o usuário autenticado
-- é o host, independente do estado local do app Flutter.
-- Chamada automaticamente no _checkAndAttachAudience quando o usuário é host.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.force_end_my_call_sessions(
  p_thread_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_count    INT  := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Encerrar todas as sessões ativas onde o usuário é host
  -- Opcionalmente filtrado por thread_id
  UPDATE public.call_sessions
  SET
    status    = 'ended',
    is_active = FALSE,
    ended_at  = NOW()
  WHERE
    COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
    AND (host_id = v_user_id OR creator_id = v_user_id)
    AND (p_thread_id IS NULL OR thread_id = p_thread_id);

  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- Marcar todos os participantes dessas sessões como desconectados
  UPDATE public.call_participants cp
  SET
    status  = 'disconnected',
    left_at = NOW()
  FROM public.call_sessions cs
  WHERE cp.call_session_id = cs.id
    AND cs.status = 'ended'
    AND cs.ended_at >= NOW() - INTERVAL '5 seconds'
    AND (cs.host_id = v_user_id OR cs.creator_id = v_user_id);

  RETURN jsonb_build_object('success', true, 'sessions_ended', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.force_end_my_call_sessions(UUID) TO authenticated;
