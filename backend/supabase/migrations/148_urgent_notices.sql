-- Migration 148: Urgent Notices (Anúncios Prioritários de Comunidade)
-- Permite que líderes de comunidade enviem notificações urgentes para todos os membros.
-- O tipo 'urgent_notice' fura o filtro de notificações e é exibido com destaque especial.

-- RPC: broadcast_urgent_notice
-- Envia uma notificação do tipo 'urgent_notice' para todos os membros ativos da comunidade.
-- Apenas o criador da comunidade ou moderadores podem chamar esta função.
CREATE OR REPLACE FUNCTION public.broadcast_urgent_notice(
  p_community_id UUID,
  p_title        TEXT,
  p_body         TEXT,
  p_action_url   TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id    UUID := auth.uid();
  v_is_leader   BOOLEAN;
  v_member_ids  UUID[];
  v_count       INTEGER := 0;
  v_uid         UUID;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Verificar se o usuário é líder ou moderador da comunidade
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_actor_id
      AND role IN ('leader', 'co_leader', 'moderator')
  ) INTO v_is_leader;

  IF NOT v_is_leader THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  IF COALESCE(NULLIF(TRIM(p_title), ''), '') = '' THEN
    RAISE EXCEPTION 'title_required';
  END IF;

  IF COALESCE(NULLIF(TRIM(p_body), ''), '') = '' THEN
    RAISE EXCEPTION 'body_required';
  END IF;

  -- Buscar todos os membros ativos da comunidade (exceto o próprio remetente)
  SELECT ARRAY_AGG(user_id)
  INTO v_member_ids
  FROM public.community_members
  WHERE community_id = p_community_id
    AND user_id != v_actor_id
    AND status = 'active';

  IF v_member_ids IS NULL OR array_length(v_member_ids, 1) = 0 THEN
    RETURN jsonb_build_object('success', TRUE, 'sent_to', 0);
  END IF;

  -- Inserir notificação para cada membro
  FOREACH v_uid IN ARRAY v_member_ids LOOP
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      actor_id,
      community_id,
      action_url,
      is_read
    ) VALUES (
      v_uid,
      'urgent_notice',
      p_title,
      p_body,
      v_actor_id,
      p_community_id,
      p_action_url,
      FALSE
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('success', TRUE, 'sent_to', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.broadcast_urgent_notice(UUID, TEXT, TEXT, TEXT) TO authenticated;
