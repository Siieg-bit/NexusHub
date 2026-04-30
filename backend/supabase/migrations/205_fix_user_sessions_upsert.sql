-- =============================================================================
-- Migration 205: Corrige sessões ativas no Centro de Segurança
-- =============================================================================
-- Problema: a tabela user_sessions nunca era populada porque não existia
-- uma RPC para registrar/atualizar a sessão atual do usuário.
-- Solução: criar a RPC upsert_user_session que o app chama ao iniciar,
-- e adicionar coluna session_token para identificar a sessão Supabase.
-- =============================================================================

-- Adicionar coluna session_token para identificar unicamente a sessão Supabase
ALTER TABLE public.user_sessions
  ADD COLUMN IF NOT EXISTS session_token TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_sessions_token
  ON public.user_sessions(session_token)
  WHERE session_token IS NOT NULL;

-- Permitir UPDATE via RPC (SECURITY DEFINER)
DROP POLICY IF EXISTS "user_sessions_update_own" ON public.user_sessions;
CREATE POLICY "user_sessions_update_own" ON public.user_sessions
  FOR UPDATE USING (user_id = auth.uid());

-- =============================================================================
-- RPC: upsert_user_session
-- Registra ou atualiza a sessão atual do usuário.
-- Chamada pelo app ao iniciar (após login ou ao abrir com sessão válida).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.upsert_user_session(
  p_session_token  TEXT,
  p_device_name    TEXT    DEFAULT NULL,
  p_device_type    TEXT    DEFAULT 'mobile',
  p_ip_address     TEXT    DEFAULT NULL,
  p_location       TEXT    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session_id UUID;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  -- Marcar todas as outras sessões do usuário como não-correntes
  UPDATE public.user_sessions
  SET is_current = FALSE
  WHERE user_id = v_user_id AND is_current = TRUE
    AND (session_token IS DISTINCT FROM p_session_token);

  -- Upsert da sessão atual pelo token
  INSERT INTO public.user_sessions (
    user_id, session_token, device_name, device_type,
    ip_address, location, is_current, last_active
  ) VALUES (
    v_user_id, p_session_token,
    COALESCE(p_device_name, 'Dispositivo desconhecido'),
    COALESCE(p_device_type, 'mobile'),
    p_ip_address, p_location,
    TRUE, NOW()
  )
  ON CONFLICT (session_token) DO UPDATE
    SET device_name  = EXCLUDED.device_name,
        device_type  = EXCLUDED.device_type,
        ip_address   = EXCLUDED.ip_address,
        location     = EXCLUDED.location,
        is_current   = TRUE,
        last_active  = NOW()
  RETURNING id INTO v_session_id;

  -- Limpar sessões antigas (mais de 90 dias sem atividade)
  DELETE FROM public.user_sessions
  WHERE user_id = v_user_id
    AND last_active < NOW() - INTERVAL '90 days';

  RETURN jsonb_build_object('session_id', v_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_user_session(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Drop funções existentes com tipo de retorno diferente para poder recriar
DROP FUNCTION IF EXISTS public.revoke_all_sessions();
DROP FUNCTION IF EXISTS public.revoke_session(UUID);

-- =============================================================================
-- RPC: revoke_all_other_sessions — revoga todas as sessões exceto a atual
-- =============================================================================
CREATE OR REPLACE FUNCTION public.revoke_all_other_sessions()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_deleted INTEGER;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  DELETE FROM public.user_sessions
  WHERE user_id = v_user_id AND is_current IS NOT TRUE;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('revoked', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION public.revoke_all_other_sessions() TO authenticated;

-- =============================================================================
-- RPC: revoke_all_sessions — revoga TODAS as sessões (incluindo a atual)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.revoke_all_sessions()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_deleted INTEGER;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  DELETE FROM public.user_sessions WHERE user_id = v_user_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('revoked', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION public.revoke_all_sessions() TO authenticated;

-- =============================================================================
-- RPC: revoke_session — revoga uma sessão específica (recriada com JSONB)
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
