-- =============================================================================
-- Migration 240 — Corrigir daily_checkin para usar moedas do Remote Config
--
-- Problema: a função daily_checkin usava LEAST(5 + v_streak, 25) hardcoded
-- para calcular as moedas do check-in, ignorando os valores do Remote Config.
--
-- Solução: ler coins_per_checkin e coins_checkin_max da tabela app_remote_config
-- com fallbacks para os valores anteriores (5 e 25).
--
-- Também corrige os valores hardcoded de reputação (10, 50, 200) que eram
-- passados diretamente para add_reputation, usando os valores do Remote Config.
-- =============================================================================

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
  -- Valores do Remote Config (com fallbacks)
  v_coins_base INTEGER;
  v_coins_max INTEGER;
  v_rep_checkin INTEGER;
  v_rep_streak7 INTEGER;
  v_rep_streak30 INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- ── Carregar valores do Remote Config ──────────────────────────────────────
  SELECT COALESCE((value::TEXT)::INTEGER, 5)   INTO v_coins_base
  FROM public.app_remote_config WHERE key = 'gamification.coins_per_checkin' LIMIT 1;
  IF v_coins_base IS NULL THEN v_coins_base := 5; END IF;

  SELECT COALESCE((value::TEXT)::INTEGER, 25)  INTO v_coins_max
  FROM public.app_remote_config WHERE key = 'gamification.coins_checkin_max' LIMIT 1;
  IF v_coins_max IS NULL THEN v_coins_max := 25; END IF;

  SELECT COALESCE((value::TEXT)::INTEGER, 10)  INTO v_rep_checkin
  FROM public.app_remote_config WHERE key = 'gamification.rep_per_checkin' LIMIT 1;
  IF v_rep_checkin IS NULL THEN v_rep_checkin := 10; END IF;

  SELECT COALESCE((value::TEXT)::INTEGER, 50)  INTO v_rep_streak7
  FROM public.app_remote_config WHERE key = 'gamification.rep_streak_7' LIMIT 1;
  IF v_rep_streak7 IS NULL THEN v_rep_streak7 := 50; END IF;

  SELECT COALESCE((value::TEXT)::INTEGER, 200) INTO v_rep_streak30
  FROM public.app_remote_config WHERE key = 'gamification.rep_streak_30' LIMIT 1;
  IF v_rep_streak30 IS NULL THEN v_rep_streak30 := 200; END IF;

  -- ── Check-in GLOBAL (sem comunidade) ───────────────────────────────────────
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

    -- Calcular moedas com valores dinâmicos
    v_coins_earned := LEAST(v_coins_base + v_streak, v_coins_max);

    UPDATE public.profiles
    SET consecutive_checkin_days = v_streak,
        last_checkin_at = now(),
        coins = coins + v_coins_earned,
        coins_float = coins_float + v_coins_earned
    WHERE id = v_user_id;

    INSERT INTO public.checkins (user_id, community_id, coins_earned, xp_earned, streak_day)
    VALUES (v_user_id, NULL, v_coins_earned, 0, v_streak);

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

  -- ── Check-in em COMUNIDADE ──────────────────────────────────────────────────
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

    -- Calcular moedas com valores dinâmicos
    v_coins_earned := LEAST(v_coins_base + v_streak, v_coins_max);

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

    -- Reputação pelo check-in (valor dinâmico)
    v_rep_result := public.add_reputation(
      v_user_id, p_community_id, 'check_in', v_rep_checkin, NULL
    );
    v_total_rep_earned := COALESCE((v_rep_result->>'amount_earned')::int, 0);
    v_level_up := COALESCE((v_rep_result->>'level_up')::boolean, FALSE);
    v_new_level := COALESCE((v_rep_result->>'level')::int, v_old_level);

    -- Bônus de streak (valores dinâmicos)
    IF v_streak > 0 AND v_streak % 30 = 0 THEN
      v_streak_bonus_result := public.add_reputation(
        v_user_id, p_community_id, 'streak_bonus_30', v_rep_streak30, NULL
      );
      v_total_rep_earned := v_total_rep_earned +
        COALESCE((v_streak_bonus_result->>'amount_earned')::int, 0);
      IF NOT v_level_up THEN
        v_level_up := COALESCE((v_streak_bonus_result->>'level_up')::boolean, FALSE);
      END IF;
      v_new_level := COALESCE((v_streak_bonus_result->>'level')::int, v_new_level);
    ELSIF v_streak > 0 AND v_streak % 7 = 0 THEN
      v_streak_bonus_result := public.add_reputation(
        v_user_id, p_community_id, 'streak_bonus_7', v_rep_streak7, NULL
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.daily_checkin(UUID) TO authenticated;
