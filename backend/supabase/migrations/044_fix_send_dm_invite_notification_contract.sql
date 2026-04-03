-- ============================================================================
-- Migration 044: Fix send_dm_invite notification contract
-- Corrige a RPC para usar o schema real de notifications.
-- ============================================================================

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
    WHERE thread_id = v_existing_thread_id AND user_id = v_caller AND status != 'active';
    RETURN v_existing_thread_id;
  END IF;

  -- Criar novo thread DM
  INSERT INTO chat_threads (type, host_id, members_count)
  VALUES ('dm', v_caller, 2)
  RETURNING id INTO v_new_thread_id;

  -- Adicionar o caller como membro ativo
  INSERT INTO chat_members (thread_id, user_id, status)
  VALUES (v_new_thread_id, v_caller, 'active');

  -- Adicionar o target como invite_sent
  INSERT INTO chat_members (thread_id, user_id, status)
  VALUES (v_new_thread_id, p_target_user_id, 'invite_sent');

  -- Se houver mensagem inicial, enviar
  IF p_initial_message IS NOT NULL AND btrim(p_initial_message) <> '' THEN
    INSERT INTO chat_messages (thread_id, author_id, type, content)
    VALUES (v_new_thread_id, v_caller, 'text', p_initial_message);

    UPDATE chat_threads
    SET last_message_at = NOW(),
        last_message_preview = LEFT(p_initial_message, 100),
        last_message_author = (SELECT nickname FROM profiles WHERE id = v_caller)
    WHERE id = v_new_thread_id;
  END IF;

  -- Criar notificação para o target usando o contrato real da tabela
  INSERT INTO notifications (
    user_id,
    actor_id,
    type,
    title,
    body,
    chat_thread_id,
    action_url
  )
  VALUES (
    p_target_user_id,
    v_caller,
    'chat_invite',
    'Nova mensagem direta',
    COALESCE(
      (SELECT nickname FROM profiles WHERE id = v_caller),
      'Alguém'
    ) || ' quer conversar com você',
    v_new_thread_id,
    '/chat/' || v_new_thread_id::text
  );

  RETURN v_new_thread_id;
END;
$$;
