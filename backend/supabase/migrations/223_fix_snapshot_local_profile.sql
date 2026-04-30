-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 223: Corrigir snapshots de denúncias para usar perfil local
--                e ampliar resolve_flag para suportar comentários e chat
--
-- Problema 1: _capture_post_snapshot, _capture_comment_snapshot e
--             _capture_chat_snapshot buscavam nickname/icon_url de `profiles`
--             (perfil global), ignorando o perfil local da comunidade
--             (community_members.local_nickname / local_icon_url).
--
-- Correção 1: Fazer JOIN com community_members usando COALESCE para preferir
--             o perfil local quando disponível, com fallback para o global.
--             Os nomes dos campos no snapshot_data permanecem iguais para
--             compatibilidade com o frontend:
--               - posts/comments: author_nickname, author_avatar
--               - chat_messages:  sender_nickname, sender_avatar
--
-- Problema 2: resolve_flag só executava ação de conteúdo para posts
--             (p_moderate_action = 'delete' → UPDATE posts SET content_status).
--             Comentários e mensagens de chat não tinham ação correspondente.
--
-- Correção 2: Ampliar resolve_flag para:
--             - delete_content em comentário → DELETE FROM comments
--             - delete_content em chat_message → soft-delete (type='system_deleted')
--             - warn/ban/silence_member → registrar no log (moderate_user cuida do efeito)
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. _capture_post_snapshot — usa community_id do próprio post
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._capture_post_snapshot(
  p_flag_id    UUID,
  p_post_id    UUID,
  p_capturer   UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snapshot_id UUID;
  v_post        RECORD;
  v_author_nick TEXT;
  v_author_av   TEXT;
BEGIN
  -- Buscar o post (mesmo que já esteja soft-deleted via content_status)
  SELECT p.*, p.content_status AS cstatus
    INTO v_post
    FROM public.posts p
   WHERE p.id = p_post_id;

  IF NOT FOUND THEN
    -- Post já foi hard-deleted; registrar snapshot vazio com aviso
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_post_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'post', p_post_id,
      jsonb_build_object(
        'error',   'post_not_found',
        'post_id', p_post_id,
        'note',    'Post foi excluído antes do snapshot ser capturado'
      ),
      p_capturer
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  -- Buscar perfil: preferir local (community_members) com fallback global (profiles)
  SELECT
    COALESCE(NULLIF(TRIM(cm.local_nickname), ''), p.nickname)   AS nick,
    COALESCE(NULLIF(TRIM(cm.local_icon_url), ''), p.icon_url)   AS av
  INTO v_author_nick, v_author_av
  FROM public.profiles p
  LEFT JOIN public.community_members cm
    ON cm.user_id = p.id AND cm.community_id = v_post.community_id
  WHERE p.id = v_post.author_id;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_post_id, original_user_id,
    snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'post', p_post_id, v_post.author_id,
    jsonb_build_object(
      'title',           v_post.title,
      'body',            v_post.body,
      'image_urls',      COALESCE(v_post.image_urls, '[]'::jsonb),
      'author_id',       v_post.author_id,
      'author_nickname', COALESCE(v_author_nick, 'Desconhecido'),
      'author_avatar',   v_author_av,
      'community_id',    v_post.community_id,
      'content_status',  v_post.cstatus,
      'created_at',      v_post.created_at,
      'captured_at',     NOW()
    ),
    p_capturer
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. _capture_comment_snapshot — obtém community_id via post pai
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._capture_comment_snapshot(
  p_flag_id      UUID,
  p_comment_id   UUID,
  p_capturer     UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snapshot_id  UUID;
  v_comment      RECORD;
  v_community_id UUID;
  v_author_nick  TEXT;
  v_author_av    TEXT;
BEGIN
  SELECT c.* INTO v_comment
    FROM public.comments c
   WHERE c.id = p_comment_id;

  IF NOT FOUND THEN
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_comment_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'comment', p_comment_id,
      jsonb_build_object(
        'error',      'comment_not_found',
        'comment_id', p_comment_id
      ),
      p_capturer
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  -- Obter community_id via post pai
  SELECT p.community_id INTO v_community_id
    FROM public.posts p
   WHERE p.id = v_comment.post_id;

  -- Buscar perfil: preferir local com fallback global
  SELECT
    COALESCE(NULLIF(TRIM(cm.local_nickname), ''), p.nickname)   AS nick,
    COALESCE(NULLIF(TRIM(cm.local_icon_url), ''), p.icon_url)   AS av
  INTO v_author_nick, v_author_av
  FROM public.profiles p
  LEFT JOIN public.community_members cm
    ON cm.user_id = p.id AND cm.community_id = v_community_id
  WHERE p.id = v_comment.author_id;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_comment_id, original_user_id,
    snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'comment', p_comment_id, v_comment.author_id,
    jsonb_build_object(
      'body',            v_comment.body,
      'image_urls',      COALESCE(v_comment.image_urls, '[]'::jsonb),
      'author_id',       v_comment.author_id,
      'author_nickname', COALESCE(v_author_nick, 'Desconhecido'),
      'author_avatar',   v_author_av,
      'post_id',         v_comment.post_id,
      'created_at',      v_comment.created_at,
      'captured_at',     NOW()
    ),
    p_capturer
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. _capture_chat_snapshot — obtém community_id via flags.community_id
--    (chat_messages não tem community_id direto; o thread pode ser DM global)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._capture_chat_snapshot(
  p_flag_id    UUID,
  p_message_id UUID,
  p_capturer   UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snapshot_id  UUID;
  v_msg          RECORD;
  v_community_id UUID;
  v_sender_nick  TEXT;
  v_sender_av    TEXT;
BEGIN
  SELECT m.* INTO v_msg
    FROM public.chat_messages m
   WHERE m.id = p_message_id;

  IF NOT FOUND THEN
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_chat_message_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'chat_message', p_message_id,
      jsonb_build_object('error', 'message_not_found', 'message_id', p_message_id),
      p_capturer
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  -- Obter community_id da flag (chat_messages não tem community_id direto)
  SELECT f.community_id INTO v_community_id
    FROM public.flags f
   WHERE f.id = p_flag_id;

  -- Buscar perfil: preferir local com fallback global
  SELECT
    COALESCE(NULLIF(TRIM(cm.local_nickname), ''), p.nickname)   AS nick,
    COALESCE(NULLIF(TRIM(cm.local_icon_url), ''), p.icon_url)   AS av
  INTO v_sender_nick, v_sender_av
  FROM public.profiles p
  LEFT JOIN public.community_members cm
    ON cm.user_id = p.id AND cm.community_id = v_community_id
  WHERE p.id = v_msg.author_id;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_chat_message_id, original_user_id,
    snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'chat_message', p_message_id, v_msg.author_id,
    jsonb_build_object(
      'content',         v_msg.content,
      'media_url',       v_msg.media_url,
      'author_id',       v_msg.author_id,
      'sender_nickname', COALESCE(v_sender_nick, 'Desconhecido'),
      'sender_avatar',   v_sender_av,
      'thread_id',       v_msg.thread_id,
      'created_at',      v_msg.created_at,
      'captured_at',     NOW()
    ),
    p_capturer
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Adicionar delete_comment e delete_chat_message ao enum moderation_action
--    (se ainda não existirem)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'public.moderation_action'::regtype
      AND enumlabel = 'delete_comment'
  ) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'delete_comment';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'public.moderation_action'::regtype
      AND enumlabel = 'delete_chat_message'
  ) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'delete_chat_message';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Atualizar resolve_flag para suportar ações contextuais por tipo de conteúdo
--    - delete_content em post      → UPDATE posts SET content_status = 'disabled'
--    - delete_comment em comentário → DELETE FROM comments
--    - delete_chat_message em chat  → soft-delete (type='system_deleted')
--    - warn / ban / silence_member  → apenas registrar no log
--      (o efeito real é feito via moderate_user pelo moderador separadamente)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.resolve_flag(
  p_flag_id         UUID,
  p_action          TEXT,    -- 'approved' ou 'dismissed'
  p_resolution_note TEXT    DEFAULT NULL,
  p_moderate_content BOOLEAN DEFAULT FALSE,
  p_moderate_action  TEXT    DEFAULT NULL
  -- Valores válidos para p_moderate_action:
  --   'delete_content'     → desabilita post (content_status = 'disabled')
  --   'delete_comment'     → deleta comentário
  --   'delete_chat_message'→ soft-delete de mensagem de chat
  --   'warn'               → apenas registra advertência no log
  --   'ban'                → apenas registra banimento no log
  --   'silence_member'     → apenas registra silenciamento no log
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_flag       RECORD;
  v_role       TEXT;
  v_log_action TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  SELECT f.* INTO v_flag FROM public.flags f WHERE f.id = p_flag_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Denúncia não encontrada'; END IF;

  SELECT role::TEXT INTO v_role
  FROM public.community_members
  WHERE community_id = v_flag.community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent', 'leader', 'curator', 'moderator', 'admin')
     AND NOT public.is_team_member() THEN
    RAISE EXCEPTION 'Sem permissão para resolver denúncias';
  END IF;

  -- Atualizar status da flag
  UPDATE public.flags SET
    status          = p_action,
    resolved_by     = v_user_id,
    resolution_note = COALESCE(p_resolution_note, resolution_note),
    resolved_at     = NOW()
  WHERE id = p_flag_id;

  -- Registrar a ação de resolução da flag no log de moderação
  v_log_action := CASE WHEN p_action = 'approved' THEN 'approve_flag' ELSE 'dismiss_flag' END;
  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action,
    target_post_id, target_user_id,
    flag_id, reason
  ) VALUES (
    v_flag.community_id, v_user_id, v_log_action::public.moderation_action,
    v_flag.target_post_id, v_flag.target_user_id,
    p_flag_id,
    COALESCE(p_resolution_note, 'Denúncia ' || CASE WHEN p_action = 'approved' THEN 'aprovada' ELSE 'dispensada' END)
  );

  -- Ação sobre o conteúdo (se solicitado)
  IF p_moderate_content AND p_moderate_action IS NOT NULL THEN

    -- ── Post: desabilitar ──────────────────────────────────────────────────
    IF p_moderate_action = 'delete_content' AND v_flag.target_post_id IS NOT NULL THEN
      UPDATE public.posts SET content_status = 'disabled'
      WHERE id = v_flag.target_post_id;

    -- ── Comentário: deletar ────────────────────────────────────────────────
    ELSIF p_moderate_action = 'delete_comment' AND v_flag.target_comment_id IS NOT NULL THEN
      DELETE FROM public.comments WHERE id = v_flag.target_comment_id;

    -- ── Chat message: soft-delete ──────────────────────────────────────────
    ELSIF p_moderate_action = 'delete_chat_message' AND v_flag.target_chat_message_id IS NOT NULL THEN
      UPDATE public.chat_messages SET
        type       = 'system_deleted',
        content    = 'Mensagem removida pela moderação',
        is_deleted = TRUE,
        deleted_by = v_user_id,
        media_url  = NULL,
        media_type = NULL,
        updated_at = NOW()
      WHERE id = v_flag.target_chat_message_id;

    END IF;

    -- Registrar ação de conteúdo separada no log
    INSERT INTO public.moderation_logs (
      community_id, moderator_id, action,
      target_post_id, target_comment_id, target_user_id,
      flag_id, reason
    ) VALUES (
      v_flag.community_id, v_user_id, p_moderate_action::public.moderation_action,
      v_flag.target_post_id, v_flag.target_comment_id, v_flag.target_user_id,
      p_flag_id,
      COALESCE(p_resolution_note, 'Ação via resolução de denúncia')
    );

  END IF;

  RETURN jsonb_build_object('success', true, 'flag_id', p_flag_id, 'new_status', p_action);
END;
$$;
GRANT EXECUTE ON FUNCTION public.resolve_flag(UUID, TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;
