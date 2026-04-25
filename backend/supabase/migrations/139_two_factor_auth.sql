-- ============================================================
-- Migration 139: Autenticação de 2 Fatores (2FA)
-- TOTP (app autenticador) + SMS/Telefone
-- Backup codes, audit log, rate limit
-- ============================================================

-- ── Tabela: user_2fa_settings ─────────────────────────────
-- Armazena as configurações de 2FA por usuário.
-- O segredo TOTP real fica no Supabase Auth (auth.mfa_factors),
-- aqui guardamos apenas preferências e metadados.
CREATE TABLE IF NOT EXISTS public.user_2fa_settings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  totp_enabled        BOOLEAN NOT NULL DEFAULT FALSE,
  phone_enabled       BOOLEAN NOT NULL DEFAULT FALSE,
  phone_number        TEXT,                        -- E.164: +5511999999999
  phone_verified      BOOLEAN NOT NULL DEFAULT FALSE,
  backup_codes_hash   TEXT[],                      -- bcrypt hashes dos 8 backup codes
  backup_codes_used   INT NOT NULL DEFAULT 0,
  last_totp_at        TIMESTAMPTZ,
  last_sms_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_user_2fa UNIQUE (user_id)
);

-- ── Tabela: two_fa_audit_log ──────────────────────────────
-- Registra cada evento de 2FA para auditoria e detecção de fraude.
CREATE TABLE IF NOT EXISTS public.two_fa_audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event       TEXT NOT NULL,   -- 'totp_enrolled','totp_disabled','totp_verified','totp_failed',
                               -- 'sms_enrolled','sms_disabled','sms_sent','sms_verified','sms_failed',
                               -- 'backup_used','backup_exhausted'
  details     JSONB,
  ip_address  INET,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Tabela: sms_otp_codes ─────────────────────────────────
-- Armazena OTPs de SMS gerados pelo backend (TTL 10 min, 1 tentativa/min).
CREATE TABLE IF NOT EXISTS public.sms_otp_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone       TEXT NOT NULL,
  code_hash   TEXT NOT NULL,   -- SHA-256 do código de 6 dígitos
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
  used        BOOLEAN NOT NULL DEFAULT FALSE,
  attempts    INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Índices ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_user_2fa_user ON public.user_2fa_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_2fa_audit_user ON public.two_fa_audit_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sms_otp_user ON public.sms_otp_codes(user_id, created_at DESC);

-- ── RLS ───────────────────────────────────────────────────
ALTER TABLE public.user_2fa_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.two_fa_audit_log  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sms_otp_codes     ENABLE ROW LEVEL SECURITY;

-- Usuário só lê/escreve seus próprios dados
CREATE POLICY "user_2fa_self" ON public.user_2fa_settings
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "2fa_audit_self" ON public.two_fa_audit_log
  FOR SELECT USING (auth.uid() = user_id);

-- sms_otp_codes: sem acesso direto — apenas via RPC SECURITY DEFINER
CREATE POLICY "sms_otp_deny_direct" ON public.sms_otp_codes
  FOR ALL USING (FALSE);

-- ── Trigger: updated_at ───────────────────────────────────
CREATE OR REPLACE FUNCTION public._touch_updated_at_2fa()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_2fa_updated_at ON public.user_2fa_settings;
CREATE TRIGGER trg_2fa_updated_at
  BEFORE UPDATE ON public.user_2fa_settings
  FOR EACH ROW EXECUTE FUNCTION public._touch_updated_at_2fa();

-- ============================================================
-- RPCs
-- ============================================================

-- ── get_2fa_status ────────────────────────────────────────
-- Retorna o estado atual do 2FA do usuário logado.
CREATE OR REPLACE FUNCTION public.get_2fa_status()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_row public.user_2fa_settings%ROWTYPE;
  v_totp_factor_id TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Garante que o registro existe
  INSERT INTO public.user_2fa_settings (user_id)
  VALUES (v_uid)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT * INTO v_row FROM public.user_2fa_settings WHERE user_id = v_uid;

  -- Verifica se há fator TOTP ativo no Supabase Auth
  SELECT id::TEXT INTO v_totp_factor_id
  FROM auth.mfa_factors
  WHERE user_id = v_uid
    AND factor_type = 'totp'
    AND status = 'verified'
  LIMIT 1;

  RETURN jsonb_build_object(
    'totp_enabled',       v_row.totp_enabled AND v_totp_factor_id IS NOT NULL,
    'totp_factor_id',     v_totp_factor_id,
    'phone_enabled',      v_row.phone_enabled,
    'phone_number',       v_row.phone_number,
    'phone_verified',     v_row.phone_verified,
    'backup_codes_remaining', COALESCE(array_length(v_row.backup_codes_hash, 1), 0) - v_row.backup_codes_used,
    'has_backup_codes',   v_row.backup_codes_hash IS NOT NULL
  );
END;
$$;

-- ── enable_totp_2fa ───────────────────────────────────────
-- Chamado após o usuário verificar com sucesso o código TOTP no app.
-- Marca o TOTP como ativo e gera backup codes.
CREATE OR REPLACE FUNCTION public.enable_totp_2fa(
  p_factor_id TEXT,
  p_backup_codes TEXT[]   -- 8 códigos em texto plano, hash feito aqui
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_hashes TEXT[];
  v_code TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF array_length(p_backup_codes, 1) != 8 THEN
    RAISE EXCEPTION 'backup_codes_must_be_8';
  END IF;

  -- Hash SHA-256 de cada backup code
  FOREACH v_code IN ARRAY p_backup_codes LOOP
    v_hashes := array_append(v_hashes,
      encode(digest(v_code, 'sha256'), 'hex'));
  END LOOP;

  -- Garante que o registro existe
  INSERT INTO public.user_2fa_settings (user_id)
  VALUES (v_uid)
  ON CONFLICT (user_id) DO NOTHING;

  UPDATE public.user_2fa_settings
  SET totp_enabled      = TRUE,
      backup_codes_hash = v_hashes,
      backup_codes_used = 0,
      last_totp_at      = NOW()
  WHERE user_id = v_uid;

  -- Audit log
  INSERT INTO public.two_fa_audit_log (user_id, event, details)
  VALUES (v_uid, 'totp_enrolled', jsonb_build_object('factor_id', p_factor_id));

  RETURN jsonb_build_object('success', TRUE, 'backup_codes_remaining', 8);
END;
$$;

-- ── disable_totp_2fa ──────────────────────────────────────
-- Desativa o TOTP após reautenticação.
CREATE OR REPLACE FUNCTION public.disable_totp_2fa()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  UPDATE public.user_2fa_settings
  SET totp_enabled      = FALSE,
      backup_codes_hash = NULL,
      backup_codes_used = 0
  WHERE user_id = v_uid;

  -- Remove o fator TOTP do Supabase Auth
  DELETE FROM auth.mfa_factors
  WHERE user_id = v_uid AND factor_type = 'totp';

  INSERT INTO public.two_fa_audit_log (user_id, event)
  VALUES (v_uid, 'totp_disabled');

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

-- ── request_sms_otp ───────────────────────────────────────
-- Gera e armazena um OTP de 6 dígitos para o telefone informado.
-- Rate limit: 1 SMS por minuto por usuário.
CREATE OR REPLACE FUNCTION public.request_sms_otp(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_code      TEXT;
  v_hash      TEXT;
  v_last_sent TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  -- Valida formato E.164
  IF p_phone !~ '^\+[1-9]\d{7,14}$' THEN
    RAISE EXCEPTION 'invalid_phone_format';
  END IF;

  -- Rate limit: 1 por minuto
  SELECT MAX(created_at) INTO v_last_sent
  FROM public.sms_otp_codes
  WHERE user_id = v_uid AND created_at > NOW() - INTERVAL '1 minute';

  IF v_last_sent IS NOT NULL THEN
    RAISE EXCEPTION 'rate_limit_sms' USING DETAIL =
      'Aguarde 1 minuto antes de solicitar outro código.';
  END IF;

  -- Gera código de 6 dígitos
  v_code := LPAD((floor(random() * 1000000))::TEXT, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');

  -- Invalida OTPs anteriores do mesmo usuário
  UPDATE public.sms_otp_codes SET used = TRUE
  WHERE user_id = v_uid AND used = FALSE;

  -- Insere novo OTP
  INSERT INTO public.sms_otp_codes (user_id, phone, code_hash)
  VALUES (v_uid, p_phone, v_hash);

  -- Audit log
  INSERT INTO public.two_fa_audit_log (user_id, event, details)
  VALUES (v_uid, 'sms_sent', jsonb_build_object('phone', p_phone));

  -- Retorna o código em texto plano para o backend enviar via SMS
  -- (em produção, o backend deve usar um webhook/edge function para enviar via Twilio/etc.)
  RETURN jsonb_build_object(
    'success', TRUE,
    'code',    v_code,   -- ⚠️ remover em produção — usar edge function
    'expires_in_seconds', 600
  );
END;
$$;

-- ── verify_sms_otp ────────────────────────────────────────
-- Verifica o OTP de SMS e ativa o 2FA por telefone.
CREATE OR REPLACE FUNCTION public.verify_sms_otp(
  p_phone TEXT,
  p_code  TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_otp     public.sms_otp_codes%ROWTYPE;
  v_hash    TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  v_hash := encode(digest(p_code, 'sha256'), 'hex');

  SELECT * INTO v_otp
  FROM public.sms_otp_codes
  WHERE user_id = v_uid
    AND phone    = p_phone
    AND used     = FALSE
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'otp_expired_or_not_found';
  END IF;

  -- Incrementa tentativas
  UPDATE public.sms_otp_codes
  SET attempts = attempts + 1
  WHERE id = v_otp.id;

  IF v_otp.attempts >= 5 THEN
    UPDATE public.sms_otp_codes SET used = TRUE WHERE id = v_otp.id;
    RAISE EXCEPTION 'too_many_attempts';
  END IF;

  IF v_otp.code_hash != v_hash THEN
    INSERT INTO public.two_fa_audit_log (user_id, event, details)
    VALUES (v_uid, 'sms_failed', jsonb_build_object('phone', p_phone));
    RAISE EXCEPTION 'invalid_otp';
  END IF;

  -- Marca como usado
  UPDATE public.sms_otp_codes SET used = TRUE WHERE id = v_otp.id;

  -- Ativa 2FA por telefone
  INSERT INTO public.user_2fa_settings (user_id, phone_enabled, phone_number, phone_verified)
  VALUES (v_uid, TRUE, p_phone, TRUE)
  ON CONFLICT (user_id) DO UPDATE
    SET phone_enabled  = TRUE,
        phone_number   = p_phone,
        phone_verified = TRUE,
        last_sms_at    = NOW();

  INSERT INTO public.two_fa_audit_log (user_id, event, details)
  VALUES (v_uid, 'sms_verified', jsonb_build_object('phone', p_phone));

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

-- ── disable_phone_2fa ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.disable_phone_2fa()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  UPDATE public.user_2fa_settings
  SET phone_enabled  = FALSE,
      phone_number   = NULL,
      phone_verified = FALSE
  WHERE user_id = v_uid;

  INSERT INTO public.two_fa_audit_log (user_id, event)
  VALUES (v_uid, 'sms_disabled');

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

-- ── verify_backup_code ────────────────────────────────────
-- Verifica e consome um backup code (uso único).
CREATE OR REPLACE FUNCTION public.verify_backup_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_row     public.user_2fa_settings%ROWTYPE;
  v_hash    TEXT;
  v_hashes  TEXT[];
  v_i       INT;
  v_found   BOOLEAN := FALSE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  v_hash := encode(digest(p_code, 'sha256'), 'hex');

  SELECT * INTO v_row FROM public.user_2fa_settings WHERE user_id = v_uid;
  IF NOT FOUND OR v_row.backup_codes_hash IS NULL THEN
    RAISE EXCEPTION 'no_backup_codes';
  END IF;

  v_hashes := v_row.backup_codes_hash;

  FOR v_i IN 1..array_length(v_hashes, 1) LOOP
    IF v_hashes[v_i] = v_hash THEN
      -- Remove o código usado (substitui por NULL)
      v_hashes[v_i] := NULL;
      v_found := TRUE;
      EXIT;
    END IF;
  END LOOP;

  IF NOT v_found THEN
    INSERT INTO public.two_fa_audit_log (user_id, event)
    VALUES (v_uid, 'backup_failed');
    RAISE EXCEPTION 'invalid_backup_code';
  END IF;

  -- Remove NULLs e atualiza
  UPDATE public.user_2fa_settings
  SET backup_codes_hash = array_remove(v_hashes, NULL),
      backup_codes_used = backup_codes_used + 1
  WHERE user_id = v_uid;

  INSERT INTO public.two_fa_audit_log (user_id, event, details)
  VALUES (v_uid, 'backup_used',
    jsonb_build_object('remaining',
      array_length(array_remove(v_hashes, NULL), 1)));

  -- Alerta se esgotou
  IF array_length(array_remove(v_hashes, NULL), 1) = 0 THEN
    INSERT INTO public.two_fa_audit_log (user_id, event)
    VALUES (v_uid, 'backup_exhausted');
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'remaining', COALESCE(array_length(array_remove(v_hashes, NULL), 1), 0)
  );
END;
$$;

-- ── regenerate_backup_codes ───────────────────────────────
-- Regenera os 8 backup codes (requer 2FA ativo).
CREATE OR REPLACE FUNCTION public.regenerate_backup_codes(p_new_codes TEXT[])
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_row    public.user_2fa_settings%ROWTYPE;
  v_hashes TEXT[];
  v_code   TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF array_length(p_new_codes, 1) != 8 THEN
    RAISE EXCEPTION 'backup_codes_must_be_8';
  END IF;

  SELECT * INTO v_row FROM public.user_2fa_settings WHERE user_id = v_uid;
  IF NOT FOUND OR (NOT v_row.totp_enabled AND NOT v_row.phone_enabled) THEN
    RAISE EXCEPTION '2fa_not_active';
  END IF;

  FOREACH v_code IN ARRAY p_new_codes LOOP
    v_hashes := array_append(v_hashes, encode(digest(v_code, 'sha256'), 'hex'));
  END LOOP;

  UPDATE public.user_2fa_settings
  SET backup_codes_hash = v_hashes,
      backup_codes_used = 0
  WHERE user_id = v_uid;

  INSERT INTO public.two_fa_audit_log (user_id, event)
  VALUES (v_uid, 'backup_regenerated');

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

-- ── Permissões ────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.get_2fa_status()                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.enable_totp_2fa(TEXT, TEXT[])     TO authenticated;
GRANT EXECUTE ON FUNCTION public.disable_totp_2fa()                TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_sms_otp(TEXT)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_sms_otp(TEXT, TEXT)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.disable_phone_2fa()               TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_backup_code(TEXT)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.regenerate_backup_codes(TEXT[])   TO authenticated;
