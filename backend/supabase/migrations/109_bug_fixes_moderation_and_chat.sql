-- =============================================================================
-- Migration 109: Bug Fixes — Moderação, Chat Scope e Colunas de Suporte
--
-- Corrige:
--   1. send_dm_invite — community_id para isolar DMs por comunidade
--   2. transfer_founder_title — transferir cargo de Agente (Fundador)
--   3. apply_member_strike — advertência formal via tabela strikes existente
--   4. ban_community_member — ban via tabela bans existente
--   5. community_members.is_hidden — ocultar perfil na comunidade
--   6. community_members.ban_expires_at — referência local ao ban ativo
--
-- Schema confirmado:
--   chat_messages      → thread_id + author_id
--   chat_members.status → 'none','active','invite_sent','join_requested'
--   privacy_level      → 'everyone','following','none'
--   communities        → agent_id (dono/criador)
--   moderation_logs    → tabela existente para histórico
--   strikes            → tabela existente para advertências
--   bans               → tabela existente para banimentos
-- =============================================================================

-- ── 1. Colunas de suporte em community_members ─────────────────────────────

ALTER TABLE public.community_members
  ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.community_members
  ADD COLUMN IF NOT EXISTS ban_expires_at TIMESTAMPTZ DEFAULT NULL;

COMMENT ON COLUMN public.community_members.is_hidden IS
  'Quando true, o perfil do membro fica invisível para outros membros da comunidade';

COMMENT ON COLUMN public.community_members.ban_expires_at IS
  'Referência rápida à data de expiração do ban ativo. NULL = permanente.';

-- ── 2. send_dm_invite com suporte a community_id ───────────────────────────
--
-- Adiciona p_community_id opcional. Quando fornecido, a busca por thread
-- existente e a criação de novo thread ficam com escopo naquela comunidade,
-- evitando redirecionar para DMs de outras comunidades.
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_dm_invite(
  p_target_user_id  UUID,
  p_initial_message TEXT    DEFAULT NULL,
  p_community_id    UUID    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller              UUID := auth.uid();
  v_target_privacy      privacy_level;
  v_is_follower         BOOLEAN;
  v_is_following        BOOLEAN;
  v_is_blocked          BOOLEAN;
  v_existing_thread_id  UUID;
  v_new_thread_id       UUID;
BEGIN
  -- Autenticação
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_target_user_id IS NULL OR p_target_user_id = v_caller THEN
    RAISE EXCEPTION 'Usuário alvo inválido';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_target_user_id) THEN
    RAISE EXCEPTION 'Usuário não encontrado';
  END IF;

  -- Bloqueio bidirecional
  SELECT EXISTS(
    SELECT 1 FROM blocks
    WHERE (blocker_id = p_target_user_id AND blocked_id = v_caller)
       OR (blocker_id = v_caller AND blocked_id = p_target_user_id)
  ) INTO v_is_blocked;

  IF v_is_blocked THEN
    RAISE EXCEPTION 'Não é possível enviar mensagem para este usuário';
  END IF;

  -- Relação follower/following
  SELECT EXISTS(
    SELECT 1 FROM follows
    WHERE follower_id = v_caller AND following_id = p_target_user_id
  ) INTO v_is_follower;

  SELECT EXISTS(
    SELECT 1 FROM follows
    WHERE follower_id = p_target_user_id AND following_id = v_caller
  ) INTO v_is_following;

  -- Privacidade (enum: 'everyone','following','none')
  SELECT COALESCE(privilege_chat_invite, 'everyone'::privacy_level)
  INTO v_target_privacy
  FROM profiles
  WHERE id = p_target_user_id;

  IF v_target_privacy = 'none' THEN
    RAISE EXCEPTION 'Este usuário não aceita convites de DM';
  ELSIF v_target_privacy = 'following' AND NOT v_is_following THEN
    RAISE EXCEPTION 'Este usuário só aceita DMs de pessoas que ele segue';
  END IF;

  -- Buscar thread DM existente com escopo correto
  IF p_community_id IS NOT NULL THEN
    -- Escopo de comunidade: busca DM entre os dois NESTA comunidade
    SELECT ct.id INTO v_existing_thread_id
    FROM chat_threads ct
    JOIN chat_members cm1
      ON cm1.thread_id = ct.id AND cm1.user_id = v_caller
    JOIN chat_members cm2
      ON cm2.thread_id = ct.id AND cm2.user_id = p_target_user_id
    WHERE ct.type = 'dm'
      AND ct.community_id = p_community_id
    LIMIT 1;
  ELSE
    -- Escopo global: busca DM sem comunidade associada
    SELECT ct.id INTO v_existing_thread_id
    FROM chat_threads ct
    JOIN chat_members cm1
      ON cm1.thread_id = ct.id AND cm1.user_id = v_caller
    JOIN chat_members cm2
      ON cm2.thread_id = ct.id AND cm2.user_id = p_target_user_id
    WHERE ct.type = 'dm'
      AND ct.community_id IS NULL
    LIMIT 1;
  END IF;

  -- Reativar membership se thread já existe
  IF v_existing_thread_id IS NOT NULL THEN
    UPDATE chat_members
    SET status = 'active'
    WHERE thread_id = v_existing_thread_id
      AND user_id   = v_caller
      AND status   != 'active';
    RETURN v_existing_thread_id;
  END IF;

  -- Criar novo thread DM
  INSERT INTO chat_threads (type, host_id, members_count, community_id)
  VALUES ('dm', v_caller, 2, p_community_id)
  RETURNING id INTO v_new_thread_id;

  -- Caller como membro ativo; target como invite_sent (enum correto)
  INSERT INTO chat_members (thread_id, user_id, status)
  VALUES (v_new_thread_id, v_caller,         'active');

  INSERT INTO chat_members (thread_id, user_id, status)
  VALUES (v_new_thread_id, p_target_user_id, 'invite_sent');

  -- Mensagem inicial (colunas corretas: thread_id + author_id)
  IF p_initial_message IS NOT NULL AND btrim(p_initial_message) <> '' THEN
    INSERT INTO chat_messages (thread_id, author_id, type, content)
    VALUES (v_new_thread_id, v_caller, 'text', p_initial_message);

    UPDATE chat_threads
    SET last_message_at      = NOW(),
        last_message_preview = LEFT(p_initial_message, 100),
        last_message_author  = (SELECT nickname FROM profiles WHERE id = v_caller)
    WHERE id = v_new_thread_id;
  END IF;

  -- Notificação
  INSERT INTO notifications (
    user_id, actor_id, type, title, body, action_url
  ) VALUES (
    p_target_user_id,
    v_caller,
    'dm_invite',
    'Novo convite de DM',
    'Você recebeu um convite de mensagem direta.',
    '/chat/' || v_new_thread_id
  );

  RETURN v_new_thread_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_dm_invite(UUID, TEXT, UUID) TO authenticated;

-- ── 3. transfer_founder_title ──────────────────────────────────────────────
--
-- Transfere o cargo de Agente (Fundador) para outro líder da comunidade.
-- Usa communities.agent_id (campo correto) em vez de created_by.
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.transfer_founder_title(
  p_community_id   UUID,
  p_new_founder_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller      UUID := auth.uid();
  v_caller_role TEXT;
  v_target_role TEXT;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Caller deve ser o agente atual
  SELECT role INTO v_caller_role
  FROM community_members
  WHERE community_id = p_community_id AND user_id = v_caller;

  IF v_caller_role != 'agent' THEN
    RAISE EXCEPTION 'Apenas o Líder Fundador pode transferir este título';
  END IF;

  -- Alvo deve ser membro da equipe (não membro comum)
  SELECT role INTO v_target_role
  FROM community_members
  WHERE community_id = p_community_id AND user_id = p_new_founder_id;

  IF v_target_role NOT IN ('leader', 'curator', 'moderator') THEN
    RAISE EXCEPTION 'O novo fundador deve ser um membro da equipe da comunidade';
  END IF;

  IF p_new_founder_id = v_caller THEN
    RAISE EXCEPTION 'Você já é o Líder Fundador';
  END IF;

  -- Rebaixar caller para líder
  UPDATE community_members
  SET role = 'leader', updated_at = now()
  WHERE community_id = p_community_id AND user_id = v_caller;

  -- Promover alvo para agente
  UPDATE community_members
  SET role = 'agent', updated_at = now()
  WHERE community_id = p_community_id AND user_id = p_new_founder_id;

  -- Atualizar communities.agent_id (campo correto, não created_by)
  UPDATE communities
  SET agent_id   = p_new_founder_id,
      updated_at = now()
  WHERE id = p_community_id AND agent_id = v_caller;

  -- Registrar no histórico de moderação (tabela existente)
  INSERT INTO moderation_logs (
    community_id, moderator_id, action, severity,
    target_user_id, reason
  ) VALUES (
    p_community_id, v_caller, 'transfer_agent', 'default',
    p_new_founder_id, 'Transferência de título de Fundador'
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Título de Fundador transferido com sucesso'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_founder_title(UUID, UUID) TO authenticated;

-- ── 4. apply_member_strike ─────────────────────────────────────────────────
--
-- Aplica advertência formal via tabela strikes (existente em migration 004).
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.apply_member_strike(
  p_community_id    UUID,
  p_target_user_id  UUID,
  p_reason          TEXT DEFAULT 'Advertência formal'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller      UUID := auth.uid();
  v_caller_role TEXT;
  v_target_role TEXT;
  v_strike_id   UUID;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT role INTO v_caller_role
  FROM community_members
  WHERE community_id = p_community_id AND user_id = v_caller;

  IF v_caller_role NOT IN ('agent', 'leader', 'moderator') THEN
    RAISE EXCEPTION 'Sem permissão para aplicar strike';
  END IF;

  SELECT role INTO v_target_role
  FROM community_members
  WHERE community_id = p_community_id AND user_id = p_target_user_id;

  -- Moderadores não podem dar strike em líderes/agents
  IF v_caller_role = 'moderator' AND v_target_role IN ('agent', 'leader') THEN
    RAISE EXCEPTION 'Moderadores não podem aplicar strike em líderes';
  END IF;

  -- Líderes não podem dar strike em agents
  IF v_caller_role = 'leader' AND v_target_role = 'agent' THEN
    RAISE EXCEPTION 'Líderes não podem aplicar strike no Fundador';
  END IF;

  -- Inserir na tabela strikes (migration 004)
  INSERT INTO strikes (
    community_id, user_id, issued_by, reason, is_active
  ) VALUES (
    p_community_id, p_target_user_id, v_caller,
    COALESCE(NULLIF(btrim(p_reason), ''), 'Advertência formal'),
    true
  ) RETURNING id INTO v_strike_id;

  -- Registrar em moderation_logs
  INSERT INTO moderation_logs (
    community_id, moderator_id, action, severity,
    target_user_id, reason
  ) VALUES (
    p_community_id, v_caller, 'strike', 'warning',
    p_target_user_id, p_reason
  );

  -- Notificar o usuário
  INSERT INTO notifications (
    user_id, actor_id, type, title, body
  ) VALUES (
    p_target_user_id, v_caller,
    'moderation',
    'Advertência recebida',
    COALESCE(NULLIF(btrim(p_reason), ''), 'Você recebeu uma advertência formal.')
  );

  RETURN jsonb_build_object('success', true, 'strike_id', v_strike_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_member_strike(UUID, UUID, TEXT) TO authenticated;

-- ── 5. ban_community_member ────────────────────────────────────────────────
--
-- Bane um membro via tabela bans (existente em migration 004).
-- Duração: '1d','7d','30d','permanent'
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ban_community_member(
  p_community_id    UUID,
  p_target_user_id  UUID,
  p_duration        TEXT DEFAULT '7d',
  p_reason          TEXT DEFAULT 'Banido da comunidade'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller      UUID := auth.uid();
  v_caller_role TEXT;
  v_target_role TEXT;
  v_ban_until   TIMESTAMPTZ;
  v_is_perm     BOOLEAN;
  v_ban_id      UUID;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT role INTO v_caller_role
  FROM community_members
  WHERE community_id = p_community_id AND user_id = v_caller;

  IF v_caller_role NOT IN ('agent', 'leader', 'moderator') THEN
    RAISE EXCEPTION 'Sem permissão para banir';
  END IF;

  SELECT role INTO v_target_role
  FROM community_members
  WHERE community_id = p_community_id AND user_id = p_target_user_id;

  IF v_target_role = 'agent' THEN
    RAISE EXCEPTION 'O Líder Fundador não pode ser banido';
  END IF;

  IF v_caller_role = 'moderator' AND v_target_role IN ('leader', 'curator', 'moderator') THEN
    RAISE EXCEPTION 'Moderadores só podem banir membros comuns';
  END IF;

  IF v_caller_role = 'leader' AND v_target_role = 'leader' THEN
    RAISE EXCEPTION 'Líderes não podem banir outros líderes';
  END IF;

  -- Calcular expiração
  CASE p_duration
    WHEN '1d'        THEN v_ban_until := now() + INTERVAL '1 day';  v_is_perm := false;
    WHEN '7d'        THEN v_ban_until := now() + INTERVAL '7 days'; v_is_perm := false;
    WHEN '30d'       THEN v_ban_until := now() + INTERVAL '30 days';v_is_perm := false;
    WHEN 'permanent' THEN v_ban_until := NULL;                       v_is_perm := true;
    ELSE                  v_ban_until := now() + INTERVAL '7 days'; v_is_perm := false;
  END CASE;

  -- Inserir na tabela bans (migration 004)
  INSERT INTO bans (
    community_id, user_id, banned_by,
    reason, is_permanent, expires_at, is_active
  ) VALUES (
    p_community_id, p_target_user_id, v_caller,
    COALESCE(NULLIF(btrim(p_reason), ''), 'Banido da comunidade'),
    v_is_perm, v_ban_until, true
  ) RETURNING id INTO v_ban_id;

  -- Atualizar community_members
  UPDATE community_members
  SET
    is_banned      = true,
    ban_expires_at = v_ban_until,
    updated_at     = now()
  WHERE community_id = p_community_id
    AND user_id      = p_target_user_id;

  -- Registrar em moderation_logs
  INSERT INTO moderation_logs (
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
  INSERT INTO notifications (
    user_id, actor_id, type, title, body
  ) VALUES (
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

-- ── 6. RLS para is_hidden: membros não veem perfis ocultos ─────────────────

-- IMPORTANTE: políticas de SELECT em PostgreSQL/Supabase são permissivas e são
-- combinadas com OR. Portanto, manter a antiga policy "cm_select_members" com
-- USING (TRUE) neutralizaria completamente qualquer regra de ocultação.
-- Removemos a policy ampla e instalamos uma policy única que preserva acesso
-- ao próprio registro, expõe apenas perfis não ocultos para membros comuns e
-- mantém visibilidade total para staff da comunidade.
DROP POLICY IF EXISTS "cm_select_members" ON public.community_members;
DROP POLICY IF EXISTS "hide_hidden_profiles" ON public.community_members;
CREATE POLICY "cm_select_members_visible"
  ON public.community_members
  FOR SELECT
  USING (
    -- O próprio usuário sempre vê seu registro
    user_id = auth.uid()
    OR
    -- Perfis visíveis normalmente seguem acessíveis
    is_hidden = false
    OR
    -- Staff da comunidade vê todos (incluindo ocultos)
    EXISTS (
      SELECT 1 FROM public.community_members viewer
      WHERE viewer.community_id = community_members.community_id
        AND viewer.user_id      = auth.uid()
        AND viewer.role IN ('agent', 'leader', 'curator', 'moderator')
        AND viewer.is_banned    = false
    )
  );

