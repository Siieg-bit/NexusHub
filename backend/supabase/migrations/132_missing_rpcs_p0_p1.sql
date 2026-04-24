-- =============================================================================
-- Migration 132: RPCs faltantes — P0 e P1
-- Elimina gambiarras de inserts/updates/deletes diretos no frontend para
-- operações críticas de moderação, join/leave de comunidade e notificações.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Enum: adicionar valores de moderação de posts que faltavam
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'feature_post'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'feature_post';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'unfeature_post'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'unfeature_post';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'pin_post'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'pin_post';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'unpin_post'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'unpin_post';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'hide_post'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'hide_post';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'unhide_post'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'unhide_post';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'delete_post'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'delete_post';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'silence_member'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'silence_member';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'unsilence_member'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'unsilence_member';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'hide_member'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'hide_member';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'unhide_member'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'unhide_member';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RPC: moderate_post
--    Centraliza todas as ações de moderação em posts: feature, unfeature,
--    pin, unpin, hide, unhide, delete. Valida permissão, executa a ação
--    e registra log de moderação atomicamente.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.moderate_post(
  p_post_id      UUID,
  p_action       TEXT,
  p_community_id UUID  DEFAULT NULL,
  p_reason       TEXT  DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_community_id UUID;
  v_author_id    UUID;
  v_is_mod       BOOLEAN;
  v_is_author    BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Buscar dados do post
  SELECT community_id, author_id
  INTO v_community_id, v_author_id
  FROM public.posts
  WHERE id = p_post_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Post não encontrado';
  END IF;

  -- Usar community_id do post se não fornecido
  IF p_community_id IS NOT NULL THEN
    v_community_id := p_community_id;
  END IF;

  v_is_author := (v_user_id = v_author_id);
  v_is_mod    := public.is_community_moderator(v_community_id)
                 OR public.is_team_member();

  -- Validar permissão por tipo de ação
  CASE p_action
    WHEN 'feature_post', 'unfeature_post', 'hide_post', 'unhide_post',
         'pin_post', 'unpin_post' THEN
      IF NOT v_is_mod THEN
        RAISE EXCEPTION 'Sem permissão para moderar posts';
      END IF;
    WHEN 'delete_post' THEN
      IF NOT (v_is_author OR v_is_mod) THEN
        RAISE EXCEPTION 'Sem permissão para excluir este post';
      END IF;
    ELSE
      RAISE EXCEPTION 'Ação de moderação inválida: %', p_action;
  END CASE;

  -- Executar a ação
  CASE p_action
    WHEN 'feature_post' THEN
      UPDATE public.posts SET
        is_featured  = TRUE,
        featured_at  = NOW(),
        featured_by  = v_user_id,
        featured_until = NULL
      WHERE id = p_post_id;

    WHEN 'unfeature_post' THEN
      UPDATE public.posts SET
        is_featured  = FALSE,
        featured_at  = NULL,
        featured_by  = NULL,
        featured_until = NULL
      WHERE id = p_post_id;

    WHEN 'pin_post' THEN
      UPDATE public.posts SET
        is_pinned = TRUE,
        pinned_at = NOW()
      WHERE id = p_post_id;

    WHEN 'unpin_post' THEN
      UPDATE public.posts SET
        is_pinned = FALSE,
        pinned_at = NULL
      WHERE id = p_post_id;

    WHEN 'hide_post' THEN
      UPDATE public.posts SET status = 'disabled'
      WHERE id = p_post_id;

    WHEN 'unhide_post' THEN
      UPDATE public.posts SET status = 'ok'
      WHERE id = p_post_id;

    WHEN 'delete_post' THEN
      UPDATE public.posts SET status = 'deleted'
      WHERE id = p_post_id;
  END CASE;

  -- Registrar log de moderação (apenas quando há comunidade e é ação de staff)
  IF v_community_id IS NOT NULL AND v_is_mod THEN
    PERFORM public.log_moderation_action(
      p_community_id  => v_community_id,
      p_action        => p_action,
      p_target_post_id => p_post_id,
      p_target_user_id => v_author_id,
      p_reason        => COALESCE(p_reason, p_action || ' aplicado por moderação')
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.moderate_post TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RPC: delete_comment
--    Exclui um comentário. Apenas o autor ou moderadores podem excluir.
--    Registra log quando feito por staff.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_comment(
  p_comment_id   UUID,
  p_reason       TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_author_id    UUID;
  v_community_id UUID;
  v_post_id      UUID;
  v_wiki_id      UUID;
  v_is_author    BOOLEAN;
  v_is_mod       BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT author_id, post_id, wiki_id
  INTO v_author_id, v_post_id, v_wiki_id
  FROM public.comments
  WHERE id = p_comment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Comentário não encontrado';
  END IF;

  -- Obter community_id via post ou wiki
  IF v_post_id IS NOT NULL THEN
    SELECT community_id INTO v_community_id
    FROM public.posts WHERE id = v_post_id;
  ELSIF v_wiki_id IS NOT NULL THEN
    SELECT community_id INTO v_community_id
    FROM public.wiki_entries WHERE id = v_wiki_id;
  END IF;

  v_is_author := (v_user_id = v_author_id);
  v_is_mod    := (v_community_id IS NOT NULL AND
                  (public.is_community_moderator(v_community_id)
                   OR public.is_team_member()));

  IF NOT (v_is_author OR v_is_mod) THEN
    RAISE EXCEPTION 'Sem permissão para excluir este comentário';
  END IF;

  DELETE FROM public.comments WHERE id = p_comment_id;

  -- Log de moderação quando feito por staff
  IF v_is_mod AND NOT v_is_author AND v_community_id IS NOT NULL THEN
    PERFORM public.log_moderation_action(
      p_community_id     => v_community_id,
      p_action           => 'delete_content',
      p_target_comment_id => p_comment_id,
      p_target_user_id   => v_author_id,
      p_reason           => COALESCE(p_reason, 'Comentário removido por moderação')
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_comment TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. RPC: join_community
--    Entrada em comunidade com validações completas: comunidade ativa,
--    usuário não banido, perfil local inicializado a partir do perfil global.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.join_community(
  p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_community    RECORD;
  v_profile      RECORD;
  v_already_member BOOLEAN;
  v_is_banned    BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar se a comunidade existe e está ativa
  SELECT id, name, is_active, welcome_message
  INTO v_community
  FROM public.communities
  WHERE id = p_community_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Comunidade não encontrada';
  END IF;

  IF NOT v_community.is_active THEN
    RAISE EXCEPTION 'Esta comunidade não está disponível';
  END IF;

  -- Verificar se já é membro
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id AND user_id = v_user_id
  ) INTO v_already_member;

  IF v_already_member THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_member');
  END IF;

  -- Verificar se está banido
  SELECT EXISTS(
    SELECT 1 FROM public.bans
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_active = TRUE
      AND (expires_at IS NULL OR expires_at > NOW())
  ) INTO v_is_banned;

  IF v_is_banned THEN
    RAISE EXCEPTION 'Você está banido desta comunidade';
  END IF;

  -- Buscar perfil global para inicializar perfil local
  SELECT nickname, bio, icon_url, banner_url
  INTO v_profile
  FROM public.profiles
  WHERE id = v_user_id;

  -- Inserir membro com perfil local inicializado
  INSERT INTO public.community_members (
    community_id, user_id, role,
    local_nickname, local_bio, local_icon_url, local_banner_url
  ) VALUES (
    p_community_id, v_user_id, 'member',
    v_profile.nickname, v_profile.bio,
    v_profile.icon_url, v_profile.banner_url
  );

  -- Reputação por entrar na comunidade
  PERFORM public.add_reputation(v_user_id, p_community_id, 'join_community', 5, NULL);

  RETURN jsonb_build_object(
    'success', true,
    'welcome_message', v_community.welcome_message
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_community TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RPC: leave_community
--    Saída de comunidade com validações: não pode sair se for o único líder
--    fundador (agent) sem transferir antes.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.leave_community(
  p_community_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_role     TEXT;
  v_agent_count INT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT role INTO v_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Você não é membro desta comunidade';
  END IF;

  -- Impedir que o único agent (líder fundador) saia sem transferir
  IF v_role = 'agent' THEN
    SELECT COUNT(*) INTO v_agent_count
    FROM public.community_members
    WHERE community_id = p_community_id AND role = 'agent';

    IF v_agent_count <= 1 THEN
      RAISE EXCEPTION 'Você é o único líder fundador. Transfira a liderança antes de sair.';
    END IF;
  END IF;

  DELETE FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_community TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RPC: send_moderation_notification
--    Envia notificação de moderação de forma centralizada.
--    Valida autenticação e que o remetente é moderador da comunidade.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_moderation_notification(
  p_community_id UUID,
  p_user_id      UUID,
  p_type         TEXT,
  p_title        TEXT,
  p_body         TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_notif_id UUID;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF NOT (public.is_community_moderator(p_community_id) OR public.is_team_member()) THEN
    RAISE EXCEPTION 'Sem permissão para enviar notificações de moderação';
  END IF;

  INSERT INTO public.notifications (
    user_id, actor_id, type, title, body, community_id
  ) VALUES (
    p_user_id, v_actor_id, p_type, p_title, p_body, p_community_id
  ) RETURNING id INTO v_notif_id;

  RETURN v_notif_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_moderation_notification TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RPC: silence_community_member
--    Silencia um membro da comunidade por um período determinado.
--    Valida hierarquia de permissão e registra log atomicamente.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.silence_community_member(
  p_community_id UUID,
  p_target_id    UUID,
  p_duration_hours INT DEFAULT 24,
  p_reason       TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id     UUID := auth.uid();
  v_caller_role TEXT;
  v_target_role TEXT;
  v_until       TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT role INTO v_caller_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_caller_role NOT IN ('agent', 'leader', 'curator', 'moderator')
     AND NOT public.is_team_member() THEN
    RAISE EXCEPTION 'Sem permissão para silenciar membros';
  END IF;

  SELECT role INTO v_target_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = p_target_id;

  IF v_target_role = 'agent' THEN
    RAISE EXCEPTION 'O Líder Fundador não pode ser silenciado';
  END IF;

  v_until := NOW() + (p_duration_hours || ' hours')::INTERVAL;

  UPDATE public.community_members SET
    is_silenced   = TRUE,
    silenced_until = v_until
  WHERE community_id = p_community_id AND user_id = p_target_id;

  PERFORM public.log_moderation_action(
    p_community_id  => p_community_id,
    p_action        => 'silence_member',
    p_target_user_id => p_target_id,
    p_reason        => COALESCE(p_reason, 'Silenciado por ' || p_duration_hours || 'h'),
    p_duration_hours => p_duration_hours
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.silence_community_member TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. RPC: toggle_member_visibility
--    Oculta ou reativa o perfil de um membro na comunidade.
--    Valida permissão e registra log.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_member_visibility(
  p_community_id UUID,
  p_target_id    UUID,
  p_hide         BOOLEAN DEFAULT TRUE,
  p_reason       TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF NOT (public.is_community_moderator(p_community_id) OR public.is_team_member()) THEN
    RAISE EXCEPTION 'Sem permissão para ocultar membros';
  END IF;

  UPDATE public.community_members SET is_hidden = p_hide
  WHERE community_id = p_community_id AND user_id = p_target_id;

  PERFORM public.log_moderation_action(
    p_community_id  => p_community_id,
    p_action        => CASE WHEN p_hide THEN 'hide_member' ELSE 'unhide_member' END,
    p_target_user_id => p_target_id,
    p_reason        => COALESCE(p_reason,
      CASE WHEN p_hide THEN 'Perfil ocultado na comunidade'
           ELSE 'Perfil reativado na comunidade' END)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_member_visibility TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. RPC: resolve_flag_action
--    Wrapper que usa o resolve_flag existente (migration 073) mas garante
--    que o frontend nunca faça update direto em flags.
--    Mantém compatibilidade com o RPC existente.
-- ─────────────────────────────────────────────────────────────────────────────
-- O RPC resolve_flag já existe (migration 073) e é correto.
-- Apenas garantimos que o frontend use-o.
-- Nenhuma nova função necessária aqui.

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. RPC: toggle_chat_co_host
--     Adiciona ou remove um co-host de um chat thread.
--     Valida que o caller é o host ou um co-host.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_chat_co_host(
  p_thread_id UUID,
  p_user_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id  UUID := auth.uid();
  v_thread     RECORD;
  v_co_hosts   TEXT[];
  v_is_co_host BOOLEAN;
  v_updated    TEXT[];
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT creator_id, co_hosts INTO v_thread
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Chat não encontrado';
  END IF;

  -- Apenas o criador pode gerenciar co-hosts
  IF v_thread.creator_id != v_caller_id AND NOT public.is_team_member() THEN
    RAISE EXCEPTION 'Apenas o criador do chat pode gerenciar co-hosts';
  END IF;

  v_co_hosts   := COALESCE(v_thread.co_hosts, ARRAY[]::TEXT[]);
  v_is_co_host := p_user_id::TEXT = ANY(v_co_hosts);

  IF v_is_co_host THEN
    v_updated := ARRAY(SELECT unnest(v_co_hosts) WHERE unnest != p_user_id::TEXT);
  ELSE
    v_updated := v_co_hosts || p_user_id::TEXT;
  END IF;

  UPDATE public.chat_threads SET co_hosts = v_updated WHERE id = p_thread_id;

  RETURN jsonb_build_object(
    'is_co_host', NOT v_is_co_host,
    'co_hosts',   v_updated
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_chat_co_host TO authenticated;
