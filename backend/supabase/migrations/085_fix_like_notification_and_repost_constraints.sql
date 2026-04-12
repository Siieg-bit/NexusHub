-- 085_fix_like_notification_and_repost_constraints.sql
--
-- Correção defensiva para ambientes já migrados em produção:
-- 1) Recria o trigger de notificação de likes usando o schema atual de profiles
--    (nickname/amino_id), evitando referências antigas como display_name.
-- 2) Recria o RPC repost_post com suporte a posts globais e garantindo que
--    a coluna posts.title nunca receba NULL em reposts.

-- ============================================================================
-- 1. Trigger de like com schema atual de profiles
-- ============================================================================
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
BEGIN
  IF TG_OP != 'INSERT' THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(nickname, ''), NULLIF(amino_id, ''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles
  WHERE id = NEW.user_id;

  IF NEW.post_id IS NOT NULL THEN
    SELECT author_id, COALESCE(NULLIF(title, ''), LEFT(COALESCE(content, ''), 80), 'Post')
      INTO v_target_author, v_target_title
    FROM public.posts
    WHERE id = NEW.post_id;

    v_action_url := '/post/' || NEW.post_id;
    v_group_key  := 'like_post_' || NEW.post_id;

    PERFORM public.upsert_grouped_notification(
      p_user_id    => v_target_author,
      p_actor_id   => NEW.user_id,
      p_type       => 'like',
      p_title      => COALESCE(v_actor_name, 'Alguém') || ' curtiu seu post',
      p_body       => COALESCE(v_target_title, ''),
      p_group_key  => v_group_key,
      p_post_id    => NEW.post_id,
      p_action_url => v_action_url
    );

  ELSIF NEW.wiki_id IS NOT NULL THEN
    SELECT author_id, COALESCE(NULLIF(title, ''), 'Wiki')
      INTO v_target_author, v_target_title
    FROM public.wiki_entries
    WHERE id = NEW.wiki_id;

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
    SELECT author_id, LEFT(COALESCE(content, ''), 80)
      INTO v_target_author, v_target_title
    FROM public.comments
    WHERE id = NEW.comment_id;

    v_group_key := 'like_comment_' || NEW.comment_id;

    PERFORM public.upsert_grouped_notification(
      p_user_id    => v_target_author,
      p_actor_id   => NEW.user_id,
      p_type       => 'like',
      p_title      => COALESCE(v_actor_name, 'Alguém') || ' curtiu seu comentário',
      p_body       => COALESCE(v_target_title, ''),
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
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_on_like();

-- ============================================================================
-- 2. RPC repost_post com suporte a posts globais e title não nulo
-- ============================================================================
DROP FUNCTION IF EXISTS public.repost_post(UUID, UUID);

CREATE OR REPLACE FUNCTION public.repost_post(
  p_original_post_id UUID,
  p_community_id     UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id          UUID := auth.uid();
  v_is_member        BOOLEAN;
  v_original_post    RECORD;
  v_new_post_id      UUID;
  v_existing_repost  UUID;
  v_user_nickname    TEXT;
  v_is_global        BOOLEAN := (p_community_id IS NULL);
  v_repost_title     TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF NOT v_is_global THEN
    SELECT EXISTS(
      SELECT 1
      FROM public.community_members
      WHERE community_id = p_community_id
        AND user_id = v_user_id
        AND is_banned = false
    ) INTO v_is_member;

    IF NOT v_is_member THEN
      RAISE EXCEPTION 'Usuário não é membro da comunidade';
    END IF;
  END IF;

  IF v_is_global THEN
    SELECT *
      INTO v_original_post
    FROM public.posts
    WHERE id = p_original_post_id
      AND status = 'ok';
  ELSE
    SELECT *
      INTO v_original_post
    FROM public.posts
    WHERE id = p_original_post_id
      AND community_id = p_community_id
      AND status = 'ok';
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Post original não encontrado';
  END IF;

  IF v_original_post.author_id = v_user_id THEN
    RAISE EXCEPTION 'Não é possível republicar seu próprio post';
  END IF;

  IF v_original_post.type = 'repost' THEN
    RAISE EXCEPTION 'Não é possível republicar um repost';
  END IF;

  SELECT id
    INTO v_existing_repost
  FROM public.posts
  WHERE author_id = v_user_id
    AND type = 'repost'
    AND original_post_id = p_original_post_id
    AND status = 'ok';

  IF v_existing_repost IS NOT NULL THEN
    RAISE EXCEPTION 'Você já republicou este post';
  END IF;

  v_repost_title := COALESCE(NULLIF(v_original_post.title, ''), 'Repost');

  INSERT INTO public.posts (
    community_id,
    author_id,
    type,
    title,
    content,
    original_post_id,
    original_community_id,
    original_author_id,
    status
  ) VALUES (
    p_community_id,
    v_user_id,
    'repost'::public.post_type,
    v_repost_title,
    '',
    p_original_post_id,
    v_original_post.community_id,
    v_original_post.author_id,
    'ok'
  ) RETURNING id INTO v_new_post_id;

  IF NOT v_is_global THEN
    PERFORM public.add_reputation(
      v_user_id,
      p_community_id,
      'create_post',
      15,
      v_new_post_id
    );

    PERFORM public.add_reputation(
      v_original_post.author_id,
      p_community_id,
      'receive_repost',
      5,
      v_new_post_id
    );
  END IF;

  SELECT nickname
    INTO v_user_nickname
  FROM public.profiles
  WHERE id = v_user_id;

  INSERT INTO public.notifications (
    user_id,
    type,
    title,
    body,
    actor_id,
    community_id,
    post_id,
    action_url
  ) VALUES (
    v_original_post.author_id,
    'repost',
    'Novo Repost',
    COALESCE(v_user_nickname, 'Um usuário') || ' republicou seu post.',
    v_user_id,
    p_community_id,
    p_original_post_id,
    '/post/' || p_original_post_id
  );

  RETURN v_new_post_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.repost_post(UUID, UUID) TO authenticated;
