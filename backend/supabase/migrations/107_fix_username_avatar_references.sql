-- =============================================================================
-- Migration 107: Corrigir referências a colunas inexistentes em profiles
--
-- A tabela profiles NÃO tem as colunas "username" nem "avatar_url".
-- Os campos corretos são "nickname" e "icon_url".
--
-- Esta migration corrige:
-- 1. get_screening_chat_history (migration 064) — usa p.username e p.avatar_url
-- =============================================================================

-- ========================
-- 1. get_screening_chat_history (corrigido)
-- Agora usa nickname e icon_url em vez de username e avatar_url
-- ========================
CREATE OR REPLACE FUNCTION public.get_screening_chat_history(
  p_session_id UUID,
  p_limit      INTEGER DEFAULT 50
)
RETURNS TABLE (
  id         UUID,
  user_id    UUID,
  username   TEXT,
  avatar_url TEXT,
  text       TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.user_id,
    COALESCE(NULLIF(p.nickname, ''), NULLIF(p.amino_id, ''), 'Usuário') AS username,
    p.icon_url AS avatar_url,
    m.text,
    m.created_at
  FROM public.screening_chat_messages m
  JOIN public.profiles p ON p.id = m.user_id
  WHERE m.session_id = p_session_id
  ORDER BY m.created_at ASC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_screening_chat_history(UUID, INTEGER) TO authenticated;

-- ========================
-- 2. get_wiki_entry (migration 101) — usa pr.display_name e pr.avatar_url
-- Corrigido para usar pr.nickname e pr.icon_url
-- ========================
CREATE OR REPLACE FUNCTION public.get_wiki_entry(p_post_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  v_result := (
    SELECT jsonb_build_object(
      'id', p.id,
      'title', p.title,
      'content', p.content,
      'type', p.type,
      'status', p.status,
      'cover_image_url', p.cover_image_url,
      'community_id', p.community_id,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'likes_count', p.likes_count,
      'comments_count', p.comments_count,
      'views_count', p.views_count,
      'editor_metadata', p.editor_metadata,
      'wiki_data', p.wiki_data,
      'author', jsonb_build_object(
        'id', pr.id,
        'display_name', COALESCE(NULLIF(pr.nickname, ''), NULLIF(pr.amino_id, ''), 'Usuário'),
        'avatar_url', pr.icon_url
      )
    )
    FROM public.posts p
    LEFT JOIN public.profiles pr ON p.author_id = pr.id
    WHERE p.id = p_post_id AND p.type = 'wiki'
  );
  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Wiki não encontrada';
  END IF;
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_wiki_entry(UUID) TO authenticated;

-- ========================
-- 3. get_link_preview (migration 103) — usa pr.display_name
-- Corrigido para usar COALESCE(pr.nickname, pr.amino_id)
-- ========================
CREATE OR REPLACE FUNCTION public.get_link_preview(p_link_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_post jsonb;
  v_community jsonb;
  v_user jsonb;
BEGIN
  v_result := (
    SELECT jsonb_build_object(
      'id', sl.id,
      'url', sl.url,
      'link_type', sl.link_type,
      'title', COALESCE(sl.custom_title, sl.title),
      'description', COALESCE(sl.custom_description, sl.description),
      'image_url', sl.image_url,
      'domain', sl.domain,
      'favicon_url', sl.favicon_url,
      'click_count', sl.click_count
    )
    FROM public.smart_links sl
    WHERE sl.id = p_link_id
  );
  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Link não encontrado';
  END IF;
  -- Se for link interno, adicionar dados do objeto
  IF (v_result->>'link_type') = 'internal_post' THEN
    SELECT jsonb_build_object(
      'id', p.id,
      'title', p.title,
      'content', p.content,
      'author', COALESCE(NULLIF(pr.nickname, ''), NULLIF(pr.amino_id, ''), 'Usuário'),
      'community', c.name
    )
    INTO v_post
    FROM public.posts p
    LEFT JOIN public.profiles pr ON p.author_id = pr.id
    LEFT JOIN public.communities c ON p.community_id = c.id
    WHERE p.id = (v_result->>'internal_post_id')::UUID;
    
    v_result := v_result || jsonb_build_object('internal_data', v_post);
  END IF;
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_link_preview(UUID) TO authenticated;

-- ========================
-- 4. get_chat_form_responses (migration 099) — usa p.display_name
-- Corrigido para usar COALESCE(p.nickname, p.amino_id)
-- ========================
CREATE OR REPLACE FUNCTION public.get_chat_form_responses(p_form_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_creator BOOLEAN;
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;
  -- Verificar se usuário é criador do form
  SELECT creator_id = v_user_id INTO v_is_creator
  FROM public.chat_forms WHERE id = p_form_id;
  IF v_is_creator IS NULL THEN
    RAISE EXCEPTION 'Formulário não encontrado';
  END IF;
  -- Se não é criador, retornar apenas sua resposta
  IF NOT v_is_creator THEN
    v_result := jsonb_build_object(
      'responses', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'response_id', id,
            'responses', responses,
            'responded_at', responded_at
          )
        )
        FROM public.chat_form_responses
        WHERE form_id = p_form_id AND responder_id = v_user_id
      ),
      'total_responses', (
        SELECT COUNT(*) FROM public.chat_form_responses WHERE form_id = p_form_id
      )
    );
  ELSE
    -- Se é criador, retornar todas as respostas
    v_result := jsonb_build_object(
      'responses', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'response_id', cfr.id,
            'responder_id', cfr.responder_id,
            'responder_name', COALESCE(NULLIF(p.nickname, ''), NULLIF(p.amino_id, ''), 'Usuário'),
            'responses', cfr.responses,
            'responded_at', cfr.responded_at
          )
        )
        FROM public.chat_form_responses cfr
        JOIN public.profiles p ON cfr.responder_id = p.id
        WHERE cfr.form_id = p_form_id
      ),
      'total_responses', (
        SELECT COUNT(*) FROM public.chat_form_responses WHERE form_id = p_form_id
      )
    );
  END IF;
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_chat_form_responses(UUID) TO authenticated;

-- ========================
-- 5. upsert_grouped_notification (migration 063) — usa display_name
-- Corrigido para usar COALESCE(nickname, amino_id)
-- ========================
CREATE OR REPLACE FUNCTION public.upsert_grouped_notification(
  p_user_id       UUID,
  p_actor_id      UUID,
  p_type          TEXT,
  p_title         TEXT,
  p_body          TEXT,
  p_group_key     TEXT,
  p_post_id       UUID DEFAULT NULL,
  p_wiki_id       UUID DEFAULT NULL,
  p_comment_id    UUID DEFAULT NULL,
  p_community_id  UUID DEFAULT NULL,
  p_chat_thread_id UUID DEFAULT NULL,
  p_action_url    TEXT DEFAULT NULL,
  p_image_url     TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_id  UUID;
  v_group_count  INTEGER;
  v_actor_name   TEXT;
  v_new_title    TEXT;
BEGIN
  -- Não notificar a si mesmo
  IF p_user_id = p_actor_id THEN
    RETURN;
  END IF;

  -- Verificar preferências — agora passa p_actor_id para checar only_friends_*
  IF NOT public.should_notify(p_user_id, p_type, p_actor_id) THEN
    RETURN;
  END IF;

  -- Verificar se já existe notificação não lida do mesmo grupo (últimas 24h)
  SELECT id, group_count INTO v_existing_id, v_group_count
  FROM public.notifications
  WHERE user_id   = p_user_id
    AND group_key = p_group_key
    AND is_read   = FALSE
    AND created_at > NOW() - INTERVAL '24 hours'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    -- Atualizar contagem e título do grupo
    v_group_count := v_group_count + 1;
    SELECT COALESCE(NULLIF(nickname, ''), NULLIF(amino_id, ''), 'Usuário')
      INTO v_actor_name
    FROM public.profiles WHERE id = p_actor_id;

    v_new_title := CASE
      WHEN v_group_count = 2 THEN v_actor_name || ' e mais 1 pessoa'
      WHEN v_group_count  > 2 THEN v_actor_name || ' e mais ' || (v_group_count - 1) || ' pessoas'
      ELSE p_title
    END;

    UPDATE public.notifications
    SET
      actor_id    = p_actor_id,
      title       = v_new_title,
      body        = p_body,
      group_count = v_group_count,
      is_read     = FALSE,
      created_at  = NOW()
    WHERE id = v_existing_id;
  ELSE
    -- Inserir nova notificação
    INSERT INTO public.notifications (
      user_id, actor_id, type, title, body,
      group_key, group_count,
      post_id, wiki_id, comment_id, community_id, chat_thread_id,
      action_url, image_url,
      is_read, created_at
    ) VALUES (
      p_user_id, p_actor_id, p_type, p_title, p_body,
      p_group_key, 1,
      p_post_id, p_wiki_id, p_comment_id, p_community_id, p_chat_thread_id,
      p_action_url, p_image_url,
      FALSE, NOW()
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_grouped_notification(UUID, UUID, TEXT, TEXT, TEXT, TEXT, UUID, UUID, UUID, UUID, UUID, TEXT, TEXT) TO authenticated;
