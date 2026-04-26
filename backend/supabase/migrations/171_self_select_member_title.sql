-- Migration 171: self_select_member_title
-- Permite que membros escolham seu próprio título dentro de uma comunidade.
-- Apenas títulos com allow_self_select = true podem ser escolhidos por membros.

-- 1. Adicionar coluna allow_self_select na tabela community_member_titles
ALTER TABLE public.community_member_titles
  ADD COLUMN IF NOT EXISTS allow_self_select BOOLEAN NOT NULL DEFAULT true;

-- 2. RPC: self_select_member_title — membro escolhe seu próprio título
CREATE OR REPLACE FUNCTION public.self_select_member_title(
  p_title_id     UUID,
  p_community_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_member BOOLEAN;
  v_allow_self BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  -- Verificar se o usuário é membro da comunidade
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
  ) INTO v_is_member;
  IF NOT v_is_member THEN RAISE EXCEPTION 'not_a_member'; END IF;

  -- Verificar se o título permite auto-seleção
  SELECT COALESCE(allow_self_select, true)
    FROM public.community_member_titles
    WHERE id = p_title_id AND community_id = p_community_id
  INTO v_allow_self;
  IF v_allow_self IS NULL THEN RAISE EXCEPTION 'title_not_found'; END IF;
  IF NOT v_allow_self THEN RAISE EXCEPTION 'self_select_not_allowed'; END IF;

  -- Inserir ou atualizar o título do membro
  INSERT INTO public.member_title_assignments
    (title_id, user_id, community_id, assigned_by)
  VALUES (p_title_id, v_user_id, p_community_id, v_user_id)
  ON CONFLICT (user_id, community_id)
  DO UPDATE SET
    title_id    = EXCLUDED.title_id,
    assigned_by = EXCLUDED.assigned_by,
    assigned_at = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.self_select_member_title(UUID, UUID) TO authenticated;

-- 3. RPC: remove_own_member_title — membro remove seu próprio título
CREATE OR REPLACE FUNCTION public.remove_own_member_title(
  p_community_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  DELETE FROM public.member_title_assignments
    WHERE user_id = v_user_id AND community_id = p_community_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.remove_own_member_title(UUID) TO authenticated;

-- 4. RPC: get_selectable_titles — retorna títulos disponíveis para auto-seleção
CREATE OR REPLACE FUNCTION public.get_selectable_titles(
  p_community_id UUID
)
RETURNS TABLE (
  id                UUID,
  name              TEXT,
  emoji             TEXT,
  color             TEXT,
  auto_assign_after_days INT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, name, emoji, color, auto_assign_after_days
  FROM public.community_member_titles
  WHERE community_id = p_community_id
    AND COALESCE(allow_self_select, true) = true
  ORDER BY name;
$$;
GRANT EXECUTE ON FUNCTION public.get_selectable_titles(UUID) TO authenticated;
