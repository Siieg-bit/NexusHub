-- =============================================================================
-- Migration 250 — Admin Remote Config Governance
--
-- Cria a governança operacional para edição segura de conteúdo/configuração remota
-- pelo painel administrativo, sem mutações diretas de tabela no cliente.
--
-- Entregas:
--   - Tabela append-only de auditoria `app_remote_config_audit_log`.
--   - RPC SECURITY DEFINER `admin_update_remote_config` para upsert controlado.
--   - Grants mínimos para usuários autenticados; autorização interna exige Team Admin.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.app_remote_config_audit_log (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  config_key     TEXT NOT NULL,
  old_value      JSONB,
  new_value      JSONB NOT NULL,
  old_category   TEXT,
  new_category   TEXT NOT NULL,
  old_description TEXT,
  new_description TEXT DEFAULT '',
  action         TEXT NOT NULL CHECK (action IN ('insert', 'update')),
  actor_id       UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_remote_config_audit_log_key_created
  ON public.app_remote_config_audit_log(config_key, created_at DESC);

ALTER TABLE public.app_remote_config_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_remote_config_audit_log_read_team" ON public.app_remote_config_audit_log;
CREATE POLICY "app_remote_config_audit_log_read_team"
  ON public.app_remote_config_audit_log
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND (
          p.is_team_admin = TRUE
          OR COALESCE(p.team_rank, 0) >= 80
        )
    )
  );

DROP FUNCTION IF EXISTS public.admin_update_remote_config(TEXT, JSONB, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.admin_update_remote_config(
  p_key TEXT,
  p_value JSONB,
  p_category TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_is_admin BOOLEAN := FALSE;
  v_key TEXT := NULLIF(BTRIM(p_key), '');
  v_category TEXT := COALESCE(NULLIF(BTRIM(p_category), ''), 'general');
  v_description TEXT := COALESCE(p_description, '');
  v_existing public.app_remote_config%ROWTYPE;
  v_action TEXT;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'unauthenticated');
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = v_actor_id
      AND (
        p.is_team_admin = TRUE
        OR COALESCE(p.team_rank, 0) >= 80
      )
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authorized');
  END IF;

  IF v_key IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'invalid_key');
  END IF;

  IF p_value IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'invalid_value');
  END IF;

  IF v_category !~ '^[a-z][a-z0-9_]{1,40}$' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'invalid_category');
  END IF;

  SELECT *
    INTO v_existing
    FROM public.app_remote_config
   WHERE key = v_key
   FOR UPDATE;

  IF FOUND THEN
    v_action := 'update';

    UPDATE public.app_remote_config
       SET value = p_value,
           category = v_category,
           description = v_description
     WHERE key = v_key;
  ELSE
    v_action := 'insert';

    INSERT INTO public.app_remote_config (key, value, category, description)
    VALUES (v_key, p_value, v_category, v_description);
  END IF;

  INSERT INTO public.app_remote_config_audit_log (
    config_key,
    old_value,
    new_value,
    old_category,
    new_category,
    old_description,
    new_description,
    action,
    actor_id
  ) VALUES (
    v_key,
    CASE WHEN v_action = 'update' THEN v_existing.value ELSE NULL END,
    p_value,
    CASE WHEN v_action = 'update' THEN v_existing.category ELSE NULL END,
    v_category,
    CASE WHEN v_action = 'update' THEN v_existing.description ELSE NULL END,
    v_description,
    v_action,
    v_actor_id
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'key', v_key,
    'category', v_category,
    'description', v_description,
    'action', v_action,
    'value', p_value
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_remote_config(TEXT, JSONB, TEXT, TEXT) TO authenticated;
