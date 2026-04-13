-- ============================================================================
-- NexusHub — Migração 095: Presença gradual em janelas de 15 minutos
-- Regras:
--   * Não depender de presença em tempo real por canal
--   * Considerar online somente atividade dentro da última janela de 15 min
--   * Permitir override manual reutilizando profiles.is_ghost_mode
--   * Atualizar last_seen_at e online_status de forma consistente no backend
-- ============================================================================

-- Índice para consultas e ordenações por atividade recente.
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen_at ON public.profiles(last_seen_at DESC);

COMMENT ON COLUMN public.profiles.online_status IS
  'Estado operacional de presença. 1 = online recente, 2 = offline. Deve ser interpretado em conjunto com is_ghost_mode e last_seen_at.';

COMMENT ON COLUMN public.profiles.last_seen_at IS
  'Última atividade conhecida do usuário em UTC. A UI deve considerar online apenas se o timestamp estiver dentro da janela de 15 minutos.';

COMMENT ON COLUMN public.profiles.is_ghost_mode IS
  'Override manual de presença. Quando true, o usuário deve aparecer offline independentemente da atividade recente.';

CREATE OR REPLACE FUNCTION public.set_manual_presence_visibility(
  p_force_offline BOOLEAN
)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles;
BEGIN
  UPDATE public.profiles
  SET
    is_ghost_mode = p_force_offline,
    online_status = CASE WHEN p_force_offline THEN 2 ELSE 1 END,
    last_seen_at = NOW(),
    updated_at = NOW()
  WHERE id = auth.uid()
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_manual_presence_visibility(BOOLEAN) TO authenticated;

COMMENT ON FUNCTION public.set_manual_presence_visibility(BOOLEAN) IS
  'Alterna instantaneamente a visibilidade manual de presença do usuário autenticado, reutilizando is_ghost_mode como override offline.';

CREATE OR REPLACE FUNCTION public.bump_presence_activity()
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles;
BEGIN
  UPDATE public.profiles
  SET
    last_seen_at = NOW(),
    online_status = CASE WHEN COALESCE(is_ghost_mode, FALSE) THEN 2 ELSE 1 END,
    updated_at = NOW()
  WHERE id = auth.uid()
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.bump_presence_activity() TO authenticated;

COMMENT ON FUNCTION public.bump_presence_activity() IS
  'Registra atividade do usuário autenticado em UTC. Deve ser chamada em janelas de 15 minutos; se is_ghost_mode estiver ativo, mantém o usuário visível como offline.';
