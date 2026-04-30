-- =============================================================================
-- Migration 197: Centro de Segurança
-- =============================================================================
-- Registra eventos de segurança da conta (logins, mudanças de senha, 2FA, etc.)
-- e expõe RPCs para o hub de configurações de segurança do usuário.
-- =============================================================================

-- Enum de tipos de evento de segurança
DO $$ BEGIN
  CREATE TYPE security_event_type AS ENUM (
    'login_success',
    'login_failed',
    'password_changed',
    'email_changed',
    'two_factor_enabled',
    'two_factor_disabled',
    'backup_codes_generated',
    'backup_code_used',
    'session_revoked',
    'account_locked',
    'suspicious_activity'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Tabela de eventos de segurança
CREATE TABLE IF NOT EXISTS public.security_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type   security_event_type NOT NULL,
  ip_address   TEXT,
  device_info  TEXT,
  location     TEXT,
  metadata     JSONB DEFAULT '{}',
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_events_user ON public.security_events(user_id, created_at DESC);

-- RLS: usuário vê apenas seus próprios eventos
ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "security_events_select_own" ON public.security_events
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "security_events_insert_rpc" ON public.security_events
  FOR INSERT WITH CHECK (false);

-- Tabela de sessões ativas (para o hub de segurança)
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_name  TEXT,
  device_type  TEXT DEFAULT 'mobile',  -- 'mobile' | 'tablet' | 'web'
  ip_address   TEXT,
  location     TEXT,
  is_current   BOOLEAN DEFAULT FALSE,
  last_active  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON public.user_sessions(user_id, last_active DESC);

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_sessions_select_own" ON public.user_sessions
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "user_sessions_insert_rpc" ON public.user_sessions
  FOR INSERT WITH CHECK (false);

CREATE POLICY "user_sessions_delete_own" ON public.user_sessions
  FOR DELETE USING (user_id = auth.uid());

-- =============================================================================
-- RPC: get_security_overview — retorna resumo de segurança do usuário
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_security_overview()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_has_2fa        BOOLEAN := FALSE;
  v_has_sms_2fa    BOOLEAN := FALSE;
  v_security_level INTEGER := 0;
  v_recent_events  JSONB;
  v_active_sessions JSONB;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  -- Buscar nível de segurança e flags do perfil
  SELECT
    COALESCE(security_level, 0),
    COALESCE(email_verified, FALSE)
  INTO v_security_level, v_has_2fa
  FROM public.profiles WHERE id = v_user_id;

  -- Últimos 10 eventos de segurança
  SELECT COALESCE(jsonb_agg(e ORDER BY e.created_at DESC), '[]'::jsonb)
  INTO v_recent_events
  FROM (
    SELECT id, event_type, ip_address, device_info, location, created_at
    FROM public.security_events
    WHERE user_id = v_user_id
    ORDER BY created_at DESC
    LIMIT 10
  ) e;

  -- Sessões ativas
  SELECT COALESCE(jsonb_agg(s ORDER BY s.last_active DESC), '[]'::jsonb)
  INTO v_active_sessions
  FROM (
    SELECT id, device_name, device_type, ip_address, location, is_current, last_active
    FROM public.user_sessions
    WHERE user_id = v_user_id
    ORDER BY last_active DESC
    LIMIT 10
  ) s;

  RETURN jsonb_build_object(
    'security_level',    v_security_level,
    'has_2fa',           v_has_2fa,
    'recent_events',     v_recent_events,
    'active_sessions',   v_active_sessions
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_security_overview() TO authenticated;

-- =============================================================================
-- RPC: log_security_event — registra evento de segurança
-- =============================================================================
CREATE OR REPLACE FUNCTION public.log_security_event(
  p_event_type   TEXT,
  p_ip_address   TEXT DEFAULT NULL,
  p_device_info  TEXT DEFAULT NULL,
  p_location     TEXT DEFAULT NULL,
  p_metadata     JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  INSERT INTO public.security_events (
    user_id, event_type, ip_address, device_info, location, metadata
  ) VALUES (
    v_user_id,
    p_event_type::security_event_type,
    p_ip_address,
    p_device_info,
    p_location,
    COALESCE(p_metadata, '{}')
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_security_event(TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated;

-- =============================================================================
-- RPC: revoke_session — revoga uma sessão específica
-- =============================================================================
CREATE OR REPLACE FUNCTION public.revoke_session(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  DELETE FROM public.user_sessions
  WHERE id = p_session_id AND user_id = v_user_id AND is_current IS NOT TRUE;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.revoke_session(UUID) TO authenticated;

-- =============================================================================
-- RPC: get_security_events — lista eventos de segurança paginados
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_security_events(
  p_limit  INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id           UUID,
  event_type   security_event_type,
  ip_address   TEXT,
  device_info  TEXT,
  location     TEXT,
  metadata     JSONB,
  created_at   TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    se.id, se.event_type, se.ip_address,
    se.device_info, se.location, se.metadata, se.created_at
  FROM public.security_events se
  WHERE se.user_id = auth.uid()
  ORDER BY se.created_at DESC
  LIMIT LEAST(p_limit, 50) OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_security_events(INTEGER, INTEGER) TO authenticated;
