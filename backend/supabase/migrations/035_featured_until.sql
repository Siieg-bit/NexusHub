-- ============================================================
-- Migration 035: Add featured_until to posts
-- Permite controlar por quanto tempo um post fica em destaque
-- (1, 3 ou 7 dias). Quando featured_until < now(), o post
-- sai automaticamente do grid de destaques ativos.
-- ============================================================

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS featured_until TIMESTAMPTZ;

-- Índice para filtrar destaques ativos eficientemente
CREATE INDEX IF NOT EXISTS idx_posts_featured_until
  ON public.posts(featured_until)
  WHERE is_featured = TRUE;

-- Comentário descritivo
COMMENT ON COLUMN public.posts.featured_until IS
  'Data/hora até quando o post fica em destaque. NULL = sem expiração.';
