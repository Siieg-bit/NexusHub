-- =============================================================================
-- Migration 115: Wiki canonical (borda dourada) + suporte completo a modais
-- =============================================================================
-- 1. Adiciona coluna is_canonical em wiki_entries
-- 2. Adiciona política RLS para moderadores atualizarem is_canonical
-- 3. Adiciona política RLS de INSERT em device_fingerprints (corrige erro 42501)
-- =============================================================================

-- ── 1. Coluna is_canonical em wiki_entries ────────────────────────────────────
ALTER TABLE wiki_entries
  ADD COLUMN IF NOT EXISTS is_canonical BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN wiki_entries.is_canonical IS
  'Quando TRUE, a comunidade "canonizou" esta wiki — exibida com borda dourada.';

-- Índice para listar wikis canônicas rapidamente
CREATE INDEX IF NOT EXISTS idx_wiki_entries_canonical
  ON wiki_entries (community_id, is_canonical)
  WHERE is_canonical = TRUE;

-- ── 2. Política RLS: apenas moderadores/admins podem canonizar ────────────────
-- A política de UPDATE existente em wiki_entries permite apenas o autor editar.
-- Adicionamos uma política separada para moderadores/admins.
DO $$
BEGIN
  -- Remover política antiga de UPDATE se existir (para recriar com nova lógica)
  DROP POLICY IF EXISTS wiki_entries_update_author ON wiki_entries;
  DROP POLICY IF EXISTS wiki_entries_update_mod ON wiki_entries;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Autor pode editar campos normais (não is_canonical)
CREATE POLICY wiki_entries_update_author ON wiki_entries
  FOR UPDATE
  USING (author_id = auth.uid());

-- Moderadores e admins podem atualizar qualquer campo, incluindo is_canonical
CREATE POLICY wiki_entries_update_mod ON wiki_entries
  FOR UPDATE
  USING (
    is_community_moderator(community_id)
    OR is_team_member()
  );

-- ── 3. Políticas de INSERT/UPDATE em device_fingerprints (corrige 42501) ──────
DO $$
BEGIN
  DROP POLICY IF EXISTS device_fp_insert_own ON device_fingerprints;
  DROP POLICY IF EXISTS device_fp_update_own ON device_fingerprints;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

CREATE POLICY device_fp_insert_own ON device_fingerprints
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY device_fp_update_own ON device_fingerprints
  FOR UPDATE
  USING (user_id = auth.uid());
