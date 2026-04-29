-- ============================================================
-- Migration 186: Expandir create_community com mais parâmetros
-- Adiciona: p_icon_url, p_banner_url, p_tags, p_rules, p_about,
--           p_listed_status, p_accent_color
-- ============================================================

-- Remover todas as versões anteriores para evitar ambiguidade
DROP FUNCTION IF EXISTS public.create_community(TEXT, TEXT, TEXT, TEXT, public.community_join_type, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_community(TEXT, TEXT, TEXT, TEXT, public.community_join_type, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_community(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_community(TEXT, TEXT, TEXT, TEXT, public.community_join_type, TEXT, TEXT, TEXT, TEXT) CASCADE;

CREATE OR REPLACE FUNCTION public.create_community(
  p_name             TEXT,
  p_tagline          TEXT DEFAULT '',
  p_description      TEXT DEFAULT '',
  p_category         TEXT DEFAULT 'general',
  p_join_type        public.community_join_type DEFAULT 'open',
  p_theme_color      TEXT DEFAULT '#6C5CE7',
  p_accent_color     TEXT DEFAULT NULL,
  p_primary_language TEXT DEFAULT 'pt-BR',
  p_cover_image_url  TEXT DEFAULT NULL,
  p_icon_url         TEXT DEFAULT NULL,
  p_banner_url       TEXT DEFAULT NULL,
  p_tags             TEXT[] DEFAULT '{}',
  p_rules            TEXT DEFAULT '',
  p_about            TEXT DEFAULT '',
  p_listed_status    TEXT DEFAULT 'listed'
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
  v_accent_color  TEXT := COALESCE(NULLIF(trim(COALESCE(p_accent_color, '')), ''), v_theme_color);
  v_primary_lang  TEXT := COALESCE(NULLIF(trim(COALESCE(p_primary_language, '')), ''), 'pt-BR');
  v_listed_status TEXT := COALESCE(NULLIF(trim(COALESCE(p_listed_status, '')), ''), 'listed');
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

  -- Criar comunidade com todos os campos
  INSERT INTO public.communities (
    name, tagline, description, category, join_type,
    agent_id, theme_color, theme_accent_color, primary_language,
    cover_image_url, icon_url, banner_url,
    community_tags, rules, about_text,
    listed_status, theme_primary_color
  ) VALUES (
    v_name, v_tagline, v_description, v_category,
    COALESCE(p_join_type, 'open'::public.community_join_type),
    v_user_id, v_theme_color, v_accent_color, v_primary_lang,
    p_cover_image_url,
    COALESCE(p_icon_url, ''),
    COALESCE(p_banner_url, ''),
    COALESCE(p_tags, '{}'),
    COALESCE(p_rules, ''),
    COALESCE(p_about, ''),
    v_listed_status,
    v_theme_color
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

  -- Criar guidelines padrão (ou usar as regras fornecidas)
  INSERT INTO public.guidelines (community_id, content)
  VALUES (
    v_community_id,
    CASE
      WHEN COALESCE(p_rules, '') = '' THEN
        '# Regras da Comunidade' || E'\n\n' || 'Seja respeitoso e siga as regras.'
      ELSE
        p_rules
    END
  );

  -- Criar shared folder
  INSERT INTO public.shared_folders (community_id)
  VALUES (v_community_id);

  RETURN jsonb_build_object(
    'success', true,
    'community_id', v_community_id::TEXT
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_community TO authenticated;

NOTIFY pgrst, 'reload schema';
