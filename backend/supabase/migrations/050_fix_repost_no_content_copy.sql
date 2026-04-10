-- ─────────────────────────────────────────────────────────────
-- 050_fix_repost_no_content_copy.sql
-- Corrige o RPC repost_post para NÃO copiar título, conteúdo
-- e mídia do post original.
--
-- Um repost é como um "retweet" do Twitter/X: é um post vazio
-- que apenas referencia o post original via original_post_id.
-- O conteúdo é exibido no frontend através do join com o post
-- original — não deve ser duplicado na linha do repost.
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.repost_post(
  p_original_post_id UUID,
  p_community_id     UUID
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
BEGIN
  -- 1. Autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- 2. Verificar se é membro ativo da comunidade
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id      = v_user_id
      AND is_banned    = false
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'Usuário não é membro da comunidade';
  END IF;

  -- 3. Buscar o post original (deve estar na mesma comunidade e ativo)
  SELECT * INTO v_original_post
  FROM public.posts
  WHERE id           = p_original_post_id
    AND community_id = p_community_id
    AND status       = 'ok';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Post original não encontrado ou não pertence a esta comunidade';
  END IF;

  -- 4. Impedir auto-repost
  IF v_original_post.author_id = v_user_id THEN
    RAISE EXCEPTION 'Não é possível republicar seu próprio post';
  END IF;

  -- 5. Impedir repost de repost
  IF v_original_post.type = 'repost' THEN
    RAISE EXCEPTION 'Não é possível republicar um repost';
  END IF;

  -- 6. Verificar se já republicou este post
  SELECT id INTO v_existing_repost
  FROM public.posts
  WHERE author_id        = v_user_id
    AND type             = 'repost'
    AND original_post_id = p_original_post_id
    AND community_id     = p_community_id
    AND status           = 'ok';

  IF v_existing_repost IS NOT NULL THEN
    RAISE EXCEPTION 'Você já republicou este post';
  END IF;

  -- 7. Inserir o novo post (repost) SEM copiar conteúdo do original.
  --    O frontend busca o conteúdo via join com original_post_id.
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
    NULL,          -- sem título próprio
    '',            -- sem conteúdo próprio
    p_original_post_id,
    p_community_id,
    v_original_post.author_id,
    'ok'
  ) RETURNING id INTO v_new_post_id;

  -- 8. Reputação: +15 XP para quem republicou
  PERFORM public.add_reputation(
    v_user_id, p_community_id, 'create_post', 15, v_new_post_id
  );

  -- 9. Reputação: +5 XP para o autor original
  PERFORM public.add_reputation(
    v_original_post.author_id, p_community_id, 'receive_repost', 5, v_new_post_id
  );

  -- 10. Buscar nickname do usuário para a notificação
  SELECT nickname INTO v_user_nickname
  FROM public.profiles
  WHERE id = v_user_id;

  -- 11. Notificar o autor original
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

-- Permissões (já existem, mas garantir)
GRANT EXECUTE ON FUNCTION public.repost_post(UUID, UUID) TO authenticated;
