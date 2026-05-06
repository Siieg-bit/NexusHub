-- =============================================================================
-- Migration 233: Voice Chat aberto a todos + host da call = host do chat
--
-- Mudanças:
-- 1. Adiciona chat_threads.is_voice_open_to_all (BOOLEAN DEFAULT false)
--    Quando true, qualquer membro pode iniciar o voice chat.
--    Quando false (padrão), apenas o host/co-host pode iniciar.
--
-- 2. Recria create_call_session para:
--    a) Validar permissão de início baseada em is_voice_open_to_all
--    b) Inserir o host do chat como stage_role='host' (mesmo que não seja
--       quem iniciou a call)
--    c) Inserir o iniciador como stage_role='speaker' se não for o host do chat
-- =============================================================================

-- ─── 1. Adicionar coluna is_voice_open_to_all ─────────────────────────────
ALTER TABLE public.chat_threads
  ADD COLUMN IF NOT EXISTS is_voice_open_to_all BOOLEAN NOT NULL DEFAULT false;

-- ─── 2. Recriar create_call_session ──────────────────────────────────────
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
  v_user_id          UUID := auth.uid();
  v_call_type        INT;
  v_session_id       UUID;
  v_thread_host_id   UUID;
  v_is_open_to_all   BOOLEAN;
  v_is_host_or_cohost BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_type NOT IN ('voice', 'video', 'screening_room') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_call_type');
  END IF;

  -- Carregar configurações do chat
  SELECT
    host_id,
    COALESCE(is_voice_open_to_all, false)
  INTO v_thread_host_id, v_is_open_to_all
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF v_thread_host_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'thread_not_found');
  END IF;

  -- Verificar membership
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id   = v_user_id
      AND status    = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Verificar permissão para iniciar
  -- Host e co-hosts sempre podem iniciar.
  -- Membros comuns só podem se is_voice_open_to_all = true.
  v_is_host_or_cohost := (v_user_id = v_thread_host_id) OR EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id   = v_user_id
      AND role IN ('host', 'co_host')
  );

  IF NOT v_is_host_or_cohost AND NOT v_is_open_to_all THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
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

  -- Verificar sessão já ativa DO MESMO TIPO (após limpeza de stale)
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

  -- Criar a sessão.
  -- host_id e creator_id = host do chat (não necessariamente quem iniciou).
  -- Isso garante que o host do chat sempre é o "dono" da call.
  INSERT INTO public.call_sessions (
    thread_id, call_type, host_id, creator_id,
    type, status, is_active, started_at, created_at
  ) VALUES (
    p_thread_id, v_call_type, v_thread_host_id, v_thread_host_id,
    p_type, 'active', TRUE, NOW(), NOW()
  )
  RETURNING id INTO v_session_id;

  -- Inserir o HOST DO CHAT como stage_role='host' (pode não estar online)
  -- Usamos ON CONFLICT para ser idempotente caso ele já exista.
  INSERT INTO public.call_participants
    (call_session_id, user_id, status, stage_role, is_muted, joined_at)
  VALUES
    (v_session_id, v_thread_host_id, 'disconnected', 'host', false, NOW())
  ON CONFLICT (call_session_id, user_id) DO UPDATE SET
    stage_role = 'host';

  -- Se quem iniciou NÃO é o host do chat, inseri-lo como speaker conectado
  IF v_user_id <> v_thread_host_id THEN
    INSERT INTO public.call_participants
      (call_session_id, user_id, status, stage_role, is_muted, joined_at)
    VALUES
      (v_session_id, v_user_id, 'connected', 'speaker', false, NOW())
    ON CONFLICT (call_session_id, user_id) DO UPDATE SET
      status     = 'connected',
      stage_role = 'speaker',
      is_muted   = false,
      joined_at  = NOW(),
      left_at    = NULL;
  ELSE
    -- Quem iniciou É o host do chat: atualizar para 'connected'
    UPDATE public.call_participants
    SET status   = 'connected',
        is_muted = false,
        joined_at = NOW(),
        left_at   = NULL
    WHERE call_session_id = v_session_id
      AND user_id         = v_thread_host_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'session_id', v_session_id);
END;
$$;

-- ─── 3. Atualizar end_call_session para aceitar host do chat como dono ────
-- O host do chat pode encerrar a call mesmo que não seja o creator_id original.
CREATE OR REPLACE FUNCTION public.end_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_owner_id       UUID;
  v_thread_host_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Buscar dono da sessão e host do chat
  SELECT
    COALESCE(cs.creator_id, cs.host_id),
    ct.host_id
  INTO v_owner_id, v_thread_host_id
  FROM public.call_sessions cs
  JOIN public.chat_threads ct ON ct.id = cs.thread_id
  WHERE cs.id = p_session_id
    AND COALESCE(cs.status, CASE WHEN COALESCE(cs.is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active';

  IF v_owner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  -- Permitir encerramento: dono da sessão OU host do chat
  IF v_user_id <> v_owner_id AND v_user_id <> v_thread_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  UPDATE public.call_participants
  SET status = 'disconnected',
      left_at = NOW()
  WHERE call_session_id = p_session_id
    AND status = 'connected';

  UPDATE public.call_sessions
  SET status    = 'ended',
      is_active = FALSE,
      ended_at  = NOW()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── 4. Atualizar join_call_session para inserir speaker (não host) ────────
-- Garante que quem entra via "Subir ao palco" é inserido como 'speaker'.
-- O host do chat que entra é atualizado para 'connected' mantendo 'host'.
CREATE OR REPLACE FUNCTION public.join_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_thread_id      UUID;
  v_thread_host_id UUID;
  v_stage_role     TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Buscar thread_id e host do chat
  SELECT cs.thread_id, ct.host_id
  INTO v_thread_id, v_thread_host_id
  FROM public.call_sessions cs
  JOIN public.chat_threads ct ON ct.id = cs.thread_id
  WHERE cs.id = p_session_id
    AND COALESCE(cs.status, CASE WHEN COALESCE(cs.is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active';

  IF v_thread_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  -- Verificar membership
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = v_thread_id
      AND user_id   = v_user_id
      AND status    = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Determinar stage_role: host do chat → 'host', demais → 'speaker'
  v_stage_role := CASE WHEN v_user_id = v_thread_host_id THEN 'host' ELSE 'speaker' END;

  INSERT INTO public.call_participants
    (call_session_id, user_id, status, stage_role, is_muted, joined_at)
  VALUES
    (p_session_id, v_user_id, 'connected', v_stage_role, false, NOW())
  ON CONFLICT (call_session_id, user_id) DO UPDATE SET
    status     = 'connected',
    stage_role = v_stage_role,
    is_muted   = false,
    joined_at  = NOW(),
    left_at    = NULL;

  RETURN jsonb_build_object('success', true);
END;
$$;
