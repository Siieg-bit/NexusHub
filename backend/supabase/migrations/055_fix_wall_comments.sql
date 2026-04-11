-- =============================================================================
-- Migration 055 — Fix Wall Comments System
-- =============================================================================
-- Corrige os seguintes bugs:
--   1. Cria tabela comment_likes (não existia)
--   2. Garante colunas sticker_id, sticker_url, sticker_name, pack_id, video_url, media_type em comments
--   3. Relaxa constraint comment_has_target para permitir replies (parent_id) sem target direto
--   4. Cria RPC post_wall_message — envio seguro de mensagem no mural com sticker/mídia/texto
--   5. Cria RPC get_wall_comments — carrega comentários do mural com replies aninhados
--   6. Cria RPC toggle_wall_comment_like — curtir/descurtir comentário do mural
--   7. Cria RPC delete_wall_comment — deletar comentário do mural (owner ou dono do mural)
--   8. Adiciona RLS para comment_likes
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Criar tabela comment_likes (se não existir)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.comment_likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (comment_id, user_id)
);

ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'comment_likes' AND policyname = 'comment_likes_select'
  ) THEN
    CREATE POLICY "comment_likes_select" ON public.comment_likes FOR SELECT USING (TRUE);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'comment_likes' AND policyname = 'comment_likes_insert'
  ) THEN
    CREATE POLICY "comment_likes_insert" ON public.comment_likes FOR INSERT WITH CHECK (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'comment_likes' AND policyname = 'comment_likes_delete'
  ) THEN
    CREATE POLICY "comment_likes_delete" ON public.comment_likes FOR DELETE USING (user_id = auth.uid());
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON public.comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user ON public.comment_likes(user_id);

-- -----------------------------------------------------------------------------
-- 2. Garantir colunas de sticker e mídia em comments
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'sticker_id') THEN
    ALTER TABLE public.comments ADD COLUMN sticker_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'sticker_url') THEN
    ALTER TABLE public.comments ADD COLUMN sticker_url TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'sticker_name') THEN
    ALTER TABLE public.comments ADD COLUMN sticker_name TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'pack_id') THEN
    ALTER TABLE public.comments ADD COLUMN pack_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'video_url') THEN
    ALTER TABLE public.comments ADD COLUMN video_url TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'media_type') THEN
    ALTER TABLE public.comments ADD COLUMN media_type TEXT DEFAULT 'image'; -- 'image' | 'video' | 'sticker' | 'gif'
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'emoji_reaction') THEN
    ALTER TABLE public.comments ADD COLUMN emoji_reaction TEXT; -- emoji único como reação
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Relaxar constraint comment_has_target para permitir replies (parent_id)
--    sem target direto (o target é herdado do pai)
-- -----------------------------------------------------------------------------
ALTER TABLE public.comments DROP CONSTRAINT IF EXISTS comment_has_target;

ALTER TABLE public.comments ADD CONSTRAINT comment_has_target CHECK (
  -- Deve ter pelo menos um target OU ser reply de outro comentário
  (post_id IS NOT NULL)::int +
  (wiki_id IS NOT NULL)::int +
  (profile_wall_id IS NOT NULL)::int +
  (parent_id IS NOT NULL)::int >= 1
);

-- -----------------------------------------------------------------------------
-- 4. RPC: post_wall_message — enviar mensagem no mural com suporte completo
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_wall_message(
  p_wall_user_id  UUID,
  p_content       TEXT    DEFAULT '',
  p_media_url     TEXT    DEFAULT NULL,
  p_media_type    TEXT    DEFAULT 'image',
  p_sticker_id    TEXT    DEFAULT NULL,
  p_sticker_url   TEXT    DEFAULT NULL,
  p_sticker_name  TEXT    DEFAULT NULL,
  p_pack_id       TEXT    DEFAULT NULL,
  p_parent_id     UUID    DEFAULT NULL,
  p_emoji         TEXT    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_comment_id UUID;
  v_author_id  UUID := auth.uid();
  v_content    TEXT;
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Determinar conteúdo textual
  v_content := COALESCE(NULLIF(TRIM(p_content), ''),
    CASE
      WHEN p_sticker_url IS NOT NULL THEN '[sticker]'
      WHEN p_media_url IS NOT NULL   THEN '[' || COALESCE(p_media_type, 'image') || ']'
      WHEN p_emoji IS NOT NULL       THEN p_emoji
      ELSE ''
    END
  );

  IF v_content = '' AND p_media_url IS NULL AND p_sticker_url IS NULL AND p_emoji IS NULL THEN
    RAISE EXCEPTION 'Mensagem não pode ser vazia';
  END IF;

  INSERT INTO public.comments (
    author_id,
    profile_wall_id,
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
  ) VALUES (
    v_author_id,
    CASE WHEN p_parent_id IS NULL THEN p_wall_user_id ELSE NULL END,
    p_parent_id,
    v_content,
    p_media_url,
    COALESCE(p_media_type, 'image'),
    p_sticker_id,
    p_sticker_url,
    p_sticker_name,
    p_pack_id,
    p_emoji,
    'ok'
  ) RETURNING id INTO v_comment_id;

  -- Registrar uso do sticker nos recentes
  IF p_sticker_id IS NOT NULL AND p_sticker_url IS NOT NULL THEN
    INSERT INTO public.recently_used_stickers (
      user_id, sticker_id, sticker_url, sticker_name, used_at
    ) VALUES (
      v_author_id, p_sticker_id, p_sticker_url,
      COALESCE(p_sticker_name, ''), NOW()
    )
    ON CONFLICT (user_id, sticker_id)
    DO UPDATE SET used_at = NOW();
  END IF;

  -- Notificar dono do mural (se não for o próprio usuário)
  IF p_wall_user_id != v_author_id AND p_parent_id IS NULL THEN
    INSERT INTO public.notifications (
      user_id, type, actor_id, reference_id, reference_type
    ) VALUES (
      p_wall_user_id, 'wall_comment', v_author_id, v_comment_id, 'comment'
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_comment_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. RPC: get_wall_comments — carrega comentários do mural com replies e likes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_wall_comments(
  p_wall_user_id UUID,
  p_limit        INT DEFAULT 50,
  p_offset       INT DEFAULT 0
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
      'id',           c.id,
      'author_id',    c.author_id,
      'content',      c.content,
      'media_url',    c.media_url,
      'media_type',   c.media_type,
      'sticker_id',   c.sticker_id,
      'sticker_url',  c.sticker_url,
      'sticker_name', c.sticker_name,
      'pack_id',      c.pack_id,
      'emoji_reaction', c.emoji_reaction,
      'likes_count',  COALESCE(cl_count.cnt, 0),
      'is_liked',     (cl_me.id IS NOT NULL),
      'created_at',   c.created_at,
      'author', jsonb_build_object(
        'id',       p.id,
        'nickname', p.nickname,
        'icon_url', p.icon_url
      ),
      'replies', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'id',           r.id,
            'author_id',    r.author_id,
            'content',      r.content,
            'media_url',    r.media_url,
            'media_type',   r.media_type,
            'sticker_id',   r.sticker_id,
            'sticker_url',  r.sticker_url,
            'sticker_name', r.sticker_name,
            'pack_id',      r.pack_id,
            'emoji_reaction', r.emoji_reaction,
            'likes_count',  COALESCE(rl_count.cnt, 0),
            'is_liked',     (rl_me.id IS NOT NULL),
            'created_at',   r.created_at,
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
  LIMIT p_limit
  OFFSET p_offset;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. RPC: toggle_wall_comment_like — curtir/descurtir comentário
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.toggle_wall_comment_like(
  p_comment_id UUID
)
RETURNS BOOLEAN  -- TRUE = curtiu, FALSE = descurtiu
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_exists  BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.comment_likes
    WHERE comment_id = p_comment_id AND user_id = v_user_id
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.comment_likes
    WHERE comment_id = p_comment_id AND user_id = v_user_id;
    RETURN FALSE;
  ELSE
    INSERT INTO public.comment_likes (comment_id, user_id)
    VALUES (p_comment_id, v_user_id)
    ON CONFLICT DO NOTHING;
    RETURN TRUE;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. RPC: delete_wall_comment — deletar comentário (autor ou dono do mural)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_wall_comment(
  p_comment_id   UUID,
  p_wall_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_author_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT author_id INTO v_author_id
  FROM public.comments
  WHERE id = p_comment_id;

  IF v_author_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Apenas o autor do comentário ou o dono do mural pode deletar
  IF v_user_id != v_author_id AND v_user_id != p_wall_user_id THEN
    RAISE EXCEPTION 'Sem permissão para deletar este comentário';
  END IF;

  -- Deletar replies também (cascade já faz isso, mas garantindo)
  DELETE FROM public.comments WHERE id = p_comment_id;
  RETURN TRUE;
END;
$$;

-- -----------------------------------------------------------------------------
-- 8. Índices adicionais para performance
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_comments_parent ON public.comments(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_comments_sticker ON public.comments(sticker_id) WHERE sticker_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_comments_wall_created ON public.comments(profile_wall_id, created_at DESC) WHERE profile_wall_id IS NOT NULL;
