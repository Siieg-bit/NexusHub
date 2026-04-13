-- NexusHub — Migração 103: Sistema de Links Inteligente
-- =====================================================
-- Objetivo: Adicionar tabela de links com preview, detecção de internos e metadados

-- ========================
-- 1. CRIAR TABELA DE LINKS
-- ========================

CREATE TABLE IF NOT EXISTS public.smart_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  url TEXT NOT NULL UNIQUE,
  
  -- Tipo de link
  link_type TEXT DEFAULT 'external', -- external, internal_post, internal_community, internal_user
  
  -- Dados do link interno (se aplicável)
  internal_post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
  internal_community_id UUID REFERENCES public.communities(id) ON DELETE SET NULL,
  internal_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  
  -- Metadados do link
  title TEXT,
  description TEXT,
  image_url TEXT,
  domain TEXT,
  favicon_url TEXT,
  
  -- Customização do usuário
  custom_title TEXT,
  custom_description TEXT,
  
  -- Estatísticas
  click_count INTEGER DEFAULT 0,
  last_clicked_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT valid_internal_link CHECK (
    (link_type = 'external' AND internal_post_id IS NULL AND internal_community_id IS NULL AND internal_user_id IS NULL) OR
    (link_type = 'internal_post' AND internal_post_id IS NOT NULL) OR
    (link_type = 'internal_community' AND internal_community_id IS NOT NULL) OR
    (link_type = 'internal_user' AND internal_user_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_smart_links_url ON public.smart_links(url);
CREATE INDEX IF NOT EXISTS idx_smart_links_type ON public.smart_links(link_type);
CREATE INDEX IF NOT EXISTS idx_smart_links_domain ON public.smart_links(domain);
CREATE INDEX IF NOT EXISTS idx_smart_links_created ON public.smart_links(created_at DESC);

-- ========================
-- 2. CRIAR TABELA DE USOS DE LINKS
-- ========================

CREATE TABLE IF NOT EXISTS public.link_usages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id UUID NOT NULL REFERENCES public.smart_links(id) ON DELETE CASCADE,
  
  -- Contexto de uso
  usage_context TEXT DEFAULT 'message', -- message, comment, post, blog, etc
  context_id UUID, -- ID da mensagem, comentário, post, etc
  
  -- Usuário que adicionou o link
  added_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_link_usages_link ON public.link_usages(link_id);
CREATE INDEX IF NOT EXISTS idx_link_usages_context ON public.link_usages(usage_context, context_id);
CREATE INDEX IF NOT EXISTS idx_link_usages_user ON public.link_usages(added_by);

-- ========================
-- 3. RPC DETECT_AND_SAVE_LINK
-- ========================

CREATE OR REPLACE FUNCTION public.detect_and_save_link(
  p_url TEXT,
  p_custom_title TEXT DEFAULT NULL,
  p_custom_description TEXT DEFAULT NULL,
  p_usage_context TEXT DEFAULT 'message',
  p_context_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_link_id UUID;
  v_link_type TEXT := 'external';
  v_internal_post_id UUID;
  v_internal_community_id UUID;
  v_internal_user_id UUID;
  v_domain TEXT;
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Extrair domínio
  v_domain := (regexp_matches(p_url, 'https?://([^/]+)', 'g'))[1];
  IF v_domain IS NULL THEN
    v_domain := p_url;
  END IF;

  -- Detectar links internos
  -- Formato: /post/{id}, /community/{id}, /user/{id}
  IF p_url LIKE '/post/%' THEN
    v_internal_post_id := (regexp_matches(p_url, '/post/([a-f0-9-]+)', 'g'))[1]::UUID;
    IF v_internal_post_id IS NOT NULL THEN
      v_link_type := 'internal_post';
    END IF;
  ELSIF p_url LIKE '/community/%' THEN
    v_internal_community_id := (regexp_matches(p_url, '/community/([a-f0-9-]+)', 'g'))[1]::UUID;
    IF v_internal_community_id IS NOT NULL THEN
      v_link_type := 'internal_community';
    END IF;
  ELSIF p_url LIKE '/user/%' THEN
    v_internal_user_id := (regexp_matches(p_url, '/user/([a-f0-9-]+)', 'g'))[1]::UUID;
    IF v_internal_user_id IS NOT NULL THEN
      v_link_type := 'internal_user';
    END IF;
  END IF;

  -- Inserir ou obter link existente
  INSERT INTO public.smart_links (
    url,
    link_type,
    internal_post_id,
    internal_community_id,
    internal_user_id,
    custom_title,
    custom_description,
    domain
  ) VALUES (
    p_url,
    v_link_type,
    v_internal_post_id,
    v_internal_community_id,
    v_internal_user_id,
    p_custom_title,
    p_custom_description,
    v_domain
  )
  ON CONFLICT (url) DO UPDATE
  SET
    custom_title = COALESCE(p_custom_title, custom_title),
    custom_description = COALESCE(p_custom_description, custom_description),
    updated_at = NOW()
  RETURNING id INTO v_link_id;

  -- Registrar uso do link
  INSERT INTO public.link_usages (
    link_id,
    usage_context,
    context_id,
    added_by
  ) VALUES (
    v_link_id,
    p_usage_context,
    p_context_id,
    v_user_id
  );

  v_result := jsonb_build_object(
    'success', true,
    'link_id', v_link_id,
    'link_type', v_link_type,
    'domain', v_domain
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.detect_and_save_link(TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;

-- ========================
-- 4. RPC GET_LINK_PREVIEW
-- ========================

CREATE OR REPLACE FUNCTION public.get_link_preview(
  p_link_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
  v_post jsonb;
  v_community jsonb;
  v_user jsonb;
BEGIN
  v_result := (
    SELECT jsonb_build_object(
      'id', sl.id,
      'url', sl.url,
      'link_type', sl.link_type,
      'title', COALESCE(sl.custom_title, sl.title),
      'description', COALESCE(sl.custom_description, sl.description),
      'image_url', sl.image_url,
      'domain', sl.domain,
      'favicon_url', sl.favicon_url,
      'click_count', sl.click_count
    )
    FROM public.smart_links sl
    WHERE sl.id = p_link_id
  );

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Link não encontrado';
  END IF;

  -- Se for link interno, adicionar dados do objeto
  IF (v_result->>'link_type') = 'internal_post' THEN
    SELECT jsonb_build_object(
      'id', p.id,
      'title', p.title,
      'content', p.content,
      'author', pr.display_name,
      'community', c.name
    )
    INTO v_post
    FROM public.posts p
    LEFT JOIN public.profiles pr ON p.author_id = pr.id
    LEFT JOIN public.communities c ON p.community_id = c.id
    WHERE p.id = (v_result->>'internal_post_id')::UUID;
    
    v_result := v_result || jsonb_build_object('internal_data', v_post);
  END IF;

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_link_preview(UUID) TO authenticated;

-- ========================
-- 5. RPC UPDATE_LINK_METADATA
-- ========================

CREATE OR REPLACE FUNCTION public.update_link_metadata(
  p_link_id UUID,
  p_title TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_favicon_url TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  UPDATE public.smart_links
  SET
    title = COALESCE(p_title, title),
    description = COALESCE(p_description, description),
    image_url = COALESCE(p_image_url, image_url),
    favicon_url = COALESCE(p_favicon_url, favicon_url),
    updated_at = NOW()
  WHERE id = p_link_id;

  v_result := jsonb_build_object(
    'success', true,
    'message', 'Metadados do link atualizados'
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.update_link_metadata(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ========================
-- 6. RPC TRACK_LINK_CLICK
-- ========================

CREATE OR REPLACE FUNCTION public.track_link_click(
  p_link_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  UPDATE public.smart_links
  SET
    click_count = click_count + 1,
    last_clicked_at = NOW()
  WHERE id = p_link_id;

  v_result := jsonb_build_object(
    'success', true,
    'message', 'Clique registrado'
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.track_link_click(UUID) TO authenticated;

-- ========================
-- 7. RPC GET_POPULAR_LINKS
-- ========================

CREATE OR REPLACE FUNCTION public.get_popular_links(
  p_limit INTEGER DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  v_result := jsonb_build_object(
    'links', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', sl.id,
          'url', sl.url,
          'title', COALESCE(sl.custom_title, sl.title),
          'domain', sl.domain,
          'click_count', sl.click_count,
          'image_url', sl.image_url
        )
        ORDER BY sl.click_count DESC
      )
      FROM public.smart_links sl
      LIMIT p_limit
    )
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_popular_links(INTEGER) TO authenticated;

-- ========================
-- 8. COMENTÁRIOS
-- ========================

COMMENT ON TABLE public.smart_links IS 'Tabela de links inteligentes com detecção de tipo e metadados';
COMMENT ON TABLE public.link_usages IS 'Registro de uso de links em diferentes contextos';
COMMENT ON COLUMN public.smart_links.link_type IS 'Tipo de link: external, internal_post, internal_community, internal_user';
COMMENT ON COLUMN public.smart_links.custom_title IS 'Título customizado pelo usuário';
COMMENT ON COLUMN public.smart_links.custom_description IS 'Descrição customizada pelo usuário';
COMMENT ON FUNCTION public.detect_and_save_link(TEXT, TEXT, TEXT, TEXT, UUID) IS 'Detecta tipo de link, salva e registra uso';
COMMENT ON FUNCTION public.get_link_preview(UUID) IS 'Obtém preview completo de um link';
COMMENT ON FUNCTION public.update_link_metadata(UUID, TEXT, TEXT, TEXT, TEXT) IS 'Atualiza metadados de um link';
COMMENT ON FUNCTION public.track_link_click(UUID) IS 'Registra clique em um link';
COMMENT ON FUNCTION public.get_popular_links(INTEGER) IS 'Obtém links mais populares por cliques';
