-- ============================================================
-- Migração 129: Acúmulo de minutos online via trigger
-- ============================================================
-- Objetivo: Sempre que o presence_service fizer heartbeat
-- (UPDATE em profiles.last_seen_at), acumular 15 minutos em
-- online_minutes_today, online_minutes_week e online_minutes_total.
-- Reset diário de online_minutes_today via comparação de data.
-- ============================================================

-- 1. Garantir que as colunas existem em profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS online_minutes_today   INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS online_minutes_total   INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS online_minutes_week    INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_online_reset_at   DATE;

-- 2. Garantir que as colunas existem em community_members
ALTER TABLE community_members
  ADD COLUMN IF NOT EXISTS online_minutes_total   INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS online_minutes_week    INTEGER NOT NULL DEFAULT 0;

-- 3. Trigger: acumular minutos online ao atualizar last_seen_at
CREATE OR REPLACE FUNCTION accumulate_online_minutes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today         DATE := CURRENT_DATE;
  v_last_reset    DATE;
  v_prev_seen     TIMESTAMPTZ;
  v_elapsed_min   INTEGER;
  v_heartbeat_min INTEGER := 15; -- janela do heartbeat em minutos
BEGIN
  -- Só processar quando last_seen_at muda e online_status = 1 (online)
  IF NEW.last_seen_at IS NOT DISTINCT FROM OLD.last_seen_at THEN
    RETURN NEW;
  END IF;
  IF NEW.online_status != 1 THEN
    RETURN NEW;
  END IF;

  v_last_reset := NEW.last_online_reset_at;
  v_prev_seen  := OLD.last_seen_at;

  -- Reset diário de online_minutes_today
  IF v_last_reset IS NULL OR v_last_reset < v_today THEN
    NEW.online_minutes_today  := 0;
    NEW.last_online_reset_at  := v_today;
    -- Reset semanal (segunda-feira)
    IF EXTRACT(DOW FROM v_today) = 1 THEN
      NEW.online_minutes_week := 0;
    END IF;
  END IF;

  -- Calcular minutos desde o último heartbeat
  IF v_prev_seen IS NOT NULL THEN
    v_elapsed_min := EXTRACT(EPOCH FROM (NEW.last_seen_at - v_prev_seen))::INTEGER / 60;
    -- Só acumular se o intervalo for razoável (entre 1 e 20 min)
    -- Evita acumular horas se o app ficou fechado por muito tempo
    IF v_elapsed_min BETWEEN 1 AND 20 THEN
      NEW.online_minutes_today := NEW.online_minutes_today + v_elapsed_min;
      NEW.online_minutes_week  := NEW.online_minutes_week  + v_elapsed_min;
      NEW.online_minutes_total := NEW.online_minutes_total + v_elapsed_min;
    ELSIF v_prev_seen IS NULL THEN
      -- Primeiro heartbeat do dia: acumular 1 minuto simbólico
      NEW.online_minutes_today := NEW.online_minutes_today + 1;
      NEW.online_minutes_week  := NEW.online_minutes_week  + 1;
      NEW.online_minutes_total := NEW.online_minutes_total + 1;
    END IF;
  ELSE
    -- Sem histórico: acumular 1 minuto simbólico
    NEW.online_minutes_today := NEW.online_minutes_today + 1;
    NEW.online_minutes_week  := NEW.online_minutes_week  + 1;
    NEW.online_minutes_total := NEW.online_minutes_total + 1;
  END IF;

  RETURN NEW;
END;
$$;

-- Remover trigger antigo se existir
DROP TRIGGER IF EXISTS trg_accumulate_online_minutes ON profiles;

CREATE TRIGGER trg_accumulate_online_minutes
  BEFORE UPDATE OF last_seen_at ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION accumulate_online_minutes();

-- 4. Trigger: propagar online_minutes para community_members
-- Quando o usuário está online, atualiza o membro ativo da comunidade
-- (a comunidade "atual" é determinada pelo contexto — não temos essa info
-- no trigger de profiles, então fazemos via RPC chamada pelo cliente)

-- 5. RPC para o cliente propagar minutos para community_members
CREATE OR REPLACE FUNCTION sync_online_minutes_to_community(
  p_community_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_today_min INTEGER;
  v_total_min INTEGER;
  v_week_min  INTEGER;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  -- Buscar minutos do perfil global
  SELECT online_minutes_today, online_minutes_total, online_minutes_week
  INTO v_today_min, v_total_min, v_week_min
  FROM profiles
  WHERE id = v_user_id;

  -- Atualizar community_members
  UPDATE community_members
  SET
    online_minutes_total = COALESCE(v_total_min, 0),
    online_minutes_week  = COALESCE(v_week_min, 0),
    last_active_at       = NOW()
  WHERE user_id = v_user_id
    AND community_id = p_community_id;
END;
$$;

GRANT EXECUTE ON FUNCTION sync_online_minutes_to_community(UUID) TO authenticated;

-- 6. RPC para leaderboard por tempo online (semana)
CREATE OR REPLACE FUNCTION get_community_leaderboard_by_online_time(
  p_community_id UUID,
  p_limit        INTEGER DEFAULT 50
)
RETURNS TABLE (
  user_id            UUID,
  nickname           TEXT,
  icon_url           TEXT,
  local_nickname     TEXT,
  local_icon_url     TEXT,
  online_minutes     INTEGER,
  online_minutes_week INTEGER,
  rank               BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cm.user_id,
    p.nickname,
    p.icon_url,
    cm.local_nickname,
    cm.local_icon_url,
    cm.online_minutes_total AS online_minutes,
    cm.online_minutes_week,
    ROW_NUMBER() OVER (ORDER BY cm.online_minutes_total DESC) AS rank
  FROM community_members cm
  JOIN profiles p ON p.id = cm.user_id
  WHERE cm.community_id = p_community_id
    AND cm.is_banned = FALSE
  ORDER BY cm.online_minutes_total DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_community_leaderboard_by_online_time(UUID, INTEGER) TO authenticated;
