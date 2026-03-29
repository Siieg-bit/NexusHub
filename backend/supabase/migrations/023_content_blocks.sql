-- NexusHub — Migração 023: Adicionar content_blocks para Rich Text Editor de Blocos
-- ============================================================================
-- No Amino original, blogs são compostos por blocos intercalados:
--   [Texto] → [Imagem] → [Texto] → [Imagem] → [Texto]
-- Esta coluna armazena a estrutura de blocos como JSONB.
-- ============================================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='content_blocks')
  THEN
    ALTER TABLE public.posts ADD COLUMN content_blocks JSONB;
    COMMENT ON COLUMN public.posts.content_blocks IS 'Array de blocos de conteúdo rico: [{type, text, image_url, caption}]';
  END IF;
END $$;
