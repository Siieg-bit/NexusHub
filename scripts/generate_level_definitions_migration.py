from pathlib import Path

out = Path('/home/ubuntu/NexusHub/backend/supabase/migrations/244_level_definitions.sql')

thresholds = [
    0, 1800, 6300, 13000, 22000, 33000, 46000, 60500, 77000, 95000,
    115000, 136500, 159500, 184500, 210500, 238500, 268000, 299000, 331000, 365000,
]
colors = [
    '#636E72', '#636E72', '#2DBE60', '#2DBE60', '#2979FF', '#2979FF', '#7C3AED', '#7C3AED',
    '#E53935', '#E53935', '#FF9800', '#FF9800', '#FF9800', '#FF9800', '#FF6B6B', '#FF6B6B',
    '#FF6B6B', '#E040FB', '#E040FB', '#FFD700',
]
title_keys = [
    'levelTitleNovice', 'levelTitleBeginner', 'levelTitleApprentice', 'levelTitleExplorer',
    'levelTitleWarrior', 'levelTitleVeteran', 'levelTitleSpecialist', 'levelTitleMaster',
    'levelTitleGrandMaster', 'levelTitleChampion', 'levelTitleHero', 'levelTitleGuardian',
    'levelTitleSentinel', 'levelTitleLegendary', 'levelTitleMythical', 'levelTitleDivine',
    'levelTitleCelestial', 'levelTitleTranscendent', 'levelTitleSupreme', 'levelTitleUltimate',
]
titles = {
    'pt': ['Novato','Iniciante','Aprendiz','Explorador','Guerreiro','Veterano','Especialista','Mestre','Grão-Mestre','Campeão','Herói','Guardião','Sentinela','Lendário','Mítico','Divino','Celestial','Transcendente','Supremo','Supremo Final'],
    'en': ['Novice','Beginner','Apprentice','Explorer','Warrior','Veteran','Specialist','Master','Grand Master','Champion','Hero','Guardian','Sentinel','Legendary','Mythical','Divine','Celestial','Transcendent','Supreme','Ultimate'],
    'es': ['Novato','Principiante','Aprendiz','Explorador','Guerrero','Veterano','Especialista','Maestro','Gran Maestro','Campeón','Héroe','Guardián','Centinela','Legendario','Mítico','Divino','Celestial','Trascendente','Supremo','Definitivo'],
    'fr': ['Novice','Débutant','Apprenti','Explorateur','Guerrier','Vétéran','Spécialiste','Maître','Grand Maître','Champion','Héros','Gardien','Sentinelle','Légendaire','Mythique','Divin','Céleste','Transcendant','Suprême','Ultime'],
    'de': ['Neuling','Anfänger','Lehrling','Entdecker','Krieger','Veteran','Spezialist','Meister','Großmeister','Champion','Held','Wächter','Wachtposten','Legendär','Mythisch','Göttlich','Himmlisch','Transzendent','Erhaben','Ultimativ'],
    'it': ['Novizio','Principiante','Apprendista','Esploratore','Guerriero','Veterano','Specialista','Maestro','Gran Maestro','Campione','Eroe','Guardiano','Sentinella','Leggendario','Mitico','Divino','Celeste','Trascendente','Supremo','Definitivo'],
    'ja': ['初心者','見習い','弟子','探検家','戦士','ベテラン','スペシャリスト','マスター','グランドマスター','チャンピオン','ヒーロー','ガーディアン','センチネル','レジェンド','ミシカル','ディバイン','セレスティアル','トランセンデント','スプリーム','アルティメット'],
    'ko': ['초보자','입문자','견습생','탐험가','전사','베테랑','전문가','마스터','그랜드 마스터','챔피언','영웅','수호자','파수꾼','전설','신화','신성','천상','초월자','최고','궁극'],
    'ru': ['Новичок','Начинающий','Ученик','Исследователь','Воин','Ветеран','Специалист','Мастер','Грандмастер','Чемпион','Герой','Страж','Часовой','Легендарный','Мифический','Божественный','Небесный','Трансцендентный','Верховный','Абсолютный'],
    'ar': ['مبتدئ','مستجد','متدرب','مستكشف','محارب','محنك','متخصص','أستاذ','أستاذ كبير','بطل','بطل خارق','حارس','حارس أمين','أسطوري','خرافي','إلهي','سماوي','متسامي','أعلى','مطلق'],
}

def q(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"

rows = []
for locale, locale_titles in titles.items():
    for idx, title in enumerate(locale_titles):
        level = idx + 1
        rows.append(
            f"  ({level}, {q(locale)}, {q(title_keys[idx])}, {q(title)}, {thresholds[idx]}, {q(colors[idx])}, '[]'::jsonb, {level * 10}, TRUE, 1)"
        )

sql = """-- =============================================================================
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
""" + ",\n".join(rows) + """
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
"""

out.write_text(sql, encoding='utf-8')
print(out)
