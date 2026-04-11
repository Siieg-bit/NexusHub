-- NexusHub — Migração 059: Screening Room — Host Control & Metadata
-- ============================================================================
-- Adiciona coluna metadata (JSONB) à call_sessions para armazenar
-- video_url, video_title, is_playing e outros dados da sessão.
-- Também adiciona RPC end_screening_session para encerramento pelo host.
-- ============================================================================

-- 1. Adicionar coluna metadata se não existir
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'call_sessions'
      AND column_name  = 'metadata'
  ) THEN
    ALTER TABLE public.call_sessions ADD COLUMN metadata JSONB DEFAULT '{}';
  END IF;
END $$;

-- 2. RPC: end_screening_session
--    Encerra a sessão (status='ended') e atualiza ended_at.
--    Só o criador (host) pode encerrar.
CREATE OR REPLACE FUNCTION public.end_screening_session(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  UPDATE public.call_sessions
  SET
    status    = 'ended',
    ended_at  = NOW()
  WHERE id          = p_session_id
    AND creator_id  = auth.uid()
    AND status      = 'active';

  -- Desconectar todos os participantes
  UPDATE public.call_participants
  SET
    status  = 'disconnected',
    left_at = NOW()
  WHERE call_session_id = p_session_id
    AND status          = 'connected';
END;
$$;

GRANT EXECUTE ON FUNCTION public.end_screening_session(UUID) TO authenticated;

COMMENT ON FUNCTION public.end_screening_session IS
  'Encerra uma sessão de Screening Room e desconecta todos os participantes.
   Apenas o criador (host) pode encerrar. Migration 059.';

-- 3. RPC: update_screening_metadata
--    Atualiza o metadata da sessão (video_url, video_title, is_playing).
--    Apenas o host pode atualizar.
CREATE OR REPLACE FUNCTION public.update_screening_metadata(
  p_session_id  UUID,
  p_metadata    JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  UPDATE public.call_sessions
  SET metadata = p_metadata
  WHERE id         = p_session_id
    AND creator_id = auth.uid()
    AND status     = 'active';
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_screening_metadata(UUID, JSONB) TO authenticated;

COMMENT ON FUNCTION public.update_screening_metadata IS
  'Atualiza o metadata (video_url, video_title, is_playing) de uma sessão de Screening Room.
   Apenas o host pode atualizar. Migration 059.';

-- 4. Garantir que call_sessions está no Realtime (idempotent)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.call_sessions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
