-- Migration 209: RPC para buscar a call ativa (pública) de um usuário
-- ============================================================================
-- Retorna os dados da sessão de call ativa onde o usuário está conectado,
-- desde que o chat_thread seja do tipo 'public' (acessível por qualquer um).
-- Retorna NULL se o usuário não estiver em nenhuma call pública ativa.
CREATE OR REPLACE FUNCTION public.get_user_active_call(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id',           cs.id,
    'thread_id',    cs.thread_id,
    'type',         cs.type,
    'status',       cs.status,
    'community_id', ct.community_id,
    'created_at',   cs.created_at
  )
  INTO v_result
  FROM public.call_participants cp
  JOIN public.call_sessions cs ON cs.id = cp.call_session_id
  JOIN public.chat_threads ct ON ct.id = cs.thread_id
  WHERE cp.user_id = p_user_id
    AND cp.status = 'connected'
    AND cs.status = 'active'
    AND ct.type = 'public'
  ORDER BY cp.joined_at DESC
  LIMIT 1;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_active_call(UUID) TO authenticated;
