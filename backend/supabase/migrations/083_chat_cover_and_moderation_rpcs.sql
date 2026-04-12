-- ============================================================
-- Migration 083: Chat Cover & Moderation RPCs
-- ============================================================

-- RPC: Atualiza a capa (cover_image_url) de um chat thread
-- Apenas host ou co_host podem alterar
DROP FUNCTION IF EXISTS public.update_chat_cover(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.update_chat_cover(
  p_thread_id UUID,
  p_cover_url TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_host_id UUID;
  v_co_hosts JSONB;
BEGIN
  SELECT host_id, co_hosts INTO v_host_id, v_co_hosts
  FROM chat_threads WHERE id = p_thread_id;

  IF v_host_id IS NULL THEN
    RAISE EXCEPTION 'Chat não encontrado';
  END IF;

  IF v_caller_id != v_host_id AND NOT (v_co_hosts ? v_caller_id::TEXT) THEN
    RAISE EXCEPTION 'Permissão negada: apenas host ou co_host podem alterar a capa';
  END IF;

  UPDATE chat_threads
  SET cover_image_url = p_cover_url,
      updated_at = NOW()
  WHERE id = p_thread_id;
END;
$$;

-- RPC: Alterna modo somente-anúncio (is_announcement_only)
-- Apenas host pode alterar
DROP FUNCTION IF EXISTS public.toggle_announcement_only(UUID, BOOLEAN);
CREATE OR REPLACE FUNCTION public.toggle_announcement_only(
  p_thread_id UUID,
  p_value BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_host_id UUID;
BEGIN
  SELECT host_id INTO v_host_id
  FROM chat_threads WHERE id = p_thread_id;

  IF v_caller_id != v_host_id THEN
    RAISE EXCEPTION 'Permissão negada: apenas o host pode alterar o modo anúncio';
  END IF;

  UPDATE chat_threads
  SET is_announcement_only = p_value,
      updated_at = NOW()
  WHERE id = p_thread_id;
END;
$$;

-- RPC: Promove membro a co_host
-- Apenas host pode promover
DROP FUNCTION IF EXISTS public.promote_chat_cohost(UUID, UUID);
CREATE OR REPLACE FUNCTION public.promote_chat_cohost(
  p_thread_id UUID,
  p_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_host_id UUID;
BEGIN
  SELECT host_id INTO v_host_id
  FROM chat_threads WHERE id = p_thread_id;

  IF v_caller_id != v_host_id THEN
    RAISE EXCEPTION 'Permissão negada: apenas o host pode promover co_hosts';
  END IF;

  -- Adiciona ao array co_hosts se não estiver já
  UPDATE chat_threads
  SET co_hosts = CASE
    WHEN co_hosts ? p_user_id::TEXT THEN co_hosts
    ELSE co_hosts || to_jsonb(p_user_id::TEXT)
  END,
  updated_at = NOW()
  WHERE id = p_thread_id;

  -- Atualiza role em chat_members
  UPDATE chat_members
  SET role = 'co_host'
  WHERE thread_id = p_thread_id AND user_id = p_user_id;
END;
$$;

-- RPC: Remove co_host (rebaixa para membro)
-- Apenas host pode rebaixar
DROP FUNCTION IF EXISTS public.demote_chat_cohost(UUID, UUID);
CREATE OR REPLACE FUNCTION public.demote_chat_cohost(
  p_thread_id UUID,
  p_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_host_id UUID;
BEGIN
  SELECT host_id INTO v_host_id
  FROM chat_threads WHERE id = p_thread_id;

  IF v_caller_id != v_host_id THEN
    RAISE EXCEPTION 'Permissão negada: apenas o host pode rebaixar co_hosts';
  END IF;

  -- Remove do array co_hosts
  UPDATE chat_threads
  SET co_hosts = (
    SELECT jsonb_agg(elem)
    FROM jsonb_array_elements(co_hosts) AS elem
    WHERE elem::TEXT != ('"' || p_user_id::TEXT || '"')
  ),
  updated_at = NOW()
  WHERE id = p_thread_id;

  -- Atualiza role em chat_members
  UPDATE chat_members
  SET role = 'member'
  WHERE thread_id = p_thread_id AND user_id = p_user_id;
END;
$$;

-- RPC: Remove membro do chat (kick)
-- Host pode remover qualquer membro; co_host pode remover apenas membros comuns
DROP FUNCTION IF EXISTS public.remove_chat_member(UUID, UUID);
CREATE OR REPLACE FUNCTION public.remove_chat_member(
  p_thread_id UUID,
  p_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_host_id UUID;
  v_co_hosts JSONB;
  v_target_role TEXT;
BEGIN
  SELECT host_id, co_hosts INTO v_host_id, v_co_hosts
  FROM chat_threads WHERE id = p_thread_id;

  SELECT role INTO v_target_role
  FROM chat_members
  WHERE thread_id = p_thread_id AND user_id = p_user_id;

  -- Verificar permissão
  IF v_caller_id = v_host_id THEN
    -- Host pode remover qualquer um (exceto a si mesmo)
    IF v_caller_id = p_user_id THEN
      RAISE EXCEPTION 'Host não pode remover a si mesmo';
    END IF;
  ELSIF v_co_hosts ? v_caller_id::TEXT THEN
    -- Co_host só pode remover membros comuns
    IF v_target_role IN ('host', 'co_host') THEN
      RAISE EXCEPTION 'Co_host não pode remover host ou outros co_hosts';
    END IF;
  ELSE
    RAISE EXCEPTION 'Permissão negada';
  END IF;

  UPDATE chat_members
  SET status = 'left',
      updated_at = NOW()
  WHERE thread_id = p_thread_id AND user_id = p_user_id;
END;
$$;

-- RPC: Bane membro do chat
-- Host pode banir qualquer membro; co_host pode banir apenas membros comuns
DROP FUNCTION IF EXISTS public.ban_chat_member(UUID, UUID, TEXT, INT);
CREATE OR REPLACE FUNCTION public.ban_chat_member(
  p_thread_id UUID,
  p_user_id UUID,
  p_reason TEXT DEFAULT NULL,
  p_duration_hours INT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_host_id UUID;
  v_co_hosts JSONB;
  v_target_role TEXT;
  v_banned_until TIMESTAMPTZ;
BEGIN
  SELECT host_id, co_hosts INTO v_host_id, v_co_hosts
  FROM chat_threads WHERE id = p_thread_id;

  SELECT role INTO v_target_role
  FROM chat_members
  WHERE thread_id = p_thread_id AND user_id = p_user_id;

  -- Verificar permissão
  IF v_caller_id = v_host_id THEN
    IF v_caller_id = p_user_id THEN
      RAISE EXCEPTION 'Host não pode banir a si mesmo';
    END IF;
  ELSIF v_co_hosts ? v_caller_id::TEXT THEN
    IF v_target_role IN ('host', 'co_host') THEN
      RAISE EXCEPTION 'Co_host não pode banir host ou outros co_hosts';
    END IF;
  ELSE
    RAISE EXCEPTION 'Permissão negada';
  END IF;

  -- Calcular data de expiração do ban
  IF p_duration_hours IS NOT NULL THEN
    v_banned_until := NOW() + (p_duration_hours || ' hours')::INTERVAL;
  END IF;

  UPDATE chat_members
  SET status = 'left',
      is_banned = TRUE,
      ban_reason = p_reason,
      banned_until = v_banned_until,
      updated_at = NOW()
  WHERE thread_id = p_thread_id AND user_id = p_user_id;
END;
$$;

-- RPC: Remove ban de um membro
-- Apenas host pode desbanir
DROP FUNCTION IF EXISTS public.unban_chat_member(UUID, UUID);
CREATE OR REPLACE FUNCTION public.unban_chat_member(
  p_thread_id UUID,
  p_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_host_id UUID;
BEGIN
  SELECT host_id INTO v_host_id
  FROM chat_threads WHERE id = p_thread_id;

  IF v_caller_id != v_host_id THEN
    RAISE EXCEPTION 'Permissão negada: apenas o host pode desbanir membros';
  END IF;

  UPDATE chat_members
  SET is_banned = FALSE,
      ban_reason = NULL,
      banned_until = NULL,
      updated_at = NOW()
  WHERE thread_id = p_thread_id AND user_id = p_user_id;
END;
$$;

-- RPC: Renomeia o chat thread
-- Host ou co_host podem renomear
DROP FUNCTION IF EXISTS public.rename_chat_thread(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.rename_chat_thread(
  p_thread_id UUID,
  p_title TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_host_id UUID;
  v_co_hosts JSONB;
BEGIN
  SELECT host_id, co_hosts INTO v_host_id, v_co_hosts
  FROM chat_threads WHERE id = p_thread_id;

  IF v_caller_id != v_host_id AND NOT (v_co_hosts ? v_caller_id::TEXT) THEN
    RAISE EXCEPTION 'Permissão negada: apenas host ou co_host podem renomear o chat';
  END IF;

  IF p_title IS NULL OR trim(p_title) = '' THEN
    RAISE EXCEPTION 'Título não pode ser vazio';
  END IF;

  UPDATE chat_threads
  SET title = trim(p_title),
      updated_at = NOW()
  WHERE id = p_thread_id;
END;
$$;

-- Grants
GRANT EXECUTE ON FUNCTION public.update_chat_cover TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_announcement_only TO authenticated;
GRANT EXECUTE ON FUNCTION public.promote_chat_cohost TO authenticated;
GRANT EXECUTE ON FUNCTION public.demote_chat_cohost TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_chat_member TO authenticated;
GRANT EXECUTE ON FUNCTION public.ban_chat_member TO authenticated;
GRANT EXECUTE ON FUNCTION public.unban_chat_member TO authenticated;
GRANT EXECUTE ON FUNCTION public.rename_chat_thread TO authenticated;
