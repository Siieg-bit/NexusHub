-- =============================================================================
-- Migration 063: Corrige should_notify para respeitar pause_all_until e only_friends_*
--
-- Antes: a função ignorava pause_all_until e only_friends_likes/comments/messages
-- Depois: verifica se notificações estão pausadas e se o ator é seguido pelo usuário
-- =============================================================================

CREATE OR REPLACE FUNCTION public.should_notify(
  p_user_id   UUID,
  p_type      TEXT,
  p_actor_id  UUID DEFAULT NULL   -- quem gerou a ação (para checar only_friends_*)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings RECORD;
  v_actor_is_followed BOOLEAN := FALSE;
BEGIN
  SELECT * INTO v_settings
  FROM public.notification_settings
  WHERE user_id = p_user_id;

  -- Se não tem settings, padrão é TRUE para tudo
  IF NOT FOUND THEN
    RETURN TRUE;
  END IF;

  -- ── Master toggle ──────────────────────────────────────────────────────────
  IF NOT COALESCE(v_settings.push_enabled, TRUE) THEN
    RETURN FALSE;
  END IF;

  -- ── pause_all_until: notificações pausadas até uma data ────────────────────
  IF v_settings.pause_all_until IS NOT NULL
     AND v_settings.pause_all_until > NOW() THEN
    RETURN FALSE;
  END IF;

  -- ── only_friends_*: verificar se o ator é seguido pelo usuário ─────────────
  -- Só aplicar se p_actor_id foi fornecido e é diferente do usuário
  IF p_actor_id IS NOT NULL AND p_actor_id != p_user_id THEN
    -- Verificar se o usuário segue o ator
    SELECT EXISTS(
      SELECT 1 FROM public.follows
      WHERE follower_id = p_user_id
        AND following_id = p_actor_id
    ) INTO v_actor_is_followed;

    -- Likes: se only_friends_likes = true, só notificar se o ator é seguido
    IF p_type = 'like'
       AND COALESCE(v_settings.only_friends_likes, FALSE)
       AND NOT v_actor_is_followed THEN
      RETURN FALSE;
    END IF;

    -- Comments: se only_friends_comments = true, só notificar se o ator é seguido
    IF p_type = 'comment'
       AND COALESCE(v_settings.only_friends_comments, FALSE)
       AND NOT v_actor_is_followed THEN
      RETURN FALSE;
    END IF;

    -- Mensagens diretas: se only_friends_messages = true, só notificar se o ator é seguido
    IF p_type IN ('chat_message', 'dm_invite')
       AND COALESCE(v_settings.only_friends_messages, FALSE)
       AND NOT v_actor_is_followed THEN
      RETURN FALSE;
    END IF;
  END IF;

  -- ── Toggles granulares por tipo ────────────────────────────────────────────
  RETURN CASE p_type
    WHEN 'like'              THEN COALESCE(v_settings.push_likes, TRUE)
    WHEN 'comment'           THEN COALESCE(v_settings.push_comments, TRUE)
    WHEN 'follow'            THEN COALESCE(v_settings.push_follows, TRUE)
    WHEN 'mention'           THEN COALESCE(v_settings.push_mentions, TRUE)
    WHEN 'chat_message'      THEN COALESCE(v_settings.push_chat_messages, TRUE)
    WHEN 'chat_mention'      THEN COALESCE(v_settings.push_mentions, TRUE)
    WHEN 'dm_invite'         THEN COALESCE(v_settings.push_chat_messages, TRUE)
    WHEN 'community_invite'  THEN COALESCE(v_settings.push_community_invites, TRUE)
    WHEN 'achievement'       THEN COALESCE(v_settings.push_achievements, TRUE)
    WHEN 'level_up'          THEN COALESCE(v_settings.push_level_up, TRUE)
    WHEN 'moderation'        THEN COALESCE(v_settings.push_moderation, TRUE)
    WHEN 'strike'            THEN COALESCE(v_settings.push_moderation, TRUE)
    WHEN 'ban'               THEN COALESCE(v_settings.push_moderation, TRUE)
    ELSE TRUE
  END;
END;
$$;

-- =============================================================================
-- Atualizar chamadas em upsert_grouped_notification para passar p_actor_id
-- =============================================================================
CREATE OR REPLACE FUNCTION public.upsert_grouped_notification(
  p_user_id        UUID,
  p_actor_id       UUID,
  p_type           TEXT,
  p_title          TEXT,
  p_body           TEXT,
  p_group_key      TEXT,
  p_post_id        UUID    DEFAULT NULL,
  p_wiki_id        UUID    DEFAULT NULL,
  p_comment_id     UUID    DEFAULT NULL,
  p_community_id   UUID    DEFAULT NULL,
  p_chat_thread_id UUID    DEFAULT NULL,
  p_action_url     TEXT    DEFAULT NULL,
  p_image_url      TEXT    DEFAULT NULL
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
    SELECT display_name INTO v_actor_name
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

-- =============================================================================
-- RESULTADO:
-- - should_notify agora verifica pause_all_until (retorna FALSE se pausado)
-- - should_notify agora verifica only_friends_likes/comments/messages
--   passando p_actor_id para checar se o ator é seguido pelo usuário
-- - upsert_grouped_notification passa p_actor_id para should_notify
-- =============================================================================
