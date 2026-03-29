-- ============================================================================
-- Migration 021: Integrar reputação nas ações + correções de funcionalidades
-- ============================================================================

-- ============================================================================
-- 1. RPC: Criar post COM reputação (+15)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_post_with_reputation(
  p_community_id UUID,
  p_author_id UUID,
  p_title TEXT,
  p_content TEXT,
  p_type TEXT DEFAULT 'blog',
  p_media_urls TEXT[] DEFAULT '{}',
  p_category_id UUID DEFAULT NULL,
  p_poll_options JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_post_id UUID;
  v_is_member BOOLEAN;
BEGIN
  -- Verificar se é membro
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id AND user_id = p_author_id AND is_banned = false
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this community';
  END IF;

  -- Criar o post
  INSERT INTO public.posts (
    community_id, author_id, title, content, type, media_urls, category_id, status
  ) VALUES (
    p_community_id, p_author_id, p_title, p_content, p_type::public.post_type,
    p_media_urls, p_category_id, 'ok'
  ) RETURNING id INTO v_post_id;

  -- Criar opções de enquete se fornecidas
  IF p_poll_options IS NOT NULL AND jsonb_array_length(p_poll_options) > 0 THEN
    INSERT INTO public.poll_options (post_id, option_text, position)
    SELECT v_post_id, elem->>'text', (row_number() OVER ())::int
    FROM jsonb_array_elements(p_poll_options) AS elem;
  END IF;

  -- Adicionar reputação (+15 por criar post)
  PERFORM public.add_reputation(p_community_id, p_author_id, 15, 'create_post', v_post_id);

  RETURN v_post_id;
END;
$$;

-- ============================================================================
-- 2. RPC: Comentar em post COM reputação (+3)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_comment_with_reputation(
  p_community_id UUID,
  p_author_id UUID,
  p_content TEXT,
  p_post_id UUID DEFAULT NULL,
  p_wiki_id UUID DEFAULT NULL,
  p_profile_wall_id UUID DEFAULT NULL,
  p_parent_id UUID DEFAULT NULL,
  p_media_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_comment_id UUID;
  v_rep_amount INT;
  v_action_type TEXT;
BEGIN
  -- Criar o comentário
  INSERT INTO public.comments (
    author_id, post_id, wiki_id, profile_wall_id, parent_id, content, media_url
  ) VALUES (
    p_author_id, p_post_id, p_wiki_id, p_profile_wall_id, p_parent_id, p_content, p_media_url
  ) RETURNING id INTO v_comment_id;

  -- Determinar reputação baseado no tipo
  IF p_post_id IS NOT NULL THEN
    v_rep_amount := 3;  -- Comentar em post
    v_action_type := 'comment_post';
  ELSIF p_wiki_id IS NOT NULL THEN
    v_rep_amount := 3;  -- Comentar em wiki
    v_action_type := 'comment_wiki';
  ELSIF p_profile_wall_id IS NOT NULL THEN
    v_rep_amount := 2;  -- Escrever no mural
    v_action_type := 'wall_comment';
  ELSE
    v_rep_amount := 1;
    v_action_type := 'comment';
  END IF;

  -- Adicionar reputação (precisa do community_id)
  IF p_community_id IS NOT NULL THEN
    PERFORM public.add_reputation(p_community_id, p_author_id, v_rep_amount, v_action_type, v_comment_id);
  END IF;

  RETURN v_comment_id;
END;
$$;

-- ============================================================================
-- 3. RPC: Like/Unlike COM reputação (+2 post, +1 comment)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.toggle_like_with_reputation(
  p_community_id UUID,
  p_user_id UUID,
  p_post_id UUID DEFAULT NULL,
  p_comment_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_like UUID;
  v_target_author UUID;
  v_rep_amount INT;
  v_action_type TEXT;
  v_result JSONB;
BEGIN
  -- Verificar se já curtiu
  IF p_post_id IS NOT NULL THEN
    SELECT id INTO v_existing_like FROM public.likes
    WHERE user_id = p_user_id AND post_id = p_post_id;

    SELECT author_id INTO v_target_author FROM public.posts WHERE id = p_post_id;
    v_rep_amount := 2;
    v_action_type := 'receive_post_like';
  ELSIF p_comment_id IS NOT NULL THEN
    SELECT id INTO v_existing_like FROM public.likes
    WHERE user_id = p_user_id AND comment_id = p_comment_id;

    SELECT author_id INTO v_target_author FROM public.comments WHERE id = p_comment_id;
    v_rep_amount := 1;
    v_action_type := 'receive_comment_like';
  END IF;

  IF v_existing_like IS NOT NULL THEN
    -- Unlike: remover like
    DELETE FROM public.likes WHERE id = v_existing_like;

    -- Decrementar contagem
    IF p_post_id IS NOT NULL THEN
      UPDATE public.posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = p_post_id;
    ELSIF p_comment_id IS NOT NULL THEN
      UPDATE public.comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = p_comment_id;
    END IF;

    v_result := jsonb_build_object('liked', false, 'action', 'unliked');
  ELSE
    -- Like: criar like
    IF p_post_id IS NOT NULL THEN
      INSERT INTO public.likes (user_id, post_id) VALUES (p_user_id, p_post_id);
      UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = p_post_id;
    ELSIF p_comment_id IS NOT NULL THEN
      INSERT INTO public.likes (user_id, comment_id) VALUES (p_user_id, p_comment_id);
      UPDATE public.comments SET likes_count = likes_count + 1 WHERE id = p_comment_id;
    END IF;

    -- Dar reputação ao AUTOR do conteúdo (não a quem curtiu)
    IF v_target_author IS NOT NULL AND v_target_author != p_user_id AND p_community_id IS NOT NULL THEN
      PERFORM public.add_reputation(p_community_id, v_target_author, v_rep_amount, v_action_type,
        COALESCE(p_post_id, p_comment_id));
    END IF;

    v_result := jsonb_build_object('liked', true, 'action', 'liked');
  END IF;

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 4. RPC: Follow/Unfollow COM reputação (+1)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.toggle_follow_with_reputation(
  p_community_id UUID,
  p_follower_id UUID,
  p_following_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing UUID;
  v_result JSONB;
BEGIN
  IF p_follower_id = p_following_id THEN
    RAISE EXCEPTION 'Cannot follow yourself';
  END IF;

  SELECT id INTO v_existing FROM public.follows
  WHERE follower_id = p_follower_id AND following_id = p_following_id;

  IF v_existing IS NOT NULL THEN
    -- Unfollow
    DELETE FROM public.follows WHERE id = v_existing;

    UPDATE public.profiles SET followers_count = GREATEST(followers_count - 1, 0)
    WHERE id = p_following_id;
    UPDATE public.profiles SET following_count = GREATEST(following_count - 1, 0)
    WHERE id = p_follower_id;

    v_result := jsonb_build_object('following', false);
  ELSE
    -- Follow
    INSERT INTO public.follows (follower_id, following_id) VALUES (p_follower_id, p_following_id);

    UPDATE public.profiles SET followers_count = followers_count + 1
    WHERE id = p_following_id;
    UPDATE public.profiles SET following_count = following_count + 1
    WHERE id = p_follower_id;

    -- Reputação para quem seguiu (+1)
    IF p_community_id IS NOT NULL THEN
      PERFORM public.add_reputation(p_community_id, p_follower_id, 1, 'follow_user', p_following_id);
    END IF;

    v_result := jsonb_build_object('following', true);
  END IF;

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 5. RPC: Enviar mensagem em chat COM reputação (+1)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.send_chat_message_with_reputation(
  p_thread_id UUID,
  p_author_id UUID,
  p_content TEXT,
  p_type TEXT DEFAULT 'text',
  p_media_url TEXT DEFAULT NULL,
  p_reply_to UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_message_id UUID;
  v_community_id UUID;
  v_is_member BOOLEAN;
BEGIN
  -- Buscar community_id do chat
  SELECT community_id INTO v_community_id FROM public.chat_threads WHERE id = p_thread_id;

  -- Verificar se é membro do chat
  SELECT EXISTS(
    SELECT 1 FROM public.chat_members WHERE thread_id = p_thread_id AND user_id = p_author_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this chat';
  END IF;

  -- Criar a mensagem
  INSERT INTO public.chat_messages (
    thread_id, author_id, content, type, media_url, reply_to_id
  ) VALUES (
    p_thread_id, p_author_id, p_content, p_type::public.chat_message_type,
    p_media_url, p_reply_to
  ) RETURNING id INTO v_message_id;

  -- Atualizar last_message_at do thread
  UPDATE public.chat_threads SET last_message_at = NOW() WHERE id = p_thread_id;

  -- Reputação (+1 por mensagem)
  IF v_community_id IS NOT NULL THEN
    PERFORM public.add_reputation(v_community_id, p_author_id, 1, 'chat_message', v_message_id);
  END IF;

  RETURN v_message_id;
END;
$$;

-- ============================================================================
-- 6. RPC: Toggle Bookmark (salvar/remover post)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.toggle_bookmark(
  p_user_id UUID,
  p_post_id UUID DEFAULT NULL,
  p_wiki_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing UUID;
  v_result JSONB;
BEGIN
  -- Verificar se já salvou
  IF p_post_id IS NOT NULL THEN
    SELECT id INTO v_existing FROM public.bookmarks
    WHERE user_id = p_user_id AND post_id = p_post_id;
  ELSIF p_wiki_id IS NOT NULL THEN
    SELECT id INTO v_existing FROM public.bookmarks
    WHERE user_id = p_user_id AND wiki_id = p_wiki_id;
  END IF;

  IF v_existing IS NOT NULL THEN
    -- Remover bookmark
    DELETE FROM public.bookmarks WHERE id = v_existing;
    v_result := jsonb_build_object('bookmarked', false);
  ELSE
    -- Criar bookmark
    INSERT INTO public.bookmarks (user_id, post_id, wiki_id)
    VALUES (p_user_id, p_post_id, p_wiki_id);
    v_result := jsonb_build_object('bookmarked', true);
  END IF;

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 7. RPC: Buscar posts salvos de um usuário
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_user_bookmarked_posts(
  p_user_id UUID,
  p_community_id UUID DEFAULT NULL,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT jsonb_build_object(
    'id', p.id,
    'title', p.title,
    'content', p.content,
    'type', p.type,
    'media_urls', p.media_urls,
    'likes_count', p.likes_count,
    'comments_count', p.comments_count,
    'created_at', p.created_at,
    'community_id', p.community_id,
    'author', jsonb_build_object(
      'id', pr.id,
      'nickname', pr.nickname,
      'icon_url', pr.icon_url
    ),
    'bookmarked_at', b.created_at
  )
  FROM public.bookmarks b
  JOIN public.posts p ON b.post_id = p.id
  JOIN public.profiles pr ON p.author_id = pr.id
  WHERE b.user_id = p_user_id
    AND p.status = 'ok'
    AND (p_community_id IS NULL OR p.community_id = p_community_id)
  ORDER BY b.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ============================================================================
-- 8. RPC: Buscar stats de reputação do usuário hoje
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_daily_reputation_status(
  p_community_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_earned_today INT;
  v_total_rep INT;
  v_level INT;
  v_result JSONB;
BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO v_earned_today
  FROM public.reputation_log
  WHERE community_id = p_community_id
    AND user_id = p_user_id
    AND created_at::date = CURRENT_DATE;

  SELECT local_reputation, local_level INTO v_total_rep, v_level
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = p_user_id;

  v_result := jsonb_build_object(
    'earned_today', v_earned_today,
    'daily_limit', 500,
    'remaining_today', GREATEST(500 - v_earned_today, 0),
    'total_reputation', COALESCE(v_total_rep, 0),
    'level', COALESCE(v_level, 1)
  );

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 9. RPC: Entrar em chat público COM reputação (+2)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.join_public_chat_with_reputation(
  p_thread_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_community_id UUID;
  v_already_member BOOLEAN;
BEGIN
  SELECT community_id INTO v_community_id FROM public.chat_threads WHERE id = p_thread_id;

  SELECT EXISTS(
    SELECT 1 FROM public.chat_members WHERE thread_id = p_thread_id AND user_id = p_user_id
  ) INTO v_already_member;

  IF v_already_member THEN
    RETURN jsonb_build_object('joined', false, 'reason', 'already_member');
  END IF;

  INSERT INTO public.chat_members (thread_id, user_id)
  VALUES (p_thread_id, p_user_id);

  -- Atualizar contagem
  UPDATE public.chat_threads SET members_count = members_count + 1 WHERE id = p_thread_id;

  -- Reputação (+2)
  IF v_community_id IS NOT NULL THEN
    PERFORM public.add_reputation(v_community_id, p_user_id, 2, 'join_chat', p_thread_id);
  END IF;

  RETURN jsonb_build_object('joined', true);
END;
$$;

-- ============================================================================
-- 10. RPC: Buscar se o usuário já deu like em um post
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_user_likes(
  p_user_id UUID,
  p_post_ids UUID[]
)
RETURNS SETOF UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT post_id FROM public.likes
  WHERE user_id = p_user_id AND post_id = ANY(p_post_ids);
END;
$$;

-- ============================================================================
-- 11. RPC: Buscar se o usuário já salvou posts (bookmarks)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_user_bookmarks(
  p_user_id UUID,
  p_post_ids UUID[]
)
RETURNS SETOF UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT post_id FROM public.bookmarks
  WHERE user_id = p_user_id AND post_id = ANY(p_post_ids);
END;
$$;
