-- =============================================================================
-- Migration 207: Corrigir rastreamento dos tipos de moderação faltantes
-- =============================================================================
-- Tipos faltantes identificados na auditoria:
--   1. unmute          → moderate_user não tinha WHEN 'unmute'
--   2. wiki_approve    → review_wiki_entry não existia no banco
--   3. wiki_reject     → review_wiki_entry não existia no banco
--   4. approve_flag    → resolve_flag não registrava a ação de resolução
--   5. dismiss_flag    → resolve_flag não registrava a ação de resolução
--   6. accept_appeal   → review_ban_appeal só registrava 'unban', não 'accept_appeal'
--   7. reject_appeal   → review_ban_appeal não registrava 'reject_appeal'
-- =============================================================================

-- =============================================================================
-- 1. Adicionar WHEN 'unmute' na RPC moderate_user
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
  v_moderator_role     public.user_role;
  v_target_role        public.user_role;
  v_target_rank        INTEGER := 0;
  v_moderator_rank     INTEGER := 0;
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

  SELECT role INTO v_moderator_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_moderator_id;

  IF v_moderator_role NOT IN ('curator', 'leader', 'agent') THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'insufficient_permissions');
  END IF;

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

  IF p_target_user_id IS NOT NULL THEN
    SELECT role INTO v_target_role
    FROM public.community_members
    WHERE community_id = p_community_id AND user_id = p_target_user_id;

    IF v_target_role IS NULL
       AND p_action IN ('warn', 'strike', 'mute', 'unmute', 'ban', 'unban', 'kick') THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'target_not_member');
    END IF;
  END IF;

  v_moderator_rank := CASE v_moderator_role
    WHEN 'curator' THEN 1 WHEN 'leader' THEN 2 WHEN 'agent' THEN 3 ELSE 0
  END;
  v_target_rank := CASE v_target_role
    WHEN 'curator' THEN 1 WHEN 'leader' THEN 2 WHEN 'agent' THEN 3 ELSE 0
  END;

  IF v_target_role IS NOT NULL
     AND v_target_rank >= v_moderator_rank
     AND p_action IN ('warn', 'strike', 'mute', 'unmute', 'ban', 'unban', 'kick') THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'cannot_moderate_same_or_higher_role');
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

    -- ✅ NOVO: unmute
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
-- 2. Criar RPC review_wiki_entry (wiki_approve / wiki_reject)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.review_wiki_entry(
  p_wiki_id UUID,
  p_action  TEXT,   -- 'approve' ou 'reject'
  p_reason  TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_reviewer_id  UUID := auth.uid();
  v_wiki         RECORD;
  v_log_action   TEXT;
BEGIN
  IF v_reviewer_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  IF p_action NOT IN ('approve', 'reject') THEN RAISE EXCEPTION 'invalid_action'; END IF;

  SELECT * INTO v_wiki FROM public.wiki_entries WHERE id = p_wiki_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'wiki_not_found'; END IF;

  -- Verificar permissão: curador, líder, agent ou team member
  IF NOT (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = v_wiki.community_id
        AND user_id = v_reviewer_id
        AND role IN ('curator', 'leader', 'agent', 'moderator', 'admin')
        AND is_banned IS NOT TRUE
    )
    OR public.is_team_member()
  ) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  -- Atualizar status da wiki
  UPDATE public.wiki_entries
  SET status     = CASE WHEN p_action = 'approve' THEN 'approved' ELSE 'rejected' END,
      updated_at = NOW()
  WHERE id = p_wiki_id;

  v_log_action := CASE WHEN p_action = 'approve' THEN 'wiki_approve' ELSE 'wiki_reject' END;

  -- Registrar no log de moderação
  PERFORM public.log_moderation_action(
    p_community_id   => v_wiki.community_id,
    p_action         => v_log_action,
    p_target_user_id => v_wiki.author_id,
    p_target_wiki_id => p_wiki_id,
    p_reason         => COALESCE(p_reason,
      CASE WHEN p_action = 'approve' THEN 'Wiki aprovada' ELSE 'Wiki rejeitada' END)
  );

  -- Notificar o autor
  INSERT INTO public.notifications (
    user_id, actor_id, type, title, body, community_id, wiki_id, action_url
  ) VALUES (
    v_wiki.author_id,
    v_reviewer_id,
    CASE WHEN p_action = 'approve' THEN 'wiki_approved' ELSE 'wiki_rejected' END,
    CASE WHEN p_action = 'approve' THEN 'Sua wiki foi aprovada! 🎉' ELSE 'Sua wiki foi rejeitada' END,
    CASE WHEN p_action = 'approve'
      THEN COALESCE(NULLIF(v_wiki.title, ''), 'Wiki')
      ELSE COALESCE('Motivo: ' || p_reason, 'Sua wiki não foi aprovada pela moderação.')
    END,
    v_wiki.community_id,
    p_wiki_id,
    '/wiki/' || p_wiki_id
  );

  RETURN jsonb_build_object('success', true, 'action', p_action, 'wiki_id', p_wiki_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_wiki_entry(UUID, TEXT, TEXT) TO authenticated;

-- =============================================================================
-- 3. Corrigir resolve_flag: registrar approve_flag / dismiss_flag sempre
-- =============================================================================
CREATE OR REPLACE FUNCTION public.resolve_flag(
  p_flag_id         UUID,
  p_action          TEXT,    -- 'approved' ou 'dismissed'
  p_resolution_note TEXT    DEFAULT NULL,
  p_moderate_content BOOLEAN DEFAULT FALSE,
  p_moderate_action  TEXT    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_flag     RECORD;
  v_role     TEXT;
  v_log_action TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  SELECT f.* INTO v_flag FROM public.flags f WHERE f.id = p_flag_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Denúncia não encontrada'; END IF;

  SELECT role::TEXT INTO v_role
  FROM public.community_members
  WHERE community_id = v_flag.community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent', 'leader', 'curator', 'moderator', 'admin')
     AND NOT public.is_team_member() THEN
    RAISE EXCEPTION 'Sem permissão para resolver denúncias';
  END IF;

  -- Atualizar status da flag
  UPDATE public.flags SET
    status          = p_action,
    resolved_by     = v_user_id,
    resolution_note = COALESCE(p_resolution_note, resolution_note),
    resolved_at     = NOW()
  WHERE id = p_flag_id;

  -- ✅ NOVO: Registrar a ação de resolução da flag no log de moderação
  v_log_action := CASE WHEN p_action = 'approved' THEN 'approve_flag' ELSE 'dismiss_flag' END;

  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action,
    target_post_id, target_user_id,
    flag_id, reason
  ) VALUES (
    v_flag.community_id, v_user_id, v_log_action::public.moderation_action,
    v_flag.target_post_id, v_flag.target_user_id,
    p_flag_id,
    COALESCE(p_resolution_note, 'Denúncia ' || CASE WHEN p_action = 'approved' THEN 'aprovada' ELSE 'dispensada' END)
  );

  -- Ação sobre o conteúdo (se solicitado)
  IF p_moderate_content AND p_moderate_action IS NOT NULL THEN
    IF p_moderate_action = 'delete' AND v_flag.target_post_id IS NOT NULL THEN
      UPDATE public.posts SET content_status = 'disabled'
      WHERE id = v_flag.target_post_id;
    END IF;
    -- Registrar ação de conteúdo separada
    INSERT INTO public.moderation_logs (
      community_id, moderator_id, action,
      target_post_id, target_user_id, reason
    ) VALUES (
      v_flag.community_id, v_user_id, p_moderate_action::public.moderation_action,
      v_flag.target_post_id, v_flag.target_user_id,
      COALESCE(p_resolution_note, 'Ação via resolução de denúncia')
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'flag_id', p_flag_id, 'new_status', p_action);
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_flag(UUID, TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;

-- =============================================================================
-- 4. Corrigir review_ban_appeal: registrar accept_appeal / reject_appeal
-- =============================================================================
CREATE OR REPLACE FUNCTION public.review_ban_appeal(
  p_appeal_id UUID,
  p_action    TEXT,   -- 'accept' ou 'reject'
  p_note      TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_reviewer_id UUID := auth.uid();
  v_appeal      RECORD;
  v_is_staff    BOOLEAN;
BEGIN
  IF v_reviewer_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  IF p_action NOT IN ('accept', 'reject') THEN RAISE EXCEPTION 'invalid_action'; END IF;

  SELECT * INTO v_appeal FROM public.ban_appeals WHERE id = p_appeal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'appeal_not_found'; END IF;
  IF v_appeal.status != 'pending' THEN RAISE EXCEPTION 'appeal_not_pending'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = v_appeal.community_id
      AND user_id = v_reviewer_id
      AND role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
      AND is_banned IS NOT TRUE
  ) INTO v_is_staff;

  IF NOT v_is_staff AND NOT public.is_team_member() THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  -- Atualizar status da apelação
  UPDATE public.ban_appeals SET
    status        = CASE WHEN p_action = 'accept' THEN 'accepted'::appeal_status ELSE 'rejected'::appeal_status END,
    reviewer_id   = v_reviewer_id,
    reviewer_note = p_note,
    reviewed_at   = NOW(),
    updated_at    = NOW()
  WHERE id = p_appeal_id;

  IF p_action = 'accept' THEN
    -- Remover banimento
    UPDATE public.community_members SET
      is_banned = FALSE, ban_expires_at = NULL, updated_at = NOW()
    WHERE community_id = v_appeal.community_id AND user_id = v_appeal.appellant_id;

    -- Registrar unban no log
    PERFORM public.log_moderation_action(
      v_appeal.community_id,
      'unban',
      v_appeal.appellant_id,
      NULL, NULL, NULL, NULL,
      'Banimento removido via apelação aceita. Nota: ' || COALESCE(p_note, 'sem nota')
    );
  END IF;

  -- ✅ NOVO: Registrar accept_appeal ou reject_appeal no log de moderação
  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action,
    target_user_id, appeal_id, reason
  ) VALUES (
    v_appeal.community_id,
    v_reviewer_id,
    CASE WHEN p_action = 'accept' THEN 'accept_appeal' ELSE 'reject_appeal' END::public.moderation_action,
    v_appeal.appellant_id,
    p_appeal_id,
    COALESCE(p_note,
      CASE WHEN p_action = 'accept' THEN 'Apelação aceita' ELSE 'Apelação rejeitada' END)
  );

  -- Notificar o apelante
  INSERT INTO public.notifications (
    user_id, actor_id, type, title, body, community_id, action_url
  ) VALUES (
    v_appeal.appellant_id,
    v_reviewer_id,
    'moderation_alert',
    CASE WHEN p_action = 'accept' THEN 'Sua apelação foi aceita!' ELSE 'Sua apelação foi rejeitada' END,
    CASE WHEN p_action = 'accept'
      THEN 'Seu banimento foi removido. Você pode voltar à comunidade.'
      ELSE COALESCE('Motivo: ' || p_note, 'Sua apelação não foi aprovada.')
    END,
    v_appeal.community_id,
    '/appeals'
  );

  RETURN jsonb_build_object('success', true, 'action', p_action);
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_ban_appeal(UUID, TEXT, TEXT) TO authenticated;
