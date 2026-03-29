-- ============================================================================
-- NexusHub — Migração 027: Chat Enhancements & Post Drafts
-- Adiciona: edição de mensagem, deleção granular, DM invite, rascunhos de posts
-- ============================================================================

-- ============================================================================
-- 1. EDIÇÃO DE MENSAGEM — adicionar campo edited_at
-- ============================================================================
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

-- ============================================================================
-- 2. DELEÇÃO GRANULAR — tabela para "delete for me"
-- A deleção "para todos" já usa is_deleted + type='system_deleted'.
-- A deleção "para mim" precisa de uma tabela separada por usuário.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.message_deletions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  deleted_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(message_id, user_id)
);

ALTER TABLE public.message_deletions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='message_deletions' AND policyname='message_deletions_select_own') THEN
    CREATE POLICY "message_deletions_select_own" ON public.message_deletions
      FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='message_deletions' AND policyname='message_deletions_insert_own') THEN
    CREATE POLICY "message_deletions_insert_own" ON public.message_deletions
      FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='message_deletions' AND policyname='message_deletions_delete_own') THEN
    CREATE POLICY "message_deletions_delete_own" ON public.message_deletions
      FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_message_deletions_user ON public.message_deletions(user_id);
CREATE INDEX IF NOT EXISTS idx_message_deletions_message ON public.message_deletions(message_id);

-- ============================================================================
-- 3. RPC: edit_chat_message — Editar mensagem (SECURITY DEFINER)
-- Só o autor pode editar, e apenas mensagens de texto.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.edit_chat_message(
  p_message_id UUID,
  p_new_content TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id UUID;
  v_type TEXT;
BEGIN
  -- Verificar que a mensagem existe e pertence ao usuário
  SELECT author_id, type INTO v_author_id, v_type
  FROM chat_messages
  WHERE id = p_message_id;

  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Mensagem não encontrada';
  END IF;

  IF v_author_id != auth.uid() THEN
    RAISE EXCEPTION 'Apenas o autor pode editar a mensagem';
  END IF;

  -- Só permitir edição de mensagens de texto
  IF v_type NOT IN ('text', 'share_url') THEN
    RAISE EXCEPTION 'Apenas mensagens de texto podem ser editadas';
  END IF;

  -- Atualizar conteúdo e marcar como editada
  UPDATE chat_messages
  SET content = p_new_content,
      edited_at = NOW(),
      updated_at = NOW()
  WHERE id = p_message_id;
END;
$$;

-- ============================================================================
-- 4. RPC: delete_chat_message_for_all — Deletar para todos (SECURITY DEFINER)
-- O autor pode deletar para todos. Hosts/co-hosts também.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delete_chat_message_for_all(
  p_message_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id UUID;
  v_thread_id UUID;
  v_host_id UUID;
  v_co_hosts JSONB;
  v_caller UUID := auth.uid();
BEGIN
  -- Buscar dados da mensagem
  SELECT author_id, thread_id INTO v_author_id, v_thread_id
  FROM chat_messages
  WHERE id = p_message_id;

  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Mensagem não encontrada';
  END IF;

  -- Buscar host e co-hosts do thread
  SELECT host_id, co_hosts INTO v_host_id, v_co_hosts
  FROM chat_threads
  WHERE id = v_thread_id;

  -- Verificar permissão: autor, host ou co-host
  IF v_caller != v_author_id
     AND v_caller != v_host_id
     AND NOT (v_co_hosts IS NOT NULL AND v_co_hosts @> to_jsonb(v_caller::text))
  THEN
    RAISE EXCEPTION 'Sem permissão para deletar esta mensagem';
  END IF;

  -- Soft delete: marcar como deletada
  UPDATE chat_messages
  SET type = 'system_deleted',
      content = 'Mensagem apagada',
      is_deleted = TRUE,
      deleted_by = v_caller,
      media_url = NULL,
      media_type = NULL,
      sticker_id = NULL,
      sticker_url = NULL,
      shared_url = NULL,
      updated_at = NOW()
  WHERE id = p_message_id;
END;
$$;

-- ============================================================================
-- 5. RPC: delete_chat_message_for_me — Deletar apenas para o usuário atual
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delete_chat_message_for_me(
  p_message_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verificar que a mensagem existe
  IF NOT EXISTS (SELECT 1 FROM chat_messages WHERE id = p_message_id) THEN
    RAISE EXCEPTION 'Mensagem não encontrada';
  END IF;

  -- Inserir na tabela de deleções pessoais (UPSERT)
  INSERT INTO message_deletions (message_id, user_id)
  VALUES (p_message_id, auth.uid())
  ON CONFLICT (message_id, user_id) DO NOTHING;
END;
$$;

-- ============================================================================
-- 6. RPC: send_dm_invite — Enviar convite de DM respeitando privacidade
-- ============================================================================
CREATE OR REPLACE FUNCTION public.send_dm_invite(
  p_target_user_id UUID,
  p_initial_message TEXT DEFAULT NULL
)
RETURNS UUID  -- Retorna o thread_id
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_existing_thread_id UUID;
  v_new_thread_id UUID;
  v_target_privacy privacy_level;
  v_is_following BOOLEAN;
  v_is_blocked BOOLEAN;
BEGIN
  -- Não pode enviar DM para si mesmo
  IF v_caller = p_target_user_id THEN
    RAISE EXCEPTION 'Não é possível enviar DM para si mesmo';
  END IF;

  -- Verificar se está bloqueado
  SELECT EXISTS(
    SELECT 1 FROM blocks
    WHERE (blocker_id = p_target_user_id AND blocked_id = v_caller)
       OR (blocker_id = v_caller AND blocked_id = p_target_user_id)
  ) INTO v_is_blocked;

  IF v_is_blocked THEN
    RAISE EXCEPTION 'Não é possível enviar mensagem para este usuário';
  END IF;

  -- Verificar privacidade de chat_invite do target
  SELECT COALESCE(privilege_chat_invite, 'everyone')
  INTO v_target_privacy
  FROM profiles
  WHERE id = p_target_user_id;

  -- Verificar se o caller segue o target (para nível 'following')
  SELECT EXISTS(
    SELECT 1 FROM follows
    WHERE follower_id = v_caller AND following_id = p_target_user_id
  ) INTO v_is_following;

  -- Aplicar regra de privacidade
  IF v_target_privacy = 'nobody' THEN
    RAISE EXCEPTION 'Este usuário não aceita mensagens diretas';
  ELSIF v_target_privacy = 'following' AND NOT v_is_following THEN
    RAISE EXCEPTION 'Este usuário só aceita DMs de pessoas que ele segue';
  END IF;
  -- 'everyone' permite qualquer um

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
  IF p_initial_message IS NOT NULL AND p_initial_message != '' THEN
    INSERT INTO chat_messages (thread_id, author_id, type, content)
    VALUES (v_new_thread_id, v_caller, 'text', p_initial_message);

    UPDATE chat_threads
    SET last_message_at = NOW(),
        last_message_preview = LEFT(p_initial_message, 100),
        last_message_author = (SELECT nickname FROM profiles WHERE id = v_caller)
    WHERE id = v_new_thread_id;
  END IF;

  -- Criar notificação para o target
  INSERT INTO notifications (user_id, notification_type, title, body, data)
  VALUES (
    p_target_user_id,
    'chat',
    'Nova mensagem direta',
    COALESCE(
      (SELECT nickname FROM profiles WHERE id = v_caller),
      'Alguém'
    ) || ' quer conversar com você',
    jsonb_build_object('thread_id', v_new_thread_id, 'sender_id', v_caller, 'type', 'dm_invite')
  );

  RETURN v_new_thread_id;
END;
$$;

-- ============================================================================
-- 7. RPC: respond_dm_invite — Aceitar ou recusar convite de DM
-- ============================================================================
CREATE OR REPLACE FUNCTION public.respond_dm_invite(
  p_thread_id UUID,
  p_accept BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_current_status TEXT;
BEGIN
  -- Verificar status atual
  SELECT status::text INTO v_current_status
  FROM chat_members
  WHERE thread_id = p_thread_id AND user_id = v_caller;

  IF v_current_status IS NULL THEN
    RAISE EXCEPTION 'Convite não encontrado';
  END IF;

  IF v_current_status != 'invite_sent' THEN
    RAISE EXCEPTION 'Não há convite pendente para este chat';
  END IF;

  IF p_accept THEN
    -- Aceitar: mudar status para active
    UPDATE chat_members
    SET status = 'active', joined_at = NOW()
    WHERE thread_id = p_thread_id AND user_id = v_caller;
  ELSE
    -- Recusar: remover membership
    DELETE FROM chat_members
    WHERE thread_id = p_thread_id AND user_id = v_caller;
  END IF;
END;
$$;

-- ============================================================================
-- 8. POST DRAFTS — Tabela para rascunhos de posts
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.post_drafts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id UUID REFERENCES public.communities(id) ON DELETE SET NULL,

  -- Conteúdo do rascunho
  title TEXT,
  content TEXT,
  content_blocks JSONB,  -- Blocos de conteúdo estruturado
  media_urls JSONB DEFAULT '[]'::jsonb,  -- Array de URLs de mídia
  post_type TEXT DEFAULT 'text',  -- text, image, blog, poll, quiz, link

  -- Metadados
  tags JSONB DEFAULT '[]'::jsonb,
  visibility TEXT DEFAULT 'public',

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.post_drafts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_drafts' AND policyname='post_drafts_select_own') THEN
    CREATE POLICY "post_drafts_select_own" ON public.post_drafts
      FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_drafts' AND policyname='post_drafts_insert_own') THEN
    CREATE POLICY "post_drafts_insert_own" ON public.post_drafts
      FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_drafts' AND policyname='post_drafts_update_own') THEN
    CREATE POLICY "post_drafts_update_own" ON public.post_drafts
      FOR UPDATE USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_drafts' AND policyname='post_drafts_delete_own') THEN
    CREATE POLICY "post_drafts_delete_own" ON public.post_drafts
      FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_post_drafts_user ON public.post_drafts(user_id);
CREATE INDEX IF NOT EXISTS idx_post_drafts_updated ON public.post_drafts(updated_at DESC);
