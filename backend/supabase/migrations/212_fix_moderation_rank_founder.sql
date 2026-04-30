-- =============================================================================
-- Migration 212: Corrigir get_moderation_rank para separar founder (7) e
--                co_founder (6) conforme hierarquia completa de team members.
--
-- Hierarquia de ranks de moderação:
--   7 → founder    (team_rank = 100)
--   6 → co_founder (team_rank = 90)
--   5 → team_admin (team_rank >= 80 e < 90)
--   4 → team_mod   (team_rank >= 70 e < 80)
--   3 → agent      (cargo de comunidade)
--   2 → leader     (cargo de comunidade)
--   1 → curator    (cargo de comunidade)
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
    SELECT COALESCE(role, 'member')
    INTO v_community_role
    FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = p_user_id
      AND status = 'active';
  END IF;

  RETURN CASE COALESCE(v_community_role, 'member')
    WHEN 'agent'   THEN 3
    WHEN 'leader'  THEN 2
    WHEN 'curator' THEN 1
    ELSE 0
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_moderation_rank(UUID, UUID) TO authenticated;

-- Também atualizar o trigger sync_team_rank para garantir que team_rank = 100
-- para founder e team_rank = 90 para co_founder.
CREATE OR REPLACE FUNCTION public.sync_team_rank()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Sincroniza team_rank com base no team_role
  IF NEW.team_role IS NOT NULL THEN
    NEW.team_rank := CASE NEW.team_role::TEXT
      WHEN 'founder'      THEN 100
      WHEN 'co_founder'   THEN 90
      WHEN 'team_admin'   THEN 80
      WHEN 'trust_safety' THEN 75
      WHEN 'team_mod'     THEN 70
      WHEN 'support'      THEN 65
      WHEN 'community_manager' THEN 60
      WHEN 'content_mod'  THEN 55
      WHEN 'bug_bounty'   THEN 50
      ELSE 0
    END;
  ELSE
    NEW.team_rank := 0;
  END IF;

  -- Sincroniza is_team_admin e is_team_moderator com base no team_rank
  NEW.is_team_admin     := NEW.team_rank >= 80;
  NEW.is_team_moderator := NEW.team_rank >= 70 AND NEW.team_rank < 80;

  RETURN NEW;
END;
$$;

-- Recriar trigger se necessário
DROP TRIGGER IF EXISTS trg_sync_team_rank ON public.profiles;
CREATE TRIGGER trg_sync_team_rank
  BEFORE INSERT OR UPDATE OF team_rank, team_role
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_team_rank();
