-- =============================================================================
-- Migration 194 — Fix Wall Comments: perfil local da comunidade + overloads
-- =============================================================================
-- Corrige os seguintes problemas:
--   1. Remove overloads duplicados de get_wall_comments e post_wall_message
--      que causavam PGRST203 (Multiple Choices) no PostgREST.
--   2. Reescreve get_wall_comments para retornar local_nickname e
--      local_icon_url da tabela community_members quando p_community_id
--      for fornecido, em vez de sempre usar o perfil global (profiles).
--   3. Reescreve post_wall_message como versão única definitiva com
--      suporte a p_community_id.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Remover TODOS os overloads existentes de get_wall_comments
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_wall_comments(uuid, integer, integer) CASCADE;
DROP FUNCTION IF EXISTS public.get_wall_comments(uuid, integer, integer, uuid) CASCADE;

-- -----------------------------------------------------------------------------
-- 2. Remover TODOS os overloads existentes de post_wall_message
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, text, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, text, text, uuid, uuid) CASCADE;

-- -----------------------------------------------------------------------------
-- 3. Recriar get_wall_comments — versão única com suporte a perfil local
--    Quando p_community_id é fornecido, usa local_nickname e local_icon_url
--    da tabela community_members. Quando NULL, usa o perfil global (profiles).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_wall_comments(
  p_wall_user_id UUID,
  p_limit        INT     DEFAULT 50,
  p_offset       INT     DEFAULT 0,
  p_community_id UUID    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
      -- Perfil do autor: usa perfil local da comunidade se disponível,
      -- caso contrário usa o perfil global.
      'author', jsonb_build_object(
        'id',       p.id,
        'nickname', COALESCE(
          NULLIF(TRIM(cm_author.local_nickname), ''),
          p.nickname
        ),
        'icon_url', COALESCE(
          NULLIF(TRIM(cm_author.local_icon_url), ''),
          p.icon_url
        )
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
            -- Perfil do autor da reply: mesma lógica de perfil local
            'author', jsonb_build_object(
              'id',       rp.id,
              'nickname', COALESCE(
                NULLIF(TRIM(cm_reply.local_nickname), ''),
                rp.nickname
              ),
              'icon_url', COALESCE(
                NULLIF(TRIM(cm_reply.local_icon_url), ''),
                rp.icon_url
              )
            )
          ) ORDER BY r.created_at ASC
        )
        FROM public.comments r
        LEFT JOIN public.profiles rp ON rp.id = r.author_id
        -- Join com community_members para perfil local da reply
        LEFT JOIN public.community_members cm_reply
          ON cm_reply.user_id = r.author_id
          AND cm_reply.community_id = p_community_id
          AND p_community_id IS NOT NULL
        LEFT JOIN (
          SELECT comment_id, COUNT(*) AS cnt FROM public.comment_likes GROUP BY comment_id
        ) rl_count ON rl_count.comment_id = r.id
        LEFT JOIN public.comment_likes rl_me
          ON rl_me.comment_id = r.id AND rl_me.user_id = v_current_user
        WHERE r.parent_id = c.id AND r.status = 'ok'
      ), '[]'::jsonb)
    ) ORDER BY c.created_at DESC
  )
  INTO v_result
  FROM public.comments c
  LEFT JOIN public.profiles p ON p.id = c.author_id
  -- Join com community_members para perfil local do autor principal
  LEFT JOIN public.community_members cm_author
    ON cm_author.user_id = c.author_id
    AND cm_author.community_id = p_community_id
    AND p_community_id IS NOT NULL
  LEFT JOIN (
    SELECT comment_id, COUNT(*) AS cnt FROM public.comment_likes GROUP BY comment_id
  ) cl_count ON cl_count.comment_id = c.id
  LEFT JOIN public.comment_likes cl_me
    ON cl_me.comment_id = c.id AND cl_me.user_id = v_current_user
  WHERE c.profile_wall_id = p_wall_user_id
    AND c.status = 'ok'
    AND c.parent_id IS NULL
    -- Filtro por comunidade: NULL = mural global, UUID = mural da comunidade
    AND (
      (p_community_id IS NULL AND c.community_id IS NULL)
      OR (p_community_id IS NOT NULL AND c.community_id = p_community_id)
    )
  LIMIT p_limit
  OFFSET p_offset;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_wall_comments(uuid, integer, integer, uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- 4. Recriar post_wall_message — versão única definitiva com community_id
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_wall_message(
  p_wall_user_id  uuid,
  p_content       text    DEFAULT NULL,
  p_media_url     text    DEFAULT NULL,
  p_media_type    text    DEFAULT NULL,
  p_sticker_id    text    DEFAULT NULL,
  p_sticker_url   text    DEFAULT NULL,
  p_sticker_name  text    DEFAULT NULL,
  p_pack_id       text    DEFAULT NULL,
  p_emoji         text    DEFAULT NULL,
  p_parent_id     uuid    DEFAULT NULL,
  p_community_id  uuid    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id   uuid := auth.uid();
  v_comment_id  uuid;
  v_author_nick text;
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Validar que há conteúdo
  IF p_content IS NULL AND p_media_url IS NULL AND p_sticker_url IS NULL AND p_emoji IS NULL THEN
    RAISE EXCEPTION 'Comentário vazio';
  END IF;

  -- Buscar nickname do autor (local se disponível, global como fallback)
  SELECT COALESCE(
    NULLIF(TRIM(cm.local_nickname), ''),
    pr.nickname,
    'Alguém'
  )
  INTO v_author_nick
  FROM public.profiles pr
  LEFT JOIN public.community_members cm
    ON cm.user_id = pr.id
    AND cm.community_id = p_community_id
    AND p_community_id IS NOT NULL
  WHERE pr.id = v_author_id;

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

  -- Registrar uso do sticker nos recentes (se aplicável)
  IF p_sticker_id IS NOT NULL AND p_sticker_url IS NOT NULL THEN
    INSERT INTO public.recently_used_stickers (
      user_id, sticker_id, sticker_url, sticker_name, used_at
    ) VALUES (
      v_author_id,
      p_sticker_id,
      p_sticker_url,
      COALESCE(p_sticker_name, ''),
      NOW()
    )
    ON CONFLICT (user_id, sticker_id)
    DO UPDATE SET used_at = NOW();
  END IF;

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
        v_author_nick || ' comentou no seu mural',
        false
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Falha ao criar notificação: %', SQLERRM;
    END;
  END IF;

  RETURN v_comment_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.post_wall_message(uuid, text, text, text, text, text, text, text, text, uuid, uuid) TO authenticated;
