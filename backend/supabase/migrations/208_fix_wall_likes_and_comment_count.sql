-- =============================================================================
-- Migration 208: Corrigir curtidas no mural global e adicionar contador de
--                comentários do mural nos perfis e community_members
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Corrigir toggle_wall_comment_like
--    Problema: a RPC usa comment_likes com FK para comments.id, mas não valida
--    se o comentário é realmente de um mural. Além disso, a RPC não atualiza
--    o campo likes_count na tabela comments (desnormalizado).
--    Solução: atualizar likes_count após toggle.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.toggle_wall_comment_like(p_comment_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_exists   BOOLEAN;
  v_is_liked BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar se o comentário existe e é de um mural
  IF NOT EXISTS (
    SELECT 1 FROM public.comments
    WHERE id = p_comment_id
      AND profile_wall_id IS NOT NULL
      AND status = 'ok'
  ) THEN
    RAISE EXCEPTION 'Comentário de mural não encontrado';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.comment_likes
    WHERE comment_id = p_comment_id AND user_id = v_user_id
  ) INTO v_exists;

  IF v_exists THEN
    -- Descurtir
    DELETE FROM public.comment_likes
    WHERE comment_id = p_comment_id AND user_id = v_user_id;

    -- Atualizar contador desnormalizado
    UPDATE public.comments
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = p_comment_id;

    v_is_liked := FALSE;
  ELSE
    -- Curtir
    INSERT INTO public.comment_likes (comment_id, user_id)
    VALUES (p_comment_id, v_user_id)
    ON CONFLICT DO NOTHING;

    -- Atualizar contador desnormalizado
    UPDATE public.comments
    SET likes_count = likes_count + 1
    WHERE id = p_comment_id;

    v_is_liked := TRUE;
  END IF;

  RETURN v_is_liked;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. Adicionar coluna wall_comments_count em profiles
--    Conta comentários raiz (parent_id IS NULL) no mural global do usuário
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS wall_comments_count integer NOT NULL DEFAULT 0;

-- Preencher valor inicial com contagem real
UPDATE public.profiles p
SET wall_comments_count = (
  SELECT COUNT(*)
  FROM public.comments c
  WHERE c.profile_wall_id = p.id
    AND c.parent_id IS NULL
    AND c.community_id IS NULL
    AND c.status = 'ok'
);

-- -----------------------------------------------------------------------------
-- 3. Adicionar coluna wall_comments_count em community_members
--    Conta comentários raiz no mural da comunidade desse membro
-- -----------------------------------------------------------------------------
ALTER TABLE public.community_members
  ADD COLUMN IF NOT EXISTS wall_comments_count integer NOT NULL DEFAULT 0;

-- Preencher valor inicial com contagem real
UPDATE public.community_members cm
SET wall_comments_count = (
  SELECT COUNT(*)
  FROM public.comments c
  WHERE c.profile_wall_id = cm.user_id
    AND c.community_id = cm.community_id
    AND c.parent_id IS NULL
    AND c.status = 'ok'
);

-- -----------------------------------------------------------------------------
-- 4. Trigger para manter wall_comments_count atualizado automaticamente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_wall_comment_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Só processa comentários raiz de mural
  IF (TG_OP = 'INSERT' OR TG_OP = 'DELETE') THEN
    DECLARE
      v_row public.comments;
    BEGIN
      IF TG_OP = 'INSERT' THEN
        v_row := NEW;
      ELSE
        v_row := OLD;
      END IF;

      -- Apenas comentários raiz de mural
      IF v_row.profile_wall_id IS NULL OR v_row.parent_id IS NOT NULL THEN
        RETURN COALESCE(NEW, OLD);
      END IF;

      IF TG_OP = 'INSERT' AND v_row.status = 'ok' THEN
        -- Mural global
        IF v_row.community_id IS NULL THEN
          UPDATE public.profiles
          SET wall_comments_count = wall_comments_count + 1
          WHERE id = v_row.profile_wall_id;
        ELSE
          -- Mural da comunidade
          UPDATE public.community_members
          SET wall_comments_count = wall_comments_count + 1
          WHERE user_id = v_row.profile_wall_id
            AND community_id = v_row.community_id;
        END IF;

      ELSIF TG_OP = 'DELETE' AND v_row.status = 'ok' THEN
        IF v_row.community_id IS NULL THEN
          UPDATE public.profiles
          SET wall_comments_count = GREATEST(0, wall_comments_count - 1)
          WHERE id = v_row.profile_wall_id;
        ELSE
          UPDATE public.community_members
          SET wall_comments_count = GREATEST(0, wall_comments_count - 1)
          WHERE user_id = v_row.profile_wall_id
            AND community_id = v_row.community_id;
        END IF;
      END IF;
    END;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Quando status muda (ex: comentário deletado via soft-delete)
    IF OLD.profile_wall_id IS NOT NULL AND OLD.parent_id IS NULL THEN
      IF OLD.status = 'ok' AND NEW.status != 'ok' THEN
        -- Comentário removido
        IF OLD.community_id IS NULL THEN
          UPDATE public.profiles
          SET wall_comments_count = GREATEST(0, wall_comments_count - 1)
          WHERE id = OLD.profile_wall_id;
        ELSE
          UPDATE public.community_members
          SET wall_comments_count = GREATEST(0, wall_comments_count - 1)
          WHERE user_id = OLD.profile_wall_id
            AND community_id = OLD.community_id;
        END IF;
      ELSIF OLD.status != 'ok' AND NEW.status = 'ok' THEN
        -- Comentário restaurado
        IF NEW.community_id IS NULL THEN
          UPDATE public.profiles
          SET wall_comments_count = wall_comments_count + 1
          WHERE id = NEW.profile_wall_id;
        ELSE
          UPDATE public.community_members
          SET wall_comments_count = wall_comments_count + 1
          WHERE user_id = NEW.profile_wall_id
            AND community_id = NEW.community_id;
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Remover trigger antigo se existir
DROP TRIGGER IF EXISTS trg_wall_comment_count ON public.comments;

-- Criar trigger
CREATE TRIGGER trg_wall_comment_count
  AFTER INSERT OR UPDATE OR DELETE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.update_wall_comment_count();

-- -----------------------------------------------------------------------------
-- 5. Atualizar get_wall_comments para retornar total_count
--    (útil para exibir o contador na aba)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_wall_comments(
  p_wall_user_id  uuid,
  p_limit         integer DEFAULT 50,
  p_offset        integer DEFAULT 0,
  p_community_id  uuid    DEFAULT NULL
)
RETURNS jsonb
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
    AND (
      (p_community_id IS NULL AND c.community_id IS NULL)
      OR (p_community_id IS NOT NULL AND c.community_id = p_community_id)
    )
  LIMIT p_limit
  OFFSET p_offset;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. Atualizar post_wall_message para incrementar wall_comments_count
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_wall_message(
  p_wall_user_id uuid,
  p_content      text    DEFAULT NULL,
  p_media_url    text    DEFAULT NULL,
  p_media_type   text    DEFAULT NULL,
  p_sticker_id   text    DEFAULT NULL,
  p_sticker_url  text    DEFAULT NULL,
  p_sticker_name text    DEFAULT NULL,
  p_pack_id      text    DEFAULT NULL,
  p_emoji        text    DEFAULT NULL,
  p_parent_id    uuid    DEFAULT NULL,
  p_community_id uuid    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_author_id   uuid := auth.uid();
  v_comment_id  uuid;
  v_author_nick text;
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_content IS NULL AND p_media_url IS NULL AND p_sticker_url IS NULL AND p_emoji IS NULL THEN
    RAISE EXCEPTION 'Comentário vazio';
  END IF;

  -- Buscar nickname do autor
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
    author_id, profile_wall_id, community_id, parent_id,
    content, media_url, media_type,
    sticker_id, sticker_url, sticker_name, pack_id,
    emoji_reaction, status
  )
  VALUES (
    v_author_id,
    CASE WHEN p_parent_id IS NULL THEN p_wall_user_id ELSE NULL END,
    p_community_id,
    p_parent_id,
    p_content, p_media_url, p_media_type,
    p_sticker_id, p_sticker_url, p_sticker_name, p_pack_id,
    p_emoji, 'ok'
  )
  RETURNING id INTO v_comment_id;

  -- Atualizar contador de comentários do mural (apenas para comentários raiz)
  IF p_parent_id IS NULL THEN
    IF p_community_id IS NULL THEN
      UPDATE public.profiles
      SET wall_comments_count = wall_comments_count + 1
      WHERE id = p_wall_user_id;
    ELSE
      UPDATE public.community_members
      SET wall_comments_count = wall_comments_count + 1
      WHERE user_id = p_wall_user_id
        AND community_id = p_community_id;
    END IF;
  END IF;

  -- Registrar sticker nos recentes
  IF p_sticker_id IS NOT NULL AND p_sticker_url IS NOT NULL THEN
    INSERT INTO public.recently_used_stickers (
      user_id, sticker_id, sticker_url, sticker_name, used_at
    ) VALUES (
      v_author_id, p_sticker_id, p_sticker_url, COALESCE(p_sticker_name, ''), NOW()
    )
    ON CONFLICT (user_id, sticker_id)
    DO UPDATE SET used_at = NOW();
  END IF;

  -- Notificar dono do mural
  IF p_parent_id IS NULL AND v_author_id <> p_wall_user_id THEN
    BEGIN
      INSERT INTO public.notifications (
        user_id, type, actor_id, comment_id, title, is_read
      )
      VALUES (
        p_wall_user_id, 'wall_comment', v_author_id, v_comment_id,
        v_author_nick || ' comentou no seu mural', false
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Falha ao criar notificação: %', SQLERRM;
    END;
  END IF;

  RETURN v_comment_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. Atualizar delete_wall_comment para decrementar wall_comments_count
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_wall_comment(
  p_comment_id   uuid,
  p_wall_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id      uuid := auth.uid();
  v_comment      public.comments%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT * INTO v_comment
  FROM public.comments
  WHERE id = p_comment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Comentário não encontrado';
  END IF;

  -- Apenas o autor ou o dono do mural pode deletar
  IF v_comment.author_id <> v_user_id AND p_wall_user_id <> v_user_id THEN
    RAISE EXCEPTION 'Sem permissão para deletar este comentário';
  END IF;

  -- Soft-delete
  UPDATE public.comments
  SET status = 'deleted'
  WHERE id = p_comment_id;

  -- Decrementar contador (apenas para comentários raiz)
  IF v_comment.parent_id IS NULL AND v_comment.profile_wall_id IS NOT NULL THEN
    IF v_comment.community_id IS NULL THEN
      UPDATE public.profiles
      SET wall_comments_count = GREATEST(0, wall_comments_count - 1)
      WHERE id = v_comment.profile_wall_id;
    ELSE
      UPDATE public.community_members
      SET wall_comments_count = GREATEST(0, wall_comments_count - 1)
      WHERE user_id = v_comment.profile_wall_id
        AND community_id = v_comment.community_id;
    END IF;
  END IF;
END;
$$;
