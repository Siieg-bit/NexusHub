-- =============================================================================
-- Migration 195: Corrigir referências a colunas inexistentes (username, display_name)
-- =============================================================================
-- Problema: a tabela `profiles` nunca teve as colunas `username` nem `display_name`.
-- Os campos corretos são `nickname` (nome de exibição) e `amino_id` (handle único).
--
-- Funções corrigidas:
-- 1. create_comment_with_reputation — removida a sobrecarga antiga que aceitava
--    p_author_id (desnecessário pois a função usa auth.uid() internamente).
--    Essa sobrecarga era a causa do erro "column username does not exist" ao
--    comentar com @menção, pois o Supabase resolvia para a versão errada da função.
--
-- 2. transfer_community_ownership — corrigido COALESCE(display_name, username, ...)
--    para COALESCE(nickname, amino_id, 'Usuário').
-- =============================================================================

-- 1. Remover sobrecarga antiga de create_comment_with_reputation (com p_author_id)
DROP FUNCTION IF EXISTS public.create_comment_with_reputation(
  uuid, uuid, text, uuid, uuid, uuid, uuid, text
);

-- 2. Corrigir transfer_community_ownership
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
  -- Buscar nome do novo líder para o log (CORRIGIDO: nickname/amino_id em vez de display_name/username)
  SELECT COALESCE(NULLIF(nickname, ''), NULLIF(amino_id, ''), 'Usuário')
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
