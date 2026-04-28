-- =============================================================================
-- Migration 181: Corrigir erro call_already_active em chamadas de voz
-- =============================================================================
-- Problema raiz:
--   1. O screening_room_provider.dart cria sessões com INSERT direto (sem RPC),
--      gerando sessões que nunca são encerradas corretamente quando o app fecha.
--   2. O RPC create_call_session (migration 178) bloqueia QUALQUER tipo de
--      chamada se houver qualquer sessão ativa no thread, independente do tipo.
--      Ou seja, uma sessão screening_room fantasma bloqueia chamadas de voz.
--   3. O end_screening_session (migration 059) só encerra sessões com
--      status='active', ignorando sessões legadas com is_active=TRUE e
--      status=NULL — essas ficam presas indefinidamente.
--   4. O threshold de stale (4h na migration 178) é muito alto para uso real.
--
-- Soluções:
--   1. Encerrar imediatamente TODAS as sessões fantasmas do banco de produção.
--   2. Corrigir create_call_session para verificar conflito POR TIPO, não
--      globalmente — uma sessão screening_room não bloqueia chamadas voice/video.
--   3. Reduzir threshold de stale para 1 hora.
--   4. Corrigir end_screening_session para encerrar também sessões legadas
--      (is_active=TRUE com status NULL).
--   5. Criar RPC create_screening_session para substituir o INSERT direto do
--      screening_room_provider.dart, seguindo a regra de ouro de mutações.
-- =============================================================================

-- ─── 1. Limpeza imediata de sessões fantasmas em produção ─────────────────────
-- Encerrar TODAS as sessões ativas com mais de 1 hora sem encerramento explícito.
UPDATE public.call_sessions
SET
  status    = 'ended',
  is_active = FALSE,
  ended_at  = NOW()
WHERE COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
  AND started_at < NOW() - INTERVAL '1 hour';

-- ─── 2. Corrigir create_call_session: verificar conflito POR TIPO ─────────────
-- Agora uma sessão screening_room NÃO bloqueia chamadas voice/video e vice-versa.
-- O threshold de stale também é reduzido para 1 hora.
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

  -- Auto-encerrar sessões stale do MESMO TIPO (ativas há mais de 1 hora)
  UPDATE public.call_sessions
  SET
    status    = 'ended',
    is_active = FALSE,
    ended_at  = NOW()
  WHERE thread_id = p_thread_id
    AND COALESCE(type, CASE call_type WHEN 2 THEN 'video' WHEN 4 THEN 'screening_room' ELSE 'voice' END) = p_type
    AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
    AND started_at < NOW() - INTERVAL '1 hour';

  -- Verificar membership
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id   = v_user_id
      AND status    = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Verificar sessão já ativa DO MESMO TIPO (após limpeza de stale)
  -- Sessões de outros tipos (ex: screening_room) NÃO bloqueiam chamadas voice/video.
  IF EXISTS (
    SELECT 1 FROM public.call_sessions
    WHERE thread_id = p_thread_id
      AND COALESCE(type, CASE call_type WHEN 2 THEN 'video' WHEN 4 THEN 'screening_room' ELSE 'voice' END) = p_type
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

-- ─── 3. Corrigir end_screening_session: encerrar também sessões legadas ────────
-- A versão anterior (migration 059) só encerrava sessões com status='active',
-- ignorando sessões legadas com is_active=TRUE e status=NULL.
CREATE OR REPLACE FUNCTION public.end_screening_session(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Encerrar sessão — suporta tanto status='active' quanto is_active=TRUE (legado)
  UPDATE public.call_sessions
  SET
    status    = 'ended',
    is_active = FALSE,
    ended_at  = NOW()
  WHERE id = p_session_id
    AND COALESCE(creator_id, host_id) = v_user_id
    AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active';

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

-- ─── 4. Criar RPC create_screening_session (substitui INSERT direto) ──────────
-- Segue a regra de ouro: mutações via RPC SECURITY DEFINER.
-- Valida membership, encerra sessões stale do mesmo tipo, verifica conflito
-- e cria a sessão com metadados iniciais.
CREATE OR REPLACE FUNCTION public.create_screening_session(
  p_thread_id         UUID,
  p_video_url         TEXT    DEFAULT '',
  p_video_title       TEXT    DEFAULT '',
  p_video_thumbnail   TEXT    DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_session_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Auto-encerrar sessões stale de screening_room (> 1 hora)
  UPDATE public.call_sessions
  SET
    status    = 'ended',
    is_active = FALSE,
    ended_at  = NOW()
  WHERE thread_id = p_thread_id
    AND COALESCE(type, CASE call_type WHEN 4 THEN 'screening_room' ELSE 'voice' END) = 'screening_room'
    AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
    AND started_at < NOW() - INTERVAL '1 hour';

  -- Verificar membership
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id   = v_user_id
      AND status    = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Verificar sessão de screening_room já ativa
  IF EXISTS (
    SELECT 1 FROM public.call_sessions
    WHERE thread_id = p_thread_id
      AND COALESCE(type, CASE call_type WHEN 4 THEN 'screening_room' ELSE 'voice' END) = 'screening_room'
      AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'screening_room_already_active');
  END IF;

  INSERT INTO public.call_sessions (
    thread_id, call_type, host_id, creator_id,
    type, status, is_active, started_at, created_at,
    metadata
  ) VALUES (
    p_thread_id, 4, v_user_id, v_user_id,
    'screening_room', 'active', TRUE, NOW(), NOW(),
    jsonb_build_object(
      'video_url',       p_video_url,
      'video_title',     p_video_title,
      'video_thumbnail', p_video_thumbnail
    )
  )
  RETURNING id INTO v_session_id;

  -- Criador entra como HOST
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
GRANT EXECUTE ON FUNCTION public.create_screening_session(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ─── 5. Atualizar cleanup_stale_call_sessions para threshold de 1 hora ────────
CREATE OR REPLACE FUNCTION public.cleanup_stale_call_sessions(
  p_max_age_hours INT DEFAULT 1
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
