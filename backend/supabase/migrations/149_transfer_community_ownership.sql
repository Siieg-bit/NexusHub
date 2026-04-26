-- Migration 149: Transferência de Propriedade de Comunidade
-- Permite que o líder de uma comunidade transfira a liderança para outro membro.
-- O líder atual é rebaixado para co_leader após a transferência.

CREATE OR REPLACE FUNCTION public.transfer_community_ownership(
  p_community_id UUID,
  p_new_leader_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id     UUID := auth.uid();
  v_is_leader    BOOLEAN;
  v_is_member    BOOLEAN;
  v_new_username TEXT;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  IF v_actor_id = p_new_leader_id THEN
    RAISE EXCEPTION 'cannot_transfer_to_self';
  END IF;

  -- Verificar que o actor é o líder atual
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_actor_id
      AND role = 'leader'
  ) INTO v_is_leader;

  IF NOT v_is_leader THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  -- Verificar que o novo líder é membro ativo da comunidade
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = p_new_leader_id
      AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'target_not_member';
  END IF;

  -- Buscar username do novo líder para o log
  SELECT COALESCE(display_name, username, 'Usuário')
  INTO v_new_username
  FROM public.profiles
  WHERE id = p_new_leader_id;

  -- Rebaixar o líder atual para co_leader
  UPDATE public.community_members
  SET role = 'co_leader', updated_at = NOW()
  WHERE community_id = p_community_id
    AND user_id = v_actor_id;

  -- Promover o novo líder
  UPDATE public.community_members
  SET role = 'leader', updated_at = NOW()
  WHERE community_id = p_community_id
    AND user_id = p_new_leader_id;

  -- Atualizar o owner_id na tabela communities
  UPDATE public.communities
  SET owner_id = p_new_leader_id, updated_at = NOW()
  WHERE id = p_community_id;

  -- Registrar no log de moderação
  INSERT INTO public.moderation_logs (
    community_id, actor_id, target_user_id, action, reason
  ) VALUES (
    p_community_id, v_actor_id, p_new_leader_id,
    'transfer_ownership',
    'Liderança transferida para ' || v_new_username
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'new_leader_id', p_new_leader_id,
    'new_leader_name', v_new_username
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_community_ownership(UUID, UUID) TO authenticated;
