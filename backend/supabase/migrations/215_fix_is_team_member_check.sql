-- ============================================================
-- Migration 215: Corrigir is_team_member() para incluir
-- qualquer usuário com team_rank > 0 (não apenas is_team_admin
-- ou is_team_moderator, que podem estar desatualizados).
-- ============================================================

-- Corrigir is_team_member para verificar team_rank também
CREATE OR REPLACE FUNCTION is_team_member()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT 
       is_team_admin = true 
       OR is_team_moderator = true 
       OR (team_rank IS NOT NULL AND team_rank > 0)
     FROM profiles 
     WHERE id = auth.uid()),
    false
  );
$$;

-- Garantir que o trigger sync_team_rank atualiza is_team_admin e is_team_moderator
-- corretamente para todos os cargos
CREATE OR REPLACE FUNCTION sync_team_rank()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.team_role IS NULL OR NEW.team_role = 'none' THEN
    NEW.team_rank        := 0;
    NEW.is_team_admin    := false;
    NEW.is_team_moderator := false;
  ELSIF NEW.team_role = 'founder' THEN
    NEW.team_rank        := 100;
    NEW.is_team_admin    := true;
    NEW.is_team_moderator := true;
  ELSIF NEW.team_role = 'co_founder' THEN
    NEW.team_rank        := 90;
    NEW.is_team_admin    := true;
    NEW.is_team_moderator := true;
  ELSIF NEW.team_role = 'team_admin' THEN
    NEW.team_rank        := 80;
    NEW.is_team_admin    := true;
    NEW.is_team_moderator := true;
  ELSIF NEW.team_role = 'trust_safety' THEN
    NEW.team_rank        := 75;
    NEW.is_team_admin    := false;
    NEW.is_team_moderator := true;
  ELSIF NEW.team_role = 'team_mod' THEN
    NEW.team_rank        := 70;
    NEW.is_team_admin    := false;
    NEW.is_team_moderator := true;
  ELSIF NEW.team_role = 'support' THEN
    NEW.team_rank        := 65;
    NEW.is_team_admin    := false;
    NEW.is_team_moderator := false;
  ELSIF NEW.team_role = 'community_manager' THEN
    NEW.team_rank        := 60;
    NEW.is_team_admin    := false;
    NEW.is_team_moderator := false;
  ELSIF NEW.team_role = 'bug_bounty' THEN
    NEW.team_rank        := 50;
    NEW.is_team_admin    := false;
    NEW.is_team_moderator := false;
  ELSE
    NEW.team_rank        := 0;
    NEW.is_team_admin    := false;
    NEW.is_team_moderator := false;
  END IF;
  RETURN NEW;
END;
$$;

-- Recriar o trigger caso não exista
DROP TRIGGER IF EXISTS trg_sync_team_rank ON profiles;
CREATE TRIGGER trg_sync_team_rank
  BEFORE INSERT OR UPDATE OF team_role ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_team_rank();

-- Sincronizar todos os perfis existentes com team_role definido
UPDATE profiles
SET team_role = team_role
WHERE team_role IS NOT NULL AND team_role != 'none';

-- Verificar resultado
SELECT id, nickname, team_role, team_rank, is_team_admin, is_team_moderator
FROM profiles
WHERE team_rank > 0 OR is_team_admin = true OR is_team_moderator = true
ORDER BY team_rank DESC
LIMIT 10;
