-- =============================================================================
-- 034 — Chat: política DELETE para team_admin + RPC de criação de chat público
-- =============================================================================

-- ─── 1. Política DELETE para chat_threads (team_admin ou host) ───────────────
-- Sem essa política, nem o host consegue deletar via REST API.
CREATE POLICY "chat_threads_delete_host_or_admin" ON public.chat_threads
  FOR DELETE USING (
    host_id = auth.uid()
    OR public.is_team_member()
  );

-- ─── 2. RPC: create_public_chat ──────────────────────────────────────────────
-- Cria um chat público em uma comunidade.
-- Requer que o usuário seja membro da comunidade.
-- Retorna o ID do chat criado.
CREATE OR REPLACE FUNCTION public.create_public_chat(
  p_community_id  UUID,
  p_title         TEXT,
  p_description   TEXT DEFAULT NULL,
  p_icon_url      TEXT DEFAULT NULL,
  p_background_url TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id     UUID := auth.uid();
  v_is_member   BOOLEAN;
  v_thread_id   UUID;
BEGIN
  -- Verificar autenticação
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  -- Verificar título
  IF p_title IS NULL OR trim(p_title) = '' THEN
    RETURN json_build_object('success', false, 'error', 'title_required');
  END IF;

  -- Verificar se é membro da comunidade
  -- (community_members não tem coluna status — apenas is_banned)
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = FALSE
  ) INTO v_is_member;

  -- Team members (is_team_admin ou is_team_moderator) podem criar em qualquer comunidade
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

  -- Criar o chat público
  INSERT INTO public.chat_threads (
    community_id,
    host_id,
    title,
    description,
    icon_url,
    background_url,
    type,
    members_count
  ) VALUES (
    p_community_id,
    v_user_id,
    trim(p_title),
    p_description,
    p_icon_url,
    p_background_url,
    'public',
    1  -- o criador já é membro
  )
  RETURNING id INTO v_thread_id;

  -- Adicionar o criador como membro ativo
  INSERT INTO public.chat_members (
    thread_id,
    user_id,
    status,
    role
  ) VALUES (
    v_thread_id,
    v_user_id,
    'active',
    'host'
  );

  RETURN json_build_object(
    'success', true,
    'thread_id', v_thread_id
  );
END;
$$;
