-- =============================================================================
-- Migration 232: Corrigir join_call_session — stage_role='speaker' ao entrar
--
-- Problema raiz:
--   A RPC join_call_session no banco é a versão antiga (migration 046) que
--   insere sem stage_role, usando o DEFAULT 'audience' da coluna.
--   Isso faz com que participantes que sobem ao palco apareçam com
--   stage_role='audience' em vez de 'speaker', e o speakers getter do Flutter
--   filtra apenas 'host', 'speaker' e null — portanto 'audience' não aparece.
--
-- Soluções:
--   1. Corrigir o DEFAULT da coluna stage_role para 'speaker'
--   2. Recriar join_call_session com stage_role='speaker' explícito
--   3. Backfill: atualizar participantes com stage_role='audience' que não são
--      host para 'speaker' (corrige dados históricos)
-- =============================================================================

-- ─── 1. Corrigir o DEFAULT da coluna stage_role ───────────────────────────────
ALTER TABLE public.call_participants
  ALTER COLUMN stage_role SET DEFAULT 'speaker';

-- ─── 2. Backfill: corrigir participantes com stage_role='audience' ────────────
-- Participantes com 'audience' que não são host → promover para 'speaker'
-- (dados históricos inseridos com o DEFAULT errado)
UPDATE public.call_participants
SET stage_role = 'speaker'
WHERE stage_role = 'audience'
  AND status = 'connected';

-- ─── 3. Recriar join_call_session com stage_role='speaker' explícito ──────────
DROP FUNCTION IF EXISTS public.join_call_session(UUID);
CREATE OR REPLACE FUNCTION public.join_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

  -- Buscar thread e tipo da sessão (aceita status='active' OU is_active=TRUE legado)
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

  -- Role padrão ao entrar: 'speaker' (todos podem falar em voice/screening_room)
  -- Pode ser rebaixado pelo host depois via step_down_call ou kick
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
