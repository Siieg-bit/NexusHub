-- =============================================================================
-- Migration 082: Chat Moderation — Roles, Ban e Cover
-- Adiciona:
--   - chat_members.role TEXT ('member' | 'co_host' | 'host')
--   - chat_members.is_banned BOOLEAN
--   - chat_members.banned_until TIMESTAMPTZ (ban temporário)
--   - chat_members.ban_reason TEXT
--   - RPCs: promote_chat_cohost, demote_chat_cohost, ban_chat_member,
--           unban_chat_member, remove_chat_member, toggle_announcement_only,
--           update_chat_cover
-- =============================================================================

-- ── 1. Adicionar campos de role e ban em chat_members ──────────────────────

ALTER TABLE public.chat_members
  ADD COLUMN IF NOT EXISTS role        TEXT NOT NULL DEFAULT 'member'
    CHECK (role IN ('member', 'co_host', 'host')),
  ADD COLUMN IF NOT EXISTS is_banned   BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS banned_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ban_reason  TEXT;

-- Atualizar role do host para 'host' nos registros existentes
UPDATE public.chat_members cm
SET role = 'host'
FROM public.chat_threads ct
WHERE cm.thread_id = ct.id
  AND cm.user_id = ct.host_id
  AND cm.role = 'member';

-- Atualizar role dos co_hosts para 'co_host' nos registros existentes
UPDATE public.chat_members cm
SET role = 'co_host'
FROM public.chat_threads ct
WHERE cm.thread_id = ct.id
  AND ct.co_hosts ? cm.user_id::text
  AND cm.role = 'member';

CREATE INDEX IF NOT EXISTS idx_chat_members_role
  ON public.chat_members(thread_id, role);

CREATE INDEX IF NOT EXISTS idx_chat_members_banned
  ON public.chat_members(thread_id, is_banned)
  WHERE is_banned = TRUE;

-- ── 2. RPC: promote_chat_cohost ────────────────────────────────────────────
-- Apenas o host pode promover um membro a co_host.

CREATE OR REPLACE FUNCTION public.promote_chat_cohost(
  p_thread_id UUID,
  p_target_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_host_id UUID;
BEGIN
  IF v_caller IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT host_id INTO v_host_id FROM public.chat_threads WHERE id = p_thread_id;

  IF v_host_id IS DISTINCT FROM v_caller THEN
    RETURN json_build_object('success', false, 'error', 'not_host');
  END IF;

  IF p_target_user_id = v_caller THEN
    RETURN json_build_object('success', false, 'error', 'cannot_promote_self');
  END IF;

  -- Atualizar role em chat_members
  UPDATE public.chat_members
  SET role = 'co_host'
  WHERE thread_id = p_thread_id AND user_id = p_target_user_id AND status = 'active';

  -- Adicionar ao array co_hosts em chat_threads
  UPDATE public.chat_threads
  SET co_hosts = CASE
    WHEN co_hosts ? p_target_user_id::text THEN co_hosts
    ELSE co_hosts || to_jsonb(p_target_user_id::text)
  END
  WHERE id = p_thread_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 3. RPC: demote_chat_cohost ─────────────────────────────────────────────
-- Apenas o host pode rebaixar um co_host.

CREATE OR REPLACE FUNCTION public.demote_chat_cohost(
  p_thread_id UUID,
  p_target_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_host_id UUID;
BEGIN
  IF v_caller IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT host_id INTO v_host_id FROM public.chat_threads WHERE id = p_thread_id;

  IF v_host_id IS DISTINCT FROM v_caller THEN
    RETURN json_build_object('success', false, 'error', 'not_host');
  END IF;

  UPDATE public.chat_members
  SET role = 'member'
  WHERE thread_id = p_thread_id AND user_id = p_target_user_id;

  -- Remover do array co_hosts
  UPDATE public.chat_threads
  SET co_hosts = (
    SELECT jsonb_agg(elem)
    FROM jsonb_array_elements(co_hosts) AS elem
    WHERE elem::text != to_jsonb(p_target_user_id::text)::text
  )
  WHERE id = p_thread_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 4. RPC: ban_chat_member ────────────────────────────────────────────────
-- Host pode banir qualquer membro. Co_host pode banir apenas 'member'.

CREATE OR REPLACE FUNCTION public.ban_chat_member(
  p_thread_id      UUID,
  p_target_user_id UUID,
  p_reason         TEXT    DEFAULT NULL,
  p_duration_hours INTEGER DEFAULT NULL  -- NULL = permanente
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller      UUID := auth.uid();
  v_host_id     UUID;
  v_caller_role TEXT;
  v_target_role TEXT;
  v_banned_until TIMESTAMPTZ;
BEGIN
  IF v_caller IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT host_id INTO v_host_id FROM public.chat_threads WHERE id = p_thread_id;

  SELECT role INTO v_caller_role
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = v_caller;

  SELECT role INTO v_target_role
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = p_target_user_id;

  -- Não pode banir a si mesmo
  IF p_target_user_id = v_caller THEN
    RETURN json_build_object('success', false, 'error', 'cannot_ban_self');
  END IF;

  -- Não pode banir o host
  IF p_target_user_id = v_host_id THEN
    RETURN json_build_object('success', false, 'error', 'cannot_ban_host');
  END IF;

  -- Co_host só pode banir membros comuns
  IF v_caller_role = 'co_host' AND v_target_role != 'member' THEN
    RETURN json_build_object('success', false, 'error', 'insufficient_permission');
  END IF;

  -- Verificar permissão mínima (host ou co_host)
  IF v_caller_role NOT IN ('host', 'co_host') AND v_host_id IS DISTINCT FROM v_caller THEN
    RETURN json_build_object('success', false, 'error', 'not_moderator');
  END IF;

  -- Calcular expiração do ban
  IF p_duration_hours IS NOT NULL THEN
    v_banned_until := NOW() + (p_duration_hours || ' hours')::INTERVAL;
  END IF;

  -- Aplicar ban
  UPDATE public.chat_members
  SET
    is_banned    = TRUE,
    banned_until = v_banned_until,
    ban_reason   = p_reason,
    status       = 'active'  -- mantém na tabela para impedir reentrada
  WHERE thread_id = p_thread_id AND user_id = p_target_user_id;

  -- Se não existe linha, inserir como banido
  IF NOT FOUND THEN
    INSERT INTO public.chat_members (thread_id, user_id, is_banned, banned_until, ban_reason, status)
    VALUES (p_thread_id, p_target_user_id, TRUE, v_banned_until, p_reason, 'active')
    ON CONFLICT (thread_id, user_id) DO UPDATE
    SET is_banned = TRUE, banned_until = v_banned_until, ban_reason = p_reason;
  END IF;

  RETURN json_build_object('success', true, 'banned_until', v_banned_until);
END;
$$;

-- ── 5. RPC: unban_chat_member ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.unban_chat_member(
  p_thread_id      UUID,
  p_target_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller      UUID := auth.uid();
  v_caller_role TEXT;
BEGIN
  IF v_caller IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT role INTO v_caller_role
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = v_caller;

  IF v_caller_role NOT IN ('host', 'co_host') THEN
    RETURN json_build_object('success', false, 'error', 'not_moderator');
  END IF;

  UPDATE public.chat_members
  SET is_banned = FALSE, banned_until = NULL, ban_reason = NULL
  WHERE thread_id = p_thread_id AND user_id = p_target_user_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 6. RPC: remove_chat_member ─────────────────────────────────────────────
-- Remove (kick) um membro. Co_host pode remover membros. Host pode remover todos.

CREATE OR REPLACE FUNCTION public.remove_chat_member(
  p_thread_id      UUID,
  p_target_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller      UUID := auth.uid();
  v_host_id     UUID;
  v_caller_role TEXT;
  v_target_role TEXT;
BEGIN
  IF v_caller IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT host_id INTO v_host_id FROM public.chat_threads WHERE id = p_thread_id;

  SELECT role INTO v_caller_role
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = v_caller;

  SELECT role INTO v_target_role
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = p_target_user_id;

  IF p_target_user_id = v_caller THEN
    RETURN json_build_object('success', false, 'error', 'cannot_remove_self');
  END IF;

  IF p_target_user_id = v_host_id THEN
    RETURN json_build_object('success', false, 'error', 'cannot_remove_host');
  END IF;

  IF v_caller_role = 'co_host' AND v_target_role != 'member' THEN
    RETURN json_build_object('success', false, 'error', 'insufficient_permission');
  END IF;

  IF v_caller_role NOT IN ('host', 'co_host') AND v_host_id IS DISTINCT FROM v_caller THEN
    RETURN json_build_object('success', false, 'error', 'not_moderator');
  END IF;

  DELETE FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = p_target_user_id;

  -- Decrementar members_count
  UPDATE public.chat_threads
  SET members_count = GREATEST(0, members_count - 1)
  WHERE id = p_thread_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 7. RPC: toggle_announcement_only ──────────────────────────────────────
-- Apenas host pode bloquear/desbloquear envio de mensagens para membros.

CREATE OR REPLACE FUNCTION public.toggle_announcement_only(
  p_thread_id UUID,
  p_enabled   BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller  UUID := auth.uid();
  v_host_id UUID;
BEGIN
  IF v_caller IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT host_id INTO v_host_id FROM public.chat_threads WHERE id = p_thread_id;

  IF v_host_id IS DISTINCT FROM v_caller THEN
    RETURN json_build_object('success', false, 'error', 'not_host');
  END IF;

  UPDATE public.chat_threads
  SET is_announcement_only = p_enabled, updated_at = NOW()
  WHERE id = p_thread_id;

  RETURN json_build_object('success', true, 'is_announcement_only', p_enabled);
END;
$$;

-- ── 8. RPC: update_chat_cover ──────────────────────────────────────────────
-- Host ou co_host podem definir a capa do chat (cover_image_url).

CREATE OR REPLACE FUNCTION public.update_chat_cover(
  p_thread_id     UUID,
  p_cover_url     TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller      UUID := auth.uid();
  v_caller_role TEXT;
BEGIN
  IF v_caller IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT role INTO v_caller_role
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = v_caller;

  IF v_caller_role NOT IN ('host', 'co_host') THEN
    RETURN json_build_object('success', false, 'error', 'not_moderator');
  END IF;

  UPDATE public.chat_threads
  SET cover_image_url = p_cover_url, updated_at = NOW()
  WHERE id = p_thread_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 9. RPC: update_chat_title ──────────────────────────────────────────────
-- Host ou co_host podem renomear o chat.

CREATE OR REPLACE FUNCTION public.update_chat_title(
  p_thread_id UUID,
  p_title     TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller      UUID := auth.uid();
  v_caller_role TEXT;
BEGIN
  IF v_caller IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF p_title IS NULL OR trim(p_title) = '' THEN
    RETURN json_build_object('success', false, 'error', 'title_required');
  END IF;

  SELECT role INTO v_caller_role
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = v_caller;

  IF v_caller_role NOT IN ('host', 'co_host') THEN
    RETURN json_build_object('success', false, 'error', 'not_moderator');
  END IF;

  UPDATE public.chat_threads
  SET title = trim(p_title), updated_at = NOW()
  WHERE id = p_thread_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 10. Verificar ban ao entrar no chat (join_public_chat_with_reputation) ─
-- Adicionar verificação de ban na RPC de join existente

CREATE OR REPLACE FUNCTION public.join_public_chat_with_reputation(
  p_thread_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_thread       RECORD;
  v_existing     RECORD;
  v_community_id UUID;
  v_is_member    BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT * INTO v_thread FROM public.chat_threads WHERE id = p_thread_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'thread_not_found');
  END IF;

  -- Verificar se está banido
  SELECT * INTO v_existing
  FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = v_user_id;

  IF FOUND AND v_existing.is_banned = TRUE THEN
    IF v_existing.banned_until IS NULL OR v_existing.banned_until > NOW() THEN
      RETURN json_build_object('success', false, 'error', 'banned',
        'banned_until', v_existing.banned_until,
        'ban_reason', v_existing.ban_reason);
    ELSE
      -- Ban expirado: desbanir automaticamente
      UPDATE public.chat_members
      SET is_banned = FALSE, banned_until = NULL
      WHERE thread_id = p_thread_id AND user_id = v_user_id;
    END IF;
  END IF;

  -- Verificar membership na comunidade (se aplicável)
  v_community_id := v_thread.community_id;
  IF v_community_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = v_community_id
        AND user_id = v_user_id
        AND is_banned = FALSE
    ) INTO v_is_member;
    IF NOT v_is_member THEN
      SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = v_user_id AND (is_team_admin = TRUE OR is_team_moderator = TRUE)
      ) INTO v_is_member;
    END IF;
    IF NOT v_is_member THEN
      RETURN json_build_object('success', false, 'error', 'not_community_member');
    END IF;
  END IF;

  -- Inserir ou reativar membership
  INSERT INTO public.chat_members (thread_id, user_id, status, role)
  VALUES (p_thread_id, v_user_id, 'active', 'member')
  ON CONFLICT (thread_id, user_id) DO UPDATE
  SET status = 'active';

  -- Incrementar members_count se novo
  IF NOT FOUND THEN
    UPDATE public.chat_threads
    SET members_count = members_count + 1
    WHERE id = p_thread_id;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
