-- ============================================================================
-- MIGRAÇÃO 046: RPCs faltantes chamadas pelo frontend
-- Criadas durante auditoria arquitetural - 03/04/2026
-- ============================================================================

-- ============================================================================
-- 1. create_call_session
--    Cria uma sessão de chamada de voz/vídeo em um chat thread.
--    Parâmetros: p_thread_id UUID, p_type TEXT ('voice'|'video'|'screening_room')
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_call_session(
  p_thread_id UUID,
  p_type TEXT DEFAULT 'voice'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_session_id UUID;
  v_is_member BOOLEAN;
BEGIN
  -- Validar autenticação
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Validar tipo
  IF p_type NOT IN ('voice', 'video', 'screening_room') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_call_type');
  END IF;

  -- Verificar membership no chat
  SELECT EXISTS(
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id AND user_id = v_user_id AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Verificar se já existe uma chamada ativa neste thread
  IF EXISTS(
    SELECT 1 FROM public.call_sessions
    WHERE thread_id = p_thread_id AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'call_already_active');
  END IF;

  -- Criar sessão
  INSERT INTO public.call_sessions (thread_id, created_by, type, status)
  VALUES (p_thread_id, v_user_id, p_type, 'active')
  RETURNING id INTO v_session_id;

  -- Adicionar criador como participante
  INSERT INTO public.call_participants (call_session_id, user_id, status, joined_at)
  VALUES (v_session_id, v_user_id, 'connected', NOW());

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id
  );
END;
$$;

-- ============================================================================
-- 2. join_call_session
--    Permite que um membro do chat entre em uma chamada ativa.
--    Parâmetros: p_session_id UUID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.join_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_thread_id UUID;
  v_is_member BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Buscar thread da sessão e verificar se está ativa
  SELECT thread_id INTO v_thread_id
  FROM public.call_sessions
  WHERE id = p_session_id AND status = 'active';

  IF v_thread_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found_or_ended');
  END IF;

  -- Verificar membership no chat
  SELECT EXISTS(
    SELECT 1 FROM public.chat_members
    WHERE thread_id = v_thread_id AND user_id = v_user_id AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Upsert participante (suporta reconexão)
  INSERT INTO public.call_participants (call_session_id, user_id, status, joined_at)
  VALUES (p_session_id, v_user_id, 'connected', NOW())
  ON CONFLICT (call_session_id, user_id)
  DO UPDATE SET status = 'connected', joined_at = NOW();

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================================
-- 3. leave_call_session
--    Marca o participante como desconectado. Se ninguém mais estiver
--    conectado, encerra a sessão automaticamente.
--    Parâmetros: p_session_id UUID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.leave_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_remaining INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Marcar como desconectado
  UPDATE public.call_participants
  SET status = 'disconnected', left_at = NOW()
  WHERE call_session_id = p_session_id AND user_id = v_user_id;

  -- Contar participantes ainda conectados
  SELECT COUNT(*) INTO v_remaining
  FROM public.call_participants
  WHERE call_session_id = p_session_id AND status = 'connected';

  -- Se ninguém mais está conectado, encerrar a sessão
  IF v_remaining = 0 THEN
    UPDATE public.call_sessions
    SET status = 'ended', ended_at = NOW()
    WHERE id = p_session_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'session_ended', v_remaining = 0);
END;
$$;

-- ============================================================================
-- 4. end_call_session
--    Encerra uma sessão de chamada (apenas o criador pode encerrar).
--    Parâmetros: p_session_id UUID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.end_call_session(
  p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_created_by UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar se é o criador da chamada
  SELECT created_by INTO v_created_by
  FROM public.call_sessions
  WHERE id = p_session_id AND status = 'active';

  IF v_created_by IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  IF v_created_by != v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_the_creator');
  END IF;

  -- Desconectar todos os participantes
  UPDATE public.call_participants
  SET status = 'disconnected', left_at = NOW()
  WHERE call_session_id = p_session_id AND status = 'connected';

  -- Encerrar a sessão
  UPDATE public.call_sessions
  SET status = 'ended', ended_at = NOW()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================================
-- 5. create_group_chat
--    Cria um chat em grupo com membros iniciais.
--    Parâmetros: p_community_id, p_title, p_description, p_icon_url,
--                p_is_public, p_member_ids
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_group_chat(
  p_community_id UUID,
  p_title TEXT,
  p_description TEXT DEFAULT NULL,
  p_icon_url TEXT DEFAULT NULL,
  p_is_public BOOLEAN DEFAULT FALSE,
  p_member_ids UUID[] DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_thread_id UUID;
  v_thread_type public.chat_thread_type;
  v_member_id UUID;
  v_is_community_member BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar membership na comunidade
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id AND user_id = v_user_id AND status = 'active'
  ) INTO v_is_community_member;

  IF NOT v_is_community_member THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_community_member');
  END IF;

  -- Determinar tipo
  v_thread_type := CASE WHEN p_is_public THEN 'public' ELSE 'group' END;

  -- Criar thread
  INSERT INTO public.chat_threads (
    community_id, type, title, description, icon_url, host_id, members_count
  )
  VALUES (
    p_community_id, v_thread_type, p_title, p_description, p_icon_url,
    v_user_id, 1 + COALESCE(array_length(p_member_ids, 1), 0)
  )
  RETURNING id INTO v_thread_id;

  -- Adicionar criador como membro
  INSERT INTO public.chat_members (thread_id, user_id, status, joined_at)
  VALUES (v_thread_id, v_user_id, 'active', NOW());

  -- Adicionar membros convidados
  IF p_member_ids IS NOT NULL THEN
    FOREACH v_member_id IN ARRAY p_member_ids
    LOOP
      INSERT INTO public.chat_members (thread_id, user_id, status, joined_at)
      VALUES (v_thread_id, v_member_id, 'active', NOW())
      ON CONFLICT (thread_id, user_id) DO NOTHING;
    END LOOP;
  END IF;

  -- Criar mensagem de sistema
  INSERT INTO public.chat_messages (thread_id, author_id, type, content)
  VALUES (v_thread_id, v_user_id, 'system', 'Grupo criado');

  RETURN jsonb_build_object(
    'success', true,
    'thread_id', v_thread_id
  );
END;
$$;

-- ============================================================================
-- 6. create_quiz_with_questions
--    Cria um post do tipo quiz com perguntas e opções de forma atômica.
--    Parâmetros: p_community_id, p_title, p_content, p_media_urls,
--                p_questions (JSONB array), p_allow_comments
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_quiz_with_questions(
  p_community_id UUID,
  p_title TEXT,
  p_content TEXT DEFAULT '',
  p_media_urls JSONB DEFAULT '[]'::jsonb,
  p_questions JSONB DEFAULT '[]'::jsonb,
  p_allow_comments BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_post_id UUID;
  v_question JSONB;
  v_question_id UUID;
  v_option JSONB;
  v_correct_idx INTEGER;
  v_opt_idx INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar membership na comunidade
  IF NOT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id AND user_id = v_user_id AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_community_member');
  END IF;

  -- Criar o post do tipo quiz
  INSERT INTO public.posts (
    community_id, author_id, type, title, content,
    media_list, allow_comments
  )
  VALUES (
    p_community_id, v_user_id, 'quiz', p_title, p_content,
    p_media_urls, p_allow_comments
  )
  RETURNING id INTO v_post_id;

  -- Criar perguntas e opções
  FOR i IN 0 .. jsonb_array_length(p_questions) - 1
  LOOP
    v_question := p_questions->i;
    v_correct_idx := COALESCE((v_question->>'correct_option_index')::int, 0);

    INSERT INTO public.quiz_questions (post_id, question_text, sort_order)
    VALUES (v_post_id, v_question->>'question_text', i)
    RETURNING id INTO v_question_id;

    -- Inserir opções
    v_opt_idx := 0;
    FOR j IN 0 .. jsonb_array_length(v_question->'options') - 1
    LOOP
      v_option := (v_question->'options')->j;
      INSERT INTO public.quiz_options (question_id, text, is_correct, sort_order)
      VALUES (
        v_question_id,
        v_option->>'text',
        j = v_correct_idx,
        j
      );
    END LOOP;
  END LOOP;

  -- Adicionar reputação
  PERFORM public.add_reputation(v_user_id, p_community_id, 'post_quiz', 5);

  RETURN jsonb_build_object(
    'success', true,
    'post_id', v_post_id
  );
END;
$$;

-- ============================================================================
-- 7. increment_story_views
--    Incrementa o contador de views de um story (idempotente por viewer).
--    Parâmetros: p_story_id UUID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.increment_story_views(
  p_story_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_inserted BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  -- Inserir view (idempotente via UNIQUE constraint)
  INSERT INTO public.story_views (story_id, viewer_id)
  VALUES (p_story_id, v_user_id)
  ON CONFLICT (story_id, viewer_id) DO NOTHING;

  -- Verificar se foi inserido (nova view)
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  -- Incrementar contador apenas se é uma nova view
  IF v_inserted THEN
    UPDATE public.stories
    SET views_count = views_count + 1
    WHERE id = p_story_id;
  END IF;
END;
$$;

-- ============================================================================
-- 8. mark_chat_read
--    Marca todas as mensagens de um chat como lidas para o usuário.
--    Parâmetros: p_thread_id UUID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_chat_read(
  p_thread_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.chat_members
  SET last_read_at = NOW(), unread_count = 0
  WHERE thread_id = p_thread_id AND user_id = v_user_id;
END;
$$;

-- ============================================================================
-- 9. pin_message
--    Fixa uma mensagem no chat (apenas host/co-host pode fixar).
--    Parâmetros: p_thread_id UUID, p_message_id UUID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.pin_message(
  p_thread_id UUID,
  p_message_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_host_id UUID;
  v_co_hosts JSONB;
  v_is_authorized BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar se a mensagem pertence ao thread
  IF NOT EXISTS(
    SELECT 1 FROM public.chat_messages
    WHERE id = p_message_id AND thread_id = p_thread_id AND is_deleted = FALSE
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_not_found');
  END IF;

  -- Verificar permissão (host ou co-host)
  SELECT host_id, co_hosts INTO v_host_id, v_co_hosts
  FROM public.chat_threads WHERE id = p_thread_id;

  IF v_user_id = v_host_id THEN
    v_is_authorized := TRUE;
  ELSIF v_co_hosts IS NOT NULL AND v_co_hosts @> to_jsonb(v_user_id::text) THEN
    v_is_authorized := TRUE;
  END IF;

  -- Verificar se é moderador/agent da comunidade
  IF NOT v_is_authorized THEN
    IF EXISTS(
      SELECT 1 FROM public.community_members cm
      JOIN public.chat_threads ct ON ct.community_id = cm.community_id
      WHERE ct.id = p_thread_id AND cm.user_id = v_user_id
        AND cm.role IN ('agent', 'leader')
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  -- Fixar a mensagem
  UPDATE public.chat_threads
  SET pinned_message_id = p_message_id, updated_at = NOW()
  WHERE id = p_thread_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================================
-- 10. send_broadcast
--     Envia um broadcast para membros de uma comunidade.
--     Parâmetros: p_title, p_content, p_scope, p_community_id, p_action_url
-- ============================================================================
CREATE OR REPLACE FUNCTION public.send_broadcast(
  p_title TEXT,
  p_content TEXT,
  p_scope TEXT DEFAULT 'community',
  p_community_id UUID DEFAULT NULL,
  p_action_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_broadcast_id UUID;
  v_is_authorized BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar permissão: deve ser agent/leader da comunidade ou team member
  IF p_community_id IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public.community_members
      WHERE community_id = p_community_id AND user_id = v_user_id
        AND role IN ('agent', 'leader')
        AND status = 'active'
    ) INTO v_is_authorized;
  END IF;

  -- Verificar se é team member (admin global)
  IF NOT v_is_authorized THEN
    SELECT EXISTS(
      SELECT 1 FROM public.profiles
      WHERE id = v_user_id AND is_team_admin = TRUE
    ) INTO v_is_authorized;
  END IF;

  IF NOT v_is_authorized THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  -- Inserir broadcast
  INSERT INTO public.broadcasts (
    author_id, community_id, title, content, action_url, status
  )
  VALUES (
    v_user_id, p_community_id, p_title, p_content, p_action_url, 'sent'
  )
  RETURNING id INTO v_broadcast_id;

  -- Criar notificações para membros da comunidade
  IF p_community_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    SELECT
      cm.user_id,
      'broadcast',
      p_title,
      LEFT(p_content, 200),
      jsonb_build_object(
        'broadcast_id', v_broadcast_id,
        'community_id', p_community_id,
        'action_url', p_action_url
      )
    FROM public.community_members cm
    WHERE cm.community_id = p_community_id
      AND cm.status = 'active'
      AND cm.user_id != v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'broadcast_id', v_broadcast_id
  );
END;
$$;

-- ============================================================================
-- 11. toggle_chat_pin
--     Fixa ou desfixa um chat thread (toggle is_pinned).
--     Apenas host/agent/leader pode fixar.
--     Parâmetros: p_thread_id UUID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.toggle_chat_pin(
  p_thread_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_host_id UUID;
  v_community_id UUID;
  v_current_pinned BOOLEAN;
  v_is_authorized BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Buscar dados do thread
  SELECT host_id, community_id, is_pinned
  INTO v_host_id, v_community_id, v_current_pinned
  FROM public.chat_threads WHERE id = p_thread_id;

  IF v_host_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'thread_not_found');
  END IF;

  -- Verificar permissão
  IF v_user_id = v_host_id THEN
    v_is_authorized := TRUE;
  ELSIF v_community_id IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public.community_members
      WHERE community_id = v_community_id AND user_id = v_user_id
        AND role IN ('agent', 'leader') AND status = 'active'
    ) INTO v_is_authorized;
  END IF;

  IF NOT v_is_authorized THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  -- Toggle pin
  UPDATE public.chat_threads
  SET is_pinned = NOT v_current_pinned, updated_at = NOW()
  WHERE id = p_thread_id;

  RETURN jsonb_build_object(
    'success', true,
    'is_pinned', NOT v_current_pinned
  );
END;
$$;

-- ============================================================================
-- 12. toggle_reaction
--     Adiciona ou remove uma reação (emoji) em uma mensagem de chat.
--     Armazena no campo JSONB reactions do chat_messages.
--     Parâmetros: p_message_id UUID, p_emoji TEXT
-- ============================================================================
CREATE OR REPLACE FUNCTION public.toggle_reaction(
  p_message_id UUID,
  p_emoji TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_thread_id UUID;
  v_current_reactions JSONB;
  v_emoji_users JSONB;
  v_user_id_text TEXT;
  v_is_member BOOLEAN;
  v_added BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_user_id_text := v_user_id::text;

  -- Buscar mensagem e verificar existência
  SELECT thread_id, COALESCE(reactions, '{}'::jsonb)
  INTO v_thread_id, v_current_reactions
  FROM public.chat_messages
  WHERE id = p_message_id AND is_deleted = FALSE;

  IF v_thread_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_not_found');
  END IF;

  -- Verificar membership no chat
  SELECT EXISTS(
    SELECT 1 FROM public.chat_members
    WHERE thread_id = v_thread_id AND user_id = v_user_id AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  -- Obter array atual de users para este emoji
  v_emoji_users := COALESCE(v_current_reactions->p_emoji, '[]'::jsonb);

  -- Toggle: se já reagiu, remover; senão, adicionar
  IF v_emoji_users @> to_jsonb(v_user_id_text) THEN
    -- Remover
    v_emoji_users := (
      SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
      FROM jsonb_array_elements(v_emoji_users) AS elem
      WHERE elem #>> '{}' != v_user_id_text
    );
    v_added := FALSE;
  ELSE
    -- Adicionar
    v_emoji_users := v_emoji_users || to_jsonb(v_user_id_text);
    v_added := TRUE;
  END IF;

  -- Atualizar ou remover o emoji do mapa
  IF jsonb_array_length(v_emoji_users) = 0 THEN
    v_current_reactions := v_current_reactions - p_emoji;
  ELSE
    v_current_reactions := jsonb_set(v_current_reactions, ARRAY[p_emoji], v_emoji_users);
  END IF;

  -- Salvar
  UPDATE public.chat_messages
  SET reactions = v_current_reactions
  WHERE id = p_message_id;

  RETURN jsonb_build_object('success', true, 'added', v_added);
END;
$$;

-- ============================================================================
-- 13. increment_post_views
--     Incrementa atomicamente o views_count de um post.
--     Evita race condition do padrão read-then-write no cliente.
--     Parâmetros: p_post_id UUID
-- ============================================================================
CREATE OR REPLACE FUNCTION public.increment_post_views(
  p_post_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.posts
  SET views_count = views_count + 1
  WHERE id = p_post_id;
END;
$$;
