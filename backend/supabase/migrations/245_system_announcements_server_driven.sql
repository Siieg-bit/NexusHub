-- =============================================================================
-- Migration 245 — System Announcements server-driven v2
--
-- Estende a tabela existente `system_announcements` sem quebrar a RPC legada
-- `get_active_system_announcements()`, adiciona campos de controle visual e
-- cria a RPC v2 consumida pelo app Flutter com feature flag de rollback.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.system_announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  image_url   TEXT,
  cta_text    TEXT,
  cta_url     TEXT,
  status      TEXT NOT NULL DEFAULT 'draft',
  publish_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expire_at   TIMESTAMPTZ,
  created_by  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.system_announcements
  ADD COLUMN IF NOT EXISTS locale TEXT DEFAULT 'pt',
  ADD COLUMN IF NOT EXISTS severity TEXT DEFAULT 'info',
  ADD COLUMN IF NOT EXISTS placement TEXT DEFAULT 'global_feed',
  ADD COLUMN IF NOT EXISTS dismissible BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 100,
  ADD COLUMN IF NOT EXISTS schema_version INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

UPDATE public.system_announcements
SET
  locale = COALESCE(NULLIF(LOWER(TRIM(locale)), ''), 'pt'),
  severity = COALESCE(NULLIF(LOWER(TRIM(severity)), ''), 'info'),
  placement = COALESCE(NULLIF(LOWER(TRIM(placement)), ''), 'global_feed'),
  dismissible = COALESCE(dismissible, TRUE),
  sort_order = COALESCE(sort_order, 100),
  schema_version = GREATEST(COALESCE(schema_version, 1), 1),
  metadata = COALESCE(metadata, '{}'::jsonb);

ALTER TABLE public.system_announcements
  ALTER COLUMN locale SET DEFAULT 'pt',
  ALTER COLUMN locale SET NOT NULL,
  ALTER COLUMN severity SET DEFAULT 'info',
  ALTER COLUMN severity SET NOT NULL,
  ALTER COLUMN placement SET DEFAULT 'global_feed',
  ALTER COLUMN placement SET NOT NULL,
  ALTER COLUMN dismissible SET DEFAULT TRUE,
  ALTER COLUMN dismissible SET NOT NULL,
  ALTER COLUMN sort_order SET DEFAULT 100,
  ALTER COLUMN sort_order SET NOT NULL,
  ALTER COLUMN schema_version SET DEFAULT 1,
  ALTER COLUMN schema_version SET NOT NULL,
  ALTER COLUMN metadata SET DEFAULT '{}'::jsonb,
  ALTER COLUMN metadata SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'system_announcements_status_check'
      AND conrelid = 'public.system_announcements'::regclass
  ) THEN
    ALTER TABLE public.system_announcements
      ADD CONSTRAINT system_announcements_status_check
      CHECK (status IN ('draft', 'active', 'expired'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'system_announcements_locale_check'
      AND conrelid = 'public.system_announcements'::regclass
  ) THEN
    ALTER TABLE public.system_announcements
      ADD CONSTRAINT system_announcements_locale_check
      CHECK (locale IN ('pt', 'en'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'system_announcements_severity_check'
      AND conrelid = 'public.system_announcements'::regclass
  ) THEN
    ALTER TABLE public.system_announcements
      ADD CONSTRAINT system_announcements_severity_check
      CHECK (severity IN ('info', 'warning', 'critical'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'system_announcements_placement_check'
      AND conrelid = 'public.system_announcements'::regclass
  ) THEN
    ALTER TABLE public.system_announcements
      ADD CONSTRAINT system_announcements_placement_check
      CHECK (placement IN ('global_feed', 'home_banner', 'modal'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'system_announcements_schema_version_positive'
      AND conrelid = 'public.system_announcements'::regclass
  ) THEN
    ALTER TABLE public.system_announcements
      ADD CONSTRAINT system_announcements_schema_version_positive
      CHECK (schema_version > 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_system_announcements_v2_active
  ON public.system_announcements(locale, placement, status, publish_at, sort_order);

ALTER TABLE public.system_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "system_announcements_read" ON public.system_announcements;
CREATE POLICY "system_announcements_read" ON public.system_announcements
  FOR SELECT TO authenticated
  USING (
    status = 'active'
    AND publish_at <= NOW()
    AND (expire_at IS NULL OR expire_at > NOW())
  );

DROP POLICY IF EXISTS "system_announcements_admin_write" ON public.system_announcements;
CREATE POLICY "system_announcements_admin_write" ON public.system_announcements
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

CREATE OR REPLACE FUNCTION public.get_active_announcements_v2(
  p_locale TEXT DEFAULT 'pt',
  p_schema_version INTEGER DEFAULT 1,
  p_placement TEXT DEFAULT 'global_feed'
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  body TEXT,
  severity TEXT,
  placement TEXT,
  image_url TEXT,
  cta_text TEXT,
  cta_url TEXT,
  dismissible BOOLEAN,
  publish_at TIMESTAMPTZ,
  expire_at TIMESTAMPTZ,
  sort_order INTEGER,
  schema_version INTEGER,
  metadata JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_locale TEXT := COALESCE(NULLIF(LOWER(TRIM(p_locale)), ''), 'pt');
  v_effective_locale TEXT := 'pt';
  v_schema_version INTEGER := GREATEST(COALESCE(p_schema_version, 1), 1);
  v_placement TEXT := COALESCE(NULLIF(LOWER(TRIM(p_placement)), ''), 'global_feed');
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  IF v_locale NOT IN ('pt', 'en') THEN
    v_locale := 'pt';
  END IF;

  IF v_placement NOT IN ('global_feed', 'home_banner', 'modal') THEN
    v_placement := 'global_feed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.system_announcements sa
    WHERE sa.locale = v_locale
      AND sa.placement = v_placement
      AND sa.status = 'active'
      AND sa.publish_at <= NOW()
      AND (sa.expire_at IS NULL OR sa.expire_at > NOW())
      AND sa.schema_version <= v_schema_version
  ) THEN
    v_effective_locale := v_locale;
  END IF;

  RETURN QUERY
  SELECT
    sa.id,
    sa.title,
    sa.body,
    sa.severity,
    sa.placement,
    sa.image_url,
    sa.cta_text,
    sa.cta_url,
    sa.dismissible,
    sa.publish_at,
    sa.expire_at,
    sa.sort_order,
    sa.schema_version,
    sa.metadata
  FROM public.system_announcements sa
  WHERE sa.locale = v_effective_locale
    AND sa.placement = v_placement
    AND sa.status = 'active'
    AND sa.publish_at <= NOW()
    AND (sa.expire_at IS NULL OR sa.expire_at > NOW())
    AND sa.schema_version <= v_schema_version
  ORDER BY sa.sort_order ASC, sa.publish_at DESC, sa.id ASC
  LIMIT 10;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_announcements_v2(TEXT, INTEGER, TEXT) TO authenticated;

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES (
  'features.remote_announcements_enabled',
  'true',
  'features',
  'Habilitar anúncios do sistema via system_announcements/get_active_announcements_v2 com fallback local vazio no app'
)
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  category = EXCLUDED.category,
  description = EXCLUDED.description;
