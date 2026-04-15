-- =============================================================================
-- Migration 113: Chat scope and status fixes
-- Corrige:
--   1. DMs isoladas por comunidade via p_community_id
--   2. Ativação/desativação de chats por host/co-host
--   3. Bloqueio de novas mensagens em chats com status disabled
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. RPC send_dm_invite com escopo opcional por comunidade
--    Mantém compatibilidade com chamadas antigas e evita reaproveitar a mesma
--    DM em comunidades diferentes.
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.send_dm_invite(UUID, TEXT, UUID);

CREATE OR REPLACE FUNCTION public.send_dm_invite(
  p_target_user_id UUID,
  p_initial_message TEXT DEFAULT NULL,
  p_community_id UUID DEFAULT NULL
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

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_target_user_id) THEN
    RAISE EXCEPTION 'Usuário não encontrado';
  END IF;

  IF p_community_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.community_members
      WHERE community_id = p_community_id
        AND user_id = v_caller
        AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'Você não participa desta comunidade';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.community_members
      WHERE community_id = p_community_id
        AND user_id = p_target_user_id
        AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'O usuário alvo não participa desta comunidade';
    END IF;
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.follows
    WHERE follower_id = v_caller AND following_id = p_target_user_id
  ) INTO v_is_follower;

  SELECT EXISTS(
    SELECT 1 FROM public.follows
    WHERE follower_id = p_target_user_id AND following_id = v_caller
  ) INTO v_is_following;

  SELECT COALESCE(privilege_chat_invite, 'everyone')
  INTO v_target_privacy
  FROM public.profiles
  WHERE id = p_target_user_id;

  IF v_target_privacy = 'nobody' THEN
    RAISE EXCEPTION 'Este usuário não aceita convites de DM';
  ELSIF v_target_privacy = 'followers' AND NOT v_is_follower THEN
    RAISE EXCEPTION 'Este usuário só aceita DMs de seguidores';
  ELSIF v_target_privacy = 'following' AND NOT v_is_following THEN
    RAISE EXCEPTION 'Este usuário só aceita DMs de pessoas que ele segue';
  END IF;

  SELECT ct.id INTO v_existing_thread_id
  FROM public.chat_threads ct
  JOIN public.chat_members cm1
    ON cm1.thread_id = ct.id AND cm1.user_id = v_caller
  JOIN public.chat_members cm2
    ON cm2.thread_id = ct.id AND cm2.user_id = p_target_user_id
  WHERE ct.type = 'dm'
    AND (
      (p_community_id IS NULL AND ct.community_id IS NULL)
      OR ct.community_id = p_community_id
    )
  LIMIT 1;

  IF v_existing_thread_id IS NOT NULL THEN
    UPDATE public.chat_members
    SET status = CASE
      WHEN user_id = p_target_user_id AND status = 'invite_sent' THEN 'invite_sent'
      ELSE 'active'
    END
    WHERE thread_id = v_existing_thread_id
      AND user_id IN (v_caller, p_target_user_id)
      AND status != 'active';

    RETURN v_existing_thread_id;
  END IF;

  INSERT INTO public.chat_threads (
    community_id,
    type,
    host_id,
    members_count,
    status
  )
  VALUES (
    p_community_id,
    'dm',
    v_caller,
    2,
    'ok'
  )
  RETURNING id INTO v_new_thread_id;

  INSERT INTO public.chat_members (thread_id, user_id, status, role)
  VALUES (v_new_thread_id, v_caller, 'active', 'host');

  INSERT INTO public.chat_members (thread_id, user_id, status, role)
  VALUES (v_new_thread_id, p_target_user_id, 'invite_sent', 'member');

  IF p_initial_message IS NOT NULL AND btrim(p_initial_message) <> '' THEN
    INSERT INTO public.chat_messages (thread_id, author_id, type, content)
    VALUES (v_new_thread_id, v_caller, 'text', p_initial_message);

    UPDATE public.chat_threads
    SET last_message_at = NOW(),
        last_message_preview = LEFT(p_initial_message, 100),
        last_message_author = (
          SELECT nickname FROM public.profiles WHERE id = v_caller
        )
    WHERE id = v_new_thread_id;
  END IF;

  INSERT INTO public.notifications (
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
    COALESCE((SELECT nickname FROM public.profiles WHERE id = v_caller), 'Alguém')
      || ' quer conversar com você',
    v_new_thread_id,
    '/chat/' || v_new_thread_id::text
  );

  RETURN v_new_thread_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_dm_invite(
  p_target_user_id UUID,
  p_initial_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.send_dm_invite(p_target_user_id, p_initial_message, NULL);
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. RPC para ativar/desativar chats de grupo/públicos
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.toggle_chat_thread_status(UUID, BOOLEAN);

CREATE OR REPLACE FUNCTION public.toggle_chat_thread_status(
  p_thread_id UUID,
  p_disabled BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_caller_role TEXT;
  v_thread_type public.chat_thread_type;
  v_new_status public.content_status;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT type INTO v_thread_type
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF v_thread_type IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'thread_not_found');
  END IF;

  IF v_thread_type = 'dm' THEN
    RETURN jsonb_build_object('success', false, 'error', 'dm_cannot_be_disabled');
  END IF;

  SELECT role INTO v_caller_role
  FROM public.chat_members
  WHERE thread_id = p_thread_id
    AND user_id = v_caller
    AND status = 'active';

  IF v_caller_role NOT IN ('host', 'co_host') AND NOT public.is_team_member() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_moderator');
  END IF;

  v_new_status := CASE WHEN p_disabled THEN 'disabled' ELSE 'ok' END;

  UPDATE public.chat_threads
  SET status = v_new_status,
      updated_at = NOW()
  WHERE id = p_thread_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_new_status,
    'disabled', p_disabled
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. RPC de envio endurecida para respeitar chat desativado
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.send_chat_message_with_reputation(
  p_thread_id      UUID,
  p_content        TEXT,
  p_type           TEXT     DEFAULT 'text',
  p_media_url      TEXT     DEFAULT NULL,
  p_media_type     TEXT     DEFAULT NULL,
  p_media_duration INTEGER  DEFAULT NULL,
  p_reply_to       UUID     DEFAULT NULL,
  p_sticker_id     TEXT     DEFAULT NULL,
  p_sticker_url    TEXT     DEFAULT NULL,
  p_sticker_name   TEXT     DEFAULT NULL,
  p_pack_id        TEXT     DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_message_id   UUID;
  v_community_id UUID;
  v_is_member    BOOLEAN;
  v_author_id    UUID := auth.uid();
  v_mapped_type  TEXT;
  v_sticker_uuid UUID;
  v_thread_status public.content_status;
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  SELECT community_id, status
  INTO v_community_id, v_thread_status
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF v_thread_status IS NULL THEN
    RAISE EXCEPTION 'thread_not_found';
  END IF;

  IF v_thread_status = 'disabled' THEN
    RAISE EXCEPTION 'chat_disabled';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id = v_author_id
      AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this chat';
  END IF;

  BEGIN
    v_sticker_uuid := CASE
      WHEN p_sticker_id IS NULL OR p_sticker_id = '' THEN NULL
      ELSE p_sticker_id::UUID
    END;
  EXCEPTION WHEN invalid_text_representation THEN
    v_sticker_uuid := NULL;
  END;

  v_mapped_type := CASE p_type
    WHEN 'image'               THEN 'image'
    WHEN 'gif'                 THEN 'gif'
    WHEN 'audio'               THEN 'audio'
    WHEN 'video'               THEN 'video'
    WHEN 'sticker'             THEN 'sticker'
    WHEN 'voice_note'          THEN 'voice_note'
    WHEN 'strike'              THEN 'strike'
    WHEN 'share_url'           THEN 'share_url'
    WHEN 'share_user'          THEN 'share_user'
    WHEN 'poll'                THEN 'poll'
    WHEN 'forward'             THEN 'forward'
    WHEN 'file'                THEN 'file'
    WHEN 'system_tip'          THEN 'system_tip'
    WHEN 'system_voice_start'  THEN 'system_voice_start'
    WHEN 'system_voice_end'    THEN 'system_voice_end'
    WHEN 'system_screen_start' THEN 'system_screen_start'
    WHEN 'system_screen_end'   THEN 'system_screen_end'
    WHEN 'system_pin'          THEN 'system_pin'
    WHEN 'system_unpin'        THEN 'system_unpin'
    WHEN 'system_join'         THEN 'system_join'
    WHEN 'system_leave'        THEN 'system_leave'
    WHEN 'system_removed'      THEN 'system_removed'
    WHEN 'system_admin_delete' THEN 'system_admin_delete'
    WHEN 'system_deleted'      THEN 'system_deleted'
    ELSE 'text'
  END;

  INSERT INTO public.chat_messages (
    thread_id,
    author_id,
    content,
    type,
    media_url,
    media_type,
    media_duration,
    reply_to_id,
    sticker_id,
    sticker_url,
    sticker_name,
    pack_id
  ) VALUES (
    p_thread_id,
    v_author_id,
    COALESCE(p_content, ''),
    v_mapped_type::public.chat_message_type,
    p_media_url,
    p_media_type,
    p_media_duration,
    p_reply_to,
    v_sticker_uuid,
    p_sticker_url,
    p_sticker_name,
    p_pack_id
  ) RETURNING id INTO v_message_id;

  UPDATE public.chat_threads
  SET last_message_at = NOW()
  WHERE id = p_thread_id;

  IF v_community_id IS NOT NULL THEN
    BEGIN
      PERFORM public.add_reputation(
        v_author_id,
        v_community_id,
        'chat_message',
        1,
        v_message_id
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN v_message_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_dm_invite(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_dm_invite(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_chat_thread_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_chat_message_with_reputation(
  UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT, TEXT
) TO authenticated;
