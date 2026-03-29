-- ============================================================================
-- Migração 029: Funcionalidades de Prioridade BAIXA
-- - is_pinned_profile em posts
-- - Tabela hidden_posts (esconder post do feed)
-- - Tabela recently_used_stickers (stickers recentemente usados)
-- ============================================================================

-- 1. Coluna is_pinned_profile em posts
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS is_pinned_profile BOOLEAN NOT NULL DEFAULT FALSE;

-- Índice para buscar posts fixados no perfil de um usuário
CREATE INDEX IF NOT EXISTS idx_posts_pinned_profile
  ON posts(author_id, is_pinned_profile)
  WHERE is_pinned_profile = TRUE;

-- 2. Tabela hidden_posts — esconder post do feed sem deletar
CREATE TABLE IF NOT EXISTS hidden_posts (
  user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id  UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  hidden_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, post_id)
);

ALTER TABLE hidden_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "hidden_posts: usuário gerencia os próprios" ON hidden_posts
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 3. Tabela recently_used_stickers — stickers recentemente usados por usuário
CREATE TABLE IF NOT EXISTS recently_used_stickers (
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sticker_id   TEXT NOT NULL,
  sticker_url  TEXT NOT NULL DEFAULT '',
  sticker_name TEXT NOT NULL DEFAULT '',
  used_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, sticker_id)
);

ALTER TABLE recently_used_stickers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recently_used_stickers: usuário gerencia os próprios" ON recently_used_stickers
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Índice para buscar recentes por usuário ordenado por data
CREATE INDEX IF NOT EXISTS idx_recently_used_stickers_user_date
  ON recently_used_stickers(user_id, used_at DESC);

-- Limitar a 20 stickers recentes por usuário via trigger
CREATE OR REPLACE FUNCTION trim_recently_used_stickers()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM recently_used_stickers
  WHERE user_id = NEW.user_id
    AND sticker_id NOT IN (
      SELECT sticker_id FROM recently_used_stickers
      WHERE user_id = NEW.user_id
      ORDER BY used_at DESC
      LIMIT 20
    );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trim_recently_used_stickers ON recently_used_stickers;
CREATE TRIGGER trg_trim_recently_used_stickers
  AFTER INSERT OR UPDATE ON recently_used_stickers
  FOR EACH ROW EXECUTE FUNCTION trim_recently_used_stickers();
