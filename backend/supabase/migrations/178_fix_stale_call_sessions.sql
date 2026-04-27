-- =============================================================================
-- Migration 178: Corrigir sessões de chamada fantasmas (stale call sessions)
-- =============================================================================
-- Problema: sessões de call_sessions ficam com status='active' indefinidamente
-- quando o app fecha sem chamar end_call_session. Isso impede criar novas chamadas
-- no mesmo thread (erro call_already_active).
--
-- Solução:
-- 1. Encerrar sessões ativas com mais de 4 horas sem heartbeat (stale sessions)
-- 2. Adicionar FK call_participants.user_id → profiles.id para PostgREST joins
-- 3. Melhorar create_call_session para auto-encerrar sessões stale antes de bloquear
-- =============================================================================

-- 1. Encerrar sessões fantasmas imediatamente (limpeza de produção)
UPDATE public.call_sessions
SET
  status    = 'ended',
  is_active = FALSE,
  ended_at  = NOW()
WHERE COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
  AND started_at < NOW() - INTERVAL '4 hours';

-- 2. Adicionar FK call_participants.user_id → profiles.id (necessário para PostgREST joins)
ALTER TABLE public.call_participants
  ADD COLUMN IF NOT EXISTS stage_role TEXT DEFAULT 'audience',
  ADD COLUMN IF NOT EXISTS is_muted BOOLEAN DEFAULT FALSE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'call_participants_user_id_fkey'
      AND table_name = 'call_participants'
      AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.call_participants
      ADD CONSTRAINT call_participants_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- 3. Atualizar create_call_session para auto-encerrar sessões stale (> 4h) antes de bloquear
CREATE OR REPLACE FUNCTION public.create_call_session(
  p_thread_id UUID,
  p_type      TEXT DEFAULT 'voice'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_call_type  INT;
  v_session_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_type NOT IN ('voice', 'video', 'screening_room') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_call_type');
  END IF;

  -- Auto-encerrar sessões stale (ativas há mais de 4 horas) antes de verificar conflito
  UPDATE public.call_sessions
  SET
    status    = 'ended',
    is_active = FALSE,
    ended_at  = NOW()
  WHERE thread_id = p_thread_id
    AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
    AND started_at < NOW() - INTERVAL '4 hours';

  -- Verificar membership
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id   = v_user_id
      AND status    = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Verificar sessão já ativa (após limpeza de stale)
  IF EXISTS (
    SELECT 1 FROM public.call_sessions
    WHERE thread_id = p_thread_id
      AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'call_already_active');
  END IF;

  -- Mapear tipo textual para inteiro legado
  v_call_type := CASE p_type
    WHEN 'video'          THEN 2
    WHEN 'screening_room' THEN 4
    ELSE 1
  END;

  INSERT INTO public.call_sessions (
    thread_id, call_type, host_id, creator_id,
    type, status, is_active, started_at, created_at
  ) VALUES (
    p_thread_id, v_call_type, v_user_id, v_user_id,
    p_type, 'active', TRUE, NOW(), NOW()
  )
  RETURNING id INTO v_session_id;

  -- Criador entra como HOST com microfone ativo
  INSERT INTO public.call_participants
    (call_session_id, user_id, status, stage_role, is_muted, joined_at)
  VALUES
    (v_session_id, v_user_id, 'connected', 'host', false, NOW())
  ON CONFLICT (call_session_id, user_id) DO UPDATE SET
    status     = 'connected',
    stage_role = 'host',
    is_muted   = false,
    joined_at  = NOW(),
    left_at    = NULL;

  RETURN jsonb_build_object('success', true, 'session_id', v_session_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_call_session(UUID, TEXT) TO authenticated;

-- 4. RPC utilitária para limpar sessões stale manualmente (uso admin/debug)
CREATE OR REPLACE FUNCTION public.cleanup_stale_call_sessions(
  p_max_age_hours INT DEFAULT 4
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE public.call_sessions
  SET
    status    = 'ended',
    is_active = FALSE,
    ended_at  = COALESCE(ended_at, NOW())
  WHERE COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
    AND started_at < NOW() - (p_max_age_hours || ' hours')::INTERVAL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.cleanup_stale_call_sessions(INT) TO authenticated;
