-- NexusHub — Migration 138: Secure Auth System
-- Implementa:
--   1. Tabela auth_audit_log — log imutável de eventos críticos de autenticação
--   2. Tabela auth_rate_limits — rate limit específico para operações de auth
--   3. RPC request_email_change — inicia troca de e-mail com rate limit + audit
--   4. RPC request_password_change — inicia troca de senha com rate limit + audit
--   5. RPC log_auth_event — registra evento de auth (login, logout, falha, etc.)
--   6. RPC check_auth_rate_limit — verifica e incrementa rate limit de auth
-- ============================================================================

-- ── 1. Tabela auth_audit_log ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.auth_audit_log (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event        TEXT        NOT NULL,  -- 'email_change_requested', 'email_changed', 'password_changed',
                                      -- 'login_success', 'login_failed', 'logout', 'account_deleted',
                                      -- 'password_reset_requested', 'reauth_failed'
  old_value    TEXT,                  -- e-mail antigo (hash), etc.
  new_value    TEXT,                  -- e-mail novo (hash), etc.
  ip_address   INET,
  user_agent   TEXT,
  details      JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices para queries rápidas
CREATE INDEX IF NOT EXISTS idx_auth_audit_user_event
  ON public.auth_audit_log(user_id, event, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_auth_audit_created
  ON public.auth_audit_log(created_at DESC);

-- RLS: usuário vê apenas seus próprios logs; admins veem tudo
ALTER TABLE public.auth_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_audit_select_own"
  ON public.auth_audit_log FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "auth_audit_insert_own"
  ON public.auth_audit_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Admins (service_role) podem ver tudo — via supabaseAdmin no bubble-admin
-- (service_role bypassa RLS automaticamente)

-- ── 2. Tabela auth_rate_limits ───────────────────────────────────────────────
-- Controla tentativas de operações sensíveis por usuário
CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action       TEXT        NOT NULL,  -- 'email_change', 'password_change', 'reauth', 'resend_confirmation'
  attempt_count INT        NOT NULL DEFAULT 1,
  window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  window_end   TIMESTAMPTZ NOT NULL DEFAULT now() + interval '1 hour',
  blocked_until TIMESTAMPTZ,          -- NULL = não bloqueado
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, action, window_start)
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_user_action
  ON public.auth_rate_limits(user_id, action, window_end DESC);

ALTER TABLE public.auth_rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_rate_limits_own"
  ON public.auth_rate_limits FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── 3. RPC check_auth_rate_limit ────────────────────────────────────────────
-- Retorna: { allowed: bool, attempts_remaining: int, blocked_until: timestamptz }
-- Limites: email_change = 3/hora, password_change = 5/hora, reauth = 5/15min
CREATE OR REPLACE FUNCTION public.check_auth_rate_limit(
  p_action TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_max_attempts INT;
  v_window     INTERVAL;
  v_current    RECORD;
  v_window_start TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'not_authenticated');
  END IF;

  -- Definir limites por ação
  CASE p_action
    WHEN 'email_change'          THEN v_max_attempts := 3;  v_window := interval '1 hour';
    WHEN 'password_change'       THEN v_max_attempts := 5;  v_window := interval '1 hour';
    WHEN 'reauth'                THEN v_max_attempts := 5;  v_window := interval '15 minutes';
    WHEN 'resend_confirmation'   THEN v_max_attempts := 3;  v_window := interval '1 hour';
    WHEN 'password_reset'        THEN v_max_attempts := 3;  v_window := interval '1 hour';
    ELSE                              v_max_attempts := 10; v_window := interval '1 hour';
  END CASE;

  v_window_start := date_trunc('hour', now());
  IF p_action = 'reauth' THEN
    v_window_start := date_trunc('minute', now()) - (EXTRACT(MINUTE FROM now())::int % 15) * interval '1 minute';
  END IF;

  -- Buscar registro atual
  SELECT * INTO v_current
  FROM public.auth_rate_limits
  WHERE user_id = v_user_id
    AND action = p_action
    AND window_end > now()
  ORDER BY window_end DESC
  LIMIT 1;

  -- Verificar bloqueio ativo
  IF v_current.blocked_until IS NOT NULL AND v_current.blocked_until > now() THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'attempts_remaining', 0,
      'blocked_until', v_current.blocked_until
    );
  END IF;

  -- Sem registro ou janela expirada — criar novo
  IF v_current IS NULL OR v_current.window_end <= now() THEN
    INSERT INTO public.auth_rate_limits (user_id, action, attempt_count, window_start, window_end)
    VALUES (v_user_id, p_action, 1, v_window_start, v_window_start + v_window)
    ON CONFLICT (user_id, action, window_start) DO UPDATE
      SET attempt_count = auth_rate_limits.attempt_count + 1,
          window_end    = EXCLUDED.window_end;

    RETURN jsonb_build_object(
      'allowed', true,
      'attempts_remaining', v_max_attempts - 1,
      'blocked_until', null
    );
  END IF;

  -- Janela ativa — verificar limite
  IF v_current.attempt_count >= v_max_attempts THEN
    -- Bloquear por 1 hora após exceder
    UPDATE public.auth_rate_limits
    SET blocked_until = now() + interval '1 hour'
    WHERE id = v_current.id;

    RETURN jsonb_build_object(
      'allowed', false,
      'attempts_remaining', 0,
      'blocked_until', now() + interval '1 hour'
    );
  END IF;

  -- Incrementar contador
  UPDATE public.auth_rate_limits
  SET attempt_count = attempt_count + 1
  WHERE id = v_current.id;

  RETURN jsonb_build_object(
    'allowed', true,
    'attempts_remaining', v_max_attempts - v_current.attempt_count - 1,
    'blocked_until', null
  );
END;
$$;

-- ── 4. RPC log_auth_event ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.log_auth_event(
  p_event      TEXT,
  p_old_value  TEXT    DEFAULT NULL,
  p_new_value  TEXT    DEFAULT NULL,
  p_details    JSONB   DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  INSERT INTO public.auth_audit_log (user_id, event, old_value, new_value, details)
  VALUES (v_user_id, p_event, p_old_value, p_new_value, p_details);
END;
$$;

-- ── 5. RPC request_email_change ──────────────────────────────────────────────
-- Valida rate limit, registra audit log e retorna status.
-- A troca real é feita pelo Supabase Auth (updateUser) no cliente Flutter.
CREATE OR REPLACE FUNCTION public.request_email_change(
  p_new_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_rate_check JSONB;
  v_current_email TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar rate limit
  v_rate_check := public.check_auth_rate_limit('email_change');
  IF NOT (v_rate_check->>'allowed')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'rate_limited',
      'blocked_until', v_rate_check->>'blocked_until'
    );
  END IF;

  -- Buscar e-mail atual
  SELECT email INTO v_current_email FROM auth.users WHERE id = v_user_id;

  -- Validar que o novo e-mail é diferente
  IF lower(p_new_email) = lower(v_current_email) THEN
    RETURN jsonb_build_object('success', false, 'error', 'same_email');
  END IF;

  -- Verificar se o novo e-mail já está em uso
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = lower(p_new_email) AND id != v_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'email_already_in_use');
  END IF;

  -- Registrar no audit log (hash do e-mail por privacidade)
  INSERT INTO public.auth_audit_log (user_id, event, old_value, new_value, details)
  VALUES (
    v_user_id,
    'email_change_requested',
    md5(lower(v_current_email)),
    md5(lower(p_new_email)),
    jsonb_build_object('attempts_remaining', v_rate_check->>'attempts_remaining')
  );

  RETURN jsonb_build_object(
    'success', true,
    'attempts_remaining', (v_rate_check->>'attempts_remaining')::int
  );
END;
$$;

-- ── 6. RPC request_password_change ──────────────────────────────────────────
-- Valida rate limit, registra audit log e retorna status.
-- A troca real é feita pelo Supabase Auth (updateUser) no cliente Flutter.
CREATE OR REPLACE FUNCTION public.request_password_change()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_rate_check JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar rate limit
  v_rate_check := public.check_auth_rate_limit('password_change');
  IF NOT (v_rate_check->>'allowed')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'rate_limited',
      'blocked_until', v_rate_check->>'blocked_until'
    );
  END IF;

  -- Registrar no audit log
  INSERT INTO public.auth_audit_log (user_id, event, details)
  VALUES (
    v_user_id,
    'password_change_requested',
    jsonb_build_object('attempts_remaining', v_rate_check->>'attempts_remaining')
  );

  RETURN jsonb_build_object(
    'success', true,
    'attempts_remaining', (v_rate_check->>'attempts_remaining')::int
  );
END;
$$;

-- ── 7. RPC get_auth_audit_log ────────────────────────────────────────────────
-- Retorna os últimos eventos de auth do usuário logado (para exibir no app)
CREATE OR REPLACE FUNCTION public.get_auth_audit_log(
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  id         UUID,
  event      TEXT,
  details    JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.event,
    a.details,
    a.created_at
  FROM public.auth_audit_log a
  WHERE a.user_id = v_user_id
  ORDER BY a.created_at DESC
  LIMIT p_limit;
END;
$$;

-- ── 8. Adicionar coluna email_verified ao profiles ───────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'email_verified'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

-- ── 9. Trigger: marcar email_verified=true quando auth.users.email_confirmed_at é preenchido
-- Isso é feito via função que pode ser chamada no onboarding ou via webhook
CREATE OR REPLACE FUNCTION public.sync_email_verified()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Quando email_confirmed_at é preenchido, marcar email_verified=true no profile
  IF NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL THEN
    UPDATE public.profiles SET email_verified = true WHERE id = NEW.id;
    -- Registrar no audit log
    INSERT INTO public.auth_audit_log (user_id, event, details)
    VALUES (NEW.id, 'email_verified', jsonb_build_object('email', md5(lower(NEW.email))));
  END IF;
  RETURN NEW;
END;
$$;

-- Trigger na tabela auth.users (requer SECURITY DEFINER e acesso ao schema auth)
DROP TRIGGER IF EXISTS on_email_confirmed ON auth.users;
CREATE TRIGGER on_email_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_email_verified();

-- ── 10. Função para validar força de senha (usada no lado servidor) ──────────
CREATE OR REPLACE FUNCTION public.validate_password_strength(
  p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  v_score INT := 0;
  v_issues TEXT[] := '{}';
BEGIN
  -- Comprimento mínimo
  IF length(p_password) < 8 THEN
    v_issues := array_append(v_issues, 'min_length_8');
  ELSE
    v_score := v_score + 1;
  END IF;

  -- Letra maiúscula
  IF p_password !~ '[A-Z]' THEN
    v_issues := array_append(v_issues, 'needs_uppercase');
  ELSE
    v_score := v_score + 1;
  END IF;

  -- Letra minúscula
  IF p_password !~ '[a-z]' THEN
    v_issues := array_append(v_issues, 'needs_lowercase');
  ELSE
    v_score := v_score + 1;
  END IF;

  -- Número
  IF p_password !~ '[0-9]' THEN
    v_issues := array_append(v_issues, 'needs_number');
  ELSE
    v_score := v_score + 1;
  END IF;

  -- Caractere especial
  IF p_password !~ '[^a-zA-Z0-9]' THEN
    v_issues := array_append(v_issues, 'needs_special');
  ELSE
    v_score := v_score + 1;
  END IF;

  RETURN jsonb_build_object(
    'valid', array_length(v_issues, 1) IS NULL OR array_length(v_issues, 1) = 0,
    'score', v_score,  -- 0-5
    'issues', v_issues
  );
END;
$$;

-- ── 11. RPC resend_confirmation_email ────────────────────────────────────────
-- Rate-limited: máximo 3 reenvios por hora
CREATE OR REPLACE FUNCTION public.resend_confirmation_email()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_rate_check JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_rate_check := public.check_auth_rate_limit('resend_confirmation');
  IF NOT (v_rate_check->>'allowed')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'rate_limited',
      'blocked_until', v_rate_check->>'blocked_until'
    );
  END IF;

  INSERT INTO public.auth_audit_log (user_id, event)
  VALUES (v_user_id, 'confirmation_email_resent');

  RETURN jsonb_build_object('success', true);
END;
$$;
