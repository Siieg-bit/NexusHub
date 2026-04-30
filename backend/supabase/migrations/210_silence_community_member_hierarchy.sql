-- =============================================================================
-- Migration 210: Criar silence_community_member com hierarquia correta
-- =============================================================================
-- A função silence_community_member estava ausente no banco de produção.
-- Esta migration a cria usando a função get_moderation_rank (migration 209)
-- para garantir que a hierarquia de moderação seja respeitada.
--
-- Hierarquia:
--   - curator (rank 1): pode silenciar apenas member (rank 0)
--   - leader  (rank 2): pode silenciar curator (rank 1) e member (rank 0)
--   - agent   (rank 3): pode silenciar leader (rank 2) e abaixo
--   - team_mod/team_admin (rank 4/5): podem silenciar qualquer cargo de comunidade
-- =============================================================================

CREATE OR REPLACE FUNCTION public.silence_community_member(
  p_community_id   UUID,
  p_target_id      UUID,
  p_duration_hours INT  DEFAULT 24,
  p_reason         TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id     UUID    := auth.uid();
  v_caller_rank INTEGER := 0;
  v_target_rank INTEGER := 0;
  v_until       TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Calcular ranks usando hierarquia completa
  v_caller_rank := public.get_moderation_rank(v_user_id, p_community_id);
  v_target_rank := public.get_moderation_rank(p_target_id, p_community_id);

  -- Rank mínimo para silenciar: curator (1) ou superior
  IF v_caller_rank < 1 THEN
    RAISE EXCEPTION 'Sem permissão para silenciar membros';
  END IF;

  -- Não pode silenciar alguém de mesmo nível ou superior
  IF v_target_rank >= v_caller_rank THEN
    RAISE EXCEPTION 'Não é possível silenciar um membro de cargo igual ou superior ao seu';
  END IF;

  -- curator (rank 1) só pode silenciar member (rank 0)
  IF v_caller_rank = 1 AND v_target_rank > 0 THEN
    RAISE EXCEPTION 'Curadores só podem silenciar membros comuns';
  END IF;

  v_until := NOW() + (p_duration_hours || ' hours')::INTERVAL;

  UPDATE public.community_members
  SET is_muted = TRUE, mute_expires_at = v_until
  WHERE community_id = p_community_id AND user_id = p_target_id;

  PERFORM public.log_moderation_action(
    p_community_id   => p_community_id,
    p_action         => 'mute',
    p_target_user_id => p_target_id,
    p_reason         => COALESCE(p_reason, 'Silenciado por ' || p_duration_hours || 'h'),
    p_duration_hours => p_duration_hours
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.silence_community_member(UUID, UUID, INT, TEXT) TO authenticated;
