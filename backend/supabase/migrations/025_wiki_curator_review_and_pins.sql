-- ============================================================================
-- 025: Wiki Curator Review (campos ja existem no schema base 002_content.sql)
-- ============================================================================

-- Garantir campos de review na wiki_entries (idempotente)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wiki_entries' AND column_name = 'reviewed_by') THEN
    ALTER TABLE public.wiki_entries ADD COLUMN reviewed_by UUID REFERENCES public.profiles(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wiki_entries' AND column_name = 'reviewed_at') THEN
    ALTER TABLE public.wiki_entries ADD COLUMN reviewed_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wiki_entries' AND column_name = 'submission_note') THEN
    ALTER TABLE public.wiki_entries ADD COLUMN submission_note TEXT;
  END IF;
END $$;

-- Wiki pin no perfil usa a tabela bookmarks existente (bookmarks.wiki_id)
-- Nenhuma tabela nova necessaria.

-- Index para busca de wikis pendentes por comunidade
CREATE INDEX IF NOT EXISTS idx_wiki_entries_status ON public.wiki_entries(community_id, status);

-- Index para busca de bookmarks de wiki por usuario
CREATE INDEX IF NOT EXISTS idx_bookmarks_wiki ON public.bookmarks(user_id, wiki_id) WHERE wiki_id IS NOT NULL;
