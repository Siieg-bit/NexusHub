-- Migration 143: RPC issue_strike — Sistema de Strikes com ban automático
--
-- Fluxo:
--   1. Valida permissão do moderador (agent, leader, curator, moderator)
--   2. Insere registro na tabela `strikes`
--   3. Incrementa `strike_count` em `community_members`
--   4. Registra no `moderation_logs`
--   5. Se strike_count >= 3: aplica ban de 30 dias automaticamente
--   6. Retorna JSONB com resultado, strike_count atual e se houve auto-ban

CREATE OR REPLACE FUNCTION public.issue_strike(
  p_community_id  UUID,
  p_target_id     UUID,
  p_reason        TEXT,
  p_expires_days  INT DEFAULT 90  -- strikes expiram em 90 dias por padrão
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_moderator_id   UUID := auth.uid();
  v_moderator_role TEXT;
  v_target_role    TEXT;
  v_strike_count   INT;
  v_auto_banned    BOOLEAN := FALSE;
  v_expires_at     TIMESTAMPTZ;
  v_ban_expires    TIMESTAMPTZ;
BEGIN
  -- 1. Autenticação
  IF v_moderator_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- 2. Verificar papel do moderador na comunidade
  SELECT role INTO v_moderator_role
  FROM public.community_members
  WHERE community_id = p_community_id
    AND user_id = v_moderator_id;

  IF v_moderator_role IS NULL OR v_moderator_role NOT IN ('agent', 'leader', 'curator', 'moderator') THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  -- 3. Verificar papel do alvo (não pode aplicar strike em agent/leader se for curator/moderator)
  SELECT role INTO v_target_role
  FROM public.community_members
  WHERE community_id = p_community_id
    AND user_id = p_target_id;

  IF v_target_role IS NULL THEN
    RAISE EXCEPTION 'target_not_member';
  END IF;

  IF v_target_role IN ('agent', 'leader') AND v_moderator_role NOT IN ('agent', 'leader') THEN
    RAISE EXCEPTION 'cannot_strike_higher_role';
  END IF;

  -- 4. Calcular expiração do strike
  v_expires_at := NOW() + (p_expires_days || ' days')::INTERVAL;

  -- 5. Inserir strike
  INSERT INTO public.strikes (
    community_id,
    user_id,
    issued_by,
    reason,
    expires_at
  ) VALUES (
    p_community_id,
    p_target_id,
    v_moderator_id,
    p_reason,
    v_expires_at
  );

  -- 6. Incrementar strike_count e obter valor atual
  UPDATE public.community_members
  SET strike_count = COALESCE(strike_count, 0) + 1
  WHERE community_id = p_community_id
    AND user_id = p_target_id
  RETURNING strike_count INTO v_strike_count;

  -- 7. Registrar no log de moderação
  PERFORM public.log_moderation_action(
    p_community_id   => p_community_id,
    p_action         => 'strike',
    p_target_user_id => p_target_id,
    p_reason         => p_reason
  );

  -- 8. Ban automático ao atingir 3 strikes
  IF v_strike_count >= 3 THEN
    v_ban_expires := NOW() + INTERVAL '30 days';
    v_auto_banned := TRUE;

    -- Inserir ban de 30 dias
    INSERT INTO public.bans (
      community_id,
      user_id,
      banned_by,
      reason,
      is_permanent,
      expires_at
    ) VALUES (
      p_community_id,
      p_target_id,
      v_moderator_id,
      'Ban automático: 3 strikes acumulados. Motivo do último: ' || p_reason,
      FALSE,
      v_ban_expires
    )
    ON CONFLICT DO NOTHING;

    -- Registrar ban no log
    PERFORM public.log_moderation_action(
      p_community_id   => p_community_id,
      p_action         => 'ban',
      p_target_user_id => p_target_id,
      p_reason         => 'Ban automático por 3 strikes',
      p_duration_hours => 720  -- 30 dias
    );

    -- Resetar strike_count após ban automático
    UPDATE public.community_members
    SET strike_count = 0
    WHERE community_id = p_community_id
      AND user_id = p_target_id;
  END IF;

  RETURN jsonb_build_object(
    'success',       TRUE,
    'strike_count',  v_strike_count,
    'auto_banned',   v_auto_banned,
    'ban_expires_at', CASE WHEN v_auto_banned THEN v_ban_expires::TEXT ELSE NULL END
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.issue_strike TO authenticated;
