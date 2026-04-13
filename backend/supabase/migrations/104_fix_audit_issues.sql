-- =============================================================================
-- Migration 104: Correções da Auditoria
--
-- Corrige:
-- 1. get_my_communities — remove referência à coluna 'status' inexistente
-- 2. Garante que content_status enum tem valor 'ok'
-- 3. Corrige create_community para aceitar cover_image_url
-- =============================================================================

-- ========================
-- 1. FIX get_my_communities — remover cm.status = 'active' (coluna não existe)
-- ========================
DROP FUNCTION IF EXISTS public.get_my_communities(BOOLEAN);

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
        ORDER BY cm.joined_at DESC
      )
      FROM public.communities c
      INNER JOIN public.community_members cm ON c.id = cm.community_id
      WHERE cm.user_id = v_user_id
        AND cm.is_banned = false
        AND c.status != 'deleted'::public.content_status
    )
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_my_communities(BOOLEAN) TO authenticated;

-- ========================
-- 2. Garantir que content_status tem 'ok'
-- ========================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'content_status' AND e.enumlabel = 'ok'
  ) THEN
    ALTER TYPE public.content_status ADD VALUE IF NOT EXISTS 'ok';
  END IF;
END $$;

-- ========================
-- 3. Atualizar create_community para aceitar cover_image_url
-- ========================
DROP FUNCTION IF EXISTS public.create_community(text, text, text, text, public.community_join_type, text, text);

CREATE OR REPLACE FUNCTION public.create_community(
  p_name TEXT,
  p_tagline TEXT DEFAULT '',
  p_description TEXT DEFAULT '',
  p_category TEXT DEFAULT 'general',
  p_join_type public.community_join_type DEFAULT 'open',
  p_theme_color TEXT DEFAULT '#6C5CE7',
  p_primary_language TEXT DEFAULT 'pt-BR',
  p_cover_image_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id       UUID := auth.uid();
  v_community_id  UUID;
  v_name          TEXT := NULLIF(trim(COALESCE(p_name, '')), '');
  v_tagline       TEXT := NULLIF(trim(COALESCE(p_tagline, '')), '');
  v_description   TEXT := NULLIF(trim(COALESCE(p_description, '')), '');
  v_category      TEXT := COALESCE(NULLIF(trim(COALESCE(p_category, '')), ''), 'general');
  v_theme_color   TEXT := COALESCE(NULLIF(trim(COALESCE(p_theme_color, '')), ''), '#6C5CE7');
  v_primary_lang  TEXT := COALESCE(NULLIF(trim(COALESCE(p_primary_language, '')), ''), 'pt-BR');
  -- Perfil global do criador
  v_nickname      TEXT;
  v_bio           TEXT;
  v_icon_url      TEXT;
  v_banner_url    TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;
  IF v_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'name_required');
  END IF;

  -- Buscar perfil global do criador para usar como perfil local inicial
  SELECT nickname, bio, icon_url, banner_url
    INTO v_nickname, v_bio, v_icon_url, v_banner_url
    FROM public.profiles
   WHERE id = v_user_id;

  -- Criar comunidade
  INSERT INTO public.communities (
    name, tagline, description, category, join_type,
    agent_id, theme_color, primary_language, cover_image_url,
    theme_primary_color
  ) VALUES (
    v_name, v_tagline, v_description, v_category,
    COALESCE(p_join_type, 'open'::public.community_join_type),
    v_user_id, v_theme_color, v_primary_lang,
    p_cover_image_url, v_theme_color
  )
  RETURNING id INTO v_community_id;

  -- Adicionar criador como AGENT com perfil local = cópia do global
  INSERT INTO public.community_members (
    community_id, user_id, role,
    local_nickname, local_bio, local_icon_url, local_banner_url
  ) VALUES (
    v_community_id, v_user_id, 'agent',
    v_nickname, v_bio, v_icon_url, v_banner_url
  );

  -- Criar guidelines padrão
  INSERT INTO public.guidelines (community_id, content)
  VALUES (v_community_id, '# Regras da Comunidade' || E'\n\n' || 'Seja respeitoso e siga as regras.');

  -- Criar shared folder
  INSERT INTO public.shared_folders (community_id)
  VALUES (v_community_id);

  RETURN jsonb_build_object('success', true, 'community_id', v_community_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_community(TEXT, TEXT, TEXT, TEXT, public.community_join_type, TEXT, TEXT, TEXT) TO authenticated;
