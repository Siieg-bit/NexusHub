-- =============================================================================
-- Migration 106: Corrigir erro de coluna "username" nas triggers de menção
--
-- Problema: O trigger trg_notify_on_comment() (migration 061) usa
--   WHERE lower(username) = lower(v_mention)
-- mas a tabela profiles NÃO tem coluna "username". O campo correto é "nickname".
--
-- O mesmo problema existe no trigger trg_notify_on_chat_mention().
--
-- Além disso, os triggers de notificação para likes e comments não passavam
-- p_community_id, fazendo com que notificações de comunidade aparecessem
-- no alerta global.
--
-- Esta migration corrige:
-- 1. trg_notify_on_comment — usar nickname em vez de username + passar community_id
-- 2. trg_notify_on_chat_mention — usar nickname em vez de username
-- 3. trg_notify_on_like — passar community_id do post/wiki/comment
-- =============================================================================

-- ========================
-- 1. TRIGGER: trg_notify_on_comment (corrigido)
-- Agora usa nickname em vez de username e passa community_id
-- ========================
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
  v_community_id  UUID;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT COALESCE(NULLIF(nickname, ''), NULLIF(amino_id, ''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles WHERE id = NEW.author_id;

  -- Obter community_id do post ou wiki
  IF NEW.post_id IS NOT NULL THEN
    SELECT author_id, COALESCE(NULLIF(title, ''), LEFT(COALESCE(content, ''), 80), 'Post'), community_id
      INTO v_post_author, v_post_title, v_community_id
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
        p_community_id => v_community_id,
        p_action_url => v_action_url
      );
    END IF;
  END IF;

  IF NEW.wiki_id IS NOT NULL THEN
    SELECT author_id, community_id INTO v_wiki_author, v_community_id
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
        p_community_id => v_community_id,
        p_action_url => v_action_url
      );
    END IF;
  END IF;

  -- Processar menções @nickname no conteúdo do comentário
  -- CORRIGIDO: usar nickname em vez de username (que não existe)
  FOR v_mention IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_]+)', 'g'))[1]
  LOOP
    SELECT id INTO v_mentioned_id
    FROM public.profiles
    WHERE (lower(nickname) = lower(v_mention) OR lower(amino_id) = lower(v_mention))
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
        p_community_id => v_community_id,
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

-- ========================
-- 2. TRIGGER: trg_notify_on_chat_mention (corrigido)
-- Agora usa nickname em vez de username
-- ========================
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
  v_community_id  UUID;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;
  IF NEW.content IS NULL OR NEW.content NOT LIKE '%@%' THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(nickname, ''), NULLIF(amino_id, ''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles WHERE id = NEW.author_id;

  SELECT title, community_id INTO v_thread_title, v_community_id
  FROM public.chat_threads WHERE id = NEW.thread_id;

  -- Processar menções @nickname (CORRIGIDO: usar nickname em vez de username)
  FOR v_mention IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_]+)', 'g'))[1]
  LOOP
    SELECT p.id INTO v_mentioned_id
    FROM public.profiles p
    INNER JOIN public.chat_members cm ON cm.user_id = p.id
    WHERE (lower(p.nickname) = lower(v_mention) OR lower(p.amino_id) = lower(v_mention))
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
        p_community_id   => v_community_id,
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

-- ========================
-- 3. TRIGGER: trg_notify_on_like (corrigido para passar community_id)
-- ========================
CREATE OR REPLACE FUNCTION public.trg_notify_on_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name    TEXT;
  v_target_title  TEXT;
  v_target_author UUID;
  v_action_url    TEXT;
  v_group_key     TEXT;
  v_community_id  UUID;
BEGIN
  IF TG_OP != 'INSERT' THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(nickname, ''), NULLIF(amino_id, ''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles
  WHERE id = NEW.user_id;

  IF NEW.post_id IS NOT NULL THEN
    SELECT author_id,
           COALESCE(NULLIF(title, ''), LEFT(COALESCE(content, ''), 80), 'Post'),
           community_id
      INTO v_target_author, v_target_title, v_community_id
    FROM public.posts
    WHERE id = NEW.post_id;

    v_action_url := '/post/' || NEW.post_id;
    v_group_key  := 'like_post_' || NEW.post_id;

    IF v_target_author IS NOT NULL AND v_target_author != NEW.user_id THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id      => v_target_author,
        p_actor_id     => NEW.user_id,
        p_type         => 'like',
        p_title        => COALESCE(v_actor_name, 'Alguém') || ' curtiu seu post',
        p_body         => COALESCE(v_target_title, ''),
        p_group_key    => v_group_key,
        p_post_id      => NEW.post_id,
        p_community_id => v_community_id,
        p_action_url   => v_action_url
      );
    END IF;

  ELSIF NEW.wiki_id IS NOT NULL THEN
    SELECT author_id, COALESCE(NULLIF(title, ''), 'Wiki'), community_id
      INTO v_target_author, v_target_title, v_community_id
    FROM public.wiki_entries
    WHERE id = NEW.wiki_id;

    v_action_url := '/wiki/' || NEW.wiki_id;
    v_group_key  := 'like_wiki_' || NEW.wiki_id;

    IF v_target_author IS NOT NULL AND v_target_author != NEW.user_id THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id    => v_target_author,
        p_actor_id   => NEW.user_id,
        p_type       => 'like',
        p_title      => COALESCE(v_actor_name, 'Alguém') || ' curtiu sua wiki',
        p_body       => COALESCE(v_target_title, ''),
        p_group_key  => v_group_key,
        p_wiki_id    => NEW.wiki_id,
        p_community_id => v_community_id,
        p_action_url => v_action_url
      );
    END IF;

  ELSIF NEW.comment_id IS NOT NULL THEN
    SELECT c.author_id, LEFT(COALESCE(c.content, ''), 80),
           COALESCE(p.community_id, w.community_id)
      INTO v_target_author, v_target_title, v_community_id
    FROM public.comments c
    LEFT JOIN public.posts p ON p.id = c.post_id
    LEFT JOIN public.wiki_entries w ON w.id = c.wiki_id
    WHERE c.id = NEW.comment_id;

    v_group_key := 'like_comment_' || NEW.comment_id;

    IF v_target_author IS NOT NULL AND v_target_author != NEW.user_id THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id      => v_target_author,
        p_actor_id     => NEW.user_id,
        p_type         => 'like',
        p_title        => COALESCE(v_actor_name, 'Alguém') || ' curtiu seu comentário',
        p_body         => COALESCE(v_target_title, ''),
        p_group_key    => v_group_key,
        p_comment_id   => NEW.comment_id,
        p_community_id => v_community_id
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_like ON public.likes;
CREATE TRIGGER trg_notify_like
  AFTER INSERT ON public.likes
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_on_like();
