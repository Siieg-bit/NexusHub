-- Migration 150: Featured Members
-- RPCs para destacar/remover destaque de membros e listar os membros em destaque.

-- ─── 1. RPC: toggle_featured_member ────────────────────────────────────────
-- Adiciona ou remove um membro do destaque da comunidade (máx. 10 por comunidade).
CREATE OR REPLACE FUNCTION public.toggle_featured_member(
  p_community_id UUID,
  p_target_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id   UUID := auth.uid();
  v_is_staff   BOOLEAN;
  v_existing   UUID;
  v_count      INT;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Verificar que o actor é staff da comunidade
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_actor_id
      AND role IN ('leader', 'co_leader', 'moderator', 'agent')
  ) INTO v_is_staff;

  IF NOT v_is_staff THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  -- Verificar se já está em destaque
  SELECT id INTO v_existing
  FROM public.featured_content
  WHERE community_id = p_community_id
    AND user_id = p_target_user_id
    AND type = 'member';

  IF v_existing IS NOT NULL THEN
    -- Remover destaque
    DELETE FROM public.featured_content WHERE id = v_existing;
    RETURN jsonb_build_object('action', 'removed', 'user_id', p_target_user_id);
  ELSE
    -- Verificar limite de 10 membros em destaque
    SELECT COUNT(*) INTO v_count
    FROM public.featured_content
    WHERE community_id = p_community_id AND type = 'member';

    IF v_count >= 10 THEN
      RAISE EXCEPTION 'max_featured_members_reached';
    END IF;

    -- Adicionar destaque
    INSERT INTO public.featured_content (
      community_id, user_id, type, featured_by, sort_order
    ) VALUES (
      p_community_id, p_target_user_id, 'member', v_actor_id, v_count
    );

    RETURN jsonb_build_object('action', 'added', 'user_id', p_target_user_id);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_featured_member(UUID, UUID) TO authenticated;

-- ─── 2. RPC: get_featured_members ───────────────────────────────────────────
-- Retorna os membros em destaque de uma comunidade com seus dados de perfil.
CREATE OR REPLACE FUNCTION public.get_featured_members(
  p_community_id UUID
)
RETURNS TABLE (
  featured_id   UUID,
  user_id       UUID,
  username      TEXT,
  display_name  TEXT,
  avatar_url    TEXT,
  level         INT,
  role          TEXT,
  sort_order    INT,
  featured_at   TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    fc.id            AS featured_id,
    fc.user_id,
    p.nickname       AS username,
    p.nickname       AS display_name,
    p.icon_url       AS avatar_url,
    COALESCE(p.level, 1) AS level,
    COALESCE(cm.role, 'member') AS role,
    fc.sort_order,
    fc.created_at    AS featured_at
  FROM public.featured_content fc
  JOIN public.profiles p ON p.id = fc.user_id
  LEFT JOIN public.community_members cm
    ON cm.community_id = fc.community_id AND cm.user_id = fc.user_id
  WHERE fc.community_id = p_community_id
    AND fc.type = 'member'
    AND (fc.expires_at IS NULL OR fc.expires_at > NOW())
  ORDER BY fc.sort_order ASC, fc.created_at ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_featured_members(UUID) TO authenticated, anon;
