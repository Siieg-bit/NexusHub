-- ─────────────────────────────────────────────────────────────
-- 049_block_user_system.sql
-- Sistema de Bloqueio Completo com Isolamento Total
-- ─────────────────────────────────────────────────────────────
-- A tabela `blocks` já existe (migration 001).
-- Esta migration adiciona:
--   1. RPC block_user   — bloquear com validações
--   2. RPC unblock_user — desbloquear por blocked_id (não por block UUID)
--   3. RPC get_blocked_ids — retorna todos os IDs bloqueados/bloqueadores
--   4. RLS policies em posts/comments para filtrar automaticamente
--   5. Atualiza send_dm_invite (migration 044) para verificar bloqueio
--      na versão mais recente (já feito em 027, mas garantindo)
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- 1. RPC block_user
--    Bloqueia um usuário. Ao bloquear:
--      - Remove follows mútuos
--      - Remove DM threads ativas entre os dois
--      - Não pode bloquear a si mesmo
--      - Idempotente (se já bloqueado, retorna sem erro)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_already_blocked BOOLEAN;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_blocked_id IS NULL OR p_blocked_id = v_caller THEN
    RAISE EXCEPTION 'ID de usuário inválido';
  END IF;

  -- Verificar se o alvo existe
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_blocked_id) THEN
    RAISE EXCEPTION 'Usuário não encontrado';
  END IF;

  -- Idempotente: se já bloqueado, retorna sucesso sem erro
  SELECT EXISTS(
    SELECT 1 FROM public.blocks
    WHERE blocker_id = v_caller AND blocked_id = p_blocked_id
  ) INTO v_already_blocked;

  IF NOT v_already_blocked THEN
    -- Inserir bloqueio
    INSERT INTO public.blocks (blocker_id, blocked_id)
    VALUES (v_caller, p_blocked_id)
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    -- Remover follows mútuos (ambas as direções)
    DELETE FROM public.follows
    WHERE (follower_id = v_caller AND following_id = p_blocked_id)
       OR (follower_id = p_blocked_id AND following_id = v_caller);

    -- Desativar DM threads entre os dois (não deletar, apenas ocultar)
    UPDATE public.chat_members
    SET status = 'hidden'
    WHERE status = 'active'
      AND thread_id IN (
        SELECT ct.id FROM public.chat_threads ct
        JOIN public.chat_members cm1 ON cm1.thread_id = ct.id AND cm1.user_id = v_caller
        JOIN public.chat_members cm2 ON cm2.thread_id = ct.id AND cm2.user_id = p_blocked_id
        WHERE ct.type = 'dm'
      );
  END IF;

  RETURN jsonb_build_object('success', true, 'already_blocked', v_already_blocked);
END;
$$;

GRANT EXECUTE ON FUNCTION public.block_user(UUID) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 2. RPC unblock_user
--    Desbloqueia por blocked_id (não por block UUID).
--    Mais seguro e conveniente para o cliente.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_deleted INT;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_blocked_id IS NULL THEN
    RAISE EXCEPTION 'ID de usuário inválido';
  END IF;

  DELETE FROM public.blocks
  WHERE blocker_id = v_caller AND blocked_id = p_blocked_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('success', true, 'unblocked', v_deleted > 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.unblock_user(UUID) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. RPC get_blocked_ids
--    Retorna todos os IDs com os quais o usuário tem relação
--    de bloqueio (em qualquer direção). Usado pelo Flutter para
--    filtrar feeds localmente quando RLS não é suficiente.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_blocked_ids()
RETURNS UUID[]
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT ARRAY(
    SELECT DISTINCT
      CASE
        WHEN blocker_id = auth.uid() THEN blocked_id
        ELSE blocker_id
      END
    FROM public.blocks
    WHERE blocker_id = auth.uid()
       OR blocked_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_blocked_ids() TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 4. RLS policies em posts: ocultar posts de/para bloqueados
--    Adiciona policy de SELECT que filtra automaticamente
--    posts de usuários com relação de bloqueio.
-- ─────────────────────────────────────────────────────────────

-- Remover policy existente se houver (para recriar)
DROP POLICY IF EXISTS "posts_no_blocked_users" ON public.posts;

CREATE POLICY "posts_no_blocked_users" ON public.posts
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    NOT EXISTS (
      SELECT 1 FROM public.blocks
      WHERE (blocker_id = auth.uid() AND blocked_id = posts.author_id)
         OR (blocker_id = posts.author_id AND blocked_id = auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 5. RLS policies em comments: ocultar comentários de/para bloqueados
-- ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "comments_no_blocked_users" ON public.comments;

CREATE POLICY "comments_no_blocked_users" ON public.comments
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    NOT EXISTS (
      SELECT 1 FROM public.blocks
      WHERE (blocker_id = auth.uid() AND blocked_id = comments.author_id)
         OR (blocker_id = comments.author_id AND blocked_id = auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 6. Atualizar send_dm_invite para verificar bloqueio bidirecional
--    (já existe em 027/044, mas garantindo a versão mais recente)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_dm_invite(
  p_target_user_id UUID,
  p_initial_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_target_privacy TEXT;
  v_is_follower BOOLEAN;
  v_is_following BOOLEAN;
  v_is_blocked BOOLEAN;
  v_existing_thread_id UUID;
  v_new_thread_id UUID;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_target_user_id IS NULL OR p_target_user_id = v_caller THEN
    RAISE EXCEPTION 'Usuário alvo inválido';
  END IF;

  -- Verificar se target existe
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_target_user_id) THEN
    RAISE EXCEPTION 'Usuário não encontrado';
  END IF;

  -- Verificar bloqueio bidirecional
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

  -- Verificar privacidade de chat_invite do target
  SELECT COALESCE(privilege_chat_invite, 'everyone')
  INTO v_target_privacy
  FROM profiles
  WHERE id = p_target_user_id;

  IF v_target_privacy = 'nobody' THEN
    RAISE EXCEPTION 'Este usuário não aceita convites de DM';
  ELSIF v_target_privacy = 'followers' AND NOT v_is_follower THEN
    RAISE EXCEPTION 'Este usuário só aceita DMs de seguidores';
  ELSIF v_target_privacy = 'following' AND NOT v_is_following THEN
    RAISE EXCEPTION 'Este usuário só aceita DMs de pessoas que ele segue';
  END IF;

  -- Verificar se já existe um DM thread entre os dois
  SELECT ct.id INTO v_existing_thread_id
  FROM chat_threads ct
  JOIN chat_members cm1 ON cm1.thread_id = ct.id AND cm1.user_id = v_caller
  JOIN chat_members cm2 ON cm2.thread_id = ct.id AND cm2.user_id = p_target_user_id
  WHERE ct.type = 'dm'
  LIMIT 1;

  IF v_existing_thread_id IS NOT NULL THEN
    -- Reativar memberships se necessário
    UPDATE chat_members SET status = 'active'
    WHERE thread_id = v_existing_thread_id
      AND user_id = v_caller
      AND status != 'active';
    RETURN v_existing_thread_id;
  END IF;

  -- Criar novo thread DM
  INSERT INTO chat_threads (type, host_id, members_count)
  VALUES ('dm', v_caller, 2)
  RETURNING id INTO v_new_thread_id;

  -- Adicionar ambos como membros
  INSERT INTO chat_members (thread_id, user_id, role, status)
  VALUES
    (v_new_thread_id, v_caller, 'member', 'active'),
    (v_new_thread_id, p_target_user_id, 'member', 'pending');

  -- Enviar mensagem inicial se fornecida
  IF p_initial_message IS NOT NULL AND length(trim(p_initial_message)) > 0 THEN
    INSERT INTO chat_messages (thread_id, sender_id, content, type)
    VALUES (v_new_thread_id, v_caller, p_initial_message, 'text');
  END IF;

  -- Notificar o target
  INSERT INTO notifications (user_id, type, title, body, actor_id, action_url)
  VALUES (
    p_target_user_id,
    'dm_invite',
    'Novo convite de DM',
    'Você recebeu um convite de mensagem direta.',
    v_caller,
    '/chat/' || v_new_thread_id
  );

  RETURN v_new_thread_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_dm_invite(UUID, TEXT) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 7. Índice para performance nas queries de bloqueio
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON public.blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON public.blocks(blocked_id);
CREATE INDEX IF NOT EXISTS idx_blocks_both ON public.blocks(blocker_id, blocked_id);
