-- =============================================================================
-- Migration 105: Adicionar RPC toggle_like_with_reputation
--
-- Corrige:
-- 1. Criar RPC toggle_like_with_reputation para curtir/descurtir posts
-- =============================================================================

-- ========================
-- RPC: toggle_like_with_reputation
-- ========================
CREATE OR REPLACE FUNCTION public.toggle_like_with_reputation(
  p_community_id UUID,
  p_user_id UUID,
  p_post_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_post_id UUID;
  v_is_liked BOOLEAN;
  v_post_author_id UUID;
  v_reputation_change INT := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  -- Verificar se o post existe
  SELECT id, author_id INTO v_post_id, v_post_author_id
    FROM public.posts
   WHERE id = p_post_id AND community_id = p_community_id;

  IF v_post_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_not_found');
  END IF;

  -- Verificar se já curtiu
  SELECT EXISTS(
    SELECT 1 FROM public.post_likes
     WHERE post_id = p_post_id AND user_id = p_user_id
  ) INTO v_is_liked;

  IF v_is_liked THEN
    -- Remover curtida
    DELETE FROM public.post_likes
     WHERE post_id = p_post_id AND user_id = p_user_id;
    
    -- Atualizar contador
    UPDATE public.posts
       SET likes_count = GREATEST(0, likes_count - 1)
     WHERE id = p_post_id;
    
    -- Remover reputação (se o post não for do próprio usuário)
    IF v_post_author_id != p_user_id THEN
      v_reputation_change := -1;
      PERFORM public.add_reputation(
        p_user_id := v_post_author_id,
        p_community_id := p_community_id,
        p_action_type := 'post_like_removed',
        p_amount := 1
      );
    END IF;
  ELSE
    -- Adicionar curtida
    INSERT INTO public.post_likes (post_id, user_id)
    VALUES (p_post_id, p_user_id)
    ON CONFLICT DO NOTHING;
    
    -- Atualizar contador
    UPDATE public.posts
       SET likes_count = likes_count + 1
     WHERE id = p_post_id;
    
    -- Adicionar reputação (se o post não for do próprio usuário)
    IF v_post_author_id != p_user_id THEN
      v_reputation_change := 1;
      PERFORM public.add_reputation(
        p_user_id := v_post_author_id,
        p_community_id := p_community_id,
        p_action_type := 'post_like',
        p_amount := 1
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'is_liked', NOT v_is_liked,
    'likes_count', (SELECT likes_count FROM public.posts WHERE id = p_post_id),
    'reputation_change', v_reputation_change
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.toggle_like_with_reputation(UUID, UUID, UUID) TO authenticated;
