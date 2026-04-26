-- Migration 145: Adicionar suporte a shared_link_summary na RPC send_chat_message_with_reputation
-- Permite que o link preview gerado automaticamente seja salvo junto com a mensagem.

CREATE OR REPLACE FUNCTION public.send_chat_message_with_reputation(
  p_thread_id           UUID,
  p_content             TEXT,
  p_type                TEXT     DEFAULT 'text',
  p_media_url           TEXT     DEFAULT NULL,
  p_media_type          TEXT     DEFAULT NULL,
  p_media_duration      INTEGER  DEFAULT NULL,
  p_reply_to            UUID     DEFAULT NULL,
  p_sticker_id          TEXT     DEFAULT NULL,
  p_sticker_url         TEXT     DEFAULT NULL,
  p_sticker_name        TEXT     DEFAULT NULL,
  p_pack_id             TEXT     DEFAULT NULL,
  p_media_blurhash      TEXT     DEFAULT NULL,
  p_shared_link_summary JSONB    DEFAULT NULL
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
  v_is_read_only  BOOLEAN;
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  SELECT community_id, status, is_read_only
  INTO v_community_id, v_thread_status, v_is_read_only
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF v_thread_status IS NULL THEN
    RAISE EXCEPTION 'thread_not_found';
  END IF;

  IF v_thread_status = 'disabled' THEN
    RAISE EXCEPTION 'chat_disabled';
  END IF;

  -- Verificar modo somente leitura (host e co-hosts podem enviar mesmo assim)
  IF v_is_read_only THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.chat_threads
       WHERE id = p_thread_id
         AND (host_id = v_author_id OR co_hosts @> to_jsonb(v_author_id::text))
    ) THEN
      RAISE EXCEPTION 'chat_read_only';
    END IF;
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
    pack_id,
    media_blurhash,
    shared_link_summary
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
    p_pack_id,
    p_media_blurhash,
    p_shared_link_summary
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

-- Revogar grant antigo (assinatura original sem p_media_blurhash)
REVOKE EXECUTE ON FUNCTION public.send_chat_message_with_reputation(
  UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT, TEXT
) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.send_chat_message_with_reputation(
  UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB
) TO authenticated;
