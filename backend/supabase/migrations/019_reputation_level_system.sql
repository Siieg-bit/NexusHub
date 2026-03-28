-- ============================================================================
-- MIGRATION 019: SISTEMA UNIFICADO DE NÍVEIS / REPUTAÇÃO
-- ============================================================================
-- Nível 1 a 20. Baseado em reputação acumulada (local_reputation).
-- Máximo 500 reputação por dia por comunidade.
-- Nível 20 requer 365.000 rep (~2 anos a 500/dia).
--
-- Curva progressiva: rep_for_level(n) = floor(365000 * ((n-1)/19)^1.8)
-- ============================================================================

-- 1. Tabela de log de reputação (auditoria + controle diário)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.reputation_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  
  -- Tipo de ação que gerou reputação
  action_type TEXT NOT NULL,  -- 'check_in', 'create_post', 'create_poll', 'comment',
                               -- 'receive_like_post', 'receive_like_comment', 'wall_comment',
                               -- 'join_chat', 'send_message', 'follow_user', 'complete_quiz',
                               -- 'streak_bonus_7', 'streak_bonus_30'
  
  -- Referência opcional ao objeto que gerou a rep
  reference_id UUID,           -- ID do post, comentário, chat, etc.
  
  -- Quantidade de reputação ganha (já com cap aplicado)
  amount INTEGER NOT NULL DEFAULT 0,
  
  -- Reputação que seria ganha sem o cap (para debug)
  raw_amount INTEGER NOT NULL DEFAULT 0,
  
  -- Data (para controle do limite diário)
  earned_date DATE NOT NULL DEFAULT CURRENT_DATE,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reputation_log_user_community ON public.reputation_log(user_id, community_id);
CREATE INDEX idx_reputation_log_user_date ON public.reputation_log(user_id, community_id, earned_date);
CREATE INDEX idx_reputation_log_action ON public.reputation_log(action_type);

-- 2. Adicionar coluna de controle diário no community_members
-- ============================================================================
ALTER TABLE public.community_members
  ADD COLUMN IF NOT EXISTS reputation_earned_today INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reputation_today_date DATE DEFAULT CURRENT_DATE;

-- 3. Função: Calcular nível baseado em reputação
-- ============================================================================
CREATE OR REPLACE FUNCTION public.calculate_level(rep INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  thresholds INTEGER[] := ARRAY[
    0, 1800, 6300, 13000, 22000, 33000, 46000, 60500,
    77000, 95000, 115000, 136500, 159500, 184500, 210500,
    238500, 268000, 299000, 331000, 365000
  ];
  lvl INTEGER := 1;
BEGIN
  IF rep IS NULL OR rep <= 0 THEN
    RETURN 1;
  END IF;
  
  FOR i IN REVERSE 20..1 LOOP
    IF rep >= thresholds[i] THEN
      RETURN i;
    END IF;
  END LOOP;
  
  RETURN 1;
END;
$$;

-- 4. Função: Reputação ganha hoje por um membro numa comunidade
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_reputation_earned_today(
  p_user_id UUID,
  p_community_id UUID
)
RETURNS INTEGER
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  earned INTEGER;
BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO earned
  FROM public.reputation_log
  WHERE user_id = p_user_id
    AND community_id = p_community_id
    AND earned_date = CURRENT_DATE;
  
  RETURN earned;
END;
$$;

-- 5. Função principal: Adicionar reputação com limite diário
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_reputation(
  p_user_id UUID,
  p_community_id UUID,
  p_action_type TEXT,
  p_raw_amount INTEGER,
  p_reference_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_max_daily INTEGER := 500;
  v_earned_today INTEGER;
  v_effective_amount INTEGER;
  v_new_reputation INTEGER;
  v_new_level INTEGER;
  v_old_level INTEGER;
  v_member RECORD;
BEGIN
  -- Buscar membro
  SELECT * INTO v_member
  FROM public.community_members
  WHERE user_id = p_user_id AND community_id = p_community_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Membro não encontrado na comunidade'
    );
  END IF;
  
  -- Resetar contador diário se mudou o dia
  IF v_member.reputation_today_date IS NULL OR v_member.reputation_today_date < CURRENT_DATE THEN
    UPDATE public.community_members
    SET reputation_earned_today = 0,
        reputation_today_date = CURRENT_DATE
    WHERE user_id = p_user_id AND community_id = p_community_id;
    
    v_earned_today := 0;
  ELSE
    v_earned_today := COALESCE(v_member.reputation_earned_today, 0);
  END IF;
  
  -- Calcular quantidade efetiva (com cap diário)
  IF v_earned_today >= v_max_daily THEN
    v_effective_amount := 0;
  ELSE
    v_effective_amount := LEAST(p_raw_amount, v_max_daily - v_earned_today);
  END IF;
  
  -- Registrar no log (mesmo se 0, para auditoria)
  INSERT INTO public.reputation_log (
    user_id, community_id, action_type, amount, raw_amount, reference_id, earned_date
  ) VALUES (
    p_user_id, p_community_id, p_action_type, v_effective_amount, p_raw_amount, p_reference_id, CURRENT_DATE
  );
  
  -- Se não ganhou nada, retornar
  IF v_effective_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'amount_earned', 0,
      'daily_remaining', 0,
      'capped', true,
      'reputation', v_member.local_reputation,
      'level', v_member.local_level
    );
  END IF;
  
  -- Guardar nível antigo
  v_old_level := COALESCE(v_member.local_level, 1);
  
  -- Atualizar reputação e nível
  v_new_reputation := COALESCE(v_member.local_reputation, 0) + v_effective_amount;
  v_new_level := public.calculate_level(v_new_reputation);
  
  UPDATE public.community_members
  SET local_reputation = v_new_reputation,
      local_level = v_new_level,
      reputation_earned_today = COALESCE(reputation_earned_today, 0) + v_effective_amount,
      reputation_today_date = CURRENT_DATE,
      last_active_at = NOW()
  WHERE user_id = p_user_id AND community_id = p_community_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'amount_earned', v_effective_amount,
    'daily_remaining', v_max_daily - (v_earned_today + v_effective_amount),
    'capped', false,
    'reputation', v_new_reputation,
    'level', v_new_level,
    'level_up', v_new_level > v_old_level,
    'old_level', v_old_level
  );
END;
$$;

-- 6. Função: Check-in com reputação
-- ============================================================================
CREATE OR REPLACE FUNCTION public.perform_checkin(
  p_user_id UUID,
  p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_member RECORD;
  v_streak INTEGER;
  v_rep_result JSONB;
  v_streak_bonus_result JSONB;
  v_total_earned INTEGER := 0;
BEGIN
  -- Buscar membro
  SELECT * INTO v_member
  FROM public.community_members
  WHERE user_id = p_user_id AND community_id = p_community_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Não é membro');
  END IF;
  
  -- Verificar se já fez check-in hoje
  IF v_member.has_checkin_today = TRUE AND
     v_member.last_checkin_at IS NOT NULL AND
     v_member.last_checkin_at::date = CURRENT_DATE THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Já fez check-in hoje',
      'streak', v_member.consecutive_checkin_days
    );
  END IF;
  
  -- Calcular streak
  IF v_member.last_checkin_at IS NOT NULL AND
     v_member.last_checkin_at::date = CURRENT_DATE - INTERVAL '1 day' THEN
    v_streak := COALESCE(v_member.consecutive_checkin_days, 0) + 1;
  ELSE
    v_streak := 1;
  END IF;
  
  -- Atualizar check-in
  UPDATE public.community_members
  SET has_checkin_today = TRUE,
      last_checkin_at = NOW(),
      consecutive_checkin_days = v_streak
  WHERE user_id = p_user_id AND community_id = p_community_id;
  
  -- Dar reputação pelo check-in (10 rep)
  v_rep_result := public.add_reputation(p_user_id, p_community_id, 'check_in', 10);
  v_total_earned := v_total_earned + COALESCE((v_rep_result->>'amount_earned')::int, 0);
  
  -- Bonus de streak de 7 dias
  IF v_streak > 0 AND v_streak % 7 = 0 THEN
    v_streak_bonus_result := public.add_reputation(p_user_id, p_community_id, 'streak_bonus_7', 50);
    v_total_earned := v_total_earned + COALESCE((v_streak_bonus_result->>'amount_earned')::int, 0);
  END IF;
  
  -- Bonus de streak de 30 dias
  IF v_streak > 0 AND v_streak % 30 = 0 THEN
    v_streak_bonus_result := public.add_reputation(p_user_id, p_community_id, 'streak_bonus_30', 200);
    v_total_earned := v_total_earned + COALESCE((v_streak_bonus_result->>'amount_earned')::int, 0);
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'streak', v_streak,
    'reputation_earned', v_total_earned,
    'reputation', (v_rep_result->>'reputation')::int,
    'level', (v_rep_result->>'level')::int,
    'level_up', COALESCE((v_rep_result->>'level_up')::boolean, false)
  );
END;
$$;

-- 7. Trigger: Resetar has_checkin_today à meia-noite (via cron ou manual)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reset_daily_checkins()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.community_members
  SET has_checkin_today = FALSE,
      reputation_earned_today = 0,
      reputation_today_date = CURRENT_DATE
  WHERE has_checkin_today = TRUE
    AND (last_checkin_at IS NULL OR last_checkin_at::date < CURRENT_DATE);
END;
$$;

-- 8. Trigger: Auto-calcular nível quando reputação muda
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trigger_recalculate_level()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.local_reputation IS DISTINCT FROM OLD.local_reputation THEN
    NEW.local_level := public.calculate_level(NEW.local_reputation);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_recalculate_level ON public.community_members;
CREATE TRIGGER trg_recalculate_level
  BEFORE UPDATE ON public.community_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_recalculate_level();

-- 9. Corrigir leaderboard para usar o novo sistema
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
  p_community_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  user_id UUID,
  nickname TEXT,
  icon_url TEXT,
  level INTEGER,
  reputation INTEGER,
  role TEXT
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cm.user_id,
    COALESCE(cm.local_nickname, p.nickname) AS nickname,
    COALESCE(cm.local_icon_url, p.icon_url) AS icon_url,
    COALESCE(cm.local_level, public.calculate_level(cm.local_reputation)) AS level,
    COALESCE(cm.local_reputation, 0) AS reputation,
    cm.role::text AS role
  FROM public.community_members cm
  JOIN public.profiles p ON p.id = cm.user_id
  WHERE cm.community_id = p_community_id
    AND cm.is_banned = FALSE
  ORDER BY cm.local_reputation DESC NULLS LAST
  LIMIT p_limit;
END;
$$;

-- 10. Função: Obter estatísticas de reputação de um membro
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_member_reputation_stats(
  p_user_id UUID,
  p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_member RECORD;
  v_earned_today INTEGER;
  v_total_actions INTEGER;
  v_level INTEGER;
  v_next_level_rep INTEGER;
  v_thresholds INTEGER[] := ARRAY[
    0, 1800, 6300, 13000, 22000, 33000, 46000, 60500,
    77000, 95000, 115000, 136500, 159500, 184500, 210500,
    238500, 268000, 299000, 331000, 365000
  ];
BEGIN
  SELECT * INTO v_member
  FROM public.community_members
  WHERE user_id = p_user_id AND community_id = p_community_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Membro não encontrado');
  END IF;
  
  v_earned_today := public.get_reputation_earned_today(p_user_id, p_community_id);
  v_level := public.calculate_level(COALESCE(v_member.local_reputation, 0));
  
  IF v_level >= 20 THEN
    v_next_level_rep := 365000;
  ELSE
    v_next_level_rep := v_thresholds[v_level + 1];
  END IF;
  
  SELECT COUNT(*) INTO v_total_actions
  FROM public.reputation_log
  WHERE user_id = p_user_id AND community_id = p_community_id;
  
  RETURN jsonb_build_object(
    'reputation', COALESCE(v_member.local_reputation, 0),
    'level', v_level,
    'next_level_reputation', v_next_level_rep,
    'reputation_to_next_level', GREATEST(0, v_next_level_rep - COALESCE(v_member.local_reputation, 0)),
    'progress', CASE
      WHEN v_level >= 20 THEN 1.0
      ELSE LEAST(1.0, (COALESCE(v_member.local_reputation, 0) - v_thresholds[v_level])::float / NULLIF(v_thresholds[v_level + 1] - v_thresholds[v_level], 0))
    END,
    'earned_today', v_earned_today,
    'daily_remaining', GREATEST(0, 500 - v_earned_today),
    'daily_cap', 500,
    'streak', COALESCE(v_member.consecutive_checkin_days, 0),
    'total_actions', v_total_actions,
    'has_checkin_today', COALESCE(v_member.has_checkin_today, false)
  );
END;
$$;

-- 11. Atualizar todos os membros existentes: recalcular nível baseado na reputação atual
-- ============================================================================
UPDATE public.community_members
SET local_level = public.calculate_level(COALESCE(local_reputation, 0))
WHERE local_level IS DISTINCT FROM public.calculate_level(COALESCE(local_reputation, 0));

-- 12. RLS para reputation_log
-- ============================================================================
ALTER TABLE public.reputation_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own reputation log"
  ON public.reputation_log FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert reputation log"
  ON public.reputation_log FOR INSERT
  WITH CHECK (true);
