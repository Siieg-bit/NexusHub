-- =============================================================================
-- RPC: get_active_screening_session
--
-- Retorna a sessão de projeção ativa (status='active') para um dado thread.
-- Usada pelo MessageBubble para verificar se a projeção ainda está em andamento
-- antes de permitir que o usuário entre, evitando entrar em sessão encerrada.
--
-- Parâmetros:
--   p_thread_id UUID — ID do thread da comunidade
--
-- Retorno:
--   Tabela com: id, thread_id, host_id, status, metadata, created_at
--   Vazia se não houver sessão ativa.
-- =============================================================================

CREATE OR REPLACE FUNCTION get_active_screening_session(p_thread_id UUID)
RETURNS TABLE (
  id          UUID,
  thread_id   UUID,
  host_id     UUID,
  status      TEXT,
  metadata    JSONB,
  created_at  TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    cs.id,
    cs.thread_id,
    cs.host_id,
    cs.status,
    cs.metadata,
    cs.created_at
  FROM call_sessions cs
  WHERE cs.thread_id = p_thread_id
    AND cs.type      = 'screening_room'
    AND cs.status    = 'active'
  ORDER BY cs.created_at DESC
  LIMIT 1;
$$;

-- Garantir que usuários autenticados possam chamar esta função
GRANT EXECUTE ON FUNCTION get_active_screening_session(UUID) TO authenticated;
