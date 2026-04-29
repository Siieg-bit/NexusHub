-- ============================================================
-- Migration 189: Sistema completo de Custom Titles
-- - Adiciona sort_order à member_titles
-- - Tags automáticas por cargo (Líder/Curador/TeamMember)
-- - RLS UPDATE para o próprio usuário
-- - RPCs: manage_member_title (atualizado), reorder_member_titles,
--         delete_own_title, get_member_titles_full
-- ============================================================

-- 1. Adicionar sort_order se não existir
ALTER TABLE public.member_titles
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- 2. Adicionar flag is_role_badge (tags automáticas de cargo, não editáveis pelo usuário)
ALTER TABLE public.member_titles
  ADD COLUMN IF NOT EXISTS is_role_badge BOOLEAN DEFAULT FALSE;

-- 3. Política RLS de UPDATE para o próprio usuário (reordenação)
DROP POLICY IF EXISTS member_titles_update_own ON public.member_titles;
CREATE POLICY member_titles_update_own ON public.member_titles
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 4. RPC: manage_member_title (atualizado com sort_order e limite de 20)
-- ============================================================
-- Drop versão antiga com assinatura diferente
DROP FUNCTION IF EXISTS public.manage_member_title(uuid, uuid, text, text, text, text);

CREATE OR REPLACE FUNCTION public.manage_member_title(
  p_community_id    UUID,
  p_target_user_id  UUID,
  p_action          TEXT,   -- 'add', 'remove', 'update'
  p_title           TEXT,
  p_color           TEXT DEFAULT '#FFFFFF',
  p_icon            TEXT DEFAULT NULL,
  p_new_title       TEXT DEFAULT NULL,  -- para action='update'
  p_new_color       TEXT DEFAULT NULL   -- para action='update'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_my_role   TEXT;
  v_count     INT;
  v_max_order INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Verificar permissão: leader, agent ou team_admin
  SELECT role INTO v_my_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_my_role NOT IN ('leader', 'agent') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_team_admin = TRUE
    ) THEN
      RETURN jsonb_build_object('error', 'insufficient_permissions');
    END IF;
  END IF;

  IF p_action = 'add' THEN
    -- Verificar limite de 20 títulos (excluindo role badges)
    SELECT COUNT(*) INTO v_count
    FROM public.member_titles
    WHERE community_id = p_community_id
      AND user_id = p_target_user_id
      AND is_role_badge = FALSE;

    IF v_count >= 20 THEN
      RETURN jsonb_build_object('error', 'max_titles_reached', 'max', 20);
    END IF;

    -- Calcular próximo sort_order
    SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_max_order
    FROM public.member_titles
    WHERE community_id = p_community_id AND user_id = p_target_user_id;

    INSERT INTO public.member_titles
      (community_id, user_id, issued_by, title, color, icon, sort_order, is_role_badge)
    VALUES
      (p_community_id, p_target_user_id, v_user_id, p_title, p_color, p_icon, v_max_order, FALSE)
    ON CONFLICT (community_id, user_id, title) DO UPDATE
    SET color = p_color, icon = p_icon, is_visible = TRUE;

  ELSIF p_action = 'remove' THEN
    DELETE FROM public.member_titles
    WHERE community_id = p_community_id
      AND user_id = p_target_user_id
      AND title = p_title
      AND is_role_badge = FALSE;

  ELSIF p_action = 'update' THEN
    UPDATE public.member_titles
    SET
      title = COALESCE(p_new_title, title),
      color = COALESCE(p_new_color, color)
    WHERE community_id = p_community_id
      AND user_id = p_target_user_id
      AND title = p_title
      AND is_role_badge = FALSE;
  END IF;

  -- Atualizar cache custom_titles no community_members
  UPDATE public.community_members
  SET custom_titles = (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', mt.id,
          'title', mt.title,
          'color', mt.color,
          'icon', mt.icon,
          'is_role_badge', mt.is_role_badge,
          'sort_order', mt.sort_order
        ) ORDER BY mt.is_role_badge DESC, mt.sort_order ASC
      ),
      '[]'::jsonb
    )
    FROM public.member_titles mt
    WHERE mt.community_id = p_community_id
      AND mt.user_id = p_target_user_id
      AND mt.is_visible = TRUE
  )
  WHERE community_id = p_community_id AND user_id = p_target_user_id;

  RETURN jsonb_build_object('success', TRUE);
END;
$$;
GRANT EXECUTE ON FUNCTION public.manage_member_title TO authenticated;

-- ============================================================
-- 5. RPC: sync_role_badge — Sincroniza tag automática de cargo
-- Chamado ao mudar o role de um membro
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_role_badge(
  p_community_id UUID,
  p_user_id      UUID,
  p_role         user_role
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_badge_title TEXT;
  v_badge_color TEXT;
BEGIN
  -- Remover role badges antigos
  DELETE FROM public.member_titles
  WHERE community_id = p_community_id
    AND user_id = p_user_id
    AND is_role_badge = TRUE;

  -- Definir badge por cargo
  CASE p_role
    WHEN 'leader'  THEN v_badge_title := 'Líder';   v_badge_color := '#2DBE60';
    WHEN 'agent'   THEN v_badge_title := 'Agente';  v_badge_color := '#2DBE60';
    WHEN 'curator' THEN v_badge_title := 'Curador'; v_badge_color := '#2196F3';
    ELSE v_badge_title := NULL;
  END CASE;

  -- Inserir novo badge se aplicável
  IF v_badge_title IS NOT NULL THEN
    INSERT INTO public.member_titles
      (community_id, user_id, issued_by, title, color, sort_order, is_role_badge)
    VALUES
      (p_community_id, p_user_id, p_user_id, v_badge_title, v_badge_color, 0, TRUE)
    ON CONFLICT (community_id, user_id, title) DO UPDATE
    SET color = v_badge_color, is_visible = TRUE, is_role_badge = TRUE, sort_order = 0;
  END IF;

  -- Atualizar cache
  UPDATE public.community_members
  SET custom_titles = (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', mt.id,
          'title', mt.title,
          'color', mt.color,
          'icon', mt.icon,
          'is_role_badge', mt.is_role_badge,
          'sort_order', mt.sort_order
        ) ORDER BY mt.is_role_badge DESC, mt.sort_order ASC
      ),
      '[]'::jsonb
    )
    FROM public.member_titles mt
    WHERE mt.community_id = p_community_id
      AND mt.user_id = p_user_id
      AND mt.is_visible = TRUE
  )
  WHERE community_id = p_community_id AND user_id = p_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.sync_role_badge TO authenticated;

-- ============================================================
-- 6. RPC: sync_team_member_badge — Badge exclusivo para TeamMember
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_team_member_badge(
  p_user_id   UUID,
  p_is_team   BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_is_team THEN
    -- Inserir badge TeamMember em todas as comunidades que o usuário é membro
    INSERT INTO public.member_titles
      (community_id, user_id, issued_by, title, color, sort_order, is_role_badge)
    SELECT
      cm.community_id, p_user_id, p_user_id,
      'Team Member', '#FFFFFF', 0, TRUE
    FROM public.community_members cm
    WHERE cm.user_id = p_user_id
    ON CONFLICT (community_id, user_id, title) DO UPDATE
    SET color = '#FFFFFF', is_visible = TRUE, is_role_badge = TRUE;
  ELSE
    -- Remover badge TeamMember
    DELETE FROM public.member_titles
    WHERE user_id = p_user_id
      AND title = 'Team Member'
      AND is_role_badge = TRUE;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.sync_team_member_badge TO authenticated;

-- ============================================================
-- 7. RPC: reorder_member_titles — Usuário reordena seus próprios títulos
-- ============================================================
CREATE OR REPLACE FUNCTION public.reorder_member_titles(
  p_community_id UUID,
  p_ordered_ids  UUID[]   -- IDs dos títulos na nova ordem
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_id      UUID;
  v_idx     INT := 1;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Atualizar sort_order para cada título (apenas títulos não-role-badge do próprio usuário)
  FOREACH v_id IN ARRAY p_ordered_ids LOOP
    UPDATE public.member_titles
    SET sort_order = v_idx
    WHERE id = v_id
      AND user_id = v_user_id
      AND community_id = p_community_id
      AND is_role_badge = FALSE;
    v_idx := v_idx + 1;
  END LOOP;

  -- Atualizar cache
  UPDATE public.community_members
  SET custom_titles = (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', mt.id,
          'title', mt.title,
          'color', mt.color,
          'icon', mt.icon,
          'is_role_badge', mt.is_role_badge,
          'sort_order', mt.sort_order
        ) ORDER BY mt.is_role_badge DESC, mt.sort_order ASC
      ),
      '[]'::jsonb
    )
    FROM public.member_titles mt
    WHERE mt.community_id = p_community_id
      AND mt.user_id = v_user_id
      AND mt.is_visible = TRUE
  )
  WHERE community_id = p_community_id AND user_id = v_user_id;

  RETURN jsonb_build_object('success', TRUE);
END;
$$;
GRANT EXECUTE ON FUNCTION public.reorder_member_titles TO authenticated;

-- ============================================================
-- 8. RPC: delete_own_title — Usuário deleta um de seus próprios títulos
-- ============================================================
CREATE OR REPLACE FUNCTION public.delete_own_title(
  p_community_id UUID,
  p_title_id     UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  DELETE FROM public.member_titles
  WHERE id = p_title_id
    AND user_id = v_user_id
    AND community_id = p_community_id
    AND is_role_badge = FALSE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found_or_not_allowed');
  END IF;

  -- Atualizar cache
  UPDATE public.community_members
  SET custom_titles = (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', mt.id,
          'title', mt.title,
          'color', mt.color,
          'icon', mt.icon,
          'is_role_badge', mt.is_role_badge,
          'sort_order', mt.sort_order
        ) ORDER BY mt.is_role_badge DESC, mt.sort_order ASC
      ),
      '[]'::jsonb
    )
    FROM public.member_titles mt
    WHERE mt.community_id = p_community_id
      AND mt.user_id = v_user_id
      AND mt.is_visible = TRUE
  )
  WHERE community_id = p_community_id AND user_id = v_user_id;

  RETURN jsonb_build_object('success', TRUE);
END;
$$;
GRANT EXECUTE ON FUNCTION public.delete_own_title TO authenticated;

-- ============================================================
-- 9. RPC: get_member_titles_full — Lista completa de títulos de um membro
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_member_titles_full(
  p_community_id UUID,
  p_user_id      UUID
)
RETURNS TABLE (
  id            UUID,
  title         TEXT,
  color         TEXT,
  icon          TEXT,
  is_role_badge BOOLEAN,
  sort_order    INTEGER,
  issued_by_nickname TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mt.id,
    mt.title,
    mt.color,
    mt.icon,
    mt.is_role_badge,
    mt.sort_order,
    p.nickname AS issued_by_nickname
  FROM public.member_titles mt
  LEFT JOIN public.profiles p ON p.id = mt.issued_by
  WHERE mt.community_id = p_community_id
    AND mt.user_id = p_user_id
    AND mt.is_visible = TRUE
  ORDER BY mt.is_role_badge DESC, mt.sort_order ASC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_member_titles_full TO authenticated;

-- ============================================================
-- 10. Sincronizar role badges para membros existentes
-- ============================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT community_id, user_id, role
    FROM public.community_members
    WHERE role IN ('leader', 'agent', 'curator')
  LOOP
    PERFORM public.sync_role_badge(r.community_id, r.user_id, r.role::user_role);
  END LOOP;
END;
$$;

-- Sincronizar TeamMember badges para usuários is_team_admin
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.profiles WHERE is_team_admin = TRUE LOOP
    PERFORM public.sync_team_member_badge(r.id, TRUE);
  END LOOP;
END;
$$;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
