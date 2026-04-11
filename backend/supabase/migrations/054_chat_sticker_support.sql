-- =============================================================================
-- MIGRATION 054 — Suporte completo a stickers no chat e comentários
-- =============================================================================
-- 1. Adicionar colunas sticker_name e pack_id na tabela chat_messages
-- 2. Atualizar RPC send_chat_message_with_reputation para aceitar sticker_id,
--    sticker_url, sticker_name e pack_id
-- 3. Adicionar coluna sticker_name e pack_id em post_comments
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Adicionar colunas sticker_name e pack_id em chat_messages (se não existirem)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'chat_messages' AND column_name = 'sticker_name'
  ) THEN
    ALTER TABLE public.chat_messages ADD COLUMN sticker_name TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'chat_messages' AND column_name = 'pack_id'
  ) THEN
    ALTER TABLE public.chat_messages ADD COLUMN pack_id TEXT;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2. Adicionar colunas em comments (tabela real de comentários do app)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'comments' AND column_name = 'sticker_id'
  ) THEN
    ALTER TABLE public.comments ADD COLUMN sticker_id TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'comments' AND column_name = 'sticker_url'
  ) THEN
    ALTER TABLE public.comments ADD COLUMN sticker_url TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'comments' AND column_name = 'sticker_name'
  ) THEN
    ALTER TABLE public.comments ADD COLUMN sticker_name TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'comments' AND column_name = 'pack_id'
  ) THEN
    ALTER TABLE public.comments ADD COLUMN pack_id TEXT;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. RPC atualizado: send_chat_message_with_reputation
--    Agora aceita sticker_id, sticker_url, sticker_name e pack_id
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_chat_message_with_reputation(
  p_thread_id   UUID,
  p_content     TEXT,
  p_type        TEXT DEFAULT 'text',
  p_media_url   TEXT DEFAULT NULL,
  p_reply_to    UUID DEFAULT NULL,
  p_sticker_id  TEXT DEFAULT NULL,
  p_sticker_url TEXT DEFAULT NULL,
  p_sticker_name TEXT DEFAULT NULL,
  p_pack_id     TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_message_id   UUID;
  v_community_id UUID;
  v_is_member    BOOLEAN;
  v_author_id    UUID := auth.uid();
BEGIN
  -- Validar sessão
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Buscar community_id do chat
  SELECT community_id INTO v_community_id
  FROM public.chat_threads
  WHERE id = p_thread_id;

  -- Verificar se é membro
  SELECT EXISTS(
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id AND user_id = v_author_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this chat';
  END IF;

  -- Inserir mensagem
  INSERT INTO public.chat_messages (
    thread_id, author_id, content, type,
    media_url, reply_to_id,
    sticker_id, sticker_url, sticker_name, pack_id
  ) VALUES (
    p_thread_id, v_author_id, p_content, p_type::public.chat_message_type,
    p_media_url, p_reply_to,
    p_sticker_id, p_sticker_url, p_sticker_name, p_pack_id
  ) RETURNING id INTO v_message_id;

  -- Atualizar last_message_at
  UPDATE public.chat_threads
  SET last_message_at = NOW()
  WHERE id = p_thread_id;

  -- Reputação (+1 por mensagem)
  IF v_community_id IS NOT NULL THEN
    PERFORM public.add_reputation(
      v_author_id, v_community_id, 'chat_message', 1, v_message_id
    );
  END IF;

  -- Registrar uso do sticker nos recentes (se for sticker)
  IF p_sticker_id IS NOT NULL AND p_sticker_url IS NOT NULL THEN
    INSERT INTO public.recently_used_stickers (
      user_id, sticker_id, sticker_url, sticker_name, used_at
    ) VALUES (
      v_author_id, p_sticker_id, p_sticker_url,
      COALESCE(p_sticker_name, ''), NOW()
    )
    ON CONFLICT (user_id, sticker_id)
    DO UPDATE SET used_at = NOW();

    -- Incrementar contador de usos
    UPDATE public.stickers
    SET uses_count = uses_count + 1
    WHERE id = p_sticker_id::UUID;
  END IF;

  RETURN v_message_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. RPC: send_comment_with_sticker — enviar comentário com sticker
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_comment_with_sticker(
  p_post_id     UUID,
  p_content     TEXT DEFAULT '',
  p_parent_id   UUID DEFAULT NULL,
  p_sticker_id  TEXT DEFAULT NULL,
  p_sticker_url TEXT DEFAULT NULL,
  p_sticker_name TEXT DEFAULT NULL,
  p_pack_id     TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_comment_id UUID;
  v_author_id  UUID := auth.uid();
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.comments (
    post_id, author_id, content, parent_id,
    sticker_id, sticker_url, sticker_name, pack_id
  ) VALUES (
    p_post_id, v_author_id,
    COALESCE(p_content, ''),
    p_parent_id,
    p_sticker_id, p_sticker_url, p_sticker_name, p_pack_id
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

    UPDATE public.stickers
    SET uses_count = uses_count + 1
    WHERE id = p_sticker_id::UUID;
  END IF;

  RETURN v_comment_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. Garantir que recently_used_stickers tem a constraint correta
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'recently_used_stickers_user_id_sticker_id_key'
  ) THEN
    ALTER TABLE public.recently_used_stickers
    ADD CONSTRAINT recently_used_stickers_user_id_sticker_id_key
    UNIQUE (user_id, sticker_id);
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- -----------------------------------------------------------------------------
-- 6. View: sticker_message_view — facilita leitura de mensagens com stickers
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.sticker_message_view AS
SELECT
  cm.id,
  cm.thread_id,
  cm.author_id,
  cm.type,
  cm.content,
  cm.sticker_id,
  cm.sticker_url,
  cm.sticker_name,
  cm.pack_id,
  cm.created_at,
  p.display_name AS author_name,
  p.icon_url AS author_icon
FROM public.chat_messages cm
LEFT JOIN public.profiles p ON p.id = cm.author_id
WHERE cm.type = 'sticker'
  AND cm.is_deleted = FALSE;

-- -----------------------------------------------------------------------------
-- 7. Storage bucket para stickers criados por usuários (se não existir)
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-stickers',
  'user-stickers',
  TRUE,
  5242880, -- 5MB
  ARRAY['image/png', 'image/jpeg', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = TRUE,
    file_size_limit = 5242880;

-- RLS do bucket
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects'
      AND schemaname = 'storage'
      AND policyname = 'user_stickers_upload'
  ) THEN
    CREATE POLICY "user_stickers_upload"
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (bucket_id = 'user-stickers');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects'
      AND schemaname = 'storage'
      AND policyname = 'user_stickers_read'
  ) THEN
    CREATE POLICY "user_stickers_read"
      ON storage.objects
      FOR SELECT
      TO public
      USING (bucket_id = 'user-stickers');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects'
      AND schemaname = 'storage'
      AND policyname = 'user_stickers_owner_delete'
  ) THEN
    CREATE POLICY "user_stickers_owner_delete"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'user-stickers'
        AND (storage.foldername(name))[2] = auth.uid()::TEXT
      );
  END IF;
END $$;
