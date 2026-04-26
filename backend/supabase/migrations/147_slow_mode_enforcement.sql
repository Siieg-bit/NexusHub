-- Migration 147: Aplicar Slow Mode real na RPC send_chat_message_with_reputation
-- O campo slow_mode_interval já existe na tabela chat_threads (migration 060),
-- mas a RPC não validava o cooldown. Esta migration corrige isso.
-- Também adiciona coluna last_message_at em chat_members para rastrear o cooldown por usuário.

ALTER TABLE public.chat_members
  ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NULL;

-- Dropar ambas as versões anteriores pois o tipo de retorno muda de UUID para JSONB
DROP FUNCTION IF EXISTS public.send_chat_message_with_reputation(
  UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT, TEXT
);
DROP FUNCTION IF EXISTS public.send_chat_message_with_reputation(
  UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB
);
-- Versão com p_media_blurhash (13 parâmetros)
DROP FUNCTION IF EXISTS public.send_chat_message_with_reputation(
  UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB
);

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
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_message_id        UUID;
  v_community_id      UUID;
  v_is_member         BOOLEAN;
  v_author_id         UUID := auth.uid();
  v_mapped_type       TEXT;
  v_sticker_uuid      UUID;
  v_thread_status     public.content_status;
  v_is_read_only      BOOLEAN;
  v_slow_mode_interval INTEGER;
  v_last_msg_at       TIMESTAMPTZ;
  v_seconds_since     FLOAT;
  v_seconds_remaining FLOAT;
  v_is_host           BOOLEAN;
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  SELECT community_id, status, is_read_only, slow_mode_interval
  INTO v_community_id, v_thread_status, v_is_read_only, v_slow_mode_interval
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF v_thread_status IS NULL THEN
    RAISE EXCEPTION 'thread_not_found';
  END IF;

  IF v_thread_status = 'disabled' THEN
    RAISE EXCEPTION 'chat_disabled';
  END IF;

  -- Verificar se é host ou co-host (isentos de slow mode e read-only)
  SELECT (host_id = v_author_id OR co_hosts @> to_jsonb(v_author_id::text))
  INTO v_is_host
  FROM public.chat_threads
  WHERE id = p_thread_id;

  -- Verificar modo somente leitura
  IF v_is_read_only AND NOT v_is_host THEN
    RAISE EXCEPTION 'chat_read_only';
  END IF;

  -- Verificar membership
  SELECT EXISTS(
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id = v_author_id
      AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;

  -- Validar Slow Mode (apenas para não-hosts)
  IF v_slow_mode_interval > 0 AND NOT v_is_host THEN
    SELECT last_message_at
    INTO v_last_msg_at
    FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id = v_author_id;

    IF v_last_msg_at IS NOT NULL THEN
      v_seconds_since := EXTRACT(EPOCH FROM (NOW() - v_last_msg_at));
      IF v_seconds_since < v_slow_mode_interval THEN
        v_seconds_remaining := v_slow_mode_interval - v_seconds_since;
        -- Retornar erro com segundos restantes para o frontend exibir o countdown
        RETURN jsonb_build_object(
          'error', 'slow_mode_cooldown',
          'seconds_remaining', CEIL(v_seconds_remaining)::INTEGER
        );
      END IF;
    END IF;
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
    WHEN 'text'                THEN 'text'
    WHEN 'image'               THEN 'image'
    WHEN 'video'               THEN 'video'
    WHEN 'audio'               THEN 'audio'
    WHEN 'sticker'             THEN 'sticker'
    WHEN 'share_url'           THEN 'share_url'
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

  -- Atualizar last_message_at para slow mode tracking
  IF v_slow_mode_interval > 0 AND NOT v_is_host THEN
    UPDATE public.chat_members
    SET last_message_at = NOW()
    WHERE thread_id = p_thread_id
      AND user_id = v_author_id;
  END IF;

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

  RETURN jsonb_build_object('message_id', v_message_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_chat_message_with_reputation(
  UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB
) TO authenticated;
