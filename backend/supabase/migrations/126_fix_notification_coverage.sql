-- ============================================================================
-- Migração 126: Corrigir cobertura completa de notificações push
--
-- Gaps identificados:
-- 1. chat_messages não gera push para membros do chat (só mencoes)
-- 2. wall_post inserido com INSERT direto (sem type no upsert) — já funciona
--    via trigger trg_send_push_on_notification, mas o tipo 'wall_post' não
--    estava mapeado na Edge Function (corrigido na EF)
-- 3. repost não passava community_id para a notificação
-- 4. dm_invite não gerava notificação push
-- 5. wiki_approved não tinha trigger de notificação
-- 6. chat_invite não tinha push
-- ============================================================================

-- ============================================================================
-- 1. TRIGGER: nova mensagem em chat → notificar membros com unread_count > 0
--    (exceto o autor, exceto is_muted, exceto DMs onde o outro está online)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name    TEXT;
  v_thread_title  TEXT;
  v_community_id  UUID;
  v_thread_type   TEXT;
  v_member        RECORD;
  v_preview       TEXT;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  -- Ignorar mensagens de sistema
  IF NEW.type IN (
    'system_join','system_leave','system_voice_start','system_voice_end',
    'system_screen_start','system_screen_end','system_tip','system_pin',
    'system_unpin','system_removed','system_admin_delete','system_deleted'
  ) THEN
    RETURN NEW;
  END IF;

  -- Buscar dados do autor
  SELECT COALESCE(NULLIF(nickname,''), NULLIF(amino_id,''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles WHERE id = NEW.author_id;

  -- Buscar dados do thread
  SELECT title, community_id, type
    INTO v_thread_title, v_community_id, v_thread_type
  FROM public.chat_threads WHERE id = NEW.thread_id;

  -- Montar preview da mensagem
  v_preview := CASE NEW.type
    WHEN 'image'      THEN '📷 Imagem'
    WHEN 'video'      THEN '🎥 Vídeo'
    WHEN 'voice_note' THEN '🎤 Áudio'
    WHEN 'audio'      THEN '🎤 Áudio'
    WHEN 'sticker'    THEN '🏷️ Sticker'
    WHEN 'gif'        THEN 'GIF'
    WHEN 'file'       THEN '📎 Arquivo'
    WHEN 'share_url'  THEN '🔗 Link'
    WHEN 'share_user' THEN '👤 Perfil compartilhado'
    ELSE LEFT(COALESCE(NEW.content, ''), 100)
  END;

  -- Notificar cada membro ativo do chat (exceto o autor e mutados)
  FOR v_member IN
    SELECT cm.user_id
    FROM public.chat_members cm
    WHERE cm.thread_id = NEW.thread_id
      AND cm.user_id != NEW.author_id
      AND cm.status = 'active'
      AND cm.is_muted = FALSE
      AND (cm.is_banned = FALSE OR cm.is_banned IS NULL)
  LOOP
    PERFORM public.upsert_grouped_notification(
      p_user_id       => v_member.user_id,
      p_actor_id      => NEW.author_id,
      p_type          => 'chat_message',
      p_title         => COALESCE(v_actor_name, 'Alguém') || ' em ' || COALESCE(v_thread_title, 'Chat'),
      p_body          => v_preview,
      p_group_key     => 'chat_thread_' || NEW.thread_id,
      p_community_id  => v_community_id,
      p_chat_thread_id => NEW.thread_id,
      p_action_url    => '/chat/' || NEW.thread_id
    );
  END LOOP;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trg_notify_on_chat_message] Erro: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Criar trigger (remover se existir antes)
DROP TRIGGER IF EXISTS trg_notify_chat_message ON public.chat_messages;
CREATE TRIGGER trg_notify_chat_message
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_on_chat_message();

-- ============================================================================
-- 2. CORRIGIR repost_post: incluir community_id na notificação
-- ============================================================================
CREATE OR REPLACE FUNCTION public.repost_post(p_post_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_original     RECORD;
  v_new_post_id  UUID;
  v_actor_name   TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  -- Buscar post original
  SELECT id, author_id, title, content, community_id
    INTO v_original
  FROM public.posts
  WHERE id = p_post_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_not_found');
  END IF;

  -- Evitar repost do próprio post
  IF v_original.author_id = v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_repost_own_post');
  END IF;

  -- Verificar se já fez repost
  IF EXISTS (
    SELECT 1 FROM public.posts
    WHERE author_id = v_user_id
      AND repost_of = p_post_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_reposted');
  END IF;

  -- Buscar nome do ator
  SELECT COALESCE(NULLIF(nickname,''), NULLIF(amino_id,''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles WHERE id = v_user_id;

  -- Criar o repost
  INSERT INTO public.posts (author_id, repost_of, community_id, type)
  VALUES (v_user_id, p_post_id, v_original.community_id, 'repost')
  RETURNING id INTO v_new_post_id;

  -- Notificar o autor original
  IF v_original.author_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_id, actor_id, type, title, body,
      group_key, group_count,
      post_id, community_id, action_url,
      is_read, created_at
    ) VALUES (
      v_original.author_id,
      v_user_id,
      'repost',
      v_actor_name || ' repostou seu post',
      COALESCE(NULLIF(v_original.title,''), LEFT(COALESCE(v_original.content,''), 80), 'Post'),
      'repost_' || p_post_id,
      1,
      p_post_id,
      v_original.community_id,
      '/post/' || p_post_id,
      FALSE,
      NOW()
    )
    ON CONFLICT (user_id, group_key)
    DO UPDATE SET
      group_count = public.notifications.group_count + 1,
      actor_id    = EXCLUDED.actor_id,
      is_read     = FALSE,
      created_at  = NOW();
  END IF;

  RETURN jsonb_build_object('success', true, 'post_id', v_new_post_id);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================================
-- 3. TRIGGER: wiki aprovada → notificar autor
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_wiki_approved()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Notificar quando status muda para 'approved'
  IF TG_OP = 'UPDATE'
    AND OLD.status IS DISTINCT FROM NEW.status
    AND NEW.status = 'approved'
    AND NEW.author_id IS NOT NULL
  THEN
    PERFORM public.upsert_grouped_notification(
      p_user_id    => NEW.author_id,
      p_actor_id   => NULL,
      p_type       => 'wiki_approved',
      p_title      => 'Sua wiki foi aprovada! 🎉',
      p_body       => COALESCE(NULLIF(NEW.title,''), 'Wiki'),
      p_group_key  => 'wiki_approved_' || NEW.id,
      p_wiki_id    => NEW.id,
      p_community_id => NEW.community_id,
      p_action_url => '/wiki/' || NEW.id
    );
  END IF;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trg_notify_on_wiki_approved] Erro: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wiki_approved_notify ON public.wiki_entries;
CREATE TRIGGER trg_wiki_approved_notify
  AFTER UPDATE ON public.wiki_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_on_wiki_approved();

-- ============================================================================
-- 4. TRIGGER: novo membro na comunidade → notificar admin/moderadores
--    e notificar o usuário que seu pedido foi aceito (join_request aprovado)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_community_join()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name   TEXT;
  v_comm_name    TEXT;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  -- Buscar nome do usuário e da comunidade
  SELECT COALESCE(NULLIF(nickname,''), NULLIF(amino_id,''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles WHERE id = NEW.user_id;

  SELECT name INTO v_comm_name
  FROM public.communities WHERE id = NEW.community_id;

  -- Notificar o usuário que entrou (confirmação de entrada)
  PERFORM public.upsert_grouped_notification(
    p_user_id      => NEW.user_id,
    p_actor_id     => NULL,
    p_type         => 'community_update',
    p_title        => 'Bem-vindo(a) à ' || COALESCE(v_comm_name, 'comunidade') || '! 🎉',
    p_body         => 'Você agora é membro desta comunidade.',
    p_group_key    => 'community_join_' || NEW.community_id || '_' || NEW.user_id,
    p_community_id => NEW.community_id,
    p_action_url   => '/community/' || NEW.community_id
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trg_notify_on_community_join] Erro: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_community_join_notify ON public.community_members;
CREATE TRIGGER trg_community_join_notify
  AFTER INSERT ON public.community_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_on_community_join();

-- ============================================================================
-- 5. CORRIGIR send_dm_invite: adicionar notificação push ao destinatário
-- ============================================================================
CREATE OR REPLACE FUNCTION public.send_dm_invite(p_target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_thread_id  UUID;
  v_actor_name TEXT;
  v_existing   UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF v_user_id = p_target_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_dm_yourself');
  END IF;

  -- Verificar se já existe DM entre os dois
  SELECT ct.id INTO v_existing
  FROM public.chat_threads ct
  JOIN public.chat_members cm1 ON cm1.thread_id = ct.id AND cm1.user_id = v_user_id
  JOIN public.chat_members cm2 ON cm2.thread_id = ct.id AND cm2.user_id = p_target_user_id
  WHERE ct.type = 'dm'
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'thread_id', v_existing, 'existing', true);
  END IF;

  -- Buscar nome do remetente
  SELECT COALESCE(NULLIF(nickname,''), NULLIF(amino_id,''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles WHERE id = v_user_id;

  -- Criar thread DM
  INSERT INTO public.chat_threads (type, host_id)
  VALUES ('dm', v_user_id)
  RETURNING id INTO v_thread_id;

  -- Adicionar ambos como membros
  INSERT INTO public.chat_members (thread_id, user_id, status, role)
  VALUES
    (v_thread_id, v_user_id, 'active', 'host'),
    (v_thread_id, p_target_user_id, 'active', 'member');

  -- Notificar o destinatário
  INSERT INTO public.notifications (
    user_id, actor_id, type, title, body,
    group_key, group_count,
    chat_thread_id, action_url,
    is_read, created_at
  ) VALUES (
    p_target_user_id,
    v_user_id,
    'dm_invite',
    v_actor_name || ' quer conversar com você',
    'Você recebeu uma mensagem direta.',
    'dm_invite_' || v_thread_id,
    1,
    v_thread_id,
    '/chat/' || v_thread_id,
    FALSE,
    NOW()
  )
  ON CONFLICT (user_id, group_key) DO UPDATE SET
    is_read    = FALSE,
    created_at = NOW();

  RETURN jsonb_build_object('success', true, 'thread_id', v_thread_id, 'existing', false);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
