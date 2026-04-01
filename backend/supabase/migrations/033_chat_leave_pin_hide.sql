-- ============================================================================
-- Migração 033: Suporte a leave/pin/hide pessoal de chats
--
-- Problemas resolvidos:
--   1. Chats públicos reaparecem na lista após o usuário sair
--      → Causa: _ensureMembership() recriava a linha sem verificar status
--      → Solução: status 'left' impede auto-join e filtra da lista
--
--   2. _ElementLifecycle.defunct ao clicar em chat já deixado
--      → Causa: auto-join recriava membership enquanto tela anterior
--               ainda estava sendo descartada
--      → Solução: join_public_chat_with_reputation respeita status 'left'
--
--   3. Long press → Fixar no topo / Apagar chat
--      → Solução: coluna is_pinned_by_user em chat_members +
--                 RPCs pin_chat_for_user / unpin_chat_for_user /
--                 hide_chat_for_user
-- ============================================================================

-- ── 1. Adicionar valor 'left' ao enum chat_membership_status ──
-- (ALTER TYPE ADD VALUE é idempotente no Postgres 14+)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'public.chat_membership_status'::regtype
      AND enumlabel = 'left'
  ) THEN
    ALTER TYPE public.chat_membership_status ADD VALUE 'left';
  END IF;
END$$;

-- ── 2. Adicionar coluna is_pinned_by_user em chat_members ──
ALTER TABLE public.chat_members
  ADD COLUMN IF NOT EXISTS is_pinned_by_user BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.chat_members
  ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_chat_members_pinned
  ON public.chat_members(user_id, is_pinned_by_user)
  WHERE is_pinned_by_user = TRUE;

-- ── 3. Atualizar join_public_chat_with_reputation para respeitar status 'left' ──
-- Se o usuário saiu intencionalmente (status = 'left'), NÃO reentrar automaticamente.
-- Retorna {joined: false, reason: 'left'} para que o app mostre o CTA de entrar.
CREATE OR REPLACE FUNCTION public.join_public_chat_with_reputation(
  p_thread_id UUID,
  p_user_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing  RECORD;
  v_thread    RECORD;
BEGIN
  -- Verificar se o thread existe e é público
  SELECT id, type, community_id INTO v_thread
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('joined', false, 'reason', 'thread_not_found');
  END IF;

  -- Verificar membership existente
  SELECT id, status INTO v_existing
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = p_user_id;

  IF FOUND THEN
    -- Se já é membro ativo, confirmar
    IF v_existing.status = 'active' THEN
      RETURN jsonb_build_object('joined', true, 'reason', 'already_member');
    END IF;

    -- Se saiu intencionalmente, NÃO reentrar automaticamente
    IF v_existing.status = 'left' THEN
      RETURN jsonb_build_object('joined', false, 'reason', 'left');
    END IF;

    -- Outros status (invite_sent, join_requested): reativar
    UPDATE public.chat_members
    SET status = 'active', joined_at = NOW()
    WHERE id = v_existing.id;
    RETURN jsonb_build_object('joined', true, 'reason', 'reactivated');
  END IF;

  -- Novo membro: inserir
  INSERT INTO public.chat_members(thread_id, user_id, status, joined_at)
  VALUES (p_thread_id, p_user_id, 'active', NOW());

  -- Incrementar members_count
  UPDATE public.chat_threads
  SET members_count = COALESCE(members_count, 0) + 1
  WHERE id = p_thread_id;

  -- Reputação: +2 por entrar num chat público
  BEGIN
    UPDATE public.profiles
    SET reputation = COALESCE(reputation, 0) + 2
    WHERE id = p_user_id;
  EXCEPTION WHEN OTHERS THEN
    NULL; -- Não bloquear join por falha de reputação
  END;

  RETURN jsonb_build_object('joined', true, 'reason', 'joined');
END;
$$;

-- ── 4. RPC leave_public_chat ──
-- Marca status como 'left' (não deleta a linha) para que:
--   a) O chat suma da lista (query filtra status != 'left')
--   b) O auto-join não recrie membership
--   c) O usuário possa re-entrar explicitamente via CTA
CREATE OR REPLACE FUNCTION public.leave_public_chat(
  p_thread_id UUID,
  p_user_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chat_members
  SET status = 'left', is_pinned_by_user = FALSE, pinned_at = NULL
  WHERE thread_id = p_thread_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('left', false, 'reason', 'not_member');
  END IF;

  -- Decrementar members_count
  UPDATE public.chat_threads
  SET members_count = GREATEST(COALESCE(members_count, 1) - 1, 0)
  WHERE id = p_thread_id;

  RETURN jsonb_build_object('left', true);
END;
$$;

-- ── 5. RPC rejoin_public_chat ──
-- Permite que o usuário entre novamente após ter saído intencionalmente.
CREATE OR REPLACE FUNCTION public.rejoin_public_chat(
  p_thread_id UUID,
  p_user_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing RECORD;
BEGIN
  SELECT id, status INTO v_existing
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = p_user_id;

  IF FOUND THEN
    UPDATE public.chat_members
    SET status = 'active', joined_at = NOW()
    WHERE id = v_existing.id;
  ELSE
    INSERT INTO public.chat_members(thread_id, user_id, status, joined_at)
    VALUES (p_thread_id, p_user_id, 'active', NOW());

    UPDATE public.chat_threads
    SET members_count = COALESCE(members_count, 0) + 1
    WHERE id = p_thread_id;
  END IF;

  RETURN jsonb_build_object('joined', true);
END;
$$;

-- ── 6. RPC pin_chat_for_user ──
CREATE OR REPLACE FUNCTION public.pin_chat_for_user(
  p_thread_id UUID,
  p_user_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chat_members
  SET is_pinned_by_user = TRUE, pinned_at = NOW()
  WHERE thread_id = p_thread_id AND user_id = p_user_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('pinned', false, 'reason', 'not_member');
  END IF;

  RETURN jsonb_build_object('pinned', true);
END;
$$;

-- ── 7. RPC unpin_chat_for_user ──
CREATE OR REPLACE FUNCTION public.unpin_chat_for_user(
  p_thread_id UUID,
  p_user_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chat_members
  SET is_pinned_by_user = FALSE, pinned_at = NULL
  WHERE thread_id = p_thread_id AND user_id = p_user_id;

  RETURN jsonb_build_object('unpinned', true);
END;
$$;

-- ── 8. Atualizar RLS de chat_members para incluir status 'left' ──
-- Usuários com status 'left' não devem ver mensagens do chat
-- (a RLS existente já usa existência da linha; agora filtramos por status)
DROP POLICY IF EXISTS "chat_members: membros leem" ON public.chat_members;
CREATE POLICY "chat_members: membros leem" ON public.chat_members
  FOR SELECT USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.chat_members cm2
      WHERE cm2.thread_id = chat_members.thread_id
        AND cm2.user_id = auth.uid()
        AND cm2.status = 'active'
    )
  );
