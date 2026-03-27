-- NexusHub — Migração 012: Wiki Enhancements (Ratings, What I Like, Approval)
-- ============================================================================

-- Add status and rating columns to wiki_entries if not present
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='wiki_entries' AND column_name='status')
  THEN
    ALTER TABLE public.wiki_entries ADD COLUMN status TEXT NOT NULL DEFAULT 'approved';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='wiki_entries' AND column_name='average_rating')
  THEN
    ALTER TABLE public.wiki_entries ADD COLUMN average_rating NUMERIC(3,2) DEFAULT 0;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='wiki_entries' AND column_name='total_ratings')
  THEN
    ALTER TABLE public.wiki_entries ADD COLUMN total_ratings INTEGER DEFAULT 0;
  END IF;
END $$;

-- Wiki Ratings table
CREATE TABLE IF NOT EXISTS public.wiki_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wiki_entry_id UUID NOT NULL REFERENCES public.wiki_entries(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(wiki_entry_id, user_id)
);

ALTER TABLE public.wiki_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wiki_ratings_select" ON public.wiki_ratings
  FOR SELECT USING (true);

CREATE POLICY "wiki_ratings_insert" ON public.wiki_ratings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wiki_ratings_update" ON public.wiki_ratings
  FOR UPDATE USING (auth.uid() = user_id);

-- Trigger to update average_rating on wiki_entries
CREATE OR REPLACE FUNCTION public.update_wiki_average_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.wiki_entries SET
    average_rating = (SELECT COALESCE(AVG(rating), 0) FROM public.wiki_ratings WHERE wiki_entry_id = COALESCE(NEW.wiki_entry_id, OLD.wiki_entry_id)),
    total_ratings = (SELECT COUNT(*) FROM public.wiki_ratings WHERE wiki_entry_id = COALESCE(NEW.wiki_entry_id, OLD.wiki_entry_id))
  WHERE id = COALESCE(NEW.wiki_entry_id, OLD.wiki_entry_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_wiki_rating_change ON public.wiki_ratings;
CREATE TRIGGER trg_wiki_rating_change
  AFTER INSERT OR UPDATE OR DELETE ON public.wiki_ratings
  FOR EACH ROW EXECUTE FUNCTION public.update_wiki_average_rating();

-- Wiki "What I Like" table
CREATE TABLE IF NOT EXISTS public.wiki_what_i_like (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wiki_entry_id UUID NOT NULL REFERENCES public.wiki_entries(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.wiki_what_i_like ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wiki_what_i_like_select" ON public.wiki_what_i_like
  FOR SELECT USING (true);

CREATE POLICY "wiki_what_i_like_insert" ON public.wiki_what_i_like
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wiki_what_i_like_delete" ON public.wiki_what_i_like
  FOR DELETE USING (auth.uid() = user_id);
