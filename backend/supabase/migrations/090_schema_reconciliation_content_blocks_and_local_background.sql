-- NexusHub — Migração 090: reconciliação fina do schema após auditoria detalhada
-- -----------------------------------------------------------------------------
-- Objetivo:
-- 1. Garantir que posts.content_blocks exista em ambientes onde a migração antiga
--    não foi refletida corretamente no banco remoto.
-- 2. Garantir que community_members.local_background_color também faça parte do
--    histórico versionado do projeto, alinhando o repositório ao schema remoto.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'posts'
      AND column_name = 'content_blocks'
  ) THEN
    ALTER TABLE public.posts
      ADD COLUMN content_blocks JSONB;

    COMMENT ON COLUMN public.posts.content_blocks IS
      'Array de blocos de conteúdo rico: [{type, text, image_url, caption}]';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'community_members'
      AND column_name = 'local_background_color'
  ) THEN
    ALTER TABLE public.community_members
      ADD COLUMN local_background_color TEXT;

    COMMENT ON COLUMN public.community_members.local_background_color IS
      'Cor de fundo local personalizada do membro dentro da comunidade';
  END IF;
END $$;
