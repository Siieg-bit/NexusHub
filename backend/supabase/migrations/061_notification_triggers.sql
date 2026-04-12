-- =============================================================================
-- Migration 061: Triggers automáticos de notificação
-- Gera notificações para: like, follow, comment, mention, chat_message
-- Respeita notification_settings de cada usuário
-- =============================================================================

-- ─── Helper: verificar se usuário quer receber notificação ───────────────────
CREATE OR REPLACE FUNCTION public.should_notify(
  p_user_id   UUID,
  p_type      TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings RECORD;
BEGIN
  SELECT * INTO v_settings
  FROM public.notification_settings
  WHERE user_id = p_user_id;

  -- Se não tem settings, padrão é TRUE para tudo
  IF NOT FOUND THEN
    RETURN TRUE;
  END IF;

  -- Master toggle
  IF NOT COALESCE(v_settings.push_enabled, TRUE) THEN
    RETURN FALSE;
  END IF;

  RETURN CASE p_type
    WHEN 'like'              THEN COALESCE(v_settings.push_likes, TRUE)
    WHEN 'comment'           THEN COALESCE(v_settings.push_comments, TRUE)
    WHEN 'follow'            THEN COALESCE(v_settings.push_follows, TRUE)
    WHEN 'mention'           THEN COALESCE(v_settings.push_mentions, TRUE)
    WHEN 'chat_message'      THEN COALESCE(v_settings.push_chat_messages, TRUE)
    WHEN 'chat_mention'      THEN COALESCE(v_settings.push_mentions, TRUE)
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

-- ─── Helper: upsert com agrupamento ──────────────────────────────────────────
-- Agrupa notificações do mesmo tipo no mesmo recurso (ex: vários likes no mesmo post)
CREATE OR REPLACE FUNCTION public.upsert_grouped_notification(
  p_user_id       UUID,
  p_actor_id      UUID,
  p_type          TEXT,
  p_title         TEXT,
  p_body          TEXT,
  p_group_key     TEXT,
  p_post_id       UUID    DEFAULT NULL,
  p_wiki_id       UUID    DEFAULT NULL,
  p_comment_id    UUID    DEFAULT NULL,
  p_community_id  UUID    DEFAULT NULL,
  p_chat_thread_id UUID   DEFAULT NULL,
  p_action_url    TEXT    DEFAULT NULL,
  p_image_url     TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_id   UUID;
  v_group_count   INTEGER;
  v_actor_name    TEXT;
  v_new_title     TEXT;
BEGIN
  -- Não notificar a si mesmo
  IF p_user_id = p_actor_id THEN
    RETURN;
  END IF;

  -- Verificar preferências
  IF NOT public.should_notify(p_user_id, p_type) THEN
    RETURN;
  END IF;

  -- Verificar se já existe notificação não lida do mesmo grupo (últimas 24h)
  SELECT id, group_count INTO v_existing_id, v_group_count
  FROM public.notifications
  WHERE user_id = p_user_id
    AND group_key = p_group_key
    AND is_read = FALSE
    AND created_at > NOW() - INTERVAL '24 hours'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    -- Atualizar contagem e título do grupo
    v_group_count := v_group_count + 1;
    SELECT COALESCE(NULLIF(nickname, ''), amino_id, 'Alguém') INTO v_actor_name
    FROM public.profiles WHERE id = p_actor_id;

    v_new_title := CASE p_type
      WHEN 'like'    THEN v_actor_name || ' e mais ' || (v_group_count - 1) || ' curtiram'
      WHEN 'comment' THEN v_actor_name || ' e mais ' || (v_group_count - 1) || ' comentaram'
      WHEN 'follow'  THEN v_actor_name || ' e mais ' || (v_group_count - 1) || ' seguiram você'
      ELSE p_title
    END;

    UPDATE public.notifications
    SET
      group_count = v_group_count,
      title       = v_new_title,
      actor_id    = p_actor_id,
      created_at  = NOW()
    WHERE id = v_existing_id;
  ELSE
    -- Inserir nova notificação
    INSERT INTO public.notifications (
      user_id, actor_id, type, title, body,
      group_key, group_count,
      post_id, wiki_id, comment_id,
      community_id, chat_thread_id,
      action_url, image_url
    ) VALUES (
      p_user_id, p_actor_id, p_type, p_title, p_body,
      p_group_key, 1,
      p_post_id, p_wiki_id, p_comment_id,
      p_community_id, p_chat_thread_id,
      p_action_url, p_image_url
    );
  END IF;
END;
$$;

-- =============================================================================
-- TRIGGER 1: Like em post → notifica autor do post
-- =============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post_author   UUID;
  v_wiki_author   UUID;
  v_actor_name    TEXT;
  v_post_title    TEXT;
  v_target_id     UUID;
  v_target_title  TEXT;
  v_target_author UUID;
  v_action_url    TEXT;
  v_group_key     TEXT;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT COALESCE(NULLIF(nickname, ''), amino_id, 'Alguém') INTO v_actor_name
  FROM public.profiles WHERE id = NEW.user_id;

  IF NEW.post_id IS NOT NULL THEN
    SELECT author_id, title INTO v_target_author, v_target_title
    FROM public.posts WHERE id = NEW.post_id;
    v_action_url := '/post/' || NEW.post_id;
    v_group_key  := 'like_post_' || NEW.post_id;

    PERFORM public.upsert_grouped_notification(
      p_user_id      => v_target_author,
      p_actor_id     => NEW.user_id,
      p_type         => 'like',
      p_title        => COALESCE(v_actor_name, 'Alguém') || ' curtiu seu post',
      p_body         => COALESCE(v_target_title, ''),
      p_group_key    => v_group_key,
      p_post_id      => NEW.post_id,
      p_action_url   => v_action_url
    );

  ELSIF NEW.wiki_id IS NOT NULL THEN
    SELECT author_id, title INTO v_target_author, v_target_title
    FROM public.wiki_entries WHERE id = NEW.wiki_id;
    v_action_url := '/wiki/' || NEW.wiki_id;
    v_group_key  := 'like_wiki_' || NEW.wiki_id;

    PERFORM public.upsert_grouped_notification(
      p_user_id    => v_target_author,
      p_actor_id   => NEW.user_id,
      p_type       => 'like',
      p_title      => COALESCE(v_actor_name, 'Alguém') || ' curtiu sua wiki',
      p_body       => COALESCE(v_target_title, ''),
      p_group_key  => v_group_key,
      p_wiki_id    => NEW.wiki_id,
      p_action_url => v_action_url
    );

  ELSIF NEW.comment_id IS NOT NULL THEN
    SELECT author_id, content INTO v_target_author, v_target_title
    FROM public.comments WHERE id = NEW.comment_id;
    v_group_key := 'like_comment_' || NEW.comment_id;

    PERFORM public.upsert_grouped_notification(
      p_user_id    => v_target_author,
      p_actor_id   => NEW.user_id,
      p_type       => 'like',
      p_title      => COALESCE(v_actor_name, 'Alguém') || ' curtiu seu comentário',
      p_body       => LEFT(COALESCE(v_target_title, ''), 80),
      p_group_key  => v_group_key,
      p_comment_id => NEW.comment_id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_like ON public.likes;
CREATE TRIGGER trg_notify_like
  AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_like();

-- =============================================================================
-- TRIGGER 2: Follow → notifica o usuário seguido
-- =============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_follow()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name TEXT;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT COALESCE(NULLIF(nickname, ''), amino_id, 'Alguém') INTO v_actor_name
  FROM public.profiles WHERE id = NEW.follower_id;

  PERFORM public.upsert_grouped_notification(
    p_user_id    => NEW.following_id,
    p_actor_id   => NEW.follower_id,
    p_type       => 'follow',
    p_title      => COALESCE(v_actor_name, 'Alguém') || ' começou a te seguir',
    p_body       => '',
    p_group_key  => 'follow_' || NEW.following_id || '_' || date_trunc('day', NOW()),
    p_action_url => '/user/' || NEW.follower_id
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_follow ON public.follows;
CREATE TRIGGER trg_notify_follow
  AFTER INSERT ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_follow();

-- =============================================================================
-- TRIGGER 3: Comment → notifica autor do post + menciona usuários (@user)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name    TEXT;
  v_post_author   UUID;
  v_wiki_author   UUID;
  v_post_title    TEXT;
  v_action_url    TEXT;
  v_mention       TEXT;
  v_mentioned_id  UUID;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT COALESCE(NULLIF(nickname, ''), amino_id, 'Alguém') INTO v_actor_name
  FROM public.profiles WHERE id = NEW.author_id;

  -- Notificar autor do post
  IF NEW.post_id IS NOT NULL THEN
    SELECT author_id, title INTO v_post_author, v_post_title
    FROM public.posts WHERE id = NEW.post_id;
    v_action_url := '/post/' || NEW.post_id;

    IF v_post_author IS NOT NULL AND v_post_author != NEW.author_id THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id    => v_post_author,
        p_actor_id   => NEW.author_id,
        p_type       => 'comment',
        p_title      => COALESCE(v_actor_name, 'Alguém') || ' comentou no seu post',
        p_body       => LEFT(COALESCE(NEW.content, ''), 100),
        p_group_key  => 'comment_post_' || NEW.post_id,
        p_post_id    => NEW.post_id,
        p_comment_id => NEW.id,
        p_action_url => v_action_url
      );
    END IF;
  END IF;

  -- Notificar autor da wiki
  IF NEW.wiki_id IS NOT NULL THEN
    SELECT author_id INTO v_wiki_author
    FROM public.wiki_entries WHERE id = NEW.wiki_id;
    v_action_url := '/wiki/' || NEW.wiki_id;

    IF v_wiki_author IS NOT NULL AND v_wiki_author != NEW.author_id THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id    => v_wiki_author,
        p_actor_id   => NEW.author_id,
        p_type       => 'comment',
        p_title      => COALESCE(v_actor_name, 'Alguém') || ' comentou na sua wiki',
        p_body       => LEFT(COALESCE(NEW.content, ''), 100),
        p_group_key  => 'comment_wiki_' || NEW.wiki_id,
        p_wiki_id    => NEW.wiki_id,
        p_comment_id => NEW.id,
        p_action_url => v_action_url
      );
    END IF;
  END IF;

  -- Processar menções @username no conteúdo do comentário
  FOR v_mention IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_]+)', 'g'))[1]
  LOOP
    SELECT id INTO v_mentioned_id
    FROM public.profiles
    WHERE lower(username) = lower(v_mention)
      AND id != NEW.author_id
    LIMIT 1;

    IF v_mentioned_id IS NOT NULL THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id    => v_mentioned_id,
        p_actor_id   => NEW.author_id,
        p_type       => 'mention',
        p_title      => COALESCE(v_actor_name, 'Alguém') || ' te mencionou em um comentário',
        p_body       => LEFT(COALESCE(NEW.content, ''), 100),
        p_group_key  => 'mention_comment_' || NEW.id || '_' || v_mentioned_id,
        p_post_id    => NEW.post_id,
        p_wiki_id    => NEW.wiki_id,
        p_comment_id => NEW.id,
        p_action_url => COALESCE(v_action_url, '/post/' || NEW.post_id)
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_comment ON public.comments;
CREATE TRIGGER trg_notify_comment
  AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_comment();

-- =============================================================================
-- TRIGGER 4: Chat message → notifica membros do chat (menções @user)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_chat_mention()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name    TEXT;
  v_thread_title  TEXT;
  v_mention       TEXT;
  v_mentioned_id  UUID;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;
  -- Só processar mensagens de texto com menções
  IF NEW.content IS NULL OR NEW.content NOT LIKE '%@%' THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(nickname, ''), amino_id, 'Alguém') INTO v_actor_name
  FROM public.profiles WHERE id = NEW.author_id;

  SELECT title INTO v_thread_title
  FROM public.chat_threads WHERE id = NEW.thread_id;

  -- Processar menções @username
  FOR v_mention IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_]+)', 'g'))[1]
  LOOP
    SELECT p.id INTO v_mentioned_id
    FROM public.profiles p
    INNER JOIN public.chat_members cm ON cm.user_id = p.id
    WHERE lower(p.username) = lower(v_mention)
      AND cm.thread_id = NEW.thread_id
      AND p.id != NEW.author_id
    LIMIT 1;

    IF v_mentioned_id IS NOT NULL THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id        => v_mentioned_id,
        p_actor_id       => NEW.author_id,
        p_type           => 'chat_mention',
        p_title          => COALESCE(v_actor_name, 'Alguém') || ' te mencionou em ' || COALESCE(v_thread_title, 'um chat'),
        p_body           => LEFT(COALESCE(NEW.content, ''), 100),
        p_group_key      => 'chat_mention_' || NEW.thread_id || '_' || v_mentioned_id,
        p_chat_thread_id => NEW.thread_id,
        p_action_url     => '/chat/' || NEW.thread_id
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_chat_mention ON public.chat_messages;
CREATE TRIGGER trg_notify_chat_mention
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_chat_mention();

-- =============================================================================
-- RPC: get_unread_notification_count — contagem rápida para badge
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_unread_notification_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.notifications
  WHERE user_id = auth.uid()
    AND is_read = FALSE;
  RETURN COALESCE(v_count, 0);
END;
$$;

-- =============================================================================
-- RPC: mark_notifications_read_by_type — marcar por categoria
-- =============================================================================
CREATE OR REPLACE FUNCTION public.mark_notifications_read_by_type(
  p_types TEXT[]
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE public.notifications
  SET is_read = TRUE
  WHERE user_id = auth.uid()
    AND is_read = FALSE
    AND type = ANY(p_types);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- =============================================================================
-- RPC: delete_notification — remover notificação individual
-- =============================================================================
CREATE OR REPLACE FUNCTION public.delete_notification(
  p_notification_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.notifications
  WHERE id = p_notification_id
    AND user_id = auth.uid();
  RETURN FOUND;
END;
$$;

-- =============================================================================
-- RPC: delete_all_notifications — limpar todas as notificações do usuário
-- =============================================================================
CREATE OR REPLACE FUNCTION public.delete_all_notifications()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM public.notifications
  WHERE user_id = auth.uid();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- =============================================================================
-- RPC: get_notifications_paginated — com filtro por categoria
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_notifications_paginated(
  p_limit     INTEGER DEFAULT 30,
  p_offset    INTEGER DEFAULT 0,
  p_category  TEXT    DEFAULT 'all'  -- 'all', 'social', 'chat', 'community', 'system'
)
RETURNS TABLE (
  id              UUID,
  type            TEXT,
  title           TEXT,
  body            TEXT,
  image_url       TEXT,
  actor_id        UUID,
  actor_name      TEXT,
  actor_avatar    TEXT,
  community_id    UUID,
  post_id         UUID,
  wiki_id         UUID,
  comment_id      UUID,
  chat_thread_id  UUID,
  action_url      TEXT,
  is_read         BOOLEAN,
  group_key       TEXT,
  group_count     INTEGER,
  created_at      TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    n.id,
    n.type,
    n.title,
    n.body,
    n.image_url,
    n.actor_id,
    COALESCE(NULLIF(p.nickname, ''), p.amino_id, 'Alguém') AS actor_name,
    p.icon_url   AS actor_avatar,
    n.community_id,
    n.post_id,
    n.wiki_id,
    n.comment_id,
    n.chat_thread_id,
    n.action_url,
    n.is_read,
    n.group_key,
    n.group_count,
    n.created_at
  FROM public.notifications n
  LEFT JOIN public.profiles p ON p.id = n.actor_id
  WHERE n.user_id = auth.uid()
    AND (
      p_category = 'all'
      OR (p_category = 'social'    AND n.type IN ('like', 'comment', 'follow', 'mention', 'wall_post'))
      OR (p_category = 'chat'      AND n.type IN ('chat_message', 'chat_mention', 'dm_invite'))
      OR (p_category = 'community' AND n.type IN ('community_invite', 'community_update', 'join_request', 'role_change'))
      OR (p_category = 'system'    AND n.type IN ('level_up', 'achievement', 'check_in_streak', 'moderation', 'strike', 'ban', 'broadcast', 'wiki_approved', 'wiki_rejected', 'tip'))
    )
  ORDER BY n.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Adicionar colunas faltantes no notification_settings (se não existirem)
ALTER TABLE public.notification_settings
  ADD COLUMN IF NOT EXISTS in_app_sounds     BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS in_app_vibration  BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS only_friends_likes    BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS only_friends_comments BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS only_friends_messages BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS pause_all_until   TIMESTAMPTZ DEFAULT NULL;

-- Índice para realtime (notificações não lidas recentes)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread_recent
  ON public.notifications(user_id, is_read, created_at DESC)
  WHERE is_read = FALSE;
