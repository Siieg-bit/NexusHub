-- =============================================================================
-- MIGRATION 053 — Sistema Completo de Stickers / Figurinhas
-- Criação personalizada, favoritos, salvamento entre usuários,
-- integração com chat e comentários.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. EXTENSÃO DA TABELA sticker_packs — suporte a packs de usuários
-- -----------------------------------------------------------------------------
ALTER TABLE public.sticker_packs
  ADD COLUMN IF NOT EXISTS creator_id       UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_user_created  BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_public        BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS cover_url        TEXT,
  ADD COLUMN IF NOT EXISTS tags             TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS sticker_count    INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saves_count      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at       TIMESTAMPTZ DEFAULT NOW();

-- Índices para packs de usuários
CREATE INDEX IF NOT EXISTS idx_sticker_packs_creator
  ON public.sticker_packs(creator_id) WHERE creator_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sticker_packs_user_created
  ON public.sticker_packs(is_user_created, is_public, created_at DESC);

-- -----------------------------------------------------------------------------
-- 2. EXTENSÃO DA TABELA stickers — metadados adicionais
-- -----------------------------------------------------------------------------
ALTER TABLE public.stickers
  ADD COLUMN IF NOT EXISTS creator_id       UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS thumbnail_url    TEXT,
  ADD COLUMN IF NOT EXISTS is_animated      BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS tags             TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS uses_count       INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saves_count      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at       TIMESTAMPTZ DEFAULT NOW();

-- Índice para busca por tags
CREATE INDEX IF NOT EXISTS idx_stickers_tags_gin
  ON public.stickers USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_stickers_creator
  ON public.stickers(creator_id) WHERE creator_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3. TABELA user_saved_sticker_packs — usuários salvam packs de outros
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_saved_sticker_packs (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pack_id    UUID NOT NULL REFERENCES public.sticker_packs(id) ON DELETE CASCADE,
  saved_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, pack_id)
);

ALTER TABLE public.user_saved_sticker_packs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'user_saved_sticker_packs'
      AND policyname = 'user_saved_sticker_packs_own'
  ) THEN
    CREATE POLICY "user_saved_sticker_packs_own"
      ON public.user_saved_sticker_packs
      FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- Política de leitura pública (para contar saves)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'user_saved_sticker_packs'
      AND policyname = 'user_saved_sticker_packs_read_public'
  ) THEN
    CREATE POLICY "user_saved_sticker_packs_read_public"
      ON public.user_saved_sticker_packs
      FOR SELECT
      USING (TRUE);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_saved_packs_user
  ON public.user_saved_sticker_packs(user_id, saved_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_saved_packs_pack
  ON public.user_saved_sticker_packs(pack_id);

-- -----------------------------------------------------------------------------
-- 4. TABELA sticker_reactions — reagir a mensagens/comentários com stickers
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sticker_reactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sticker_id      TEXT NOT NULL,
  sticker_url     TEXT NOT NULL DEFAULT '',
  -- Contexto (apenas um dos campos abaixo é preenchido)
  message_id      UUID REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  comment_id      UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  post_id         UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, sticker_id, message_id),
  UNIQUE (user_id, sticker_id, comment_id),
  UNIQUE (user_id, sticker_id, post_id)
);

ALTER TABLE public.sticker_reactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sticker_reactions'
      AND policyname = 'sticker_reactions_read_all'
  ) THEN
    CREATE POLICY "sticker_reactions_read_all"
      ON public.sticker_reactions
      FOR SELECT USING (TRUE);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sticker_reactions'
      AND policyname = 'sticker_reactions_own'
  ) THEN
    CREATE POLICY "sticker_reactions_own"
      ON public.sticker_reactions
      FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sticker_reactions_message
  ON public.sticker_reactions(message_id) WHERE message_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sticker_reactions_comment
  ON public.sticker_reactions(comment_id) WHERE comment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sticker_reactions_post
  ON public.sticker_reactions(post_id) WHERE post_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 5. STORAGE BUCKET — stickers criados por usuários
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-stickers',
  'user-stickers',
  TRUE,
  5242880,  -- 5MB
  ARRAY['image/png', 'image/jpeg', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = TRUE,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/gif', 'image/webp'];

-- Políticas de storage para user-stickers
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM storage.policies
    WHERE bucket_id = 'user-stickers' AND name = 'user_stickers_public_read'
  ) THEN
    INSERT INTO storage.policies (bucket_id, name, definition)
    VALUES (
      'user-stickers',
      'user_stickers_public_read',
      '{"operation":"SELECT","check":null,"using":"true"}'
    );
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- -----------------------------------------------------------------------------
-- 6. RPC: create_sticker_pack — criar pack de stickers
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_sticker_pack(
  p_name        TEXT,
  p_description TEXT DEFAULT '',
  p_cover_url   TEXT DEFAULT NULL,
  p_tags        TEXT[] DEFAULT '{}',
  p_is_public   BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pack_id UUID;
BEGIN
  INSERT INTO public.sticker_packs (
    name, description, cover_url, tags,
    creator_id, is_user_created, is_public,
    is_free, is_active, author_name
  )
  SELECT
    p_name, p_description, p_cover_url, p_tags,
    auth.uid(), TRUE, COALESCE(p_is_public, TRUE),
    TRUE, TRUE,
    COALESCE(p.nickname, 'Usuário')
  FROM public.profiles p
  WHERE p.id = auth.uid()
  RETURNING id INTO v_pack_id;

  RETURN v_pack_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. RPC: add_sticker_to_pack — adicionar sticker a um pack
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.add_sticker_to_pack(
  p_pack_id     UUID,
  p_image_url   TEXT,
  p_name        TEXT DEFAULT '',
  p_tags        TEXT[] DEFAULT '{}',
  p_is_animated BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sticker_id UUID;
  v_is_owner   BOOLEAN;
BEGIN
  -- Verificar se o usuário é dono do pack
  SELECT EXISTS(
    SELECT 1 FROM public.sticker_packs
    WHERE id = p_pack_id AND creator_id = auth.uid()
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RAISE EXCEPTION 'Sem permissão para adicionar sticker a este pack';
  END IF;

  INSERT INTO public.stickers (
    pack_id, image_url, name, tags, is_animated, creator_id, sort_order
  )
  SELECT
    p_pack_id, p_image_url, p_name, p_tags, p_is_animated, auth.uid(),
    COALESCE((SELECT MAX(sort_order) + 1 FROM public.stickers WHERE pack_id = p_pack_id), 0)
  RETURNING id INTO v_sticker_id;

  -- Atualizar contador do pack
  UPDATE public.sticker_packs
  SET sticker_count = sticker_count + 1,
      updated_at = NOW(),
      -- Usar o primeiro sticker como cover se não houver
      cover_url = COALESCE(cover_url, p_image_url)
  WHERE id = p_pack_id;

  RETURN v_sticker_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 8. RPC: delete_sticker_from_pack — remover sticker de um pack
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_sticker_from_pack(
  p_sticker_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pack_id UUID;
BEGIN
  -- Verificar propriedade
  SELECT pack_id INTO v_pack_id
  FROM public.stickers s
  JOIN public.sticker_packs sp ON sp.id = s.pack_id
  WHERE s.id = p_sticker_id
    AND (s.creator_id = auth.uid() OR sp.creator_id = auth.uid());

  IF v_pack_id IS NULL THEN
    RAISE EXCEPTION 'Sem permissão para remover este sticker';
  END IF;

  DELETE FROM public.stickers WHERE id = p_sticker_id;

  -- Atualizar contador
  UPDATE public.sticker_packs
  SET sticker_count = GREATEST(sticker_count - 1, 0),
      updated_at = NOW()
  WHERE id = v_pack_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 9. RPC: save_sticker_pack — salvar pack de outro usuário
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_sticker_pack(
  p_pack_id UUID
)
RETURNS BOOLEAN  -- TRUE = salvo, FALSE = removido
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.user_saved_sticker_packs
    WHERE user_id = auth.uid() AND pack_id = p_pack_id
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.user_saved_sticker_packs
    WHERE user_id = auth.uid() AND pack_id = p_pack_id;

    UPDATE public.sticker_packs
    SET saves_count = GREATEST(saves_count - 1, 0)
    WHERE id = p_pack_id;

    RETURN FALSE;
  ELSE
    INSERT INTO public.user_saved_sticker_packs (user_id, pack_id)
    VALUES (auth.uid(), p_pack_id)
    ON CONFLICT (user_id, pack_id) DO NOTHING;

    UPDATE public.sticker_packs
    SET saves_count = saves_count + 1
    WHERE id = p_pack_id;

    RETURN TRUE;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 10. RPC: get_my_sticker_packs — packs criados pelo usuário
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_sticker_packs()
RETURNS TABLE (
  id            UUID,
  name          TEXT,
  description   TEXT,
  cover_url     TEXT,
  tags          TEXT[],
  sticker_count INTEGER,
  saves_count   INTEGER,
  is_public     BOOLEAN,
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.id, sp.name, sp.description, sp.cover_url, sp.tags,
    sp.sticker_count, sp.saves_count, sp.is_public,
    sp.created_at, sp.updated_at
  FROM public.sticker_packs sp
  WHERE sp.creator_id = auth.uid()
    AND sp.is_user_created = TRUE
  ORDER BY sp.updated_at DESC;
END;
$$;

-- -----------------------------------------------------------------------------
-- 11. RPC: get_saved_sticker_packs — packs salvos pelo usuário
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_saved_sticker_packs()
RETURNS TABLE (
  id            UUID,
  name          TEXT,
  description   TEXT,
  cover_url     TEXT,
  tags          TEXT[],
  sticker_count INTEGER,
  saves_count   INTEGER,
  creator_id    UUID,
  author_name   TEXT,
  saved_at      TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.id, sp.name, sp.description, sp.cover_url, sp.tags,
    sp.sticker_count, sp.saves_count, sp.creator_id, sp.author_name,
    usp.saved_at
  FROM public.user_saved_sticker_packs usp
  JOIN public.sticker_packs sp ON sp.id = usp.pack_id
  WHERE usp.user_id = auth.uid()
    AND sp.is_active = TRUE
  ORDER BY usp.saved_at DESC;
END;
$$;

-- -----------------------------------------------------------------------------
-- 12. RPC: get_public_sticker_packs — descobrir packs públicos
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_public_sticker_packs(
  p_search      TEXT DEFAULT NULL,
  p_limit       INTEGER DEFAULT 20,
  p_offset      INTEGER DEFAULT 0
)
RETURNS TABLE (
  id            UUID,
  name          TEXT,
  description   TEXT,
  cover_url     TEXT,
  tags          TEXT[],
  sticker_count INTEGER,
  saves_count   INTEGER,
  creator_id    UUID,
  author_name   TEXT,
  creator_icon  TEXT,
  is_saved      BOOLEAN,
  created_at    TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.id, sp.name, sp.description, sp.cover_url, sp.tags,
    sp.sticker_count, sp.saves_count, sp.creator_id, sp.author_name,
    p.icon_url AS creator_icon,
    EXISTS(
      SELECT 1 FROM public.user_saved_sticker_packs usp2
      WHERE usp2.user_id = auth.uid() AND usp2.pack_id = sp.id
    ) AS is_saved,
    sp.created_at
  FROM public.sticker_packs sp
  LEFT JOIN public.profiles p ON p.id = sp.creator_id
  WHERE sp.is_user_created = TRUE
    AND sp.is_public = TRUE
    AND sp.is_active = TRUE
    AND sp.sticker_count > 0
    AND (
      p_search IS NULL
      OR sp.name ILIKE '%' || p_search || '%'
      OR sp.description ILIKE '%' || p_search || '%'
      OR p_search = ANY(sp.tags)
    )
  ORDER BY sp.saves_count DESC, sp.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- -----------------------------------------------------------------------------
-- 13. RPC: get_pack_stickers — listar stickers de um pack
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_pack_stickers(
  p_pack_id UUID
)
RETURNS TABLE (
  id          UUID,
  pack_id     UUID,
  name        TEXT,
  image_url   TEXT,
  tags        TEXT[],
  is_animated BOOLEAN,
  uses_count  INTEGER,
  sort_order  INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id, s.pack_id, s.name, s.image_url, s.tags,
    s.is_animated, s.uses_count, s.sort_order
  FROM public.stickers s
  JOIN public.sticker_packs sp ON sp.id = s.pack_id
  WHERE s.pack_id = p_pack_id
    AND (
      sp.is_public = TRUE
      OR sp.creator_id = auth.uid()
      OR EXISTS(
        SELECT 1 FROM public.user_saved_sticker_packs usp
        WHERE usp.user_id = auth.uid() AND usp.pack_id = p_pack_id
      )
    )
  ORDER BY s.sort_order ASC, s.created_at ASC;
END;
$$;

-- -----------------------------------------------------------------------------
-- 14. RPC: get_all_my_stickers — todos os stickers disponíveis para o usuário
--     (meus packs + packs salvos + packs da loja)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_all_my_stickers()
RETURNS TABLE (
  sticker_id    TEXT,
  sticker_url   TEXT,
  sticker_name  TEXT,
  pack_id       TEXT,
  pack_name     TEXT,
  pack_cover    TEXT,
  is_my_pack    BOOLEAN,
  is_favorite   BOOLEAN,
  sort_order    INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    s.id::TEXT AS sticker_id,
    s.image_url AS sticker_url,
    COALESCE(s.name, '') AS sticker_name,
    sp.id::TEXT AS pack_id,
    sp.name AS pack_name,
    sp.cover_url AS pack_cover,
    (sp.creator_id = auth.uid()) AS is_my_pack,
    EXISTS(
      SELECT 1 FROM public.user_sticker_favorites usf
      WHERE usf.user_id = auth.uid()
        AND usf.sticker_id = s.id::TEXT
        AND usf.category = 'favorite'
    ) AS is_favorite,
    s.sort_order
  FROM public.stickers s
  JOIN public.sticker_packs sp ON sp.id = s.pack_id
  WHERE sp.is_active = TRUE
    AND (
      -- Pack da loja (não criado por usuário)
      (sp.is_user_created = FALSE)
      OR
      -- Pack criado pelo próprio usuário
      (sp.creator_id = auth.uid())
      OR
      -- Pack salvo pelo usuário
      EXISTS(
        SELECT 1 FROM public.user_saved_sticker_packs usp
        WHERE usp.user_id = auth.uid() AND usp.pack_id = sp.id
      )
    )
  ORDER BY is_my_pack DESC, sp.name, s.sort_order;
END;
$$;

-- -----------------------------------------------------------------------------
-- 15. RPC: update_sticker_pack — editar pack do usuário
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_sticker_pack(
  p_pack_id     UUID,
  p_name        TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_cover_url   TEXT DEFAULT NULL,
  p_tags        TEXT[] DEFAULT NULL,
  p_is_public   BOOLEAN DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.sticker_packs
  SET
    name        = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    cover_url   = COALESCE(p_cover_url, cover_url),
    tags        = COALESCE(p_tags, tags),
    is_public   = COALESCE(p_is_public, is_public),
    updated_at  = NOW()
  WHERE id = p_pack_id
    AND creator_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pack não encontrado ou sem permissão';
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 16. RPC: delete_sticker_pack — deletar pack do usuário
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_sticker_pack(
  p_pack_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.sticker_packs
  WHERE id = p_pack_id
    AND creator_id = auth.uid()
    AND is_user_created = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pack não encontrado ou sem permissão';
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 17. RPC: increment_sticker_uses — registrar uso de sticker
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_sticker_uses(
  p_sticker_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.stickers
  SET uses_count = uses_count + 1
  WHERE id = p_sticker_id::UUID;
EXCEPTION WHEN OTHERS THEN NULL;
END;
$$;

-- -----------------------------------------------------------------------------
-- 18. RPC: get_sticker_pack_detail — detalhes de um pack específico
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_sticker_pack_detail(
  p_pack_id UUID
)
RETURNS TABLE (
  id            UUID,
  name          TEXT,
  description   TEXT,
  cover_url     TEXT,
  tags          TEXT[],
  sticker_count INTEGER,
  saves_count   INTEGER,
  is_public     BOOLEAN,
  creator_id    UUID,
  author_name   TEXT,
  creator_icon  TEXT,
  is_owner      BOOLEAN,
  is_saved      BOOLEAN,
  created_at    TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.id, sp.name, sp.description, sp.cover_url, sp.tags,
    sp.sticker_count, sp.saves_count, sp.is_public,
    sp.creator_id, sp.author_name,
    p.icon_url AS creator_icon,
    (sp.creator_id = auth.uid()) AS is_owner,
    EXISTS(
      SELECT 1 FROM public.user_saved_sticker_packs usp
      WHERE usp.user_id = auth.uid() AND usp.pack_id = sp.id
    ) AS is_saved,
    sp.created_at
  FROM public.sticker_packs sp
  LEFT JOIN public.profiles p ON p.id = sp.creator_id
  WHERE sp.id = p_pack_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 19. TRIGGER — atualizar cover_url do pack quando sticker é deletado
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_pack_cover_on_sticker_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Se o cover do pack era a imagem do sticker deletado, usar o próximo
  UPDATE public.sticker_packs sp
  SET cover_url = (
    SELECT image_url FROM public.stickers
    WHERE pack_id = OLD.pack_id
    ORDER BY sort_order ASC
    LIMIT 1
  )
  WHERE sp.id = OLD.pack_id
    AND (sp.cover_url = OLD.image_url OR sp.cover_url IS NULL);
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_pack_cover ON public.stickers;
CREATE TRIGGER trg_update_pack_cover
  AFTER DELETE ON public.stickers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_pack_cover_on_sticker_delete();

-- -----------------------------------------------------------------------------
-- 20. RLS para sticker_packs — usuários podem criar/editar os próprios
-- -----------------------------------------------------------------------------
ALTER TABLE public.sticker_packs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sticker_packs'
      AND policyname = 'sticker_packs_owner_write'
  ) THEN
    CREATE POLICY "sticker_packs_owner_write"
      ON public.sticker_packs
      FOR ALL
      USING (creator_id = auth.uid())
      WITH CHECK (creator_id = auth.uid());
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 21. RLS para stickers — usuários podem gerenciar stickers dos próprios packs
-- -----------------------------------------------------------------------------
ALTER TABLE public.stickers ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'stickers'
      AND policyname = 'stickers_select_all'
  ) THEN
    CREATE POLICY "stickers_select_all"
      ON public.stickers
      FOR SELECT
      USING (TRUE);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'stickers'
      AND policyname = 'stickers_owner_write'
  ) THEN
    CREATE POLICY "stickers_owner_write"
      ON public.stickers
      FOR ALL
      USING (creator_id = auth.uid())
      WITH CHECK (creator_id = auth.uid());
  END IF;
END $$;
