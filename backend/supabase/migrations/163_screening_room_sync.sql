-- =============================================================================
-- Migration 163: Sala de Projeção — Sincronização em Tempo Real
--
-- Adiciona suporte a:
-- 1. sync_position / sync_is_playing / sync_updated_at em call_sessions
--    → Estado de reprodução persistido para novos participantes que entram
-- 2. host_user_id em call_sessions
--    → Permite transferência de controle do host para outro participante
-- 3. RPC update_sync_state
--    → Atualiza estado de reprodução (chamada pelo host via Broadcast)
-- 4. RPC transfer_screening_host
--    → Transfere o controle de host para outro participante
-- 5. RPC get_screening_session_state
--    → Retorna o estado completo da sessão para novos entrantes
-- =============================================================================

-- ─── 1. Colunas de sincronização em call_sessions ────────────────────────────

ALTER TABLE public.call_sessions
  ADD COLUMN IF NOT EXISTS sync_position     BIGINT      DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sync_is_playing   BOOLEAN     DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS sync_updated_at   TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS host_user_id      UUID        REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.call_sessions.sync_position   IS 'Posição de reprodução em milissegundos (estado do host)';
COMMENT ON COLUMN public.call_sessions.sync_is_playing IS 'TRUE se o vídeo está em reprodução no momento';
COMMENT ON COLUMN public.call_sessions.sync_updated_at IS 'Timestamp do último evento de sync (para cálculo de drift)';
COMMENT ON COLUMN public.call_sessions.host_user_id    IS 'ID do usuário com controle de reprodução (pode ser diferente do creator)';

-- ─── 2. RPC: update_sync_state ───────────────────────────────────────────────
-- Atualiza o estado de reprodução. Apenas o host (creator ou host_user_id)
-- pode chamar. Usado como fallback de persistência além do Broadcast.

CREATE OR REPLACE FUNCTION public.update_sync_state(
  p_session_id   UUID,
  p_position     BIGINT,
  p_is_playing   BOOLEAN
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
  SET
    sync_position   = p_position,
    sync_is_playing = p_is_playing,
    sync_updated_at = NOW()
  WHERE id = p_session_id
    AND status = 'active'
    AND (creator_id = auth.uid() OR host_user_id = auth.uid());

  IF NOT FOUND THEN
    RAISE EXCEPTION 'permission_denied: only the host can update sync state';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_sync_state(UUID, BIGINT, BOOLEAN) TO authenticated;

COMMENT ON FUNCTION public.update_sync_state IS
  'Atualiza o estado de reprodução da sala. Apenas o host pode chamar. Migration 163.';

-- ─── 3. RPC: transfer_screening_host ─────────────────────────────────────────
-- Transfere o controle de host para outro participante ativo na sessão.
-- Apenas o creator original pode transferir.

CREATE OR REPLACE FUNCTION public.transfer_screening_host(
  p_session_id  UUID,
  p_new_host_id UUID
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

  -- Verificar que o novo host é participante ativo
  IF NOT EXISTS (
    SELECT 1 FROM public.call_participants
    WHERE call_session_id = p_session_id
      AND user_id         = p_new_host_id
      AND status          = 'connected'
  ) THEN
    RAISE EXCEPTION 'target_user_not_in_room';
  END IF;

  UPDATE public.call_sessions
  SET host_user_id = p_new_host_id
  WHERE id         = p_session_id
    AND creator_id = auth.uid()
    AND status     = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'permission_denied: only the creator can transfer host';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_screening_host(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION public.transfer_screening_host IS
  'Transfere o controle de host para outro participante. Apenas o creator pode chamar. Migration 163.';

-- ─── 4. RPC: get_screening_session_state ─────────────────────────────────────
-- Retorna o estado completo da sessão para novos participantes que entram.
-- Inclui: video_url, video_title, sync_position, sync_is_playing, is_host.

CREATE OR REPLACE FUNCTION public.get_screening_session_state(
  p_session_id UUID
)
RETURNS TABLE (
  session_id     UUID,
  creator_id     UUID,
  host_user_id   UUID,
  status         TEXT,
  video_url      TEXT,
  video_title    TEXT,
  sync_position  BIGINT,
  sync_is_playing BOOLEAN,
  sync_updated_at TIMESTAMPTZ,
  is_caller_host  BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cs.id                                                       AS session_id,
    cs.creator_id,
    cs.host_user_id,
    cs.status::TEXT,
    (cs.metadata->>'video_url')::TEXT                          AS video_url,
    (cs.metadata->>'video_title')::TEXT                        AS video_title,
    cs.sync_position,
    cs.sync_is_playing,
    cs.sync_updated_at,
    (cs.creator_id = auth.uid() OR cs.host_user_id = auth.uid()) AS is_caller_host
  FROM public.call_sessions cs
  WHERE cs.id = p_session_id
    AND cs.status = 'active';
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_screening_session_state(UUID) TO authenticated;

COMMENT ON FUNCTION public.get_screening_session_state IS
  'Retorna o estado completo da sessão de projeção para sincronização inicial. Migration 163.';

-- ─── 5. Garantir Realtime ativo em call_sessions ─────────────────────────────

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.call_sessions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- RESULTADO:
-- - sync_position / sync_is_playing / sync_updated_at: estado de reprodução
-- - host_user_id: controle de host transferível
-- - update_sync_state: atualiza estado (apenas host)
-- - transfer_screening_host: transfere controle (apenas creator)
-- - get_screening_session_state: estado completo para novos entrantes
-- =============================================================================
