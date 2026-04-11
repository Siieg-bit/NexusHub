-- =============================================================================
-- 076 — Compatibilidade do novo StickerPicker com as tabelas existentes
-- =============================================================================
-- O novo sticker_picker.dart lê e grava o campo `sticker_name` nas tabelas
-- user_sticker_favorites e recently_used_stickers.
-- A tabela recently_used_stickers já tem o campo (migração 029).
-- A tabela user_sticker_favorites não tinha o campo — adicionamos aqui.
-- Também atualizamos o RPC toggle_sticker_favorite para aceitar sticker_name.
-- =============================================================================

BEGIN;

-- 1. Adicionar coluna sticker_name em user_sticker_favorites (se não existir)
ALTER TABLE public.user_sticker_favorites
  ADD COLUMN IF NOT EXISTS sticker_name TEXT NOT NULL DEFAULT '';

-- 2. Garantir que a tabela recently_used_stickers está no schema public
--    (migração 029 criou sem schema explícito — pode estar em public ou default)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'recently_used_stickers'
  ) THEN
    CREATE TABLE IF NOT EXISTS public.recently_used_stickers (
      user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      sticker_id   TEXT NOT NULL,
      sticker_url  TEXT NOT NULL DEFAULT '',
      sticker_name TEXT NOT NULL DEFAULT '',
      used_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, sticker_id)
    );
    ALTER TABLE public.recently_used_stickers ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "recently_used_stickers_own"
      ON public.recently_used_stickers
      FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
    CREATE INDEX IF NOT EXISTS idx_recently_used_stickers_user_date
      ON public.recently_used_stickers(user_id, used_at DESC);
  END IF;
END $$;

-- 3. Garantir RLS na tabela recently_used_stickers (caso já exista sem RLS)
ALTER TABLE recently_used_stickers ENABLE ROW LEVEL SECURITY;

-- 4. Garantir que a policy existe (idempotente)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'recently_used_stickers'
      AND policyname = 'recently_used_stickers: usuário gerencia os próprios'
  ) THEN
    CREATE POLICY "recently_used_stickers: usuário gerencia os próprios"
      ON recently_used_stickers
      FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- 5. Atualizar o RPC toggle_sticker_favorite para aceitar e gravar sticker_name
CREATE OR REPLACE FUNCTION public.toggle_sticker_favorite(
  p_sticker_id   TEXT,
  p_sticker_url  TEXT,
  p_pack_id      TEXT DEFAULT NULL,
  p_category     TEXT DEFAULT 'saved',  -- 'saved' ou 'favorite'
  p_sticker_name TEXT DEFAULT ''
)
RETURNS BOOLEAN  -- TRUE = adicionado, FALSE = removido
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.user_sticker_favorites
    WHERE user_id = auth.uid()
      AND sticker_id = p_sticker_id
      AND category = p_category
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.user_sticker_favorites
    WHERE user_id = auth.uid()
      AND sticker_id = p_sticker_id
      AND category = p_category;
    RETURN FALSE;
  ELSE
    INSERT INTO public.user_sticker_favorites
      (user_id, sticker_id, sticker_url, sticker_name, pack_id, category)
    VALUES
      (auth.uid(), p_sticker_id, p_sticker_url, p_sticker_name, p_pack_id, p_category)
    ON CONFLICT (user_id, sticker_id, category)
    DO UPDATE SET
      sticker_url  = EXCLUDED.sticker_url,
      sticker_name = EXCLUDED.sticker_name,
      pack_id      = EXCLUDED.pack_id;
    RETURN TRUE;
  END IF;
END;
$$;

COMMIT;
