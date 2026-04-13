-- =============================================================================
-- Migration 105: Corrigir RPC toggle_like_with_reputation
--
-- A migration 032 já definia esta função usando a tabela `likes`.
-- Esta versão corrige a versão anterior que referenciava `post_likes` (inexistente)
-- e mantém compatibilidade com o frontend.
--
-- Também atualiza toggle_post_like (usado pelo CommunityFeedNotifier).
-- =============================================================================

-- ========================
-- 1. toggle_like_with_reputation (usado por post_card.dart e post_detail_screen.dart)
-- Suporta tanto p_post_id quanto p_comment_id
-- ========================
CREATE OR REPLACE FUNCTION public.toggle_like_with_reputation(
  p_community_id UUID,
  p_user_id UUID,
  p_post_id UUID DEFAULT NULL,
  p_comment_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_existing_like UUID;
  v_target_author UUID;
  v_rep_amount INT;
  v_action_type TEXT;
  v_result JSONB;
  v_new_likes_count INT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF p_post_id IS NOT NULL THEN
    -- Verificar se o post existe
    SELECT author_id INTO v_target_author
      FROM public.posts
     WHERE id = p_post_id;

    IF v_target_author IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'post_not_found');
    END IF;

    -- Verificar se já curtiu
    SELECT id INTO v_existing_like
      FROM public.likes
     WHERE user_id = p_user_id AND post_id = p_post_id;

    v_rep_amount := 2;
    v_action_type := 'receive_post_like';

  ELSIF p_comment_id IS NOT NULL THEN
    -- Verificar se o comentário existe
    SELECT author_id INTO v_target_author
      FROM public.comments
     WHERE id = p_comment_id;

    IF v_target_author IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'comment_not_found');
    END IF;

    -- Verificar se já curtiu
    SELECT id INTO v_existing_like
      FROM public.likes
     WHERE user_id = p_user_id AND comment_id = p_comment_id;

    v_rep_amount := 1;
    v_action_type := 'receive_comment_like';
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'no_target');
  END IF;

  IF v_existing_like IS NOT NULL THEN
    -- Remover curtida
    DELETE FROM public.likes WHERE id = v_existing_like;

    IF p_post_id IS NOT NULL THEN
      UPDATE public.posts
         SET likes_count = GREATEST(likes_count - 1, 0)
       WHERE id = p_post_id
       RETURNING likes_count INTO v_new_likes_count;
    ELSIF p_comment_id IS NOT NULL THEN
      UPDATE public.comments
         SET likes_count = GREATEST(likes_count - 1, 0)
       WHERE id = p_comment_id
       RETURNING likes_count INTO v_new_likes_count;
    END IF;

    v_result := jsonb_build_object(
      'success', true,
      'liked', false,
      'action', 'unliked',
      'likes_count', COALESCE(v_new_likes_count, 0)
    );
  ELSE
    -- Adicionar curtida
    IF p_post_id IS NOT NULL THEN
      INSERT INTO public.likes (user_id, post_id)
      VALUES (p_user_id, p_post_id)
      ON CONFLICT (user_id, post_id) DO NOTHING;

      UPDATE public.posts
         SET likes_count = likes_count + 1
       WHERE id = p_post_id
       RETURNING likes_count INTO v_new_likes_count;
    ELSIF p_comment_id IS NOT NULL THEN
      INSERT INTO public.likes (user_id, comment_id)
      VALUES (p_user_id, p_comment_id)
      ON CONFLICT (user_id, comment_id) DO NOTHING;

      UPDATE public.comments
         SET likes_count = likes_count + 1
       WHERE id = p_comment_id
       RETURNING likes_count INTO v_new_likes_count;
    END IF;

    -- Reputação ao AUTOR (não ao próprio usuário)
    IF v_target_author IS NOT NULL
       AND v_target_author != p_user_id
       AND p_community_id IS NOT NULL THEN
      PERFORM public.add_reputation(
        v_target_author,
        p_community_id,
        v_action_type,
        v_rep_amount,
        COALESCE(p_post_id, p_comment_id)
      );
    END IF;

    v_result := jsonb_build_object(
      'success', true,
      'liked', true,
      'action', 'liked',
      'likes_count', COALESCE(v_new_likes_count, 0)
    );
  END IF;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_like_with_reputation(UUID, UUID, UUID, UUID) TO authenticated;

-- ========================
-- 2. toggle_post_like (usado pelo CommunityFeedNotifier no post_provider.dart)
-- Wrapper simples que chama toggle_like_with_reputation
-- ========================
CREATE OR REPLACE FUNCTION public.toggle_post_like(p_post_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_community_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  -- Buscar community_id do post
  SELECT community_id INTO v_community_id
    FROM public.posts
   WHERE id = p_post_id;

  -- Delegar para toggle_like_with_reputation
  RETURN public.toggle_like_with_reputation(
    p_community_id := v_community_id,
    p_user_id := v_user_id,
    p_post_id := p_post_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

GRANT EXECUTE ON FUNCTION public.toggle_post_like(UUID) TO authenticated;
