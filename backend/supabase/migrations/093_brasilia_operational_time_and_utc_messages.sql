-- ============================================================================
-- Migration 093: Horário operacional de Brasília + mensagens em UTC
-- ============================================================================
-- Regras desta migration:
-- 1. Regras internas diárias (check-in, cap diário e reset) usam calendário de
--    Brasília de forma explícita, sem depender do timezone global do banco.
-- 2. Mensagens continuam armazenadas em TIMESTAMPTZ (UTC no transporte).
-- 3. O backend não deve pré-formatar horas de mensagens; apenas timestamps brutos.
-- ============================================================================

-- -----------------------------------------------------------------------------
-- 1. Helpers de calendário operacional
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.brasilia_now()
RETURNS timestamp
LANGUAGE sql
STABLE
AS $$
  SELECT timezone('America/Sao_Paulo', now());
$$;

CREATE OR REPLACE FUNCTION public.brasilia_today()
RETURNS date
LANGUAGE sql
STABLE
AS $$
  SELECT (timezone('America/Sao_Paulo', now()))::date;
$$;

COMMENT ON FUNCTION public.brasilia_now() IS
  'Retorna o timestamp atual no calendário operacional de Brasília (America/Sao_Paulo).';

COMMENT ON FUNCTION public.brasilia_today() IS
  'Retorna a data operacional atual de Brasília (America/Sao_Paulo).';

-- -----------------------------------------------------------------------------
-- 2. Reputação diária baseada em Brasília
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_reputation_earned_today(
  p_user_id UUID,
  p_community_id UUID
)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  earned INTEGER;
BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO earned
  FROM public.reputation_log
  WHERE user_id = p_user_id
    AND community_id = p_community_id
    AND earned_date = public.brasilia_today();

  RETURN earned;
END;
$$;

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
  v_brasilia_today DATE := public.brasilia_today();
BEGIN
  SELECT * INTO v_member
  FROM public.community_members
  WHERE user_id = p_user_id AND community_id = p_community_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Membro não encontrado na comunidade'
    );
  END IF;

  IF v_member.reputation_today_date IS NULL OR v_member.reputation_today_date < v_brasilia_today THEN
    UPDATE public.community_members
    SET reputation_earned_today = 0,
        reputation_today_date = v_brasilia_today
    WHERE user_id = p_user_id AND community_id = p_community_id;

    v_earned_today := 0;
  ELSE
    v_earned_today := COALESCE(v_member.reputation_earned_today, 0);
  END IF;

  IF v_earned_today >= v_max_daily THEN
    v_effective_amount := 0;
  ELSE
    v_effective_amount := LEAST(p_raw_amount, v_max_daily - v_earned_today);
  END IF;

  INSERT INTO public.reputation_log (
    user_id, community_id, action_type, amount, raw_amount, reference_id, earned_date
  ) VALUES (
    p_user_id,
    p_community_id,
    p_action_type,
    v_effective_amount,
    p_raw_amount,
    p_reference_id,
    v_brasilia_today
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
      reputation_today_date = v_brasilia_today,
      last_active_at = now()
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

CREATE OR REPLACE FUNCTION public.get_daily_reputation_status(
  p_community_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_earned_today INT;
  v_total_rep INT;
  v_level INT;
  v_result JSONB;
  v_brasilia_today DATE := public.brasilia_today();
BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO v_earned_today
  FROM public.reputation_log
  WHERE community_id = p_community_id
    AND user_id = p_user_id
    AND earned_date = v_brasilia_today;

  SELECT local_reputation, local_level INTO v_total_rep, v_level
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = p_user_id;

  v_result := jsonb_build_object(
    'earned_today', v_earned_today,
    'daily_limit', 500,
    'remaining_today', GREATEST(500 - v_earned_today, 0),
    'total_reputation', COALESCE(v_total_rep, 0),
    'level', COALESCE(v_level, 1)
  );

  RETURN v_result;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. Check-in diário baseado em meia-noite de Brasília
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.daily_checkin(p_community_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_streak INTEGER;
  v_coins_earned INTEGER;
  v_last_checkin TIMESTAMPTZ;
  v_today DATE := public.brasilia_today();
  v_rep_result JSONB;
  v_streak_bonus_result JSONB;
  v_total_rep_earned INTEGER := 0;
  v_level_up BOOLEAN := FALSE;
  v_new_level INTEGER;
  v_old_level INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  IF p_community_id IS NULL THEN
    SELECT last_checkin_at, consecutive_checkin_days INTO v_last_checkin, v_streak
    FROM public.profiles WHERE id = v_user_id;

    IF v_last_checkin IS NOT NULL AND timezone('America/Sao_Paulo', v_last_checkin)::date = v_today THEN
      RETURN jsonb_build_object('error', 'already_checked_in');
    END IF;

    IF v_last_checkin IS NOT NULL
       AND timezone('America/Sao_Paulo', v_last_checkin)::date = v_today - 1 THEN
      v_streak := COALESCE(v_streak, 0) + 1;
    ELSE
      v_streak := 1;
    END IF;

    v_coins_earned := LEAST(5 + v_streak, 25);

    UPDATE public.profiles
    SET consecutive_checkin_days = v_streak,
        last_checkin_at = now(),
        coins = coins + v_coins_earned,
        coins_float = coins_float + v_coins_earned
    WHERE id = v_user_id;

    INSERT INTO public.checkins (user_id, community_id, coins_earned, xp_earned, streak_day)
    VALUES (v_user_id, NULL, v_coins_earned, 10, v_streak);

    INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, description)
    VALUES (
      v_user_id,
      v_coins_earned,
      (SELECT coins FROM public.profiles WHERE id = v_user_id),
      'checkin',
      'Check-in diário (dia ' || v_streak || ')'
    );

    RETURN jsonb_build_object(
      'success', TRUE,
      'streak', v_streak,
      'coins_earned', v_coins_earned,
      'reputation_earned', 0,
      'level_up', FALSE,
      'new_level', 0
    );
  ELSE
    SELECT last_checkin_at, consecutive_checkin_days, COALESCE(local_level, 1)
    INTO v_last_checkin, v_streak, v_old_level
    FROM public.community_members
    WHERE community_id = p_community_id AND user_id = v_user_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('error', 'not_a_member');
    END IF;

    IF v_last_checkin IS NOT NULL AND timezone('America/Sao_Paulo', v_last_checkin)::date = v_today THEN
      RETURN jsonb_build_object('error', 'already_checked_in');
    END IF;

    IF v_last_checkin IS NOT NULL
       AND timezone('America/Sao_Paulo', v_last_checkin)::date = v_today - 1 THEN
      v_streak := COALESCE(v_streak, 0) + 1;
    ELSE
      v_streak := 1;
    END IF;

    v_coins_earned := LEAST(5 + v_streak, 25);

    UPDATE public.community_members
    SET consecutive_checkin_days = v_streak,
        last_checkin_at = now(),
        has_checkin_today = TRUE,
        last_active_at = now()
    WHERE community_id = p_community_id AND user_id = v_user_id;

    UPDATE public.profiles
    SET coins = coins + v_coins_earned,
        coins_float = coins_float + v_coins_earned
    WHERE id = v_user_id;

    v_rep_result := public.add_reputation(
      v_user_id, p_community_id, 'check_in', 10, NULL
    );
    v_total_rep_earned := COALESCE((v_rep_result->>'amount_earned')::int, 0);
    v_level_up := COALESCE((v_rep_result->>'level_up')::boolean, FALSE);
    v_new_level := COALESCE((v_rep_result->>'level')::int, v_old_level);

    IF v_streak > 0 AND v_streak % 30 = 0 THEN
      v_streak_bonus_result := public.add_reputation(
        v_user_id, p_community_id, 'streak_bonus_30', 200, NULL
      );
      v_total_rep_earned := v_total_rep_earned +
        COALESCE((v_streak_bonus_result->>'amount_earned')::int, 0);
      IF NOT v_level_up THEN
        v_level_up := COALESCE((v_streak_bonus_result->>'level_up')::boolean, FALSE);
      END IF;
      v_new_level := COALESCE((v_streak_bonus_result->>'level')::int, v_new_level);
    ELSIF v_streak > 0 AND v_streak % 7 = 0 THEN
      v_streak_bonus_result := public.add_reputation(
        v_user_id, p_community_id, 'streak_bonus_7', 50, NULL
      );
      v_total_rep_earned := v_total_rep_earned +
        COALESCE((v_streak_bonus_result->>'amount_earned')::int, 0);
      IF NOT v_level_up THEN
        v_level_up := COALESCE((v_streak_bonus_result->>'level_up')::boolean, FALSE);
      END IF;
      v_new_level := COALESCE((v_streak_bonus_result->>'level')::int, v_new_level);
    END IF;

    INSERT INTO public.checkins (user_id, community_id, coins_earned, xp_earned, streak_day)
    VALUES (v_user_id, p_community_id, v_coins_earned, v_total_rep_earned, v_streak);

    INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, description)
    VALUES (
      v_user_id,
      v_coins_earned,
      (SELECT coins FROM public.profiles WHERE id = v_user_id),
      'checkin',
      'Check-in diário (dia ' || v_streak || ')'
    );

    RETURN jsonb_build_object(
      'success', TRUE,
      'streak', v_streak,
      'coins_earned', v_coins_earned,
      'reputation_earned', v_total_rep_earned,
      'level_up', v_level_up,
      'new_level', v_new_level,
      'old_level', v_old_level
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.reset_daily_checkins()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_brasilia_today DATE := public.brasilia_today();
BEGIN
  UPDATE public.community_members
  SET has_checkin_today = FALSE,
      reputation_earned_today = 0,
      reputation_today_date = v_brasilia_today
  WHERE has_checkin_today = TRUE
    AND (
      last_checkin_at IS NULL
      OR timezone('America/Sao_Paulo', last_checkin_at)::date < v_brasilia_today
    );
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. Agendamento do reset à meia-noite de Brasília
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-checkin-reset-brasilia') THEN
        PERFORM cron.unschedule(jobid)
        FROM cron.job
        WHERE jobname = 'daily-checkin-reset-brasilia';
      END IF;

      PERFORM cron.schedule(
        'daily-checkin-reset-brasilia',
        '0 3 * * *',
        'SELECT public.reset_daily_checkins()'
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Não foi possível criar/atualizar o cron daily-checkin-reset-brasilia: %', SQLERRM;
    END;
  END IF;
END;
$$;
