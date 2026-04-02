-- Migração 036: Adicionar pinned_at à tabela posts
-- Necessário para ordenar posts fixados por data de fixação

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

-- Índice parcial para posts fixados
CREATE INDEX IF NOT EXISTS idx_posts_pinned_at
  ON public.posts(pinned_at DESC)
  WHERE is_pinned = TRUE;

COMMENT ON COLUMN public.posts.pinned_at IS 'Data/hora em que o post foi fixado. NULL = não fixado.';
