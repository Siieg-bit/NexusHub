-- =============================================================================
-- Migration 239 — Regras de Gamificação no Remote Config
--
-- Adiciona as regras de gamificação à tabela app_remote_config e atualiza
-- as RPCs para ler os valores dinamicamente do banco em vez de usar
-- constantes hardcoded no SQL.
--
-- Valores migrados:
--   - gamification.level_thresholds    → tabela de XP por nível (20 níveis)
--   - gamification.max_daily_rep       → limite diário de reputação
--   - gamification.rep_per_checkin     → reputação por check-in
--   - gamification.rep_per_post        → reputação por post
--   - gamification.rep_per_comment     → reputação por comentário
--   - gamification.rep_per_like        → reputação por like recebido
--   - gamification.rep_streak_7        → bônus de streak 7 dias
--   - gamification.rep_streak_30       → bônus de streak 30 dias
--   - gamification.coins_per_checkin   → moedas por check-in (base)
--   - gamification.coins_checkin_max   → máximo de moedas por check-in
-- =============================================================================

-- ── Inserir regras de gamificação no Remote Config ────────────────────────────
INSERT INTO public.app_remote_config (key, value, category, description)
VALUES
  ('gamification.level_thresholds',
   '[0, 1800, 6300, 13000, 22000, 33000, 46000, 60500, 77000, 95000, 115000, 136500, 159500, 184500, 210500, 238500, 268000, 299000, 331000, 365000]',
   'gamification',
   'XP necessário para cada nível (índice 0 = nível 1, índice 19 = nível 20)'),

  ('gamification.max_daily_rep',      '500',  'gamification', 'Máximo de reputação que pode ser ganha por dia por comunidade'),
  ('gamification.rep_per_checkin',    '10',   'gamification', 'Reputação ganha por check-in diário'),
  ('gamification.rep_per_post',       '15',   'gamification', 'Reputação ganha por criar um post'),
  ('gamification.rep_per_comment',    '3',    'gamification', 'Reputação ganha por comentar'),
  ('gamification.rep_per_like',       '2',    'gamification', 'Reputação ganha por receber um like'),
  ('gamification.rep_per_wall',       '2',    'gamification', 'Reputação ganha por escrever no mural'),
  ('gamification.rep_per_chat_msg',   '1',    'gamification', 'Reputação ganha por enviar mensagem no chat'),
  ('gamification.rep_per_follow',     '1',    'gamification', 'Reputação ganha por seguir alguém'),
  ('gamification.rep_per_quiz',       '5',    'gamification', 'Reputação ganha por completar um quiz'),
  ('gamification.rep_streak_7',       '50',   'gamification', 'Bônus de reputação por streak de 7 dias'),
  ('gamification.rep_streak_30',      '200',  'gamification', 'Bônus de reputação por streak de 30 dias'),
  ('gamification.coins_per_checkin',  '5',    'gamification', 'Moedas base por check-in diário'),
  ('gamification.coins_checkin_max',  '25',   'gamification', 'Máximo de moedas por check-in (com streak)')

ON CONFLICT (key) DO UPDATE SET
  value       = EXCLUDED.value,
  category    = EXCLUDED.category,
  description = EXCLUDED.description;

-- =============================================================================
-- Atualizar a função calculate_level para ler thresholds do Remote Config
--
-- Estratégia: a função tenta ler de app_remote_config. Se não encontrar,
-- usa os valores hardcoded como fallback (garantia de não quebrar).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.calculate_level(rep INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  thresholds INTEGER[];
  raw_value  JSONB;
  lvl        INTEGER := 1;
  i          INTEGER;
BEGIN
  IF rep IS NULL OR rep <= 0 THEN
    RETURN 1;
  END IF;

  -- Tentar carregar thresholds do Remote Config
  SELECT value INTO raw_value
  FROM public.app_remote_config
  WHERE key = 'gamification.level_thresholds'
  LIMIT 1;

  IF raw_value IS NOT NULL THEN
    SELECT ARRAY(SELECT jsonb_array_elements_text(raw_value)::INTEGER)
    INTO thresholds;
  ELSE
    -- Fallback hardcoded
    thresholds := ARRAY[
      0, 1800, 6300, 13000, 22000, 33000, 46000, 60500,
      77000, 95000, 115000, 136500, 159500, 184500, 210500,
      238500, 268000, 299000, 331000, 365000
    ];
  END IF;

  FOR i IN REVERSE array_length(thresholds, 1)..1 LOOP
    IF rep >= thresholds[i] THEN
      RETURN i;
    END IF;
  END LOOP;

  RETURN 1;
END;
$$;

-- =============================================================================
-- Atualizar a função add_reputation para ler max_daily do Remote Config
-- =============================================================================

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
  v_max_daily INTEGER;
  v_earned_today INTEGER;
  v_effective_amount INTEGER;
  v_new_reputation INTEGER;
  v_new_level INTEGER;
  v_old_level INTEGER;
  v_member RECORD;
BEGIN
  -- Carregar max_daily do Remote Config (fallback: 500)
  SELECT COALESCE((value::TEXT)::INTEGER, 500) INTO v_max_daily
  FROM public.app_remote_config
  WHERE key = 'gamification.max_daily_rep'
  LIMIT 1;

  IF v_max_daily IS NULL THEN
    v_max_daily := 500;
  END IF;

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

  v_old_level := COALESCE(v_member.local_level, 1);
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

-- =============================================================================
-- Atualizar perform_checkin para ler recompensas do Remote Config
-- =============================================================================

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
  v_rep_checkin INTEGER;
  v_rep_streak7 INTEGER;
  v_rep_streak30 INTEGER;
BEGIN
  -- Carregar recompensas do Remote Config (com fallbacks)
  SELECT COALESCE((value::TEXT)::INTEGER, 10) INTO v_rep_checkin
  FROM public.app_remote_config WHERE key = 'gamification.rep_per_checkin' LIMIT 1;
  IF v_rep_checkin IS NULL THEN v_rep_checkin := 10; END IF;

  SELECT COALESCE((value::TEXT)::INTEGER, 50) INTO v_rep_streak7
  FROM public.app_remote_config WHERE key = 'gamification.rep_streak_7' LIMIT 1;
  IF v_rep_streak7 IS NULL THEN v_rep_streak7 := 50; END IF;

  SELECT COALESCE((value::TEXT)::INTEGER, 200) INTO v_rep_streak30
  FROM public.app_remote_config WHERE key = 'gamification.rep_streak_30' LIMIT 1;
  IF v_rep_streak30 IS NULL THEN v_rep_streak30 := 200; END IF;

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

  -- Dar reputação pelo check-in
  v_rep_result := public.add_reputation(p_user_id, p_community_id, 'check_in', v_rep_checkin);
  v_total_earned := v_total_earned + COALESCE((v_rep_result->>'amount_earned')::int, 0);

  -- Bônus de streak de 7 dias
  IF v_streak > 0 AND v_streak % 7 = 0 THEN
    v_streak_bonus_result := public.add_reputation(p_user_id, p_community_id, 'streak_bonus_7', v_rep_streak7);
    v_total_earned := v_total_earned + COALESCE((v_streak_bonus_result->>'amount_earned')::int, 0);
  END IF;

  -- Bônus de streak de 30 dias
  IF v_streak > 0 AND v_streak % 30 = 0 THEN
    v_streak_bonus_result := public.add_reputation(p_user_id, p_community_id, 'streak_bonus_30', v_rep_streak30);
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

GRANT EXECUTE ON FUNCTION public.calculate_level(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_reputation(UUID, UUID, TEXT, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.perform_checkin(UUID, UUID) TO authenticated;
