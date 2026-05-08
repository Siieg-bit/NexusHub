-- =============================================================================
-- Migration 246 — Onboarding Slides server-driven
--
-- Move os highlights/slides da tela inicial de onboarding para conteúdo
-- estruturado em banco, com fallback local no app e feature flag de rollback.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.onboarding_slides (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slide_key         TEXT NOT NULL,
  locale            TEXT NOT NULL DEFAULT 'pt',
  title             TEXT NOT NULL,
  body              TEXT NOT NULL,
  icon_name         TEXT NOT NULL DEFAULT 'auto_awesome_rounded',
  icon_color_hex    TEXT NOT NULL DEFAULT '#00E5FF',
  gradient_hex      JSONB NOT NULL DEFAULT '[]'::jsonb,
  image_asset_path  TEXT NOT NULL DEFAULT '',
  variant_key       TEXT NOT NULL DEFAULT 'default',
  sort_order        INTEGER NOT NULL DEFAULT 0,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  schema_version    INTEGER NOT NULL DEFAULT 1,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT onboarding_slides_locale_variant_key_unique UNIQUE (locale, variant_key, slide_key),
  CONSTRAINT onboarding_slides_slide_key_not_empty CHECK (length(trim(slide_key)) > 0),
  CONSTRAINT onboarding_slides_title_not_empty CHECK (length(trim(title)) > 0),
  CONSTRAINT onboarding_slides_body_not_empty CHECK (length(trim(body)) > 0),
  CONSTRAINT onboarding_slides_schema_version_positive CHECK (schema_version > 0),
  CONSTRAINT onboarding_slides_icon_color_hex_check CHECK (
    icon_color_hex ~ '^#[0-9A-Fa-f]{6}$'
  ),
  CONSTRAINT onboarding_slides_gradient_array_check CHECK (
    jsonb_typeof(gradient_hex) = 'array'
  )
);

CREATE INDEX IF NOT EXISTS idx_onboarding_slides_locale_variant_active_sort
  ON public.onboarding_slides(locale, variant_key, is_active, sort_order);

ALTER TABLE public.onboarding_slides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "onboarding_slides_read" ON public.onboarding_slides;
CREATE POLICY "onboarding_slides_read" ON public.onboarding_slides
  FOR SELECT TO authenticated
  USING (TRUE);

DROP POLICY IF EXISTS "onboarding_slides_admin_write" ON public.onboarding_slides;
CREATE POLICY "onboarding_slides_admin_write" ON public.onboarding_slides
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

CREATE OR REPLACE FUNCTION public.set_onboarding_slides_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS onboarding_slides_updated_at ON public.onboarding_slides;
CREATE TRIGGER onboarding_slides_updated_at
  BEFORE UPDATE ON public.onboarding_slides
  FOR EACH ROW EXECUTE FUNCTION public.set_onboarding_slides_updated_at();

CREATE OR REPLACE FUNCTION public.get_onboarding_slides(
  p_locale TEXT DEFAULT 'pt',
  p_variant_key TEXT DEFAULT 'default',
  p_schema_version INTEGER DEFAULT 1
)
RETURNS TABLE (
  slide_key TEXT,
  locale TEXT,
  title TEXT,
  body TEXT,
  icon_name TEXT,
  icon_color_hex TEXT,
  gradient_hex JSONB,
  image_asset_path TEXT,
  variant_key TEXT,
  sort_order INTEGER,
  schema_version INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_locale TEXT := COALESCE(NULLIF(LOWER(TRIM(p_locale)), ''), 'pt');
  v_variant_key TEXT := COALESCE(NULLIF(TRIM(p_variant_key), ''), 'default');
  v_effective_locale TEXT := 'pt';
  v_schema_version INTEGER := GREATEST(COALESCE(p_schema_version, 1), 1);
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.onboarding_slides os
    WHERE os.locale = v_locale
      AND os.variant_key = v_variant_key
      AND os.is_active = TRUE
      AND os.schema_version <= v_schema_version
  ) THEN
    v_effective_locale := v_locale;
  END IF;

  RETURN QUERY
  SELECT
    os.slide_key,
    os.locale,
    os.title,
    os.body,
    os.icon_name,
    os.icon_color_hex,
    os.gradient_hex,
    os.image_asset_path,
    os.variant_key,
    os.sort_order,
    os.schema_version
  FROM public.onboarding_slides os
  WHERE os.locale = v_effective_locale
    AND os.variant_key = v_variant_key
    AND os.is_active = TRUE
    AND os.schema_version <= v_schema_version
  ORDER BY os.sort_order ASC, os.slide_key ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_onboarding_slides(TEXT, TEXT, INTEGER) TO authenticated;

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES (
  'features.remote_onboarding_slides_enabled',
  'true'::jsonb,
  'features',
  'Habilita slides/highlights de onboarding server-driven com fallback local no APK'
)
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  category = EXCLUDED.category,
  description = EXCLUDED.description;

INSERT INTO public.onboarding_slides (
  slide_key, locale, title, body, icon_name, icon_color_hex,
  gradient_hex, image_asset_path, variant_key, sort_order, is_active, schema_version
)
VALUES
  ('communities', 'pt', 'Milhares de comunidades', 'Descubra espaços para cada fandom, jogo, história e interesse.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'pt', 'Chat em tempo real', 'Converse em tempo real com amigos, comunidades e salas públicas.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'pt', 'Personalize seu perfil', 'Crie uma identidade única com níveis, conquistas, estética e RPG.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'en', 'Thousands of communities', 'Discover spaces for every fandom, game, story, and interest.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'en', 'Real-time chat', 'Talk instantly with friends, communities, and public rooms.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'en', 'Customize your profile', 'Build a unique identity with levels, achievements, aesthetics, and RPG.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'es', 'Miles de comunidades', 'Descubre espacios para cada fandom, juego, historia e interés.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'es', 'Chat en tiempo real', 'Conversa al instante con amigos, comunidades y salas públicas.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'es', 'Personaliza tu perfil', 'Crea una identidad única con niveles, logros, estética y RPG.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'fr', 'Des milliers de communautés', 'Découvrez des espaces pour chaque fandom, jeu, histoire et intérêt.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'fr', 'Chat en temps réel', 'Échangez instantanément avec vos amis, communautés et salons publics.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'fr', 'Personnalisez votre profil', 'Créez une identité unique avec niveaux, succès, esthétique et RPG.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'de', 'Tausende Communitys', 'Entdecke Räume für jedes Fandom, Spiel, jede Geschichte und jedes Interesse.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'de', 'Echtzeit-Chat', 'Sprich sofort mit Freunden, Communitys und öffentlichen Räumen.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'de', 'Profil anpassen', 'Erstelle eine einzigartige Identität mit Levels, Erfolgen, Stil und RPG.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'it', 'Migliaia di community', 'Scopri spazi per ogni fandom, gioco, storia e interesse.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'it', 'Chat in tempo reale', 'Parla subito con amici, community e stanze pubbliche.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'it', 'Personalizza il profilo', 'Crea un’identità unica con livelli, obiettivi, estetica e RPG.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'ja', '数千のコミュニティ', 'あらゆるファンダム、ゲーム、物語、興味に合う場所を見つけましょう。', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'ja', 'リアルタイムチャット', '友達、コミュニティ、公開ルームで今すぐ会話できます。', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'ja', 'プロフィールをカスタマイズ', 'レベル、実績、スタイル、RPGで自分だけの個性を作りましょう。', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'ko', '수천 개의 커뮤니티', '모든 팬덤, 게임, 이야기, 관심사를 위한 공간을 찾아보세요.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'ko', '실시간 채팅', '친구, 커뮤니티, 공개 채팅방에서 바로 대화하세요.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'ko', '프로필 꾸미기', '레벨, 업적, 스타일, RPG로 나만의 정체성을 만드세요.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'ru', 'Тысячи сообществ', 'Находите места для любого фандома, игры, истории и интереса.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'ru', 'Чат в реальном времени', 'Общайтесь с друзьями, сообществами и публичными комнатами мгновенно.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'ru', 'Настройте профиль', 'Создайте уникальный образ с уровнями, достижениями, стилем и RPG.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1),

  ('communities', 'ar', 'آلاف المجتمعات', 'اكتشف مساحات لكل fandom ولعبة وقصة واهتمام.', 'groups_rounded', '#E8003A', '["#E8003A", "#FF2D78"]'::jsonb, '', 'default', 10, TRUE, 1),
  ('real_time_chat', 'ar', 'دردشة فورية', 'تحدث فوراً مع الأصدقاء والمجتمعات والغرف العامة.', 'chat_bubble_rounded', '#00E5FF', '["#00E5FF", "#2979FF"]'::jsonb, '', 'default', 20, TRUE, 1),
  ('customize_profile', 'ar', 'خصص ملفك الشخصي', 'أنشئ هوية فريدة بالمستويات والإنجازات والمظهر وRPG.', 'auto_awesome_rounded', '#B84CFF', '["#B84CFF", "#FF2D78"]'::jsonb, '', 'default', 30, TRUE, 1)
ON CONFLICT (locale, variant_key, slide_key) DO UPDATE SET
  title = EXCLUDED.title,
  body = EXCLUDED.body,
  icon_name = EXCLUDED.icon_name,
  icon_color_hex = EXCLUDED.icon_color_hex,
  gradient_hex = EXCLUDED.gradient_hex,
  image_asset_path = EXCLUDED.image_asset_path,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  schema_version = EXCLUDED.schema_version,
  updated_at = NOW();
