-- ============================================================================
-- 110_repost_with_optional_comment.sql
-- Permite repost com comentário opcional sem quebrar chamadas existentes.
-- ============================================================================

DROP FUNCTION IF EXISTS public.repost_post(UUID, UUID);
DROP FUNCTION IF EXISTS public.repost_post(UUID, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.repost_post(
  p_original_post_id UUID,
  p_community_id     UUID DEFAULT NULL,
  p_content          TEXT DEFAULT ''
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
  v_repost_content   TEXT := COALESCE(BTRIM(p_content), '');
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
    v_repost_content,
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

GRANT EXECUTE ON FUNCTION public.repost_post(UUID, UUID, TEXT) TO authenticated;
