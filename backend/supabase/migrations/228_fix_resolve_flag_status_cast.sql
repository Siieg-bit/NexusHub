-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 228: Corrigir resolve_flag — cast explícito p_action::flag_status
--
-- Problema: UPDATE flags SET status = p_action falhava com erro 42804:
--   "column status is of type flag_status but expression is of type text"
--   O PostgreSQL não faz cast implícito de TEXT para enum.
--
-- Correção: Usar p_action::public.flag_status no UPDATE e no CASE do log_action.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.resolve_flag(
  p_flag_id          UUID,
  p_action           TEXT,
  p_resolution_note  TEXT    DEFAULT NULL,
  p_moderate_content BOOLEAN DEFAULT FALSE,
  p_moderate_action  TEXT    DEFAULT NULL
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

  -- Verificar permissão: staff da comunidade ou Manus team
  SELECT role::TEXT INTO v_role
    FROM public.community_members
   WHERE community_id = v_flag.community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent', 'leader', 'curator', 'moderator', 'admin')
     AND NOT public.is_team_member() THEN
    RAISE EXCEPTION 'Sem permissão para resolver denúncias';
  END IF;

  -- Atualizar status da flag — cast explícito para o enum flag_status
  UPDATE public.flags SET
    status          = p_action::public.flag_status,
    resolved_by     = v_user_id,
    resolution_note = COALESCE(p_resolution_note, resolution_note),
    resolved_at     = NOW()
  WHERE id = p_flag_id;

  -- Registrar ação de resolução no log de moderação
  v_log_action := CASE WHEN p_action = 'approved' THEN 'approve_flag' ELSE 'dismiss_flag' END;

  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action,
    target_post_id, target_user_id,
    flag_id, reason
  ) VALUES (
    v_flag.community_id, v_user_id, v_log_action::public.moderation_action,
    v_flag.target_post_id, v_flag.target_user_id,
    p_flag_id,
    COALESCE(p_resolution_note,
      'Denúncia ' || CASE WHEN p_action = 'approved' THEN 'aprovada' ELSE 'dispensada' END)
  );

  -- Ação sobre o conteúdo (se solicitado)
  IF p_moderate_content AND p_moderate_action IS NOT NULL THEN

    -- Post: desabilitar
    IF p_moderate_action = 'delete_content' AND v_flag.target_post_id IS NOT NULL THEN
      UPDATE public.posts SET content_status = 'disabled'
       WHERE id = v_flag.target_post_id;

    -- Comentário: deletar
    ELSIF p_moderate_action = 'delete_comment' AND v_flag.target_comment_id IS NOT NULL THEN
      DELETE FROM public.comments WHERE id = v_flag.target_comment_id;

    -- Chat message: soft-delete
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

  RETURN jsonb_build_object(
    'success',    true,
    'flag_id',    p_flag_id,
    'new_status', p_action
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_flag(UUID, TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;
