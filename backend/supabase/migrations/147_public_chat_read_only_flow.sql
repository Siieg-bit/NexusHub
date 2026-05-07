-- Migration 147: Leitura pública de chats públicos e entrada explícita estável
--
-- Objetivo:
--   1. Permitir que membros da comunidade visualizem mensagens de salas públicas
--      mesmo antes de entrarem no chat.
--   2. Manter envio/ações restritas a membros do chat.
--   3. Preservar bloqueios por banimento e o acesso restrito de DMs/grupos.
--   4. Alinhar a RPC de busca de histórico com a mesma regra de leitura.

CREATE OR REPLACE FUNCTION public.can_read_chat_messages(
  p_thread_id UUID,
  p_user_id   UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_thread RECORD;
  v_member RECORD;
  v_is_community_member BOOLEAN := FALSE;
BEGIN
  IF p_thread_id IS NULL OR p_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT id, type, status, community_id
  INTO v_thread
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  SELECT id, status, is_banned, banned_until
  INTO v_member
  FROM public.chat_members
  WHERE thread_id = p_thread_id
    AND user_id = p_user_id;

  IF FOUND THEN
    IF COALESCE(v_member.is_banned, FALSE)
       AND (v_member.banned_until IS NULL OR v_member.banned_until > NOW()) THEN
      RETURN FALSE;
    END IF;

    IF COALESCE(v_member.status, 'active') IN ('active', 'invite_sent', 'join_requested') THEN
      RETURN TRUE;
    END IF;
  END IF;

  IF v_thread.type <> 'public' OR COALESCE(v_thread.status, 'ok') <> 'ok' THEN
    RETURN FALSE;
  END IF;

  -- Se existe registro de banimento ativo mesmo sem membership ativa, bloquear leitura.
  IF FOUND
     AND COALESCE(v_member.is_banned, FALSE)
     AND (v_member.banned_until IS NULL OR v_member.banned_until > NOW()) THEN
    RETURN FALSE;
  END IF;

  IF v_thread.community_id IS NULL THEN
    RETURN TRUE;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.community_members cm
    WHERE cm.community_id = v_thread.community_id
      AND cm.user_id = p_user_id
      AND COALESCE(cm.is_banned, FALSE) = FALSE
  ) INTO v_is_community_member;

  IF v_is_community_member THEN
    RETURN TRUE;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = p_user_id
      AND (COALESCE(p.is_team_admin, FALSE) = TRUE
           OR COALESCE(p.is_team_moderator, FALSE) = TRUE)
  ) INTO v_is_community_member;

  RETURN v_is_community_member;
END;
$$;

DROP POLICY IF EXISTS "chat_messages_select" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_select_member" ON public.chat_messages;

CREATE POLICY "chat_messages_select" ON public.chat_messages
  FOR SELECT USING (public.can_read_chat_messages(thread_id, auth.uid()));

CREATE OR REPLACE FUNCTION public.fetch_messages_around(
  p_thread_id  UUID,
  p_message_id UUID,
  p_limit      INTEGER DEFAULT 30
)
RETURNS TABLE (
  id              UUID,
  thread_id       UUID,
  author_id       UUID,
  content         TEXT,
  type            TEXT,
  media_url       TEXT,
  media_type      TEXT,
  media_duration  INTEGER,
  reply_to_id     UUID,
  sticker_id      UUID,
  sticker_url     TEXT,
  sticker_name    TEXT,
  pack_id         UUID,
  media_blurhash  TEXT,
  shared_link_summary JSONB,
  extra_data      JSONB,
  is_deleted      BOOLEAN,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ,
  author_nickname TEXT,
  author_icon_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id   UUID := auth.uid();
  v_target_time TIMESTAMPTZ;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  IF NOT public.can_read_chat_messages(p_thread_id, v_caller_id) THEN
    RAISE EXCEPTION 'not_allowed_to_read_chat';
  END IF;

  SELECT created_at INTO v_target_time
  FROM public.chat_messages
  WHERE id = p_message_id
    AND thread_id = p_thread_id;

  IF v_target_time IS NULL THEN
    RAISE EXCEPTION 'message_not_found';
  END IF;

  RETURN QUERY
  WITH before_msgs AS (
    SELECT m.*
    FROM public.chat_messages m
    WHERE m.thread_id = p_thread_id
      AND m.created_at < v_target_time
    ORDER BY m.created_at DESC
    LIMIT p_limit
  ),
  after_msgs AS (
    SELECT m.*
    FROM public.chat_messages m
    WHERE m.thread_id = p_thread_id
      AND m.created_at > v_target_time
    ORDER BY m.created_at ASC
    LIMIT p_limit
  ),
  target_msg AS (
    SELECT m.*
    FROM public.chat_messages m
    WHERE m.id = p_message_id
      AND m.thread_id = p_thread_id
  ),
  combined AS (
    SELECT * FROM before_msgs
    UNION ALL
    SELECT * FROM target_msg
    UNION ALL
    SELECT * FROM after_msgs
  )
  SELECT
    c.id,
    c.thread_id,
    c.author_id,
    c.content,
    c.type::TEXT,
    c.media_url,
    c.media_type,
    c.media_duration,
    c.reply_to_id,
    c.sticker_id,
    c.sticker_url,
    c.sticker_name,
    c.pack_id,
    c.media_blurhash,
    c.shared_link_summary,
    c.extra_data,
    c.is_deleted,
    c.deleted_at,
    c.created_at,
    c.updated_at,
    p.nickname AS author_nickname,
    p.icon_url AS author_icon_url
  FROM combined c
  LEFT JOIN public.profiles p ON p.id = c.author_id
  ORDER BY c.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_read_chat_messages(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_messages_around(UUID, UUID, INTEGER) TO authenticated;
