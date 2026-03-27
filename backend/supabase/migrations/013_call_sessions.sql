-- NexusHub — Migração 013: Call Sessions & Participants (idempotent)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.call_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'voice' CHECK (type IN ('voice', 'video', 'screening_room')),
  creator_id UUID NOT NULL REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ
);

ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='call_sessions' AND policyname='call_sessions_select') THEN
    CREATE POLICY "call_sessions_select" ON public.call_sessions FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='call_sessions' AND policyname='call_sessions_insert') THEN
    CREATE POLICY "call_sessions_insert" ON public.call_sessions FOR INSERT WITH CHECK (auth.uid() = creator_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='call_sessions' AND policyname='call_sessions_update') THEN
    CREATE POLICY "call_sessions_update" ON public.call_sessions FOR UPDATE USING (auth.uid() = creator_id);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.call_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_session_id UUID NOT NULL REFERENCES public.call_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'connected' CHECK (status IN ('connected', 'disconnected')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at TIMESTAMPTZ,
  UNIQUE(call_session_id, user_id)
);

ALTER TABLE public.call_participants ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='call_participants' AND policyname='call_participants_select') THEN
    CREATE POLICY "call_participants_select" ON public.call_participants FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='call_participants' AND policyname='call_participants_insert') THEN
    CREATE POLICY "call_participants_insert" ON public.call_participants FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='call_participants' AND policyname='call_participants_update') THEN
    CREATE POLICY "call_participants_update" ON public.call_participants FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;

-- Poll votes table for interactive polls in posts
CREATE TABLE IF NOT EXISTS public.poll_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  option_index INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='poll_votes' AND policyname='poll_votes_select') THEN
    CREATE POLICY "poll_votes_select" ON public.poll_votes FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='poll_votes' AND policyname='poll_votes_insert') THEN
    CREATE POLICY "poll_votes_insert" ON public.poll_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- Add poll_data and quiz_data columns to posts if not present
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='poll_data')
  THEN
    ALTER TABLE public.posts ADD COLUMN poll_data JSONB;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='posts' AND column_name='quiz_data')
  THEN
    ALTER TABLE public.posts ADD COLUMN quiz_data JSONB;
  END IF;
END $$;

-- Enable Realtime for call tables (ignore if already added)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.call_sessions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.call_participants;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
