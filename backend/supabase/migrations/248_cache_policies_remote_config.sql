-- =============================================================================
-- Migration 248 — Cache Policies Remote Config
--
-- Centraliza TTLs de cache do app em `app_remote_config`, permitindo ajuste
-- operacional sem novo build do APK. O frontend mantém fallback local seguro e
-- a flag abaixo permite rollback imediato para os TTLs embarcados.
-- =============================================================================

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES
  (
    'features.remote_cache_policies_enabled',
    'true'::jsonb,
    'features',
    'Habilitar políticas remotas de TTL do cache local'
  ),
  (
    'cache.ttl_seconds',
    '{
      "default": 300,
      "posts": 300,
      "post": 300,
      "my_communities": 900,
      "community": 900,
      "messages": 120,
      "profiles": 3600,
      "global_feed": 300,
      "for_you_feed": 300,
      "notifications": 180,
      "wiki": 900
    }'::jsonb,
    'cache',
    'TTLs em segundos usados pelo CachePolicyService para expiração de cache offline-first'
  )
ON CONFLICT (key) DO UPDATE SET
  value       = EXCLUDED.value,
  category    = EXCLUDED.category,
  description = EXCLUDED.description;
