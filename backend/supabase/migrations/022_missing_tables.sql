-- ============================================================================
-- Migration 022: Tabelas faltantes referenciadas no frontend
-- achievements, user_achievements
-- ============================================================================

-- ── Achievements (conquistas disponíveis) ──
CREATE TABLE IF NOT EXISTS public.achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  category TEXT DEFAULT 'general', -- general, social, content, community
  requirement_type TEXT NOT NULL,   -- reputation, posts, followers, checkin_streak, comments, likes_received
  requirement_value INTEGER NOT NULL DEFAULT 1,
  reward_coins INTEGER DEFAULT 0,
  reward_reputation INTEGER DEFAULT 0,
  is_hidden BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── User Achievements (conquistas desbloqueadas por usuário) ──
CREATE TABLE IF NOT EXISTS public.user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  achievement_id UUID NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
  unlocked_at TIMESTAMPTZ DEFAULT now(),
  community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,
  UNIQUE(user_id, achievement_id)
);

-- ── Índices ──
CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON public.user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement ON public.user_achievements(achievement_id);

-- ── Seed: Conquistas padrão ──
INSERT INTO public.achievements (name, description, icon_url, category, requirement_type, requirement_value, reward_coins, reward_reputation, sort_order) VALUES
  ('Primeiro Post', 'Crie seu primeiro post', null, 'content', 'posts', 1, 10, 50, 1),
  ('Escritor', 'Crie 10 posts', null, 'content', 'posts', 10, 50, 200, 2),
  ('Autor Prolífico', 'Crie 50 posts', null, 'content', 'posts', 50, 200, 1000, 3),
  ('Mestre das Palavras', 'Crie 200 posts', null, 'content', 'posts', 200, 500, 5000, 4),
  ('Primeiro Seguidor', 'Consiga 1 seguidor', null, 'social', 'followers', 1, 5, 25, 10),
  ('Popular', 'Consiga 10 seguidores', null, 'social', 'followers', 10, 50, 200, 11),
  ('Influencer', 'Consiga 50 seguidores', null, 'social', 'followers', 50, 200, 1000, 12),
  ('Celebridade', 'Consiga 200 seguidores', null, 'social', 'followers', 200, 500, 5000, 13),
  ('Dedicado', 'Faça check-in 7 dias seguidos', null, 'community', 'checkin_streak', 7, 25, 100, 20),
  ('Comprometido', 'Faça check-in 30 dias seguidos', null, 'community', 'checkin_streak', 30, 100, 500, 21),
  ('Inabalável', 'Faça check-in 100 dias seguidos', null, 'community', 'checkin_streak', 100, 500, 2000, 22),
  ('Lendário', 'Faça check-in 365 dias seguidos', null, 'community', 'checkin_streak', 365, 2000, 10000, 23),
  ('Comentarista', 'Faça 10 comentários', null, 'content', 'comments', 10, 25, 100, 30),
  ('Debatedor', 'Faça 100 comentários', null, 'content', 'comments', 100, 100, 500, 31),
  ('Novato', 'Alcance nível 2', null, 'general', 'reputation', 1800, 10, 0, 40),
  ('Explorador', 'Alcance nível 5', null, 'general', 'reputation', 22000, 50, 0, 41),
  ('Veterano', 'Alcance nível 10', null, 'general', 'reputation', 95000, 200, 0, 42),
  ('Lendário', 'Alcance nível 15', null, 'general', 'reputation', 210500, 500, 0, 43),
  ('Supremo', 'Alcance nível 20', null, 'general', 'reputation', 365000, 2000, 0, 44)
ON CONFLICT DO NOTHING;

-- ── Função para verificar e desbloquear conquistas automaticamente ──
CREATE OR REPLACE FUNCTION public.check_achievements(
  p_user_id UUID,
  p_community_id UUID DEFAULT NULL
)
RETURNS TABLE(achievement_name TEXT, reward_coins INTEGER, reward_reputation INTEGER)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_achievement RECORD;
  v_count INTEGER;
  v_rep INTEGER;
BEGIN
  FOR v_achievement IN
    SELECT a.* FROM public.achievements a
    WHERE NOT EXISTS (
      SELECT 1 FROM public.user_achievements ua
      WHERE ua.user_id = p_user_id AND ua.achievement_id = a.id
    )
    ORDER BY a.sort_order
  LOOP
    v_count := 0;

    CASE v_achievement.requirement_type
      WHEN 'posts' THEN
        SELECT COUNT(*) INTO v_count FROM public.posts
        WHERE author_id = p_user_id AND status = 'ok';

      WHEN 'followers' THEN
        SELECT COUNT(*) INTO v_count FROM public.follows
        WHERE following_id = p_user_id;

      WHEN 'checkin_streak' THEN
        IF p_community_id IS NOT NULL THEN
          SELECT COALESCE(consecutive_checkin_days, 0) INTO v_count
          FROM public.community_members
          WHERE user_id = p_user_id AND community_id = p_community_id;
        ELSE
          SELECT COALESCE(MAX(consecutive_checkin_days), 0) INTO v_count
          FROM public.community_members
          WHERE user_id = p_user_id;
        END IF;

      WHEN 'comments' THEN
        SELECT COUNT(*) INTO v_count FROM public.comments
        WHERE author_id = p_user_id;

      WHEN 'reputation' THEN
        IF p_community_id IS NOT NULL THEN
          SELECT COALESCE(local_reputation, 0) INTO v_count
          FROM public.community_members
          WHERE user_id = p_user_id AND community_id = p_community_id;
        ELSE
          SELECT COALESCE(SUM(local_reputation), 0) INTO v_count
          FROM public.community_members
          WHERE user_id = p_user_id;
        END IF;

      WHEN 'likes_received' THEN
        SELECT COUNT(*) INTO v_count FROM public.likes l
        JOIN public.posts p ON l.post_id = p.id
        WHERE p.author_id = p_user_id;

      ELSE
        v_count := 0;
    END CASE;

    IF v_count >= v_achievement.requirement_value THEN
      INSERT INTO public.user_achievements (user_id, achievement_id, community_id)
      VALUES (p_user_id, v_achievement.id, p_community_id)
      ON CONFLICT DO NOTHING;

      -- Dar recompensas
      IF v_achievement.reward_coins > 0 THEN
        UPDATE public.profiles
        SET coins = coins + v_achievement.reward_coins
        WHERE id = p_user_id;
      END IF;

      achievement_name := v_achievement.name;
      reward_coins := v_achievement.reward_coins;
      reward_reputation := v_achievement.reward_reputation;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$;

-- ── RLS ──
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "achievements_read" ON public.achievements FOR SELECT USING (true);
CREATE POLICY "user_achievements_read" ON public.user_achievements FOR SELECT USING (true);
CREATE POLICY "user_achievements_insert" ON public.user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id);
