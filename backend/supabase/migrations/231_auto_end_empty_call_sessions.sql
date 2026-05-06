-- =============================================================================
-- Migration 231: Auto-encerramento de sessões de call/projeção vazias
--
-- Problema: quando todos os participantes saem (status → 'disconnected'),
-- a sessão fica com status='active' no banco indefinidamente.
--
-- Solução: trigger AFTER UPDATE/DELETE em call_participants que verifica se
-- ainda há participantes com status='connected'. Se não houver, encerra a
-- sessão automaticamente (status='ended', is_active=FALSE, ended_at=NOW()).
--
-- Cobre:
-- - Voice chat (type='voice')
-- - Sala de Projeção (type='screening_room')
-- - Qualquer outro tipo futuro
-- =============================================================================

-- ─── Função do trigger ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_auto_end_empty_call_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session_id   UUID;
  v_active_count INT;
BEGIN
  -- Determinar o session_id afetado
  IF TG_OP = 'DELETE' THEN
    v_session_id := OLD.call_session_id;
  ELSE
    v_session_id := NEW.call_session_id;
  END IF;

  -- Contar participantes ainda conectados nesta sessão
  SELECT COUNT(*)
    INTO v_active_count
    FROM public.call_participants
   WHERE call_session_id = v_session_id
     AND status = 'connected';

  -- Se não há mais nenhum participante conectado, encerrar a sessão
  IF v_active_count = 0 THEN
    UPDATE public.call_sessions
       SET status    = 'ended',
           is_active = FALSE,
           ended_at  = NOW()
     WHERE id        = v_session_id
       AND status   != 'ended';  -- idempotente: não atualiza se já encerrada
  END IF;

  RETURN NULL; -- AFTER trigger: valor de retorno ignorado
END;
$$;

-- ─── Trigger em call_participants ────────────────────────────────────────────
-- Dispara após UPDATE (ex: status → 'disconnected') ou DELETE de participante.
DROP TRIGGER IF EXISTS trg_auto_end_empty_call_session ON public.call_participants;

CREATE TRIGGER trg_auto_end_empty_call_session
  AFTER UPDATE OF status OR DELETE
  ON public.call_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_auto_end_empty_call_session();
