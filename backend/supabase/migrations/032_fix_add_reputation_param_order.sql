-- ============================================================================
-- Migration 032: Corrigir ordem dos parâmetros em chamadas a add_reputation
-- ============================================================================
-- CAUSA RAIZ: Migration 021 chama add_reputation com parâmetros invertidos.
--
-- Assinatura correta (definida em migration 019):
--   add_reputation(p_user_id UUID, p_community_id UUID, p_action_type TEXT, p_raw_amount INTEGER, p_reference_id UUID)
--
-- Migration 021 chamava:
--   add_reputation(p_community_id, p_author_id, <amount INT>, <action TEXT>, <ref UUID>)
--   → parâmetros 1↔2 invertidos (user_id ↔ community_id)
--   → parâmetros 3↔4 invertidos (action_type TEXT ↔ raw_amount INTEGER)
--
-- Isso causava PostgrestException porque a assinatura (uuid, uuid, integer, text, uuid)
-- não existe — só existe (uuid, uuid, text, integer, uuid).
--
-- Esta migration recria (CREATE OR REPLACE) todas as 6 funções afetadas
-- com a ordem correta dos parâmetros na chamada interna a add_reputation.
-- ============================================================================

-- ============================================================================
-- 1. create_post_with_reputation — fix add_reputation call
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

  -- FIX: Ordem correta → (p_user_id, p_community_id, p_action_type, p_raw_amount, p_reference_id)
  PERFORM public.add_reputation(p_author_id, p_community_id, 'create_post', 15, v_post_id);

  RETURN v_post_id;
END;
$$;

-- ============================================================================
-- 2. create_comment_with_reputation — fix add_reputation call
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
    v_rep_amount := 3;
    v_action_type := 'comment_post';
  ELSIF p_wiki_id IS NOT NULL THEN
    v_rep_amount := 3;
    v_action_type := 'comment_wiki';
  ELSIF p_profile_wall_id IS NOT NULL THEN
    v_rep_amount := 2;
    v_action_type := 'wall_comment';
  ELSE
    v_rep_amount := 1;
    v_action_type := 'comment';
  END IF;

  -- FIX: Ordem correta → (p_user_id, p_community_id, p_action_type, p_raw_amount, p_reference_id)
  IF p_community_id IS NOT NULL THEN
    PERFORM public.add_reputation(p_author_id, p_community_id, v_action_type, v_rep_amount, v_comment_id);
  END IF;

  RETURN v_comment_id;
END;
$$;

-- ============================================================================
-- 3. toggle_like_with_reputation — fix add_reputation call
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
    DELETE FROM public.likes WHERE id = v_existing_like;

    IF p_post_id IS NOT NULL THEN
      UPDATE public.posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = p_post_id;
    ELSIF p_comment_id IS NOT NULL THEN
      UPDATE public.comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = p_comment_id;
    END IF;

    v_result := jsonb_build_object('liked', false, 'action', 'unliked');
  ELSE
    IF p_post_id IS NOT NULL THEN
      INSERT INTO public.likes (user_id, post_id) VALUES (p_user_id, p_post_id);
      UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = p_post_id;
    ELSIF p_comment_id IS NOT NULL THEN
      INSERT INTO public.likes (user_id, comment_id) VALUES (p_user_id, p_comment_id);
      UPDATE public.comments SET likes_count = likes_count + 1 WHERE id = p_comment_id;
    END IF;

    -- FIX: Reputação ao AUTOR — ordem correta (user_id, community_id, action_type, amount, ref)
    IF v_target_author IS NOT NULL AND v_target_author != p_user_id AND p_community_id IS NOT NULL THEN
      PERFORM public.add_reputation(v_target_author, p_community_id, v_action_type, v_rep_amount,
        COALESCE(p_post_id, p_comment_id));
    END IF;

    v_result := jsonb_build_object('liked', true, 'action', 'liked');
  END IF;

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 4. toggle_follow_with_reputation — fix add_reputation call
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
    DELETE FROM public.follows WHERE id = v_existing;

    UPDATE public.profiles SET followers_count = GREATEST(followers_count - 1, 0)
    WHERE id = p_following_id;
    UPDATE public.profiles SET following_count = GREATEST(following_count - 1, 0)
    WHERE id = p_follower_id;

    v_result := jsonb_build_object('following', false);
  ELSE
    INSERT INTO public.follows (follower_id, following_id) VALUES (p_follower_id, p_following_id);

    UPDATE public.profiles SET followers_count = followers_count + 1
    WHERE id = p_following_id;
    UPDATE public.profiles SET following_count = following_count + 1
    WHERE id = p_follower_id;

    -- FIX: Ordem correta → (p_user_id, p_community_id, p_action_type, p_raw_amount, p_reference_id)
    IF p_community_id IS NOT NULL THEN
      PERFORM public.add_reputation(p_follower_id, p_community_id, 'follow_user', 1, p_following_id);
    END IF;

    v_result := jsonb_build_object('following', true);
  END IF;

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 5. send_chat_message_with_reputation — fix add_reputation call
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
  SELECT community_id INTO v_community_id FROM public.chat_threads WHERE id = p_thread_id;

  SELECT EXISTS(
    SELECT 1 FROM public.chat_members WHERE thread_id = p_thread_id AND user_id = p_author_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this chat';
  END IF;

  INSERT INTO public.chat_messages (
    thread_id, author_id, content, type, media_url, reply_to_id
  ) VALUES (
    p_thread_id, p_author_id, p_content, p_type::public.chat_message_type,
    p_media_url, p_reply_to
  ) RETURNING id INTO v_message_id;

  UPDATE public.chat_threads SET last_message_at = NOW() WHERE id = p_thread_id;

  -- FIX: Ordem correta → (p_user_id, p_community_id, p_action_type, p_raw_amount, p_reference_id)
  IF v_community_id IS NOT NULL THEN
    PERFORM public.add_reputation(p_author_id, v_community_id, 'chat_message', 1, v_message_id);
  END IF;

  RETURN v_message_id;
END;
$$;

-- ============================================================================
-- 6. join_public_chat_with_reputation — fix add_reputation call
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

  UPDATE public.chat_threads SET members_count = members_count + 1 WHERE id = p_thread_id;

  -- FIX: Ordem correta → (p_user_id, p_community_id, p_action_type, p_raw_amount, p_reference_id)
  IF v_community_id IS NOT NULL THEN
    PERFORM public.add_reputation(p_user_id, v_community_id, 'join_chat', 2, p_thread_id);
  END IF;

  RETURN jsonb_build_object('joined', true);
END;
$$;
