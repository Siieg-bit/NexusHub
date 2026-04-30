-- =============================================================================
-- Migration 209: Corrigir hierarquia de moderação entre cargos
-- =============================================================================
--
-- Problema: Team members (is_team_moderator/is_team_admin) conseguem ser
-- moderados por outros team members. Além disso, a hierarquia entre cargos
-- da comunidade não estava sendo respeitada corretamente em todas as RPCs.
--
-- Hierarquia definida (do maior para o menor):
--   Nível 5: team_admin    (is_team_admin = TRUE)       → modera todos
--   Nível 4: team_mod      (is_team_moderator = TRUE)   → modera todos os cargos de comunidade
--   Nível 3: agent         (role = 'agent')              → Líder Fundador, modera leader e abaixo
--   Nível 2: leader        (role = 'leader')             → Líder normal, modera curator e abaixo
--   Nível 1: curator       (role = 'curator')            → modera apenas member
--   Nível 0: member        (role = 'member')             → sem poder de moderação
--
-- Regras:
--   - Ninguém pode moderar alguém do mesmo nível ou superior
--   - Team members (admin/mod) não podem ser moderados por cargos de comunidade
--   - agent não pode ser banido/moderado por ninguém dentro da comunidade
--   - leader só pode moderar curator e member
--   - curator só pode moderar member
-- =============================================================================

-- =============================================================================
-- FUNÇÃO AUXILIAR: get_moderation_rank
-- Retorna o nível hierárquico de um usuário para fins de moderação.
-- Considera tanto o role global (is_team_admin, is_team_moderator) quanto
-- o role local na comunidade.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_moderation_rank(
  p_user_id      UUID,
  p_community_id UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_team_admin     BOOLEAN := FALSE;
  v_is_team_moderator BOOLEAN := FALSE;
  v_community_role    TEXT    := 'member';
BEGIN
  -- Verificar flags globais
  SELECT is_team_admin, is_team_moderator
  INTO v_is_team_admin, v_is_team_moderator
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_is_team_admin THEN RETURN 5; END IF;
  IF v_is_team_moderator THEN RETURN 4; END IF;

  -- Verificar role na comunidade (se fornecido)
  IF p_community_id IS NOT NULL THEN
    SELECT role INTO v_community_role
    FROM public.community_members
    WHERE community_id = p_community_id AND user_id = p_user_id;
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

-- =============================================================================
-- 1. RECRIAR moderate_user com hierarquia correta
-- =============================================================================
CREATE OR REPLACE FUNCTION public.moderate_user(
  p_community_id    UUID,
  p_target_user_id  UUID    DEFAULT NULL,
  p_action          TEXT    DEFAULT NULL,
  p_reason          TEXT    DEFAULT '',
  p_duration_hours  INTEGER DEFAULT NULL,
  p_target_post_id  UUID    DEFAULT NULL,
  p_featured_days   INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_moderator_id       UUID    := auth.uid();
  v_moderator_rank     INTEGER := 0;
  v_target_rank        INTEGER := 0;
  v_moderator_role     public.user_role;
  v_target_role        public.user_role;
  v_expires            TIMESTAMPTZ;
  v_featured_until     TIMESTAMPTZ;
  v_post_author_id     UUID;
  v_post_community_id  UUID;
  v_rows_affected      INTEGER := 0;
  v_notification_title TEXT;
  v_notification_body  TEXT;
  v_log_post_id        UUID;
BEGIN
  IF v_moderator_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_action IS NULL OR btrim(p_action) = '' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'missing_action');
  END IF;

  -- Calcular rank do moderador (considera flags globais + role na comunidade)
  v_moderator_rank := public.get_moderation_rank(v_moderator_id, p_community_id);

  -- Rank mínimo para moderar: curator (1) ou superior
  IF v_moderator_rank < 1 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'insufficient_permissions');
  END IF;

  -- Obter role local do moderador para ações que dependem do cargo específico
  SELECT role INTO v_moderator_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_moderator_id;

  -- Auto-moderação não permitida
  IF p_target_user_id = v_moderator_id
     AND p_action IN ('warn', 'strike', 'mute', 'unmute', 'ban', 'unban', 'kick') THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'self_moderation_not_allowed');
  END IF;

  IF p_action IN ('warn', 'strike', 'mute', 'unmute', 'ban', 'unban', 'kick')
     AND p_target_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'missing_target_user');
  END IF;

  IF p_action IN (
      'hide_post', 'unhide_post', 'feature_post', 'unfeature_post',
      'pin_post', 'unpin_post', 'delete_post', 'delete_content'
    )
     AND p_target_post_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'missing_target_post');
  END IF;

  IF p_duration_hours IS NOT NULL AND p_duration_hours > 0 THEN
    v_expires := NOW() + make_interval(hours => p_duration_hours);
  END IF;

  IF p_featured_days IS NOT NULL AND p_featured_days > 0 THEN
    v_featured_until := NOW() + make_interval(days => p_featured_days);
  END IF;

  -- Verificar hierarquia para ações sobre usuários
  IF p_target_user_id IS NOT NULL
     AND p_action IN ('warn', 'strike', 'mute', 'unmute', 'ban', 'unban', 'kick') THEN

    -- Calcular rank do alvo
    v_target_rank := public.get_moderation_rank(p_target_user_id, p_community_id);

    -- Obter role local do alvo
    SELECT role INTO v_target_role
    FROM public.community_members
    WHERE community_id = p_community_id AND user_id = p_target_user_id;

    IF v_target_role IS NULL AND p_action NOT IN ('unban') THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'target_not_member');
    END IF;

    -- Não pode moderar alguém de mesmo nível ou superior
    IF v_target_rank >= v_moderator_rank THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'cannot_moderate_same_or_higher_role');
    END IF;

    -- Regras específicas por cargo:
    -- curator (rank 1) só pode moderar member (rank 0)
    IF v_moderator_rank = 1 AND v_target_rank > 0 THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'curators_can_only_moderate_members');
    END IF;

    -- leader (rank 2) pode moderar curator (rank 1) e member (rank 0), mas não agent (rank 3+)
    -- (já coberto pela verificação v_target_rank >= v_moderator_rank)

    -- agent (rank 3) pode moderar leader (rank 2) e abaixo, mas não team members (rank 4+)
    -- (já coberto pela verificação v_target_rank >= v_moderator_rank)
  END IF;

  IF p_target_post_id IS NOT NULL THEN
    SELECT community_id, author_id INTO v_post_community_id, v_post_author_id
    FROM public.posts WHERE id = p_target_post_id;

    IF v_post_community_id IS NULL THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'post_not_found');
    END IF;
    IF v_post_community_id <> p_community_id THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'post_outside_community');
    END IF;
  END IF;

  CASE p_action
    WHEN 'ban' THEN
      UPDATE public.community_members
      SET is_banned = TRUE, ban_expires_at = v_expires
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'target_not_member');
      END IF;
      INSERT INTO public.bans (community_id, user_id, banned_by, reason, is_permanent, expires_at)
      VALUES (p_community_id, p_target_user_id, v_moderator_id, COALESCE(p_reason, ''), p_duration_hours IS NULL, v_expires);

    WHEN 'unban' THEN
      UPDATE public.community_members
      SET is_banned = FALSE, ban_expires_at = NULL
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'target_not_member');
      END IF;
      UPDATE public.bans
      SET is_active = FALSE, unbanned_by = v_moderator_id, unbanned_at = NOW()
      WHERE community_id = p_community_id AND user_id = p_target_user_id AND is_active = TRUE;

    WHEN 'mute' THEN
      UPDATE public.community_members
      SET is_muted = TRUE, mute_expires_at = v_expires
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'target_not_member');
      END IF;

    WHEN 'unmute' THEN
      UPDATE public.community_members
      SET is_muted = FALSE, mute_expires_at = NULL
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'target_not_member');
      END IF;

    WHEN 'strike' THEN
      INSERT INTO public.strikes (community_id, user_id, issued_by, reason, expires_at)
      VALUES (p_community_id, p_target_user_id, v_moderator_id, COALESCE(p_reason, ''), v_expires);
      UPDATE public.community_members
      SET strike_count = COALESCE(strike_count, 0) + 1
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'target_not_member');
      END IF;

    WHEN 'warn' THEN
      NULL;

    WHEN 'kick' THEN
      DELETE FROM public.community_members
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'target_not_member');
      END IF;

    WHEN 'hide_post' THEN
      UPDATE public.posts SET status = 'disabled', updated_at = NOW()
      WHERE id = p_target_post_id AND community_id = p_community_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN RETURN jsonb_build_object('success', FALSE, 'error', 'post_not_found'); END IF;

    WHEN 'unhide_post' THEN
      UPDATE public.posts SET status = 'ok', updated_at = NOW()
      WHERE id = p_target_post_id AND community_id = p_community_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN RETURN jsonb_build_object('success', FALSE, 'error', 'post_not_found'); END IF;

    WHEN 'feature_post' THEN
      UPDATE public.posts
      SET is_featured = TRUE, featured_at = NOW(), featured_by = v_moderator_id,
          featured_until = v_featured_until, updated_at = NOW()
      WHERE id = p_target_post_id AND community_id = p_community_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN RETURN jsonb_build_object('success', FALSE, 'error', 'post_not_found'); END IF;

    WHEN 'unfeature_post' THEN
      UPDATE public.posts
      SET is_featured = FALSE, featured_at = NULL, featured_by = NULL,
          featured_until = NULL, updated_at = NOW()
      WHERE id = p_target_post_id AND community_id = p_community_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN RETURN jsonb_build_object('success', FALSE, 'error', 'post_not_found'); END IF;

    WHEN 'pin_post' THEN
      UPDATE public.posts SET is_pinned = TRUE, pinned_at = NOW(), updated_at = NOW()
      WHERE id = p_target_post_id AND community_id = p_community_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN RETURN jsonb_build_object('success', FALSE, 'error', 'post_not_found'); END IF;

    WHEN 'unpin_post' THEN
      UPDATE public.posts SET is_pinned = FALSE, pinned_at = NULL, updated_at = NOW()
      WHERE id = p_target_post_id AND community_id = p_community_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN RETURN jsonb_build_object('success', FALSE, 'error', 'post_not_found'); END IF;

    WHEN 'delete_post', 'delete_content' THEN
      DELETE FROM public.posts WHERE id = p_target_post_id AND community_id = p_community_id;
      GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
      IF v_rows_affected = 0 THEN RETURN jsonb_build_object('success', FALSE, 'error', 'post_not_found'); END IF;

    ELSE
      RETURN jsonb_build_object('success', FALSE, 'error', 'unsupported_action');
  END CASE;

  -- Notificação para ações em usuários
  IF p_target_user_id IS NOT NULL
     AND p_action IN ('warn', 'strike', 'mute', 'unmute', 'ban', 'unban', 'kick') THEN
    v_notification_title := CASE p_action
      WHEN 'warn'   THEN 'Aviso da moderação'
      WHEN 'strike' THEN 'Strike aplicado'
      WHEN 'mute'   THEN 'Você foi silenciado'
      WHEN 'unmute' THEN 'Seu silenciamento foi removido'
      WHEN 'ban'    THEN 'Você foi banido'
      WHEN 'unban'  THEN 'Seu banimento foi removido'
      WHEN 'kick'   THEN 'Você foi removido da comunidade'
      ELSE 'Atualização da moderação'
    END;
    v_notification_body := CASE
      WHEN COALESCE(NULLIF(btrim(p_reason), ''), '') <> '' THEN p_reason
      WHEN p_action = 'warn'   THEN 'A moderação emitiu um aviso para sua conta nesta comunidade.'
      WHEN p_action = 'strike' THEN 'A moderação aplicou um strike à sua conta nesta comunidade.'
      WHEN p_action = 'mute'   THEN 'A moderação restringiu temporariamente sua participação nesta comunidade.'
      WHEN p_action = 'unmute' THEN 'A moderação removeu o silenciamento da sua conta nesta comunidade.'
      WHEN p_action = 'ban'    THEN 'A moderação removeu seu acesso a esta comunidade.'
      WHEN p_action = 'unban'  THEN 'Você voltou a ter acesso a esta comunidade.'
      WHEN p_action = 'kick'   THEN 'Você foi removido da comunidade e poderá entrar novamente depois.'
      ELSE 'Uma ação de moderação foi aplicada à sua conta.'
    END;
    INSERT INTO public.notifications (user_id, actor_id, type, title, body, community_id)
    VALUES (p_target_user_id, v_moderator_id, 'moderation', v_notification_title, v_notification_body, p_community_id);
  END IF;

  -- Notificação para ações em posts
  IF v_post_author_id IS NOT NULL
     AND v_post_author_id <> v_moderator_id
     AND p_action IN ('hide_post','unhide_post','feature_post','unfeature_post','pin_post','unpin_post','delete_post','delete_content') THEN
    v_notification_title := CASE p_action
      WHEN 'hide_post'      THEN 'Seu post foi ocultado'
      WHEN 'unhide_post'    THEN 'Seu post foi restaurado'
      WHEN 'feature_post'   THEN 'Seu post foi destacado'
      WHEN 'unfeature_post' THEN 'O destaque do seu post foi removido'
      WHEN 'pin_post'       THEN 'Seu post foi fixado'
      WHEN 'unpin_post'     THEN 'Seu post foi desafixado'
      WHEN 'delete_post'    THEN 'Seu post foi removido'
      WHEN 'delete_content' THEN 'Seu post foi removido'
      ELSE 'Atualização da moderação'
    END;
    v_notification_body := CASE
      WHEN COALESCE(NULLIF(btrim(p_reason), ''), '') <> '' THEN p_reason
      WHEN p_action = 'hide_post'      THEN 'A moderação ocultou seu post nesta comunidade.'
      WHEN p_action = 'unhide_post'    THEN 'A moderação restaurou a visibilidade do seu post.'
      WHEN p_action = 'feature_post'   THEN 'A moderação destacou seu post nesta comunidade.'
      WHEN p_action = 'unfeature_post' THEN 'A moderação removeu o destaque do seu post.'
      WHEN p_action = 'pin_post'       THEN 'A moderação fixou seu post no topo da comunidade.'
      WHEN p_action = 'unpin_post'     THEN 'A moderação removeu a fixação do seu post.'
      WHEN p_action IN ('delete_post', 'delete_content') THEN 'A moderação removeu permanentemente seu post.'
      ELSE 'A moderação atualizou o status do seu post.'
    END;
    INSERT INTO public.notifications (user_id, actor_id, type, title, body, community_id, post_id)
    VALUES (
      v_post_author_id, v_moderator_id, 'moderation',
      v_notification_title, v_notification_body, p_community_id,
      CASE WHEN p_action IN ('delete_post', 'delete_content') THEN NULL ELSE p_target_post_id END
    );
  END IF;

  v_log_post_id := CASE
    WHEN p_action IN ('delete_post', 'delete_content') THEN NULL
    ELSE p_target_post_id
  END;

  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action, target_user_id, target_post_id,
    reason, details, duration_hours, expires_at
  ) VALUES (
    p_community_id, v_moderator_id, p_action::public.moderation_action,
    p_target_user_id, v_log_post_id,
    COALESCE(p_reason, ''),
    jsonb_strip_nulls(jsonb_build_object(
      'target_post_id', p_target_post_id,
      'deleted_post_id', CASE WHEN p_action IN ('delete_post', 'delete_content') THEN p_target_post_id ELSE NULL END,
      'featured_days', p_featured_days
    )),
    p_duration_hours, v_expires
  );

  RETURN jsonb_build_object(
    'success', TRUE, 'action', p_action,
    'community_id', p_community_id,
    'target_user_id', p_target_user_id,
    'target_post_id', p_target_post_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.moderate_user(UUID, UUID, TEXT, TEXT, INTEGER, UUID, INTEGER) TO authenticated;

-- =============================================================================
-- 2. RECRIAR ban_community_member com hierarquia correta
-- =============================================================================
CREATE OR REPLACE FUNCTION public.ban_community_member(
  p_community_id    UUID,
  p_target_user_id  UUID,
  p_duration        TEXT DEFAULT '7d',
  p_reason          TEXT DEFAULT 'Banido da comunidade'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller         UUID    := auth.uid();
  v_caller_rank    INTEGER := 0;
  v_target_rank    INTEGER := 0;
  v_ban_until      TIMESTAMPTZ;
  v_is_perm        BOOLEAN;
  v_ban_id         UUID;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Calcular ranks usando hierarquia completa
  v_caller_rank := public.get_moderation_rank(v_caller, p_community_id);
  v_target_rank := public.get_moderation_rank(p_target_user_id, p_community_id);

  -- Rank mínimo para banir: leader (2) ou superior
  IF v_caller_rank < 2 THEN
    RAISE EXCEPTION 'Sem permissão para banir. Apenas Líderes e superiores podem banir membros.';
  END IF;

  -- Não pode banir alguém de mesmo nível ou superior
  IF v_target_rank >= v_caller_rank THEN
    RAISE EXCEPTION 'Não é possível banir um membro de cargo igual ou superior ao seu.';
  END IF;

  -- Calcular expiração
  CASE p_duration
    WHEN '1d'        THEN v_ban_until := now() + INTERVAL '1 day';   v_is_perm := false;
    WHEN '7d'        THEN v_ban_until := now() + INTERVAL '7 days';  v_is_perm := false;
    WHEN '30d'       THEN v_ban_until := now() + INTERVAL '30 days'; v_is_perm := false;
    WHEN 'permanent' THEN v_ban_until := NULL;                        v_is_perm := true;
    ELSE                  v_ban_until := now() + INTERVAL '7 days';  v_is_perm := false;
  END CASE;

  -- Inserir na tabela bans
  INSERT INTO public.bans (
    community_id, user_id, banned_by,
    reason, is_permanent, expires_at, is_active
  ) VALUES (
    p_community_id, p_target_user_id, v_caller,
    COALESCE(NULLIF(btrim(p_reason), ''), 'Banido da comunidade'),
    v_is_perm, v_ban_until, true
  ) RETURNING id INTO v_ban_id;

  -- Atualizar community_members
  UPDATE public.community_members
  SET is_banned = true, ban_expires_at = v_ban_until
  WHERE community_id = p_community_id AND user_id = p_target_user_id;

  -- Registrar em moderation_logs
  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action, severity,
    target_user_id, reason, duration_hours, expires_at
  ) VALUES (
    p_community_id, v_caller, 'ban', 'danger',
    p_target_user_id, p_reason,
    CASE p_duration
      WHEN '1d'  THEN 24
      WHEN '7d'  THEN 168
      WHEN '30d' THEN 720
      ELSE NULL
    END,
    v_ban_until
  );

  -- Notificar
  INSERT INTO public.notifications (user_id, actor_id, type, title, body)
  VALUES (
    p_target_user_id, v_caller,
    'moderation',
    'Você foi banido',
    COALESCE(NULLIF(btrim(p_reason), ''), 'Você foi banido desta comunidade.')
  );

  RETURN jsonb_build_object(
    'success',   true,
    'ban_id',    v_ban_id,
    'ban_until', v_ban_until,
    'permanent', v_is_perm
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.ban_community_member(UUID, UUID, TEXT, TEXT) TO authenticated;

-- =============================================================================
-- 3. RECRIAR issue_strike com hierarquia correta
-- =============================================================================
CREATE OR REPLACE FUNCTION public.issue_strike(
  p_community_id  UUID,
  p_target_id     UUID,
  p_reason        TEXT,
  p_expires_days  INT DEFAULT 90
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_moderator_id   UUID    := auth.uid();
  v_moderator_rank INTEGER := 0;
  v_target_rank    INTEGER := 0;
  v_strike_count   INT;
  v_auto_banned    BOOLEAN := FALSE;
  v_expires_at     TIMESTAMPTZ;
  v_ban_expires    TIMESTAMPTZ;
BEGIN
  IF v_moderator_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Calcular ranks
  v_moderator_rank := public.get_moderation_rank(v_moderator_id, p_community_id);
  v_target_rank    := public.get_moderation_rank(p_target_id, p_community_id);

  -- Rank mínimo para dar strike: curator (1) ou superior
  IF v_moderator_rank < 1 THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  -- Não pode dar strike em alguém de mesmo nível ou superior
  IF v_target_rank >= v_moderator_rank THEN
    RAISE EXCEPTION 'cannot_strike_same_or_higher_role';
  END IF;

  -- curator (rank 1) só pode dar strike em member (rank 0)
  IF v_moderator_rank = 1 AND v_target_rank > 0 THEN
    RAISE EXCEPTION 'curators_can_only_strike_members';
  END IF;

  -- Verificar se o alvo é membro da comunidade
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id AND user_id = p_target_id
  ) THEN
    RAISE EXCEPTION 'target_not_member';
  END IF;

  v_expires_at := NOW() + (p_expires_days || ' days')::INTERVAL;

  INSERT INTO public.strikes (
    community_id, user_id, issued_by, reason, expires_at
  ) VALUES (
    p_community_id, p_target_id, v_moderator_id, p_reason, v_expires_at
  );

  UPDATE public.community_members
  SET strike_count = COALESCE(strike_count, 0) + 1
  WHERE community_id = p_community_id AND user_id = p_target_id
  RETURNING strike_count INTO v_strike_count;

  PERFORM public.log_moderation_action(
    p_community_id   => p_community_id,
    p_action         => 'strike',
    p_target_user_id => p_target_id,
    p_reason         => p_reason
  );

  -- Ban automático ao atingir 3 strikes
  IF v_strike_count >= 3 THEN
    v_ban_expires := NOW() + INTERVAL '30 days';
    v_auto_banned := TRUE;

    INSERT INTO public.bans (
      community_id, user_id, banned_by,
      reason, is_permanent, expires_at
    ) VALUES (
      p_community_id, p_target_id, v_moderator_id,
      'Ban automático: 3 strikes acumulados. Motivo do último: ' || p_reason,
      FALSE, v_ban_expires
    )
    ON CONFLICT DO NOTHING;

    UPDATE public.community_members
    SET is_banned = TRUE, ban_expires_at = v_ban_expires, strike_count = 0
    WHERE community_id = p_community_id AND user_id = p_target_id;

    PERFORM public.log_moderation_action(
      p_community_id   => p_community_id,
      p_action         => 'ban',
      p_target_user_id => p_target_id,
      p_reason         => 'Ban automático por 3 strikes',
      p_duration_hours => 720
    );
  END IF;

  RETURN jsonb_build_object(
    'success',        TRUE,
    'strike_count',   v_strike_count,
    'auto_banned',    v_auto_banned,
    'ban_expires_at', CASE WHEN v_auto_banned THEN v_ban_expires::TEXT ELSE NULL END
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;
GRANT EXECUTE ON FUNCTION public.issue_strike TO authenticated;

-- =============================================================================
-- 4. RECRIAR apply_member_strike com hierarquia correta
-- =============================================================================
CREATE OR REPLACE FUNCTION public.apply_member_strike(
  p_community_id    UUID,
  p_target_user_id  UUID,
  p_reason          TEXT DEFAULT 'Advertência formal'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller         UUID    := auth.uid();
  v_caller_rank    INTEGER := 0;
  v_target_rank    INTEGER := 0;
  v_strike_id      UUID;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  v_caller_rank := public.get_moderation_rank(v_caller, p_community_id);
  v_target_rank := public.get_moderation_rank(p_target_user_id, p_community_id);

  IF v_caller_rank < 1 THEN
    RAISE EXCEPTION 'Sem permissão para aplicar strike';
  END IF;

  IF v_target_rank >= v_caller_rank THEN
    RAISE EXCEPTION 'Não é possível aplicar strike em membro de cargo igual ou superior';
  END IF;

  IF v_caller_rank = 1 AND v_target_rank > 0 THEN
    RAISE EXCEPTION 'Curadores só podem aplicar strike em membros comuns';
  END IF;

  INSERT INTO public.strikes (
    community_id, user_id, issued_by, reason, is_active
  ) VALUES (
    p_community_id, p_target_user_id, v_caller,
    COALESCE(NULLIF(btrim(p_reason), ''), 'Advertência formal'),
    true
  ) RETURNING id INTO v_strike_id;

  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action, severity,
    target_user_id, reason
  ) VALUES (
    p_community_id, v_caller, 'strike', 'warning',
    p_target_user_id, p_reason
  );

  INSERT INTO public.notifications (user_id, actor_id, type, title, body)
  VALUES (
    p_target_user_id, v_caller,
    'moderation',
    'Advertência recebida',
    COALESCE(NULLIF(btrim(p_reason), ''), 'Você recebeu uma advertência formal.')
  );

  RETURN jsonb_build_object('success', true, 'strike_id', v_strike_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.apply_member_strike(UUID, UUID, TEXT) TO authenticated;

-- =============================================================================
-- 5. RECRIAR change_member_role com hierarquia correta
--    Reconhece is_team_moderator (além de is_team_admin) como permissão global
-- =============================================================================
CREATE OR REPLACE FUNCTION public.change_member_role(
  p_community_id    UUID,
  p_target_user_id  UUID,
  p_new_role        TEXT,
  p_reason          TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id        UUID    := auth.uid();
  v_caller_rank    INTEGER := 0;
  v_target_rank    INTEGER := 0;
  v_target_role    TEXT;
  v_old_role       public.user_role;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Calcular ranks
  v_caller_rank := public.get_moderation_rank(v_user_id, p_community_id);
  v_target_rank := public.get_moderation_rank(p_target_user_id, p_community_id);

  -- Buscar role atual do alvo
  SELECT role INTO v_target_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = p_target_user_id;

  IF v_target_role IS NULL THEN
    RETURN jsonb_build_object('error', 'user_not_member');
  END IF;

  -- Rank mínimo para alterar cargos: leader (2) ou superior
  IF v_caller_rank < 2 THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;

  -- Não pode alterar cargo de alguém de mesmo nível ou superior
  IF v_target_rank >= v_caller_rank THEN
    RETURN jsonb_build_object('error', 'cannot_change_same_or_higher_role');
  END IF;

  -- Validar o novo role
  IF p_new_role NOT IN ('agent', 'leader', 'curator', 'member') THEN
    RETURN jsonb_build_object('error', 'invalid_role');
  END IF;

  -- Regras específicas por cargo do caller:
  -- leader (rank 2) só pode promover para curator ou rebaixar para member
  IF v_caller_rank = 2 AND p_new_role NOT IN ('curator', 'member') THEN
    RETURN jsonb_build_object('error', 'leaders_can_only_manage_curators');
  END IF;

  -- agent (rank 3) pode promover até leader, mas não pode criar outro agent
  IF v_caller_rank = 3 AND p_new_role = 'agent' THEN
    RETURN jsonb_build_object('error', 'use_transfer_founder_title_to_change_agent');
  END IF;

  -- team members (rank 4/5) podem promover até agent
  -- (sem restrições adicionais além das já verificadas)

  v_old_role := v_target_role::public.user_role;

  UPDATE public.community_members
  SET role = p_new_role::public.user_role
  WHERE community_id = p_community_id AND user_id = p_target_user_id;

  -- Registrar histórico (tabela role_changes pode não existir em todos os ambientes)
  BEGIN
    INSERT INTO public.role_changes (community_id, user_id, changed_by, old_role, new_role, reason)
    VALUES (p_community_id, p_target_user_id, v_user_id, v_old_role, p_new_role::public.user_role, p_reason);
  EXCEPTION WHEN undefined_table THEN
    NULL; -- Tabela role_changes não existe, ignorar
  END;

  INSERT INTO public.moderation_logs (community_id, moderator_id, action, target_user_id, reason)
  VALUES (
    p_community_id,
    v_user_id,
    CASE WHEN p_new_role > v_target_role THEN 'promote' ELSE 'demote' END::public.moderation_action,
    p_target_user_id,
    p_reason
  );

  INSERT INTO public.notifications (user_id, actor_id, type, title, body, community_id)
  VALUES (
    p_target_user_id,
    v_user_id,
    'moderation',
    CASE
      WHEN p_new_role IN ('leader', 'curator', 'agent') THEN 'Você foi promovido!'
      ELSE 'Alteração de cargo'
    END,
    CASE
      WHEN p_new_role = 'agent'   THEN 'Você agora é o Líder Fundador desta comunidade.'
      WHEN p_new_role = 'leader'  THEN 'Você agora é Líder desta comunidade.'
      WHEN p_new_role = 'curator' THEN 'Você agora é Curador desta comunidade.'
      ELSE 'Seu cargo na comunidade foi alterado.'
    END,
    p_community_id
  );

  RETURN jsonb_build_object('success', TRUE, 'old_role', v_old_role, 'new_role', p_new_role);
END;
$$;
GRANT EXECUTE ON FUNCTION public.change_member_role(UUID, UUID, TEXT, TEXT) TO authenticated;
