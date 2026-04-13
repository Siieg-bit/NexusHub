-- NexusHub — Migração 102: Melhorias Visuais de Comunidades
-- =========================================================
-- Objetivo: Adicionar capa de comunidade, cor tema e melhorias visuais

-- ========================
-- 1. ADICIONAR COLUNAS À TABELA COMMUNITIES
-- ========================

ALTER TABLE public.communities
ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
ADD COLUMN IF NOT EXISTS theme_primary_color TEXT DEFAULT '#0B0B0B',
ADD COLUMN IF NOT EXISTS theme_accent_color TEXT DEFAULT '#FF6B6B',
ADD COLUMN IF NOT EXISTS theme_secondary_color TEXT DEFAULT '#4ECDC4',
ADD COLUMN IF NOT EXISTS cover_position TEXT DEFAULT 'center',
ADD COLUMN IF NOT EXISTS cover_blur BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS cover_overlay_opacity NUMERIC DEFAULT 0.3,
ADD COLUMN IF NOT EXISTS visual_metadata JSONB DEFAULT '{}'::jsonb;

-- ========================
-- 2. CRIAR ÍNDICES
-- ========================

CREATE INDEX IF NOT EXISTS idx_communities_theme_color ON public.communities(theme_primary_color);
CREATE INDEX IF NOT EXISTS idx_communities_cover ON public.communities(id) WHERE cover_image_url IS NOT NULL;

-- ========================
-- 3. RPC UPDATE_COMMUNITY_VISUALS
-- ========================

CREATE OR REPLACE FUNCTION public.update_community_visuals(
  p_community_id UUID,
  p_cover_image_url TEXT DEFAULT NULL,
  p_theme_primary_color TEXT DEFAULT NULL,
  p_theme_accent_color TEXT DEFAULT NULL,
  p_theme_secondary_color TEXT DEFAULT NULL,
  p_cover_position TEXT DEFAULT NULL,
  p_cover_blur BOOLEAN DEFAULT NULL,
  p_cover_overlay_opacity NUMERIC DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_owner BOOLEAN;
  v_result jsonb;
BEGIN
  -- Validar autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar se usuário é dono/admin da comunidade
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND role IN ('leader', 'curator')
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RAISE EXCEPTION 'Você não tem permissão para editar esta comunidade';
  END IF;

  -- Validar cores (formato hex)
  IF p_theme_primary_color IS NOT NULL AND NOT p_theme_primary_color ~ '^#[0-9A-Fa-f]{6}$' THEN
    RAISE EXCEPTION 'Cor primária inválida. Use formato #RRGGBB';
  END IF;

  IF p_theme_accent_color IS NOT NULL AND NOT p_theme_accent_color ~ '^#[0-9A-Fa-f]{6}$' THEN
    RAISE EXCEPTION 'Cor de destaque inválida. Use formato #RRGGBB';
  END IF;

  IF p_theme_secondary_color IS NOT NULL AND NOT p_theme_secondary_color ~ '^#[0-9A-Fa-f]{6}$' THEN
    RAISE EXCEPTION 'Cor secundária inválida. Use formato #RRGGBB';
  END IF;

  -- Validar posição da capa
  IF p_cover_position IS NOT NULL AND p_cover_position NOT IN ('center', 'top', 'bottom') THEN
    RAISE EXCEPTION 'Posição da capa inválida. Use: center, top ou bottom';
  END IF;

  -- Validar opacidade
  IF p_cover_overlay_opacity IS NOT NULL AND (p_cover_overlay_opacity < 0 OR p_cover_overlay_opacity > 1) THEN
    RAISE EXCEPTION 'Opacidade deve estar entre 0 e 1';
  END IF;

  -- Atualizar comunidade
  UPDATE public.communities
  SET
    cover_image_url = COALESCE(p_cover_image_url, cover_image_url),
    theme_primary_color = COALESCE(p_theme_primary_color, theme_primary_color),
    theme_accent_color = COALESCE(p_theme_accent_color, theme_accent_color),
    theme_secondary_color = COALESCE(p_theme_secondary_color, theme_secondary_color),
    cover_position = COALESCE(p_cover_position, cover_position),
    cover_blur = COALESCE(p_cover_blur, cover_blur),
    cover_overlay_opacity = COALESCE(p_cover_overlay_opacity, cover_overlay_opacity),
    updated_at = NOW()
  WHERE id = p_community_id;

  v_result := jsonb_build_object(
    'success', true,
    'message', 'Visuais da comunidade atualizados com sucesso'
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.update_community_visuals(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC
) TO authenticated;

-- ========================
-- 4. RPC GET_COMMUNITY_WITH_VISUALS
-- ========================

CREATE OR REPLACE FUNCTION public.get_community_with_visuals(
  p_community_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  v_result := (
    SELECT jsonb_build_object(
      'id', c.id,
      'name', c.name,
      'tagline', c.tagline,
      'description', c.description,
      'icon_url', c.icon_url,
      'banner_url', c.banner_url,
      'cover_image_url', c.cover_image_url,
      'endpoint', c.endpoint,
      'members_count', c.members_count,
      'posts_count', c.posts_count,
      'theme', jsonb_build_object(
        'primary_color', c.theme_primary_color,
        'accent_color', c.theme_accent_color,
        'secondary_color', c.theme_secondary_color,
        'cover_position', c.cover_position,
        'cover_blur', c.cover_blur,
        'cover_overlay_opacity', c.cover_overlay_opacity
      ),
      'created_at', c.created_at,
      'updated_at', c.updated_at
    )
    FROM public.communities c
    WHERE c.id = p_community_id
  );

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Comunidade não encontrada';
  END IF;

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_community_with_visuals(UUID) TO authenticated;

-- ========================
-- 5. RPC GET_MY_COMMUNITIES
-- ========================

CREATE OR REPLACE FUNCTION public.get_my_communities(
  p_include_created BOOLEAN DEFAULT TRUE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  v_result := jsonb_build_object(
    'communities', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name', c.name,
          'tagline', c.tagline,
          'icon_url', c.icon_url,
          'banner_url', c.banner_url,
          'cover_image_url', c.cover_image_url,
          'endpoint', c.endpoint,
          'members_count', c.members_count,
          'posts_count', c.posts_count,
          'role', cm.role,
          'is_created_by_me', c.agent_id = v_user_id,
          'theme', jsonb_build_object(
            'primary_color', c.theme_primary_color,
            'accent_color', c.theme_accent_color,
            'secondary_color', c.theme_secondary_color
          ),
          'created_at', c.created_at
        )
        ORDER BY cm.created_at DESC
      )
      FROM public.communities c
      INNER JOIN public.community_members cm ON c.id = cm.community_id
      WHERE cm.user_id = v_user_id
        AND cm.status = 'active'
        AND (NOT p_include_created OR c.agent_id = v_user_id OR cm.role IN ('leader', 'curator'))
    )
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_my_communities(BOOLEAN) TO authenticated;

-- ========================
-- 6. COMENTÁRIOS
-- ========================

COMMENT ON COLUMN public.communities.cover_image_url IS 'URL da imagem de capa da comunidade';
COMMENT ON COLUMN public.communities.theme_primary_color IS 'Cor primária do tema em formato #RRGGBB';
COMMENT ON COLUMN public.communities.theme_accent_color IS 'Cor de destaque do tema em formato #RRGGBB';
COMMENT ON COLUMN public.communities.theme_secondary_color IS 'Cor secundária do tema em formato #RRGGBB';
COMMENT ON COLUMN public.communities.cover_position IS 'Posição da capa: center, top ou bottom';
COMMENT ON COLUMN public.communities.cover_blur IS 'Aplicar desfoque na capa';
COMMENT ON COLUMN public.communities.cover_overlay_opacity IS 'Opacidade do overlay da capa (0-1)';
COMMENT ON FUNCTION public.update_community_visuals(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) IS 'Atualiza visuais de uma comunidade (capa, cores, etc)';
COMMENT ON FUNCTION public.get_community_with_visuals(UUID) IS 'Obtém comunidade com todos os dados visuais';
COMMENT ON FUNCTION public.get_my_communities(BOOLEAN) IS 'Obtém comunidades do usuário, opcionalmente incluindo criadas';
