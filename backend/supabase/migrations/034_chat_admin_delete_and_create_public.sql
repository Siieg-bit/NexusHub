-- =============================================================================
-- 034 — Chat: políticas + RPCs para chat público (create, leave, delete, pin)
-- =============================================================================

-- ─── 1. Política DELETE para chat_threads (team_admin ou host) ───────────────
DROP POLICY IF EXISTS "chat_threads_delete_host_or_admin" ON public.chat_threads;
CREATE POLICY "chat_threads_delete_host_or_admin" ON public.chat_threads
  FOR DELETE
  USING (host_id = auth.uid() OR public.is_team_member());

-- ─── 2. Política UPDATE para chat_threads (team_admin ou host) ───────────────
DROP POLICY IF EXISTS chat_threads_update ON public.chat_threads;
CREATE POLICY chat_threads_update ON public.chat_threads
  FOR UPDATE
  USING (auth.uid() = host_id OR public.is_team_member());

-- ─── 3. RPC: create_public_chat ──────────────────────────────────────────────
-- Cria um chat público em uma comunidade.
-- Requer que o usuário seja membro da comunidade (ou team_admin/moderator).
CREATE OR REPLACE FUNCTION public.create_public_chat(
  p_community_id   UUID,
  p_title          TEXT,
  p_description    TEXT DEFAULT NULL,
  p_icon_url       TEXT DEFAULT NULL,
  p_background_url TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_is_member BOOLEAN;
  v_thread_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;
  IF p_title IS NULL OR trim(p_title) = '' THEN
    RETURN json_build_object('success', false, 'error', 'title_required');
  END IF;

  -- Verificar membership (is_banned = FALSE)
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = FALSE
  ) INTO v_is_member;

  -- Team admins/moderators podem criar em qualquer comunidade
  IF NOT v_is_member THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = v_user_id
        AND (is_team_admin = TRUE OR is_team_moderator = TRUE)
    ) INTO v_is_member;
  END IF;

  IF NOT v_is_member THEN
    RETURN json_build_object('success', false, 'error', 'not_a_member');
  END IF;

  INSERT INTO public.chat_threads (
    community_id, host_id, title, description,
    icon_url, background_url, type, members_count
  ) VALUES (
    p_community_id, v_user_id, trim(p_title), p_description,
    p_icon_url, p_background_url, 'public', 1
  )
  RETURNING id INTO v_thread_id;

  INSERT INTO public.chat_members (thread_id, user_id, status)
  VALUES (v_thread_id, v_user_id, 'active');

  RETURN json_build_object('success', true, 'thread_id', v_thread_id);
END;
$$;

-- ─── 4. RPC: leave_public_chat ───────────────────────────────────────────────
-- Sai de um chat público.
-- Se o usuário for o host ou único membro, o chat é deletado automaticamente.
CREATE OR REPLACE FUNCTION public.leave_public_chat(
  p_thread_id UUID,
  p_user_id   UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := COALESCE(p_user_id, auth.uid());
  v_host_id      UUID;
  v_member_count INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT host_id INTO v_host_id
  FROM public.chat_threads WHERE id = p_thread_id;

  IF v_host_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'chat_not_found');
  END IF;

  SELECT COUNT(*) INTO v_member_count
  FROM public.chat_members WHERE thread_id = p_thread_id;

  -- Host saindo ou único membro → deletar o chat
  IF v_host_id = v_user_id OR v_member_count <= 1 THEN
    DELETE FROM public.chat_members WHERE thread_id = p_thread_id;
    DELETE FROM public.chat_threads WHERE id = p_thread_id;
    RETURN json_build_object('success', true, 'deleted', true);
  END IF;

  DELETE FROM public.chat_members
  WHERE thread_id = p_thread_id AND user_id = v_user_id;

  RETURN json_build_object('success', true, 'deleted', false);
END;
$$;

-- ─── 5. RPC: delete_public_chat ──────────────────────────────────────────────
-- Deleta o chat e todos os membros.
-- Apenas o host ou team_admin/moderator pode deletar.
CREATE OR REPLACE FUNCTION public.delete_public_chat(
  p_thread_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_host_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT host_id INTO v_host_id
  FROM public.chat_threads WHERE id = p_thread_id;

  IF v_host_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'chat_not_found');
  END IF;

  IF v_host_id != v_user_id THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = v_user_id
        AND (is_team_admin = TRUE OR is_team_moderator = TRUE)
    ) INTO v_is_admin;

    IF NOT v_is_admin THEN
      RETURN json_build_object('success', false, 'error', 'not_authorized');
    END IF;
  END IF;

  DELETE FROM public.chat_members WHERE thread_id = p_thread_id;
  DELETE FROM public.chat_threads WHERE id = p_thread_id;

  RETURN json_build_object('success', true);
END;
$$;
