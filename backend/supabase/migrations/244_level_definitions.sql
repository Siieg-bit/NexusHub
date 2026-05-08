-- =============================================================================
-- Migration 244 — Level Definitions server-driven
--
-- Migra títulos, thresholds e cores de níveis para conteúdo estruturado em banco,
-- mantendo fallback local no app e feature flag de rollback.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.level_definitions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  level                INTEGER NOT NULL,
  locale               TEXT NOT NULL DEFAULT 'pt',
  title_key            TEXT NOT NULL,
  title                TEXT NOT NULL,
  reputation_required  INTEGER NOT NULL DEFAULT 0,
  color_hex            TEXT NOT NULL DEFAULT '#636E72',
  gradient_hex         JSONB NOT NULL DEFAULT '[]'::jsonb,
  sort_order           INTEGER NOT NULL DEFAULT 0,
  is_active            BOOLEAN NOT NULL DEFAULT TRUE,
  schema_version       INTEGER NOT NULL DEFAULT 1,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT level_definitions_locale_level_unique UNIQUE (locale, level),
  CONSTRAINT level_definitions_level_positive CHECK (level > 0),
  CONSTRAINT level_definitions_reputation_non_negative CHECK (reputation_required >= 0),
  CONSTRAINT level_definitions_schema_version_positive CHECK (schema_version > 0),
  CONSTRAINT level_definitions_color_hex_check CHECK (
    color_hex ~ '^#[0-9A-Fa-f]{6}$'
  ),
  CONSTRAINT level_definitions_gradient_array_check CHECK (
    jsonb_typeof(gradient_hex) = 'array'
  )
);

CREATE INDEX IF NOT EXISTS idx_level_definitions_locale_active_sort
  ON public.level_definitions(locale, is_active, sort_order);

ALTER TABLE public.level_definitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "level_definitions_read" ON public.level_definitions;
CREATE POLICY "level_definitions_read" ON public.level_definitions
  FOR SELECT TO authenticated
  USING (TRUE);

DROP POLICY IF EXISTS "level_definitions_admin_write" ON public.level_definitions;
CREATE POLICY "level_definitions_admin_write" ON public.level_definitions
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

CREATE OR REPLACE FUNCTION public.set_level_definitions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS level_definitions_updated_at ON public.level_definitions;
CREATE TRIGGER level_definitions_updated_at
  BEFORE UPDATE ON public.level_definitions
  FOR EACH ROW EXECUTE FUNCTION public.set_level_definitions_updated_at();

CREATE OR REPLACE FUNCTION public.get_level_definitions(
  p_locale TEXT DEFAULT 'pt',
  p_schema_version INTEGER DEFAULT 1
)
RETURNS TABLE (
  level INTEGER,
  locale TEXT,
  title_key TEXT,
  title TEXT,
  reputation_required INTEGER,
  color_hex TEXT,
  gradient_hex JSONB,
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
    FROM public.level_definitions ld
    WHERE ld.locale = v_locale
      AND ld.is_active = TRUE
      AND ld.schema_version <= v_schema_version
  ) THEN
    v_effective_locale := v_locale;
  END IF;

  RETURN QUERY
  SELECT
    ld.level,
    ld.locale,
    ld.title_key,
    ld.title,
    ld.reputation_required,
    ld.color_hex,
    ld.gradient_hex,
    ld.sort_order,
    ld.schema_version
  FROM public.level_definitions ld
  WHERE ld.locale = v_effective_locale
    AND ld.is_active = TRUE
    AND ld.schema_version <= v_schema_version
  ORDER BY ld.level ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_level_definitions(TEXT, INTEGER) TO authenticated;

INSERT INTO public.level_definitions (
  level, locale, title_key, title, reputation_required, color_hex,
  gradient_hex, sort_order, is_active, schema_version
)
VALUES
  (1, 'pt', 'levelTitleNovice', 'Novato', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'pt', 'levelTitleBeginner', 'Iniciante', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'pt', 'levelTitleApprentice', 'Aprendiz', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'pt', 'levelTitleExplorer', 'Explorador', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'pt', 'levelTitleWarrior', 'Guerreiro', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'pt', 'levelTitleVeteran', 'Veterano', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'pt', 'levelTitleSpecialist', 'Especialista', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'pt', 'levelTitleMaster', 'Mestre', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'pt', 'levelTitleGrandMaster', 'Grão-Mestre', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'pt', 'levelTitleChampion', 'Campeão', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'pt', 'levelTitleHero', 'Herói', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'pt', 'levelTitleGuardian', 'Guardião', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'pt', 'levelTitleSentinel', 'Sentinela', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'pt', 'levelTitleLegendary', 'Lendário', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'pt', 'levelTitleMythical', 'Mítico', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'pt', 'levelTitleDivine', 'Divino', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'pt', 'levelTitleCelestial', 'Celestial', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'pt', 'levelTitleTranscendent', 'Transcendente', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'pt', 'levelTitleSupreme', 'Supremo', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'pt', 'levelTitleUltimate', 'Supremo Final', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'en', 'levelTitleNovice', 'Novice', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'en', 'levelTitleBeginner', 'Beginner', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'en', 'levelTitleApprentice', 'Apprentice', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'en', 'levelTitleExplorer', 'Explorer', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'en', 'levelTitleWarrior', 'Warrior', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'en', 'levelTitleVeteran', 'Veteran', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'en', 'levelTitleSpecialist', 'Specialist', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'en', 'levelTitleMaster', 'Master', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'en', 'levelTitleGrandMaster', 'Grand Master', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'en', 'levelTitleChampion', 'Champion', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'en', 'levelTitleHero', 'Hero', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'en', 'levelTitleGuardian', 'Guardian', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'en', 'levelTitleSentinel', 'Sentinel', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'en', 'levelTitleLegendary', 'Legendary', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'en', 'levelTitleMythical', 'Mythical', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'en', 'levelTitleDivine', 'Divine', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'en', 'levelTitleCelestial', 'Celestial', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'en', 'levelTitleTranscendent', 'Transcendent', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'en', 'levelTitleSupreme', 'Supreme', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'en', 'levelTitleUltimate', 'Ultimate', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'es', 'levelTitleNovice', 'Novato', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'es', 'levelTitleBeginner', 'Principiante', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'es', 'levelTitleApprentice', 'Aprendiz', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'es', 'levelTitleExplorer', 'Explorador', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'es', 'levelTitleWarrior', 'Guerrero', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'es', 'levelTitleVeteran', 'Veterano', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'es', 'levelTitleSpecialist', 'Especialista', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'es', 'levelTitleMaster', 'Maestro', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'es', 'levelTitleGrandMaster', 'Gran Maestro', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'es', 'levelTitleChampion', 'Campeón', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'es', 'levelTitleHero', 'Héroe', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'es', 'levelTitleGuardian', 'Guardián', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'es', 'levelTitleSentinel', 'Centinela', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'es', 'levelTitleLegendary', 'Legendario', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'es', 'levelTitleMythical', 'Mítico', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'es', 'levelTitleDivine', 'Divino', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'es', 'levelTitleCelestial', 'Celestial', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'es', 'levelTitleTranscendent', 'Trascendente', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'es', 'levelTitleSupreme', 'Supremo', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'es', 'levelTitleUltimate', 'Definitivo', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'fr', 'levelTitleNovice', 'Novice', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'fr', 'levelTitleBeginner', 'Débutant', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'fr', 'levelTitleApprentice', 'Apprenti', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'fr', 'levelTitleExplorer', 'Explorateur', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'fr', 'levelTitleWarrior', 'Guerrier', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'fr', 'levelTitleVeteran', 'Vétéran', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'fr', 'levelTitleSpecialist', 'Spécialiste', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'fr', 'levelTitleMaster', 'Maître', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'fr', 'levelTitleGrandMaster', 'Grand Maître', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'fr', 'levelTitleChampion', 'Champion', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'fr', 'levelTitleHero', 'Héros', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'fr', 'levelTitleGuardian', 'Gardien', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'fr', 'levelTitleSentinel', 'Sentinelle', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'fr', 'levelTitleLegendary', 'Légendaire', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'fr', 'levelTitleMythical', 'Mythique', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'fr', 'levelTitleDivine', 'Divin', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'fr', 'levelTitleCelestial', 'Céleste', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'fr', 'levelTitleTranscendent', 'Transcendant', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'fr', 'levelTitleSupreme', 'Suprême', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'fr', 'levelTitleUltimate', 'Ultime', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'de', 'levelTitleNovice', 'Neuling', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'de', 'levelTitleBeginner', 'Anfänger', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'de', 'levelTitleApprentice', 'Lehrling', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'de', 'levelTitleExplorer', 'Entdecker', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'de', 'levelTitleWarrior', 'Krieger', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'de', 'levelTitleVeteran', 'Veteran', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'de', 'levelTitleSpecialist', 'Spezialist', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'de', 'levelTitleMaster', 'Meister', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'de', 'levelTitleGrandMaster', 'Großmeister', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'de', 'levelTitleChampion', 'Champion', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'de', 'levelTitleHero', 'Held', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'de', 'levelTitleGuardian', 'Wächter', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'de', 'levelTitleSentinel', 'Wachtposten', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'de', 'levelTitleLegendary', 'Legendär', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'de', 'levelTitleMythical', 'Mythisch', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'de', 'levelTitleDivine', 'Göttlich', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'de', 'levelTitleCelestial', 'Himmlisch', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'de', 'levelTitleTranscendent', 'Transzendent', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'de', 'levelTitleSupreme', 'Erhaben', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'de', 'levelTitleUltimate', 'Ultimativ', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'it', 'levelTitleNovice', 'Novizio', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'it', 'levelTitleBeginner', 'Principiante', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'it', 'levelTitleApprentice', 'Apprendista', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'it', 'levelTitleExplorer', 'Esploratore', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'it', 'levelTitleWarrior', 'Guerriero', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'it', 'levelTitleVeteran', 'Veterano', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'it', 'levelTitleSpecialist', 'Specialista', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'it', 'levelTitleMaster', 'Maestro', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'it', 'levelTitleGrandMaster', 'Gran Maestro', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'it', 'levelTitleChampion', 'Campione', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'it', 'levelTitleHero', 'Eroe', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'it', 'levelTitleGuardian', 'Guardiano', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'it', 'levelTitleSentinel', 'Sentinella', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'it', 'levelTitleLegendary', 'Leggendario', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'it', 'levelTitleMythical', 'Mitico', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'it', 'levelTitleDivine', 'Divino', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'it', 'levelTitleCelestial', 'Celeste', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'it', 'levelTitleTranscendent', 'Trascendente', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'it', 'levelTitleSupreme', 'Supremo', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'it', 'levelTitleUltimate', 'Definitivo', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'ja', 'levelTitleNovice', '初心者', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'ja', 'levelTitleBeginner', '見習い', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'ja', 'levelTitleApprentice', '弟子', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'ja', 'levelTitleExplorer', '探検家', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'ja', 'levelTitleWarrior', '戦士', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'ja', 'levelTitleVeteran', 'ベテラン', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'ja', 'levelTitleSpecialist', 'スペシャリスト', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'ja', 'levelTitleMaster', 'マスター', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'ja', 'levelTitleGrandMaster', 'グランドマスター', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'ja', 'levelTitleChampion', 'チャンピオン', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'ja', 'levelTitleHero', 'ヒーロー', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'ja', 'levelTitleGuardian', 'ガーディアン', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'ja', 'levelTitleSentinel', 'センチネル', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'ja', 'levelTitleLegendary', 'レジェンド', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'ja', 'levelTitleMythical', 'ミシカル', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'ja', 'levelTitleDivine', 'ディバイン', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'ja', 'levelTitleCelestial', 'セレスティアル', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'ja', 'levelTitleTranscendent', 'トランセンデント', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'ja', 'levelTitleSupreme', 'スプリーム', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'ja', 'levelTitleUltimate', 'アルティメット', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'ko', 'levelTitleNovice', '초보자', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'ko', 'levelTitleBeginner', '입문자', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'ko', 'levelTitleApprentice', '견습생', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'ko', 'levelTitleExplorer', '탐험가', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'ko', 'levelTitleWarrior', '전사', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'ko', 'levelTitleVeteran', '베테랑', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'ko', 'levelTitleSpecialist', '전문가', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'ko', 'levelTitleMaster', '마스터', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'ko', 'levelTitleGrandMaster', '그랜드 마스터', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'ko', 'levelTitleChampion', '챔피언', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'ko', 'levelTitleHero', '영웅', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'ko', 'levelTitleGuardian', '수호자', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'ko', 'levelTitleSentinel', '파수꾼', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'ko', 'levelTitleLegendary', '전설', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'ko', 'levelTitleMythical', '신화', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'ko', 'levelTitleDivine', '신성', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'ko', 'levelTitleCelestial', '천상', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'ko', 'levelTitleTranscendent', '초월자', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'ko', 'levelTitleSupreme', '최고', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'ko', 'levelTitleUltimate', '궁극', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'ru', 'levelTitleNovice', 'Новичок', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'ru', 'levelTitleBeginner', 'Начинающий', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'ru', 'levelTitleApprentice', 'Ученик', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'ru', 'levelTitleExplorer', 'Исследователь', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'ru', 'levelTitleWarrior', 'Воин', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'ru', 'levelTitleVeteran', 'Ветеран', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'ru', 'levelTitleSpecialist', 'Специалист', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'ru', 'levelTitleMaster', 'Мастер', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'ru', 'levelTitleGrandMaster', 'Грандмастер', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'ru', 'levelTitleChampion', 'Чемпион', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'ru', 'levelTitleHero', 'Герой', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'ru', 'levelTitleGuardian', 'Страж', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'ru', 'levelTitleSentinel', 'Часовой', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'ru', 'levelTitleLegendary', 'Легендарный', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'ru', 'levelTitleMythical', 'Мифический', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'ru', 'levelTitleDivine', 'Божественный', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'ru', 'levelTitleCelestial', 'Небесный', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'ru', 'levelTitleTranscendent', 'Трансцендентный', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'ru', 'levelTitleSupreme', 'Верховный', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'ru', 'levelTitleUltimate', 'Абсолютный', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1),
  (1, 'ar', 'levelTitleNovice', 'مبتدئ', 0, '#636E72', '[]'::jsonb, 10, TRUE, 1),
  (2, 'ar', 'levelTitleBeginner', 'مستجد', 1800, '#636E72', '[]'::jsonb, 20, TRUE, 1),
  (3, 'ar', 'levelTitleApprentice', 'متدرب', 6300, '#2DBE60', '[]'::jsonb, 30, TRUE, 1),
  (4, 'ar', 'levelTitleExplorer', 'مستكشف', 13000, '#2DBE60', '[]'::jsonb, 40, TRUE, 1),
  (5, 'ar', 'levelTitleWarrior', 'محارب', 22000, '#2979FF', '[]'::jsonb, 50, TRUE, 1),
  (6, 'ar', 'levelTitleVeteran', 'محنك', 33000, '#2979FF', '[]'::jsonb, 60, TRUE, 1),
  (7, 'ar', 'levelTitleSpecialist', 'متخصص', 46000, '#7C3AED', '[]'::jsonb, 70, TRUE, 1),
  (8, 'ar', 'levelTitleMaster', 'أستاذ', 60500, '#7C3AED', '[]'::jsonb, 80, TRUE, 1),
  (9, 'ar', 'levelTitleGrandMaster', 'أستاذ كبير', 77000, '#E53935', '[]'::jsonb, 90, TRUE, 1),
  (10, 'ar', 'levelTitleChampion', 'بطل', 95000, '#E53935', '[]'::jsonb, 100, TRUE, 1),
  (11, 'ar', 'levelTitleHero', 'بطل خارق', 115000, '#FF9800', '[]'::jsonb, 110, TRUE, 1),
  (12, 'ar', 'levelTitleGuardian', 'حارس', 136500, '#FF9800', '[]'::jsonb, 120, TRUE, 1),
  (13, 'ar', 'levelTitleSentinel', 'حارس أمين', 159500, '#FF9800', '[]'::jsonb, 130, TRUE, 1),
  (14, 'ar', 'levelTitleLegendary', 'أسطوري', 184500, '#FF9800', '[]'::jsonb, 140, TRUE, 1),
  (15, 'ar', 'levelTitleMythical', 'خرافي', 210500, '#FF6B6B', '[]'::jsonb, 150, TRUE, 1),
  (16, 'ar', 'levelTitleDivine', 'إلهي', 238500, '#FF6B6B', '[]'::jsonb, 160, TRUE, 1),
  (17, 'ar', 'levelTitleCelestial', 'سماوي', 268000, '#FF6B6B', '[]'::jsonb, 170, TRUE, 1),
  (18, 'ar', 'levelTitleTranscendent', 'متسامي', 299000, '#E040FB', '[]'::jsonb, 180, TRUE, 1),
  (19, 'ar', 'levelTitleSupreme', 'أعلى', 331000, '#E040FB', '[]'::jsonb, 190, TRUE, 1),
  (20, 'ar', 'levelTitleUltimate', 'مطلق', 365000, '#FFD700', '[]'::jsonb, 200, TRUE, 1)
ON CONFLICT (locale, level) DO UPDATE SET
  title_key = EXCLUDED.title_key,
  title = EXCLUDED.title,
  reputation_required = EXCLUDED.reputation_required,
  color_hex = EXCLUDED.color_hex,
  gradient_hex = EXCLUDED.gradient_hex,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  schema_version = EXCLUDED.schema_version;

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES (
  'features.remote_level_definitions_enabled',
  'true',
  'features',
  'Habilitar títulos, thresholds e cores de níveis via level_definitions/get_level_definitions com fallback local no app'
)
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  category = EXCLUDED.category,
  description = EXCLUDED.description;
