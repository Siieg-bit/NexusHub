-- =============================================================================
-- Migration: Separar mural de comunidade do mural global
-- Adiciona community_id na tabela comments para distinguir murais por comunidade
-- =============================================================================

-- 1. Adicionar coluna community_id (nullable — NULL = mural global)
ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE;

-- 2. Índice para performance
CREATE INDEX IF NOT EXISTS idx_comments_wall_community
  ON public.comments (profile_wall_id, community_id)
  WHERE profile_wall_id IS NOT NULL;

-- =============================================================================
-- 3. Atualizar RPC get_wall_comments para filtrar por community_id
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_wall_comments(
  p_wall_user_id UUID,
  p_limit        INTEGER DEFAULT 50,
  p_offset       INTEGER DEFAULT 0,
  p_community_id UUID    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_current_user UUID := auth.uid();
  v_result       JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',             c.id,
      'author_id',      c.author_id,
      'content',        c.content,
      'media_url',      c.media_url,
      'media_type',     c.media_type,
      'sticker_id',     c.sticker_id,
      'sticker_url',    c.sticker_url,
      'sticker_name',   c.sticker_name,
      'pack_id',        c.pack_id,
      'emoji_reaction', c.emoji_reaction,
      'likes_count',    COALESCE(cl_count.cnt, 0),
      'is_liked',       (cl_me.id IS NOT NULL),
      'created_at',     c.created_at,
      'author', jsonb_build_object(
        'id',       p.id,
        'nickname', p.nickname,
        'icon_url', p.icon_url
      ),
      'replies', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'id',             r.id,
            'author_id',      r.author_id,
            'content',        r.content,
            'media_url',      r.media_url,
            'media_type',     r.media_type,
            'sticker_id',     r.sticker_id,
            'sticker_url',    r.sticker_url,
            'sticker_name',   r.sticker_name,
            'pack_id',        r.pack_id,
            'emoji_reaction', r.emoji_reaction,
            'likes_count',    COALESCE(rl_count.cnt, 0),
            'is_liked',       (rl_me.id IS NOT NULL),
            'created_at',     r.created_at,
            'author', jsonb_build_object(
              'id',       rp.id,
              'nickname', rp.nickname,
              'icon_url', rp.icon_url
            )
          ) ORDER BY r.created_at ASC
        )
        FROM public.comments r
        LEFT JOIN public.profiles rp ON rp.id = r.author_id
        LEFT JOIN (
          SELECT comment_id, COUNT(*) AS cnt FROM public.comment_likes GROUP BY comment_id
        ) rl_count ON rl_count.comment_id = r.id
        LEFT JOIN public.comment_likes rl_me ON rl_me.comment_id = r.id AND rl_me.user_id = v_current_user
        WHERE r.parent_id = c.id AND r.status = 'ok'
      ), '[]'::jsonb)
    ) ORDER BY c.created_at DESC
  )
  INTO v_result
  FROM public.comments c
  LEFT JOIN public.profiles p ON p.id = c.author_id
  LEFT JOIN (
    SELECT comment_id, COUNT(*) AS cnt FROM public.comment_likes GROUP BY comment_id
  ) cl_count ON cl_count.comment_id = c.id
  LEFT JOIN public.comment_likes cl_me ON cl_me.comment_id = c.id AND cl_me.user_id = v_current_user
  WHERE c.profile_wall_id = p_wall_user_id
    AND c.status = 'ok'
    AND c.parent_id IS NULL
    -- Filtro por comunidade: NULL = mural global, UUID = mural da comunidade específica
    AND (
      (p_community_id IS NULL AND c.community_id IS NULL)
      OR (p_community_id IS NOT NULL AND c.community_id = p_community_id)
    )
  LIMIT p_limit
  OFFSET p_offset;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- =============================================================================
-- 4. Atualizar RPC post_wall_message para aceitar community_id
-- =============================================================================
CREATE OR REPLACE FUNCTION public.post_wall_message(
  p_wall_user_id UUID,
  p_content      TEXT    DEFAULT NULL,
  p_media_url    TEXT    DEFAULT NULL,
  p_media_type   TEXT    DEFAULT NULL,
  p_sticker_id   TEXT    DEFAULT NULL,
  p_sticker_url  TEXT    DEFAULT NULL,
  p_sticker_name TEXT    DEFAULT NULL,
  p_pack_id      TEXT    DEFAULT NULL,
  p_emoji        TEXT    DEFAULT NULL,
  p_parent_id    UUID    DEFAULT NULL,
  p_community_id UUID    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_author_id   UUID := auth.uid();
  v_comment_id  UUID;
  v_author_nick TEXT;
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Validar que há conteúdo
  IF p_content IS NULL AND p_media_url IS NULL AND p_sticker_url IS NULL AND p_emoji IS NULL THEN
    RAISE EXCEPTION 'Comentário vazio';
  END IF;

  -- Buscar nickname do autor
  SELECT nickname INTO v_author_nick FROM public.profiles WHERE id = v_author_id;

  -- Inserir comentário
  INSERT INTO public.comments (
    author_id,
    profile_wall_id,
    community_id,
    parent_id,
    content,
    media_url,
    media_type,
    sticker_id,
    sticker_url,
    sticker_name,
    pack_id,
    emoji_reaction,
    status
  )
  VALUES (
    v_author_id,
    CASE WHEN p_parent_id IS NULL THEN p_wall_user_id ELSE NULL END,
    p_community_id,
    p_parent_id,
    p_content,
    p_media_url,
    p_media_type,
    p_sticker_id,
    p_sticker_url,
    p_sticker_name,
    p_pack_id,
    p_emoji,
    'ok'
  )
  RETURNING id INTO v_comment_id;

  -- Notificar dono do mural (só para comentários raiz, não para replies)
  IF p_parent_id IS NULL AND v_author_id <> p_wall_user_id THEN
    BEGIN
      INSERT INTO public.notifications (
        user_id,
        type,
        actor_id,
        comment_id,
        title,
        is_read
      )
      VALUES (
        p_wall_user_id,
        'wall_comment',
        v_author_id,
        v_comment_id,
        COALESCE(v_author_nick, 'Alguém') || ' comentou no seu mural',
        false
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Falha ao criar notificação: %', SQLERRM;
    END;
  END IF;

  RETURN v_comment_id;
END;
$$;
