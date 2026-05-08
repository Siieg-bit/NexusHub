-- =============================================================================
-- Migration 243 — Free Coins server-driven reward tasks
--
-- Migra os cards da tela Free Coins para conteúdo estruturado em banco,
-- mantendo fallback local no app e feature flag de rollback.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.reward_tasks (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_key        TEXT NOT NULL,
  locale          TEXT NOT NULL DEFAULT 'pt',
  section_key     TEXT NOT NULL,
  section_title   TEXT NOT NULL,
  title           TEXT NOT NULL,
  subtitle        TEXT NOT NULL DEFAULT '',
  reward_label    TEXT NOT NULL DEFAULT '',
  icon_name       TEXT NOT NULL DEFAULT 'monetization_on',
  icon_color_hex  TEXT NOT NULL DEFAULT '#FF9800',
  action_type     TEXT NOT NULL DEFAULT 'informational',
  sort_order      INTEGER NOT NULL DEFAULT 0,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  schema_version  INTEGER NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT reward_tasks_locale_task_key_unique UNIQUE (locale, task_key),
  CONSTRAINT reward_tasks_schema_version_positive CHECK (schema_version > 0),
  CONSTRAINT reward_tasks_action_type_check CHECK (
    action_type IN ('informational', 'rewarded_ad', 'navigation')
  ),
  CONSTRAINT reward_tasks_icon_color_hex_check CHECK (
    icon_color_hex ~ '^#[0-9A-Fa-f]{6}$'
  )
);

CREATE INDEX IF NOT EXISTS idx_reward_tasks_locale_active_sort
  ON public.reward_tasks(locale, is_active, sort_order);

ALTER TABLE public.reward_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reward_tasks_read" ON public.reward_tasks;
CREATE POLICY "reward_tasks_read" ON public.reward_tasks
  FOR SELECT TO authenticated
  USING (TRUE);

DROP POLICY IF EXISTS "reward_tasks_admin_write" ON public.reward_tasks;
CREATE POLICY "reward_tasks_admin_write" ON public.reward_tasks
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_team_admin = TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_team_admin = TRUE
    )
  );

CREATE OR REPLACE FUNCTION public.set_reward_tasks_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reward_tasks_updated_at ON public.reward_tasks;
CREATE TRIGGER reward_tasks_updated_at
  BEFORE UPDATE ON public.reward_tasks
  FOR EACH ROW EXECUTE FUNCTION public.set_reward_tasks_updated_at();

CREATE OR REPLACE FUNCTION public.get_reward_tasks(
  p_locale TEXT DEFAULT 'pt',
  p_schema_version INTEGER DEFAULT 1
)
RETURNS TABLE (
  task_key TEXT,
  section_key TEXT,
  section_title TEXT,
  title TEXT,
  subtitle TEXT,
  reward_label TEXT,
  icon_name TEXT,
  icon_color_hex TEXT,
  action_type TEXT,
  sort_order INTEGER,
  schema_version INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_locale TEXT := COALESCE(NULLIF(LOWER(TRIM(p_locale)), ''), 'pt');
  v_effective_locale TEXT := 'pt';
  v_schema_version INTEGER := GREATEST(COALESCE(p_schema_version, 1), 1);
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.reward_tasks rt
    WHERE rt.locale = v_locale
      AND rt.is_active = TRUE
      AND rt.schema_version <= v_schema_version
  ) THEN
    v_effective_locale := v_locale;
  END IF;

  RETURN QUERY
  SELECT
    rt.task_key,
    rt.section_key,
    rt.section_title,
    rt.title,
    rt.subtitle,
    rt.reward_label,
    rt.icon_name,
    rt.icon_color_hex,
    rt.action_type,
    rt.sort_order,
    rt.schema_version
  FROM public.reward_tasks rt
  WHERE rt.locale = v_effective_locale
    AND rt.is_active = TRUE
    AND rt.schema_version <= v_schema_version
  ORDER BY rt.sort_order ASC, rt.task_key ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_reward_tasks(TEXT, INTEGER) TO authenticated;

INSERT INTO public.reward_tasks (
  task_key, locale, section_key, section_title, title, subtitle, reward_label,
  icon_name, icon_color_hex, action_type, sort_order, is_active, schema_version
)
VALUES
  ('watch_rewarded_ad', 'pt', 'watch_ads', 'Assistir Anúncios', 'Assistir Vídeo', '{watched}/{max} assistidos hoje', '+{rewarded_coins_per_ad}', 'play_circle_filled', '#E53935', 'rewarded_ad', 10, TRUE, 1),
  ('daily_check_in', 'pt', 'daily_activities', 'Atividades Diárias', 'Check-in Diário', 'Entre todos os dias para ganhar moedas', '+5-25', 'calendar_today', '#2196F3', 'informational', 20, TRUE, 1),
  ('create_post', 'pt', 'daily_activities', 'Atividades Diárias', 'Criar um Post', 'Publique conteúdo na comunidade', '+3', 'edit', '#4CAF50', 'informational', 30, TRUE, 1),
  ('comment_posts', 'pt', 'daily_activities', 'Atividades Diárias', 'Comentar em Posts', 'Participe das discussões', '+1', 'comment', '#00BCD4', 'informational', 40, TRUE, 1),
  ('answer_quiz', 'pt', 'daily_activities', 'Atividades Diárias', 'Responder Quiz', 'Participe dos quizzes da comunidade', '+2', 'quiz', '#FF9800', 'informational', 50, TRUE, 1),
  ('complete_achievements', 'pt', 'achievements', 'Conquistas', 'Completar Conquistas', 'Desbloqueie badges e ganhe moedas', '+10-100', 'emoji_events', '#FF9800', 'informational', 60, TRUE, 1),
  ('invite_friends', 'pt', 'achievements', 'Conquistas', 'Convidar Amigos', 'Ganhe moedas quando amigos se cadastram', '+50', 'person_add', '#9C27B0', 'informational', 70, TRUE, 1),
  ('level_up', 'pt', 'achievements', 'Conquistas', 'Subir de Nível', 'Ganhe moedas ao subir de nível', '+20', 'trending_up', '#2196F3', 'informational', 80, TRUE, 1),

  ('watch_rewarded_ad', 'en', 'watch_ads', 'Watch Ads', 'Watch Video', '{watched}/{max} watched today', '+{rewarded_coins_per_ad}', 'play_circle_filled', '#E53935', 'rewarded_ad', 10, TRUE, 1),
  ('daily_check_in', 'en', 'daily_activities', 'Daily Activities', 'Daily Check-in', 'Check in every day to earn coins', '+5-25', 'calendar_today', '#2196F3', 'informational', 20, TRUE, 1),
  ('create_post', 'en', 'daily_activities', 'Daily Activities', 'Create a Post', 'Publish content in the community', '+3', 'edit', '#4CAF50', 'informational', 30, TRUE, 1),
  ('comment_posts', 'en', 'daily_activities', 'Daily Activities', 'Comment on Posts', 'Join the discussions', '+1', 'comment', '#00BCD4', 'informational', 40, TRUE, 1),
  ('answer_quiz', 'en', 'daily_activities', 'Daily Activities', 'Answer Quiz', 'Join community quizzes', '+2', 'quiz', '#FF9800', 'informational', 50, TRUE, 1),
  ('complete_achievements', 'en', 'achievements', 'Achievements', 'Complete Achievements', 'Unlock badges and earn coins', '+10-100', 'emoji_events', '#FF9800', 'informational', 60, TRUE, 1),
  ('invite_friends', 'en', 'achievements', 'Achievements', 'Invite Friends', 'Earn coins when friends sign up', '+50', 'person_add', '#9C27B0', 'informational', 70, TRUE, 1),
  ('level_up', 'en', 'achievements', 'Achievements', 'Level Up', 'Earn coins when you level up', '+20', 'trending_up', '#2196F3', 'informational', 80, TRUE, 1)
ON CONFLICT (locale, task_key) DO UPDATE SET
  section_key = EXCLUDED.section_key,
  section_title = EXCLUDED.section_title,
  title = EXCLUDED.title,
  subtitle = EXCLUDED.subtitle,
  reward_label = EXCLUDED.reward_label,
  icon_name = EXCLUDED.icon_name,
  icon_color_hex = EXCLUDED.icon_color_hex,
  action_type = EXCLUDED.action_type,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  schema_version = EXCLUDED.schema_version;

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES (
  'features.remote_reward_tasks_enabled',
  'true',
  'features',
  'Habilitar cards Free Coins via reward_tasks/get_reward_tasks com fallback local no app'
)
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  category = EXCLUDED.category,
  description = EXCLUDED.description;
