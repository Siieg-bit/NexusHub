-- =============================================================================
-- Migration 242 — OTA Translations Remote Config Flag
--
-- Adiciona a feature flag `features.ota_translations_enabled` à tabela
-- `app_remote_config`, permitindo habilitar/desabilitar a camada de traduções
-- OTA sem publicar novo APK.
--
-- Esta migration é propositalmente pequena e idempotente porque a tabela base
-- foi criada na migration 238 e pode já estar aplicada em produção.
-- =============================================================================

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES
  (
    'features.ota_translations_enabled',
    'true',
    'features',
    'Habilitar traduções OTA via app_translations com fallback local no APK'
  )
ON CONFLICT (key) DO UPDATE SET
  value       = EXCLUDED.value,
  category    = EXCLUDED.category,
  description = EXCLUDED.description;
