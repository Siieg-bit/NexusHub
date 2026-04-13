-- NexusHub — Migração 101: Corrigir Sistema de Wiki
-- =================================================
-- Objetivo: Garantir que wiki_data é salvo corretamente e adicionar RPC específica

-- ========================
-- 1. VERIFICAR COLUNA WIKI_DATA
-- ========================

-- Verificar se coluna wiki_data existe em posts (foi adicionada em migration 052)
-- Se não existir, adicionar:
ALTER TABLE public.posts
ADD COLUMN IF NOT EXISTS wiki_data JSONB DEFAULT NULL;

-- ========================
-- 2. CRIAR ÍNDICE PARA WIKI_DATA
-- ========================

CREATE INDEX IF NOT EXISTS idx_posts_wiki_data ON public.posts(id) WHERE type = 'wiki' AND wiki_data IS NOT NULL;

-- ========================
-- 3. RPC CREATE_WIKI_ENTRY
-- ========================

CREATE OR REPLACE FUNCTION public.create_wiki_entry(
  p_community_id UUID,
  p_title TEXT,
  p_content TEXT DEFAULT '',
  p_cover_image_url TEXT DEFAULT NULL,
  p_media_list JSONB DEFAULT '[]'::jsonb,
  p_tags JSONB DEFAULT '[]'::jsonb,
  p_visibility TEXT DEFAULT 'public',
  p_wiki_data JSONB DEFAULT NULL,
  p_editor_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_post_id UUID;
  v_is_member BOOLEAN;
  v_result jsonb;
BEGIN
  -- Validar autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Validar que usuário é membro da comunidade
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = false
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'Você não é membro desta comunidade';
  END IF;

  -- Validar inputs
  IF p_title IS NULL OR p_title = '' THEN
    RAISE EXCEPTION 'Título é obrigatório';
  END IF;

  IF p_visibility NOT IN ('public', 'private', 'community') THEN
    RAISE EXCEPTION 'Visibilidade inválida';
  END IF;

  -- Validar JSON fields
  IF jsonb_typeof(p_media_list) <> 'array' THEN
    RAISE EXCEPTION 'media_list deve ser um array JSON';
  END IF;

  IF jsonb_typeof(p_tags) <> 'array' THEN
    RAISE EXCEPTION 'tags deve ser um array JSON';
  END IF;

  IF p_editor_metadata IS NOT NULL AND jsonb_typeof(p_editor_metadata) <> 'object' THEN
    RAISE EXCEPTION 'editor_metadata deve ser um objeto JSON';
  END IF;

  IF p_wiki_data IS NOT NULL AND jsonb_typeof(p_wiki_data) <> 'object' THEN
    RAISE EXCEPTION 'wiki_data deve ser um objeto JSON';
  END IF;

  -- Inserir wiki como post
  INSERT INTO public.posts (
    community_id,
    author_id,
    type,
    title,
    content,
    media_list,
    cover_image_url,
    tags,
    visibility,
    editor_type,
    editor_metadata,
    wiki_data,
    status
  ) VALUES (
    p_community_id,
    v_user_id,
    'wiki'::public.post_type,
    p_title,
    p_content,
    p_media_list,
    p_cover_image_url,
    p_tags,
    p_visibility::public.post_visibility,
    'wiki',
    COALESCE(p_editor_metadata, '{}'::jsonb),
    p_wiki_data,
    'ok'::public.content_status
  ) RETURNING id INTO v_post_id;

  -- Adicionar reputação
  PERFORM public.add_reputation(v_user_id, p_community_id, 'post_wiki', 25, v_post_id);

  v_result := jsonb_build_object(
    'success', true,
    'post_id', v_post_id,
    'message', 'Wiki publicada com sucesso'
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_wiki_entry(
  UUID, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT, JSONB, JSONB
) TO authenticated;

-- ========================
-- 4. RPC GET_WIKI_ENTRY
-- ========================

CREATE OR REPLACE FUNCTION public.get_wiki_entry(
  p_post_id UUID
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
      'id', p.id,
      'title', p.title,
      'content', p.content,
      'cover_image_url', p.cover_image_url,
      'media_list', p.media_list,
      'tags', p.tags,
      'visibility', p.visibility,
      'author_id', p.author_id,
      'community_id', p.community_id,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'likes_count', p.likes_count,
      'comments_count', p.comments_count,
      'views_count', p.views_count,
      'editor_metadata', p.editor_metadata,
      'wiki_data', p.wiki_data,
      'author', jsonb_build_object(
        'id', pr.id,
        'display_name', pr.display_name,
        'avatar_url', pr.avatar_url
      )
    )
    FROM public.posts p
    LEFT JOIN public.profiles pr ON p.author_id = pr.id
    WHERE p.id = p_post_id AND p.type = 'wiki'
  );

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Wiki não encontrada';
  END IF;

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_wiki_entry(UUID) TO authenticated;

-- ========================
-- 5. ATUALIZAR RPC CREATE_POST_WITH_REPUTATION
-- ========================

-- Garantir que wiki_data é passado corretamente
-- A RPC já suporta wiki_data desde migration 052

-- ========================
-- 6. COMENTÁRIOS
-- ========================

COMMENT ON FUNCTION public.create_wiki_entry(UUID, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT, JSONB, JSONB) IS 'Cria uma entrada de wiki com validações completas';
COMMENT ON FUNCTION public.get_wiki_entry(UUID) IS 'Obtém uma entrada de wiki com todos os dados';
