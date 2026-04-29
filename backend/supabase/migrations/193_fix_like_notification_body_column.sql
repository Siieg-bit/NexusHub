-- Migration 193: Corrigir nome da coluna de conteúdo em notifications na RPC de curtidas
-- A tabela notifications usa 'body' em vez de 'content'.

CREATE OR REPLACE FUNCTION public.toggle_reaction_with_reputation(
  p_community_id UUID,
  p_user_id      UUID,
  p_post_id      UUID DEFAULT NULL,
  p_type         TEXT DEFAULT 'like'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_type TEXT;
  v_target_author UUID;
  v_action        TEXT;
  v_likes_delta   INT := 0;
  v_new_likes     INT;
  v_actor_name    TEXT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;
  IF p_post_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_target');
  END IF;

  -- Buscar autor do post
  SELECT author_id INTO v_target_author FROM public.posts WHERE id = p_post_id;
  IF v_target_author IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_not_found');
  END IF;

  -- Verificar reaction existente
  SELECT type INTO v_existing_type
    FROM public.post_reactions
   WHERE post_id = p_post_id AND user_id = p_user_id;

  IF v_existing_type IS NULL THEN
    -- Adicionar nova reaction
    INSERT INTO public.post_reactions (post_id, user_id, type)
    VALUES (p_post_id, p_user_id, p_type);
    v_action := 'added';
    IF p_type = 'like' THEN v_likes_delta := 1; END IF;

    -- Reputação ao autor
    IF v_target_author != p_user_id AND p_community_id IS NOT NULL THEN
      PERFORM public.add_reputation(
        v_target_author, p_community_id, 'receive_post_like', 2, p_post_id
      );
    END IF;

    -- Notificação
    IF p_type IN ('like', 'love') AND v_target_author != p_user_id THEN
      -- Buscar nome de quem curtiu para o título
      SELECT nickname INTO v_actor_name FROM public.profiles WHERE id = p_user_id;
      
      INSERT INTO public.notifications (user_id, actor_id, type, post_id, title, body)
      VALUES (
        v_target_author, 
        p_user_id, 
        'like', 
        p_post_id, 
        COALESCE(v_actor_name, 'Alguém') || ' curtiu seu post',
        'Clique para ver quem curtiu seu conteúdo.'
      )
      ON CONFLICT DO NOTHING;
    END IF;

  ELSIF v_existing_type = p_type THEN
    -- Toggle off (remover)
    DELETE FROM public.post_reactions WHERE post_id = p_post_id AND user_id = p_user_id;
    v_action := 'removed';
    IF p_type = 'like' THEN v_likes_delta := -1; END IF;
  ELSE
    -- Trocar tipo
    UPDATE public.post_reactions SET type = p_type
     WHERE post_id = p_post_id AND user_id = p_user_id;
    v_action := 'changed';
    IF v_existing_type = 'like' THEN v_likes_delta := -1;
    ELSIF p_type = 'like' THEN v_likes_delta := 1;
    END IF;
  END IF;

  -- Atualizar likes_count
  IF v_likes_delta != 0 THEN
    UPDATE public.posts
       SET likes_count = GREATEST(likes_count + v_likes_delta, 0)
     WHERE id = p_post_id
     RETURNING likes_count INTO v_new_likes;
  ELSE
    SELECT likes_count INTO v_new_likes FROM public.posts WHERE id = p_post_id;
  END IF;

  RETURN jsonb_build_object(
    'success',     true,
    'action',      v_action,
    'type',        p_type,
    'liked',       v_action != 'removed',
    'likes_count', COALESCE(v_new_likes, 0)
  );
END;
$$;
