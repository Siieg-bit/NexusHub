-- ============================================================================
-- Migration 047: Corrigir daily_checkin para usar add_reputation corretamente
-- ============================================================================
-- PROBLEMA: A versão original de daily_checkin (migration 008) não usa
-- add_reputation(), soma +2 rep hardcoded sem cap diário, sem log no
-- reputation_log, e não retorna level_up/new_level.
--
-- CORREÇÃO: Reescrever daily_checkin para:
--   1. Usar add_reputation() com cap diário de 500
--   2. Registrar no reputation_log
--   3. Retornar level_up, new_level, reputation_earned
--   4. Manter streak bonus (7 dias +50, 30 dias +200)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.daily_checkin(p_community_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_streak INTEGER;
  v_coins_earned INTEGER;
  v_last_checkin TIMESTAMPTZ;
  v_today DATE := CURRENT_DATE;
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
    -- ================================================================
    -- CHECK-IN GLOBAL (sem comunidade)
    -- ================================================================
    SELECT last_checkin_at, consecutive_checkin_days INTO v_last_checkin, v_streak
    FROM public.profiles WHERE id = v_user_id;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = v_today THEN
      RETURN jsonb_build_object('error', 'already_checked_in');
    END IF;

    -- Calcular streak
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = v_today - 1 THEN
      v_streak := COALESCE(v_streak, 0) + 1;
    ELSE
      v_streak := 1;
    END IF;

    -- Recompensas de moedas baseadas no streak
    v_coins_earned := LEAST(5 + v_streak, 25);

    -- Atualizar perfil
    UPDATE public.profiles
    SET consecutive_checkin_days = v_streak,
        last_checkin_at = NOW(),
        coins = coins + v_coins_earned,
        coins_float = coins_float + v_coins_earned
    WHERE id = v_user_id;

    -- Registrar check-in
    INSERT INTO public.checkins (user_id, community_id, coins_earned, xp_earned, streak_day)
    VALUES (v_user_id, NULL, v_coins_earned, 10, v_streak);

    -- Registrar transação de moedas
    INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, description)
    VALUES (v_user_id, v_coins_earned,
      (SELECT coins FROM public.profiles WHERE id = v_user_id),
      'checkin', 'Check-in diário (dia ' || v_streak || ')');

    RETURN jsonb_build_object(
      'success', TRUE,
      'streak', v_streak,
      'coins_earned', v_coins_earned,
      'reputation_earned', 0,
      'level_up', FALSE,
      'new_level', 0
    );

  ELSE
    -- ================================================================
    -- CHECK-IN NA COMUNIDADE (com reputação via add_reputation)
    -- ================================================================
    SELECT last_checkin_at, consecutive_checkin_days, COALESCE(local_level, 1)
    INTO v_last_checkin, v_streak, v_old_level
    FROM public.community_members
    WHERE community_id = p_community_id AND user_id = v_user_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('error', 'not_a_member');
    END IF;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = v_today THEN
      RETURN jsonb_build_object('error', 'already_checked_in');
    END IF;

    -- Calcular streak
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = v_today - 1 THEN
      v_streak := COALESCE(v_streak, 0) + 1;
    ELSE
      v_streak := 1;
    END IF;

    -- Recompensas de moedas
    v_coins_earned := LEAST(5 + v_streak, 25);

    -- Atualizar membership (streak, checkin flag, last_active)
    UPDATE public.community_members
    SET consecutive_checkin_days = v_streak,
        last_checkin_at = NOW(),
        has_checkin_today = TRUE,
        last_active_at = NOW()
    WHERE community_id = p_community_id AND user_id = v_user_id;

    -- Atualizar moedas no perfil global
    UPDATE public.profiles
    SET coins = coins + v_coins_earned,
        coins_float = coins_float + v_coins_earned
    WHERE id = v_user_id;

    -- ── Reputação via add_reputation (com cap diário e log) ──
    v_rep_result := public.add_reputation(
      v_user_id, p_community_id, 'check_in', 10, NULL
    );
    v_total_rep_earned := COALESCE((v_rep_result->>'amount_earned')::int, 0);
    v_level_up := COALESCE((v_rep_result->>'level_up')::boolean, FALSE);
    v_new_level := COALESCE((v_rep_result->>'level')::int, v_old_level);

    -- ── Streak bonus ──
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

    -- Registrar check-in
    INSERT INTO public.checkins (user_id, community_id, coins_earned, xp_earned, streak_day)
    VALUES (v_user_id, p_community_id, v_coins_earned, v_total_rep_earned, v_streak);

    -- Registrar transação de moedas
    INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, description)
    VALUES (v_user_id, v_coins_earned,
      (SELECT coins FROM public.profiles WHERE id = v_user_id),
      'checkin', 'Check-in diário (dia ' || v_streak || ')');

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
