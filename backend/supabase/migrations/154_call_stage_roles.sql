-- ============================================================================
-- Migration 154: Stage Roles no sistema de chamadas
--
-- Adiciona suporte a roles (host/speaker/listener) e mão levantada
-- diretamente na tabela call_participants, unificando o sistema de
-- Voice Chat e o modelo de palco (FreeTalk) em uma única estrutura.
--
-- Mudanças:
--   • call_participants.stage_role  TEXT  ('host'|'speaker'|'listener')
--   • call_participants.hand_raised BOOLEAN DEFAULT false
--   • call_participants.is_muted    BOOLEAN DEFAULT false  (já pode existir)
--   • RPCs novas: raise_hand_call, accept_call_speaker,
--                 step_down_call, mute_call_participant, kick_call_participant
--   • RPC atualizada: create_call_session — define stage_role='host' para criador
--   • RPC atualizada: join_call_session   — define stage_role por tipo de sessão
-- ============================================================================

-- ─── Colunas novas em call_participants ──────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'call_participants'
      AND column_name  = 'stage_role'
  ) THEN
    ALTER TABLE public.call_participants
      ADD COLUMN stage_role TEXT NOT NULL DEFAULT 'speaker'
        CHECK (stage_role IN ('host', 'speaker', 'listener'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'call_participants'
      AND column_name  = 'hand_raised'
  ) THEN
    ALTER TABLE public.call_participants
      ADD COLUMN hand_raised BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'call_participants'
      AND column_name  = 'is_muted'
  ) THEN
    ALTER TABLE public.call_participants
      ADD COLUMN is_muted BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

-- Backfill: criador de cada sessão ativa vira 'host'
UPDATE public.call_participants cp
SET stage_role = 'host'
FROM public.call_sessions cs
WHERE cp.call_session_id = cs.id
  AND cp.user_id = COALESCE(cs.creator_id, cs.host_id)
  AND cp.stage_role = 'speaker';

-- ─── RPC: create_call_session (atualizada) ────────────────────────────────────
DROP FUNCTION IF EXISTS public.create_call_session(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.create_call_session(
  p_thread_id UUID,
  p_type      TEXT DEFAULT 'voice'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_session_id UUID;
  v_call_type  INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_type NOT IN ('voice', 'video', 'screening_room') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_call_type');
  END IF;

  -- Mapear tipo textual para inteiro legado
  v_call_type := CASE p_type
    WHEN 'video'         THEN 2
    WHEN 'screening_room' THEN 4
    ELSE 1
  END;

  -- Verificar membership
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id   = v_user_id
      AND status    = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Verificar sessão já ativa
  IF EXISTS (
    SELECT 1 FROM public.call_sessions
    WHERE thread_id = p_thread_id
      AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'call_already_active');
  END IF;

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

-- ─── RPC: join_call_session (atualizada) ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.join_call_session(UUID);
CREATE OR REPLACE FUNCTION public.join_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_thread_id UUID;
  v_type      TEXT;
  v_role      TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT thread_id, type INTO v_thread_id, v_type
  FROM public.call_sessions
  WHERE id = p_session_id
    AND COALESCE(status, CASE WHEN COALESCE(is_active, FALSE) THEN 'active' ELSE 'ended' END) = 'active';

  IF v_thread_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  -- Verificar membership no chat
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = v_thread_id
      AND user_id   = v_user_id
      AND status    = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Role padrão ao entrar:
  -- voice/screening_room em chat privado → speaker (todos falam)
  -- Pode ser rebaixado pelo host depois
  v_role := 'speaker';

  INSERT INTO public.call_participants
    (call_session_id, user_id, status, stage_role, is_muted, joined_at)
  VALUES
    (p_session_id, v_user_id, 'connected', v_role, false, NOW())
  ON CONFLICT (call_session_id, user_id) DO UPDATE SET
    status     = 'connected',
    stage_role = CASE
      WHEN call_participants.stage_role = 'host' THEN 'host'
      ELSE v_role
    END,
    joined_at  = NOW(),
    left_at    = NULL;

  RETURN jsonb_build_object('success', true, 'stage_role', v_role);
END;
$$;
GRANT EXECUTE ON FUNCTION public.join_call_session(UUID) TO authenticated;

-- ─── RPC: raise_hand_call ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.raise_hand_call(
  p_session_id UUID,
  p_raised     BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_role     TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT stage_role INTO v_role
  FROM public.call_participants
  WHERE call_session_id = p_session_id AND user_id = v_user_id AND status = 'connected';

  IF v_role IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_in_call');
  END IF;

  -- Só listeners podem levantar a mão
  IF v_role NOT IN ('listener', 'speaker') THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_on_stage');
  END IF;

  UPDATE public.call_participants
  SET hand_raised = p_raised
  WHERE call_session_id = p_session_id AND user_id = v_user_id;

  RETURN jsonb_build_object('success', true, 'hand_raised', p_raised);
END;
$$;
GRANT EXECUTE ON FUNCTION public.raise_hand_call(UUID, BOOLEAN) TO authenticated;

-- ─── RPC: accept_call_speaker ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.accept_call_speaker(
  p_session_id    UUID,
  p_target_user   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_host_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar se quem aceita é host
  SELECT stage_role INTO v_host_role
  FROM public.call_participants
  WHERE call_session_id = p_session_id AND user_id = v_user_id AND status = 'connected';

  IF v_host_role <> 'host' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_host');
  END IF;

  UPDATE public.call_participants
  SET stage_role  = 'speaker',
      hand_raised = false,
      is_muted    = false
  WHERE call_session_id = p_session_id
    AND user_id         = p_target_user
    AND status          = 'connected';

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.accept_call_speaker(UUID, UUID) TO authenticated;

-- ─── RPC: step_down_call ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.step_down_call(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  UPDATE public.call_participants
  SET stage_role  = 'listener',
      is_muted    = true,
      hand_raised = false
  WHERE call_session_id = p_session_id
    AND user_id         = v_user_id
    AND stage_role      = 'speaker';

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.step_down_call(UUID) TO authenticated;

-- ─── RPC: mute_call_participant ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mute_call_participant(
  p_session_id  UUID,
  p_target_user UUID,
  p_muted       BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_host_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Pode mutar a si mesmo ou ser host
  IF v_user_id <> p_target_user THEN
    SELECT stage_role INTO v_host_role
    FROM public.call_participants
    WHERE call_session_id = p_session_id AND user_id = v_user_id AND status = 'connected';

    IF v_host_role <> 'host' THEN
      RETURN jsonb_build_object('success', false, 'error', 'not_host');
    END IF;
  END IF;

  UPDATE public.call_participants
  SET is_muted = p_muted
  WHERE call_session_id = p_session_id
    AND user_id         = p_target_user
    AND status          = 'connected';

  RETURN jsonb_build_object('success', true, 'is_muted', p_muted);
END;
$$;
GRANT EXECUTE ON FUNCTION public.mute_call_participant(UUID, UUID, BOOLEAN) TO authenticated;

-- ─── RPC: kick_call_participant ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kick_call_participant(
  p_session_id  UUID,
  p_target_user UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_host_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT stage_role INTO v_host_role
  FROM public.call_participants
  WHERE call_session_id = p_session_id AND user_id = v_user_id AND status = 'connected';

  IF v_host_role <> 'host' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_host');
  END IF;

  -- Não pode expulsar a si mesmo
  IF p_target_user = v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_kick_self');
  END IF;

  UPDATE public.call_participants
  SET status   = 'disconnected',
      left_at  = NOW()
  WHERE call_session_id = p_session_id
    AND user_id         = p_target_user;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.kick_call_participant(UUID, UUID) TO authenticated;

-- ─── Realtime: publicar call_participants ─────────────────────────────────────
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.call_participants;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
