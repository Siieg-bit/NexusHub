-- NexusHub — Migração 024: Stories (conteúdo efêmero estilo Amino/Instagram)
-- ============================================================================
-- Stories são conteúdos efêmeros que expiram após 24h.
-- Cada usuário pode postar stories em uma comunidade.
-- Stories aparecem em um carrossel horizontal no topo do feed.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- Conteúdo
  type TEXT NOT NULL DEFAULT 'image' CHECK (type IN ('image', 'video', 'text')),
  media_url TEXT,                          -- URL da imagem ou vídeo
  text_content TEXT,                       -- Texto overlay ou story de texto puro
  background_color TEXT DEFAULT '#000000', -- Cor de fundo para stories de texto
  font_style TEXT DEFAULT 'normal',        -- Estilo de fonte (normal, bold, handwriting)

  -- Metadata
  duration INTEGER DEFAULT 5,             -- Duração em segundos para exibição
  views_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours')
);

-- Índice para buscar stories ativas e não expiradas
CREATE INDEX IF NOT EXISTS idx_stories_active
  ON public.stories(community_id, is_active, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_stories_author
  ON public.stories(author_id, created_at DESC);

-- Tabela de visualizações de stories
CREATE TABLE IF NOT EXISTS public.story_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(story_id, viewer_id)
);

-- Tabela de reações em stories
CREATE TABLE IF NOT EXISTS public.story_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reaction TEXT NOT NULL DEFAULT 'like',  -- like, love, fire, laugh, wow, sad
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(story_id, user_id)
);

-- RLS
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_reactions ENABLE ROW LEVEL SECURITY;

-- Policies
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stories' AND policyname='stories_select') THEN
    CREATE POLICY "stories_select" ON public.stories FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stories' AND policyname='stories_insert') THEN
    CREATE POLICY "stories_insert" ON public.stories FOR INSERT WITH CHECK (auth.uid() = author_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stories' AND policyname='stories_delete') THEN
    CREATE POLICY "stories_delete" ON public.stories FOR DELETE USING (auth.uid() = author_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='story_views' AND policyname='story_views_select') THEN
    CREATE POLICY "story_views_select" ON public.story_views FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='story_views' AND policyname='story_views_insert') THEN
    CREATE POLICY "story_views_insert" ON public.story_views FOR INSERT WITH CHECK (auth.uid() = viewer_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='story_reactions' AND policyname='story_reactions_select') THEN
    CREATE POLICY "story_reactions_select" ON public.story_reactions FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='story_reactions' AND policyname='story_reactions_insert') THEN
    CREATE POLICY "story_reactions_insert" ON public.story_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- Realtime
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.stories;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
