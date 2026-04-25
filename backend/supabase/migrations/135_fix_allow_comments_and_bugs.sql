-- =============================================================================
-- MIGRATION 135 — Fix allow_comments em posts + unificação de moldura global
-- =============================================================================
-- 1. Adiciona coluna allow_comments na tabela posts (corrige erro ao criar quiz)
-- 2. Remove coluna community_frame_url de community_members (unifica para global)
-- =============================================================================

-- ── 1. Coluna allow_comments em posts ────────────────────────────────────────
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS allow_comments BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN public.posts.allow_comments IS
  'Quando FALSE, comentários estão desabilitados neste post/quiz.';
