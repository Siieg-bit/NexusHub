-- ============================================================================
-- Migration 140: SMS 2FA Manual (via Edge Functions + Twilio)
-- Tabela sms_2fa_codes para armazenar OTPs hasheados
-- Tabela user_2fa_settings para configurações de 2FA por usuário
-- Tabela auth_security_log para audit log
-- RPC: get_sms_2fa_status — retorna status do SMS 2FA do usuário
-- RPC: disable_sms_2fa   — desativa SMS 2FA
-- ============================================================================

-- ── Tabela: sms_2fa_codes ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sms_2fa_codes (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone       text        NOT NULL,
  code_hash   text        NOT NULL,           -- SHA-256(code + user_id)
  expires_at  timestamptz NOT NULL,
  used        boolean     NOT NULL DEFAULT false,
  attempts    integer     NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sms_2fa_codes_user_id_idx ON public.sms_2fa_codes(user_id);
CREATE INDEX IF NOT EXISTS sms_2fa_codes_expires_idx ON public.sms_2fa_codes(expires_at);

-- RLS: apenas service_role pode ler/escrever (Edge Functions usam service_role)
ALTER TABLE public.sms_2fa_codes ENABLE ROW LEVEL SECURITY;
-- Sem policies de usuário — acesso apenas via service_role key nas Edge Functions

-- ── Tabela: user_2fa_settings ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_2fa_settings (
  user_id        uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  totp_enabled   boolean     NOT NULL DEFAULT false,
  totp_factor_id text,
  phone_enabled  boolean     NOT NULL DEFAULT false,
  phone_number   text,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_2fa_settings ENABLE ROW LEVEL SECURITY;

-- Usuário pode ler e atualizar apenas seus próprios dados
DROP POLICY IF EXISTS "user_2fa_settings_select" ON public.user_2fa_settings;
CREATE POLICY "user_2fa_settings_select"
  ON public.user_2fa_settings FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_2fa_settings_update" ON public.user_2fa_settings;
CREATE POLICY "user_2fa_settings_update"
  ON public.user_2fa_settings FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_2fa_settings_insert" ON public.user_2fa_settings;
CREATE POLICY "user_2fa_settings_insert"
  ON public.user_2fa_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── Tabela: auth_security_log ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.auth_security_log (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event      text        NOT NULL,
  details    jsonb,
  ip_address text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS auth_security_log_user_id_idx ON public.auth_security_log(user_id);
CREATE INDEX IF NOT EXISTS auth_security_log_created_idx ON public.auth_security_log(created_at DESC);

ALTER TABLE public.auth_security_log ENABLE ROW LEVEL SECURITY;

-- Usuário pode ver apenas seus próprios logs
DROP POLICY IF EXISTS "auth_security_log_select" ON public.auth_security_log;
CREATE POLICY "auth_security_log_select"
  ON public.auth_security_log FOR SELECT
  USING (auth.uid() = user_id);

-- ── Backup codes ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.backup_codes (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash  text        NOT NULL,   -- bcrypt hash do código
  used       boolean     NOT NULL DEFAULT false,
  used_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS backup_codes_user_id_idx ON public.backup_codes(user_id);

ALTER TABLE public.backup_codes ENABLE ROW LEVEL SECURITY;

-- Apenas service_role acessa backup_codes (via RPCs)
-- Nenhuma policy de usuário — acesso via SECURITY DEFINER

-- ── RPC: get_2fa_status ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_2fa_status();
CREATE OR REPLACE FUNCTION public.get_2fa_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings  public.user_2fa_settings%ROWTYPE;
  v_backup_count integer;
  v_phone_masked text;
BEGIN
  SELECT * INTO v_settings
  FROM public.user_2fa_settings
  WHERE user_id = auth.uid();

  SELECT COUNT(*) INTO v_backup_count
  FROM public.backup_codes
  WHERE user_id = auth.uid() AND used = false;

  IF v_settings.phone_number IS NOT NULL THEN
    v_phone_masked := LEFT(v_settings.phone_number, 3)
      || '****'
      || RIGHT(v_settings.phone_number, 4);
  END IF;

  RETURN jsonb_build_object(
    'totp_enabled',       COALESCE(v_settings.totp_enabled, false),
    'phone_enabled',      COALESCE(v_settings.phone_enabled, false),
    'phone_masked',       v_phone_masked,
    'backup_codes_left',  v_backup_count,
    'any_2fa_active',     COALESCE(v_settings.totp_enabled, false) OR COALESCE(v_settings.phone_enabled, false)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_2fa_status() TO authenticated;

-- ── RPC: disable_sms_2fa ─────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.disable_sms_2fa();
CREATE OR REPLACE FUNCTION public.disable_sms_2fa()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.user_2fa_settings
  SET phone_enabled = false,
      phone_number  = NULL,
      updated_at    = now()
  WHERE user_id = auth.uid();

  -- Invalidar todos os códigos SMS pendentes
  UPDATE public.sms_2fa_codes
  SET used = true
  WHERE user_id = auth.uid() AND used = false;

  -- Log
  INSERT INTO public.auth_security_log(user_id, event, details)
  VALUES (auth.uid(), 'sms_2fa_disabled', '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.disable_sms_2fa() TO authenticated;

-- ── RPC: enable_totp_2fa ─────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.enable_totp_2fa(text, text[]);
CREATE OR REPLACE FUNCTION public.enable_totp_2fa(
  p_factor_id   text,
  p_backup_codes text[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
BEGIN
  -- Salvar configurações TOTP
  INSERT INTO public.user_2fa_settings(user_id, totp_enabled, totp_factor_id)
  VALUES (auth.uid(), true, p_factor_id)
  ON CONFLICT (user_id) DO UPDATE
    SET totp_enabled   = true,
        totp_factor_id = p_factor_id,
        updated_at     = now();

  -- Remover backup codes antigos
  DELETE FROM public.backup_codes WHERE user_id = auth.uid();

  -- Inserir novos backup codes (já hasheados pelo cliente)
  FOREACH v_code IN ARRAY p_backup_codes LOOP
    INSERT INTO public.backup_codes(user_id, code_hash)
    VALUES (auth.uid(), v_code);
  END LOOP;

  -- Log
  INSERT INTO public.auth_security_log(user_id, event, details)
  VALUES (auth.uid(), 'totp_2fa_enabled', jsonb_build_object('factor_id', p_factor_id));
END;
$$;

GRANT EXECUTE ON FUNCTION public.enable_totp_2fa(text, text[]) TO authenticated;

-- ── RPC: disable_totp_2fa ────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.disable_totp_2fa();
CREATE OR REPLACE FUNCTION public.disable_totp_2fa()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.user_2fa_settings
  SET totp_enabled   = false,
      totp_factor_id = NULL,
      updated_at     = now()
  WHERE user_id = auth.uid();

  -- Remover backup codes
  DELETE FROM public.backup_codes WHERE user_id = auth.uid();

  -- Log
  INSERT INTO public.auth_security_log(user_id, event, details)
  VALUES (auth.uid(), 'totp_2fa_disabled', '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.disable_totp_2fa() TO authenticated;

-- ── RPC: use_backup_code ─────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.use_backup_code(text);
CREATE OR REPLACE FUNCTION public.use_backup_code(p_code_hash text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id
  FROM public.backup_codes
  WHERE user_id = auth.uid()
    AND code_hash = p_code_hash
    AND used = false
  LIMIT 1;

  IF v_id IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.backup_codes
  SET used = true, used_at = now()
  WHERE id = v_id;

  -- Log
  INSERT INTO public.auth_security_log(user_id, event, details)
  VALUES (auth.uid(), 'backup_code_used', '{}'::jsonb);

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_backup_code(text) TO authenticated;

-- ── Limpeza automática de códigos expirados (via pg_cron se disponível) ──────
-- Executar manualmente ou via scheduled function se necessário
-- DELETE FROM public.sms_2fa_codes WHERE expires_at < now() - interval '1 day';
