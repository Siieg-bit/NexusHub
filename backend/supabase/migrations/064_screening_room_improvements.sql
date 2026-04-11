-- =============================================================================
-- Migration 064: Melhorias na Sala de Projeção
--
-- 1. Tabela screening_chat_messages: persiste o chat interno da sala
-- 2. Função cleanup_inactive_screening_participants: remove participantes
--    que não enviaram heartbeat nos últimos 2 minutos
-- =============================================================================

-- ─── 1. Tabela de mensagens do chat interno da sala ───────────────────────────
CREATE TABLE IF NOT EXISTS public.screening_chat_messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES public.call_sessions(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  text            TEXT NOT NULL CHECK (char_length(text) BETWEEN 1 AND 500),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_screening_chat_session
  ON public.screening_chat_messages(session_id, created_at DESC);

-- RLS
ALTER TABLE public.screening_chat_messages ENABLE ROW LEVEL SECURITY;

-- Participantes da sessão podem ler as mensagens
CREATE POLICY "screening_chat_read" ON public.screening_chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.call_participants cp
      WHERE cp.call_session_id = screening_chat_messages.session_id
        AND cp.user_id = auth.uid()
        AND cp.status = 'connected'
    )
  );

-- Usuário autenticado pode inserir suas próprias mensagens
CREATE POLICY "screening_chat_insert" ON public.screening_chat_messages
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.call_participants cp
      WHERE cp.call_session_id = screening_chat_messages.session_id
        AND cp.user_id = auth.uid()
        AND cp.status = 'connected'
    )
  );

-- ─── 2. Coluna last_heartbeat em call_participants ────────────────────────────
ALTER TABLE public.call_participants
  ADD COLUMN IF NOT EXISTS last_heartbeat TIMESTAMPTZ DEFAULT NOW();

-- ─── 3. Função: cleanup_inactive_screening_participants ───────────────────────
-- Marca como 'disconnected' participantes que não enviaram heartbeat em 2 min.
-- Deve ser chamada periodicamente (ex: via cron job ou pelo host).
CREATE OR REPLACE FUNCTION public.cleanup_inactive_screening_participants(
  p_session_id UUID
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE public.call_participants
  SET
    status   = 'disconnected',
    left_at  = NOW()
  WHERE call_session_id = p_session_id
    AND status          = 'connected'
    AND last_heartbeat  < NOW() - INTERVAL '2 minutes';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_inactive_screening_participants(UUID)
  TO authenticated;

-- ─── 4. Função: send_screening_heartbeat ─────────────────────────────────────
-- Atualiza o last_heartbeat do participante. Chamada a cada 30s pelo Flutter.
CREATE OR REPLACE FUNCTION public.send_screening_heartbeat(
  p_session_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.call_participants
  SET last_heartbeat = NOW()
  WHERE call_session_id = p_session_id
    AND user_id         = auth.uid()
    AND status          = 'connected';
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_screening_heartbeat(UUID)
  TO authenticated;

-- ─── 5. RPC: get_screening_chat_history ──────────────────────────────────────
-- Retorna as últimas N mensagens do chat interno com username e avatar.
CREATE OR REPLACE FUNCTION public.get_screening_chat_history(
  p_session_id UUID,
  p_limit      INTEGER DEFAULT 50
)
RETURNS TABLE (
  id         UUID,
  user_id    UUID,
  username   TEXT,
  avatar_url TEXT,
  text       TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.user_id,
    p.username,
    p.avatar_url,
    m.text,
    m.created_at
  FROM public.screening_chat_messages m
  JOIN public.profiles p ON p.id = m.user_id
  WHERE m.session_id = p_session_id
  ORDER BY m.created_at ASC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_screening_chat_history(UUID, INTEGER)
  TO authenticated;

-- =============================================================================
-- RESULTADO:
-- - screening_chat_messages: persiste o chat interno com RLS
-- - last_heartbeat: coluna para detectar participantes inativos
-- - cleanup_inactive_screening_participants: limpa inativos após 2min sem heartbeat
-- - send_screening_heartbeat: atualiza last_heartbeat a cada 30s
-- - get_screening_chat_history: retorna histórico com username e avatar
-- =============================================================================
