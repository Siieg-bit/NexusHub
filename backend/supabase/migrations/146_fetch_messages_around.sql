-- Migration 146: RPC fetch_messages_around
-- Busca um bloco de mensagens ao redor de uma mensagem alvo (por ID),
-- permitindo paginação bidirecional no chat sem carregar todo o histórico.
-- Retorna até p_limit mensagens antes + a mensagem alvo + até p_limit mensagens depois,
-- ordenadas do mais antigo ao mais recente (ascending).

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
  -- Dados do autor (join inline)
  author_nickname TEXT,
  author_icon_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id     UUID := auth.uid();
  v_is_member     BOOLEAN;
  v_target_time   TIMESTAMPTZ;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Verificar se o caller é membro ativo do chat
  SELECT EXISTS(
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id = v_caller_id
      AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;

  -- Obter o timestamp da mensagem alvo
  SELECT created_at INTO v_target_time
  FROM public.chat_messages
  WHERE id = p_message_id
    AND thread_id = p_thread_id;

  IF v_target_time IS NULL THEN
    RAISE EXCEPTION 'message_not_found';
  END IF;

  -- Retornar o bloco: mensagens antes + alvo + mensagens depois
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
    p.nickname  AS author_nickname,
    p.icon_url  AS author_icon_url
  FROM combined c
  LEFT JOIN public.profiles p ON p.id = c.author_id
  ORDER BY c.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_messages_around(UUID, UUID, INTEGER) TO authenticated;
