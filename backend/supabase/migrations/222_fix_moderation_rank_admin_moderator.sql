-- =============================================================================
-- Migration 222: Corrigir get_moderation_rank para incluir cargos 'admin' e
--                'moderator' no mapeamento de rank de comunidade.
--
-- Problema: Os cargos 'admin' e 'moderator' do enum user_role existem na tabela
-- community_members mas não eram reconhecidos pela função get_moderation_rank,
-- resultando em rank 0 (membro comum) para esses cargos.
--
-- Hierarquia de ranks de moderação (completa):
--   7 → founder    (team_rank = 100)
--   6 → co_founder (team_rank = 90)
--   5 → team_admin (team_rank >= 80 e < 90)
--   4 → team_mod   (team_rank >= 70 e < 80)
--   3 → agent      (cargo de comunidade — criador/dono)
--   3 → admin      (cargo de comunidade — admin global com poder local)
--   2 → leader     (cargo de comunidade)
--   1 → curator    (cargo de comunidade)
--   1 → moderator  (cargo de comunidade)
--   0 → member     (padrão)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_moderation_rank(
  p_user_id      UUID,
  p_community_id UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_team_rank      INTEGER := 0;
  v_team_role      TEXT    := NULL;
  v_community_role TEXT    := 'member';
BEGIN
  -- Verificar rank e role global da equipe
  SELECT COALESCE(team_rank, 0), team_role::TEXT
  INTO v_team_rank, v_team_role
  FROM public.profiles
  WHERE id = p_user_id;

  -- Hierarquia de team members (rank numérico de moderação)
  IF v_team_role = 'founder'    THEN RETURN 7; END IF;  -- Fundador: rank 100
  IF v_team_role = 'co_founder' THEN RETURN 6; END IF;  -- Co-Fundador: rank 90
  IF v_team_rank >= 80          THEN RETURN 5; END IF;  -- Team Admin: rank 80–89
  IF v_team_rank >= 70          THEN RETURN 4; END IF;  -- Team Mod: rank 70–79

  -- Verificar role na comunidade (se fornecido)
  IF p_community_id IS NOT NULL THEN
    SELECT COALESCE(role::TEXT, 'member')
    INTO v_community_role
    FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = p_user_id
      AND status = 'active';
  END IF;

  -- Mapear cargo local da comunidade para rank numérico
  -- 'admin' e 'moderator' são cargos globais da equipe NexusHub que também
  -- podem ser atribuídos localmente em uma comunidade.
  RETURN CASE COALESCE(v_community_role, 'member')
    WHEN 'agent'     THEN 3  -- Criador/dono da comunidade
    WHEN 'admin'     THEN 3  -- Admin global com poder de moderação total
    WHEN 'leader'    THEN 2  -- Líder da comunidade
    WHEN 'curator'   THEN 1  -- Curador da comunidade
    WHEN 'moderator' THEN 1  -- Moderador da comunidade
    ELSE 0                   -- Membro comum
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_moderation_rank(UUID, UUID) TO authenticated;

-- =============================================================================
-- Também corrigir as funções de moderação que verificam o rank do caller
-- para garantir que 'admin' e 'moderator' sejam reconhecidos.
-- =============================================================================

-- Verificar e corrigir ban_community_member se necessário
CREATE OR REPLACE FUNCTION public.can_moderate_member(
  p_caller_id    UUID,
  p_target_id    UUID,
  p_community_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_rank INTEGER;
  v_target_rank INTEGER;
BEGIN
  v_caller_rank := public.get_moderation_rank(p_caller_id, p_community_id);
  v_target_rank := public.get_moderation_rank(p_target_id, p_community_id);
  -- Caller deve ter rank estritamente maior que o alvo e pelo menos rank 1
  RETURN v_caller_rank > v_target_rank AND v_caller_rank >= 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_moderate_member(UUID, UUID, UUID) TO authenticated;
