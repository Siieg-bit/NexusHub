-- =============================================================================
-- Migration 247 — Streaming Rules server-driven
--
-- Move allowlist/blocklist e metadados operacionais da Sala de Projeção para o
-- banco, mantendo fallback conservador no APK e feature flag de rollback remoto.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.streaming_platform_rules (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_id            TEXT NOT NULL UNIQUE,
  display_name           TEXT NOT NULL,
  enabled                BOOLEAN NOT NULL DEFAULT TRUE,
  allow_direct_playback  BOOLEAN NOT NULL DEFAULT FALSE,
  requires_drm           BOOLEAN NOT NULL DEFAULT FALSE,
  supports_embed         BOOLEAN NOT NULL DEFAULT FALSE,
  resolver_strategy      TEXT NOT NULL DEFAULT 'embed',
  initial_url            TEXT,
  login_url              TEXT,
  logged_in_url          TEXT,
  direct_url_hint        TEXT,
  host_patterns          TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  video_url_patterns     TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  blocked_url_patterns   TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  priority               INTEGER NOT NULL DEFAULT 100,
  metadata               JSONB NOT NULL DEFAULT '{}'::jsonb,
  schema_version         INTEGER NOT NULL DEFAULT 1,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT streaming_platform_rules_platform_id_not_empty CHECK (length(trim(platform_id)) > 0),
  CONSTRAINT streaming_platform_rules_display_name_not_empty CHECK (length(trim(display_name)) > 0),
  CONSTRAINT streaming_platform_rules_schema_version_positive CHECK (schema_version > 0),
  CONSTRAINT streaming_platform_rules_metadata_object CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_streaming_platform_rules_enabled_priority
  ON public.streaming_platform_rules(enabled, priority);

ALTER TABLE public.streaming_platform_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "streaming_platform_rules_read" ON public.streaming_platform_rules;
CREATE POLICY "streaming_platform_rules_read" ON public.streaming_platform_rules
  FOR SELECT TO authenticated
  USING (TRUE);

DROP POLICY IF EXISTS "streaming_platform_rules_admin_write" ON public.streaming_platform_rules;
CREATE POLICY "streaming_platform_rules_admin_write" ON public.streaming_platform_rules
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

CREATE OR REPLACE FUNCTION public.set_streaming_platform_rules_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS streaming_platform_rules_updated_at ON public.streaming_platform_rules;
CREATE TRIGGER streaming_platform_rules_updated_at
  BEFORE UPDATE ON public.streaming_platform_rules
  FOR EACH ROW EXECUTE FUNCTION public.set_streaming_platform_rules_updated_at();

CREATE OR REPLACE FUNCTION public.get_streaming_platform_rules(
  p_schema_version INTEGER DEFAULT 1
)
RETURNS TABLE (
  platform_id TEXT,
  display_name TEXT,
  enabled BOOLEAN,
  allow_direct_playback BOOLEAN,
  requires_drm BOOLEAN,
  supports_embed BOOLEAN,
  resolver_strategy TEXT,
  initial_url TEXT,
  login_url TEXT,
  logged_in_url TEXT,
  direct_url_hint TEXT,
  host_patterns TEXT[],
  video_url_patterns TEXT[],
  blocked_url_patterns TEXT[],
  priority INTEGER,
  metadata JSONB,
  schema_version INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_schema_version INTEGER := GREATEST(COALESCE(p_schema_version, 1), 1);
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    spr.platform_id,
    spr.display_name,
    spr.enabled,
    spr.allow_direct_playback,
    spr.requires_drm,
    spr.supports_embed,
    spr.resolver_strategy,
    spr.initial_url,
    spr.login_url,
    spr.logged_in_url,
    spr.direct_url_hint,
    spr.host_patterns,
    spr.video_url_patterns,
    spr.blocked_url_patterns,
    spr.priority,
    spr.metadata,
    spr.schema_version
  FROM public.streaming_platform_rules spr
  WHERE spr.schema_version <= v_schema_version
  ORDER BY spr.priority ASC, spr.platform_id ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_streaming_platform_rules(INTEGER) TO authenticated;

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES (
  'features.remote_streaming_rules_enabled',
  'true'::jsonb,
  'features',
  'Habilita allowlist/blocklist server-driven da Sala de Projeção com fallback conservador no APK'
)
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  category = EXCLUDED.category,
  description = EXCLUDED.description;

INSERT INTO public.streaming_platform_rules (
  platform_id, display_name, enabled, allow_direct_playback, requires_drm,
  supports_embed, resolver_strategy, initial_url, login_url, logged_in_url,
  direct_url_hint, host_patterns, video_url_patterns, blocked_url_patterns,
  priority, metadata, schema_version
)
VALUES
  ('youtube', 'YouTube', TRUE, FALSE, FALSE, TRUE, 'youtube', 'https://www.youtube.com', NULL, NULL, NULL,
   ARRAY['(^|\.)youtube\.com', '(^|\.)youtu\.be'],
   ARRAY['youtube\.com/watch\?.*v=[a-zA-Z0-9_-]{11}', 'youtu\.be/[a-zA-Z0-9_-]{11}', 'youtube\.com/shorts/[a-zA-Z0-9_-]{11}'],
   ARRAY[]::TEXT[], 10, '{}'::jsonb, 1),
  ('youtube_live', 'YouTube Live', TRUE, FALSE, FALSE, TRUE, 'youtube_live', 'https://www.youtube.com/live', NULL, NULL, NULL,
   ARRAY['(^|\.)youtube\.com', '(^|\.)youtu\.be'],
   ARRAY['youtube\.com/watch\?.*v=[a-zA-Z0-9_-]{11}', 'youtu\.be/[a-zA-Z0-9_-]{11}', 'youtube\.com/@[^/]+/live'],
   ARRAY[]::TEXT[], 11, '{}'::jsonb, 1),
  ('twitch', 'Twitch', TRUE, FALSE, FALSE, TRUE, 'twitch', 'https://www.twitch.tv', NULL, NULL, NULL,
   ARRAY['(^|\.)twitch\.tv'],
   ARRAY['twitch\.tv/videos/\d+', 'twitch\.tv/[a-zA-Z0-9_]+$', 'twitch\.tv/[a-zA-Z0-9_]+\?'],
   ARRAY[]::TEXT[], 20, '{}'::jsonb, 1),
  ('kick', 'Kick', TRUE, FALSE, FALSE, TRUE, 'kick', 'https://kick.com', NULL, NULL, NULL,
   ARRAY['(^|\.)kick\.com'],
   ARRAY['kick\.com/video/[a-zA-Z0-9_-]+', 'kick\.com/[a-zA-Z0-9_-]+$'],
   ARRAY[]::TEXT[], 30, '{}'::jsonb, 1),
  ('vimeo', 'Vimeo', TRUE, FALSE, FALSE, TRUE, 'vimeo', 'https://vimeo.com/login', 'https://vimeo.com/login', 'https://vimeo.com/manage/videos', NULL,
   ARRAY['(^|\.)vimeo\.com'],
   ARRAY['vimeo\.com/\d+'],
   ARRAY[]::TEXT[], 40, '{}'::jsonb, 1),
  ('dailymotion', 'Dailymotion', TRUE, FALSE, FALSE, TRUE, 'dailymotion', 'https://www.dailymotion.com', NULL, NULL, NULL,
   ARRAY['(^|\.)dailymotion\.com'],
   ARRAY['dailymotion\.com/video/[a-zA-Z0-9]+'],
   ARRAY[]::TEXT[], 45, '{}'::jsonb, 1),
  ('drive', 'Google Drive', TRUE, FALSE, FALSE, TRUE, 'google_drive', 'https://accounts.google.com/ServiceLogin?service=wise&continue=https://drive.google.com/drive/my-drive', 'https://accounts.google.com/ServiceLogin?service=wise&continue=https://drive.google.com/drive/my-drive', 'https://drive.google.com/drive/my-drive', NULL,
   ARRAY['(^|\.)drive\.google\.com'],
   ARRAY['drive\.google\.com/file/d/[a-zA-Z0-9_-]+'],
   ARRAY[]::TEXT[], 50, '{}'::jsonb, 1),
  ('tubi', 'Tubi', TRUE, FALSE, FALSE, TRUE, 'tubi', 'https://tubitv.com', NULL, NULL, NULL,
   ARRAY['(^|\.)tubitv\.com'],
   ARRAY['tubitv\.com/movies/\d+', 'tubitv\.com/tv-shows/\d+'],
   ARRAY[]::TEXT[], 55, '{}'::jsonb, 1),
  ('pluto', 'Pluto TV', TRUE, FALSE, FALSE, TRUE, 'pluto', 'https://pluto.tv/live-tv', NULL, 'https://pluto.tv/live-tv', NULL,
   ARRAY['(^|\.)pluto\.tv'],
   ARRAY['pluto\.tv/live-tv/[a-zA-Z0-9_-]+', 'pluto\.tv/on-demand/[^?]+'],
   ARRAY[]::TEXT[], 60, '{}'::jsonb, 1),
  ('netflix', 'Netflix', TRUE, FALSE, TRUE, TRUE, 'drm_relay', 'https://www.netflix.com/login', 'https://www.netflix.com/login', 'https://www.netflix.com/browse', NULL,
   ARRAY['(^|\.)netflix\.com'],
   ARRAY['netflix\.com/watch/\d+', 'netflix\.com/title/\d+'],
   ARRAY[]::TEXT[], 70, '{}'::jsonb, 1),
  ('disney', 'Disney+', TRUE, FALSE, TRUE, TRUE, 'disney_bamgrid', 'https://www.disneyplus.com/login', 'https://www.disneyplus.com/login', 'https://www.disneyplus.com/home', NULL,
   ARRAY['(^|\.)disneyplus\.com'],
   ARRAY['disneyplus\.com/video/[a-zA-Z0-9_-]+', 'disneyplus\.com/movies/[^/]+/[a-zA-Z0-9_-]+', 'disneyplus\.com/series/[^/]+/[a-zA-Z0-9_-]+'],
   ARRAY[]::TEXT[], 80, '{}'::jsonb, 1),
  ('amazon', 'Prime Video', TRUE, FALSE, TRUE, TRUE, 'drm_relay', 'https://www.primevideo.com', 'https://www.amazon.com/ap/signin?openid.return_to=https://www.primevideo.com', 'https://www.primevideo.com/storefront/', NULL,
   ARRAY['(^|\.)primevideo\.com', '(^|\.)amazon\.com'],
   ARRAY['primevideo\.com/detail/[A-Z0-9]+', 'primevideo\.com/.*dp/[A-Z0-9]+', 'amazon\.com/.*dp/[A-Z0-9]+'],
   ARRAY[]::TEXT[], 90, '{}'::jsonb, 1),
  ('hbo', 'Max', TRUE, FALSE, TRUE, TRUE, 'drm_relay', 'https://www.max.com/login', 'https://www.max.com/login', 'https://www.max.com/home', NULL,
   ARRAY['(^|\.)max\.com', '(^|\.)hbomax\.com'],
   ARRAY['max\.com/video/watch/[a-zA-Z0-9_-]+', 'max\.com/movies/[^/]+/[a-zA-Z0-9_-]+', 'max\.com/series/[^/]+/[a-zA-Z0-9_-]+'],
   ARRAY[]::TEXT[], 100, '{}'::jsonb, 1),
  ('crunchyroll', 'Crunchyroll', TRUE, FALSE, TRUE, TRUE, 'drm_relay', 'https://www.crunchyroll.com/login', 'https://www.crunchyroll.com/login', 'https://www.crunchyroll.com/videos/new', NULL,
   ARRAY['(^|\.)crunchyroll\.com'],
   ARRAY['crunchyroll\.com/watch/[A-Z0-9]+', 'crunchyroll\.com/series/[A-Z0-9]+'],
   ARRAY[]::TEXT[], 110, '{}'::jsonb, 1),
  ('vk', 'VK Video', TRUE, FALSE, FALSE, TRUE, 'embed', 'https://vk.com/video', NULL, NULL, NULL,
   ARRAY['(^|\.)vk\.com', '(^|\.)vk\.ru'],
   ARRAY['vk\.(com|ru)/video[-_0-9]+'],
   ARRAY[]::TEXT[], 115, '{}'::jsonb, 1),
  ('local', 'Vídeo local', TRUE, TRUE, FALSE, FALSE, 'local_storage', NULL, NULL, NULL, NULL,
   ARRAY['supabase\.co/storage'],
   ARRAY['supabase\.co/storage/.*/screening-videos'],
   ARRAY[]::TEXT[], 120, '{}'::jsonb, 1),
  ('web', 'URL Direta', TRUE, TRUE, FALSE, FALSE, 'direct', NULL, NULL, NULL, 'Cole uma URL direta HTTPS de vídeo (.m3u8, .mp4 ou .webm).',
   ARRAY[]::TEXT[],
   ARRAY['https://[^\s]+\.(m3u8|mp4|webm)(\?.*)?$'],
   ARRAY['javascript:', 'data:', 'file:', 'localhost', '127\.0\.0\.1', '(^|\.)10\.\d+\.\d+\.\d+', '(^|\.)192\.168\.', '(^|\.)172\.(1[6-9]|2\d|3[0-1])\.'],
   900, '{}'::jsonb, 1)
ON CONFLICT (platform_id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  enabled = EXCLUDED.enabled,
  allow_direct_playback = EXCLUDED.allow_direct_playback,
  requires_drm = EXCLUDED.requires_drm,
  supports_embed = EXCLUDED.supports_embed,
  resolver_strategy = EXCLUDED.resolver_strategy,
  initial_url = EXCLUDED.initial_url,
  login_url = EXCLUDED.login_url,
  logged_in_url = EXCLUDED.logged_in_url,
  direct_url_hint = EXCLUDED.direct_url_hint,
  host_patterns = EXCLUDED.host_patterns,
  video_url_patterns = EXCLUDED.video_url_patterns,
  blocked_url_patterns = EXCLUDED.blocked_url_patterns,
  priority = EXCLUDED.priority,
  metadata = EXCLUDED.metadata,
  schema_version = EXCLUDED.schema_version,
  updated_at = NOW();
