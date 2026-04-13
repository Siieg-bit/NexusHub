-- NexusHub — Migração 100: Melhorar Sistema de Rascunhos
-- ======================================================
-- Objetivo: Adicionar suporte a múltiplos rascunhos com nomes e melhor organização

-- ========================
-- 1. ADICIONAR COLUNAS À TABELA POST_DRAFTS
-- ========================

-- Adicionar coluna de nome/identificador do rascunho
ALTER TABLE public.post_drafts
ADD COLUMN IF NOT EXISTS draft_name TEXT DEFAULT 'Rascunho sem título',
ADD COLUMN IF NOT EXISTS draft_type TEXT DEFAULT 'normal', -- normal, blog, poll, quiz, wiki, story
ADD COLUMN IF NOT EXISTS is_auto_save BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_auto_save_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
ADD COLUMN IF NOT EXISTS editor_metadata JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS editor_state JSONB,
ADD COLUMN IF NOT EXISTS poll_options JSONB,
ADD COLUMN IF NOT EXISTS quiz_data JSONB,
ADD COLUMN IF NOT EXISTS wiki_data JSONB,
ADD COLUMN IF NOT EXISTS story_data JSONB;

-- ========================
-- 2. CRIAR ÍNDICES ADICIONAIS
-- ========================

CREATE INDEX IF NOT EXISTS idx_post_drafts_type ON public.post_drafts(user_id, draft_type);
CREATE INDEX IF NOT EXISTS idx_post_drafts_community ON public.post_drafts(community_id, user_id);
CREATE INDEX IF NOT EXISTS idx_post_drafts_auto_save ON public.post_drafts(user_id, is_auto_save);

-- ========================
-- 3. RPC SAVE_DRAFT
-- ========================

CREATE OR REPLACE FUNCTION public.save_draft(
  p_community_id UUID,
  p_draft_name TEXT,
  p_draft_type TEXT DEFAULT 'normal',
  p_title TEXT DEFAULT NULL,
  p_content TEXT DEFAULT NULL,
  p_content_blocks JSONB DEFAULT NULL,
  p_media_urls JSONB DEFAULT '[]'::jsonb,
  p_tags JSONB DEFAULT '[]'::jsonb,
  p_visibility TEXT DEFAULT 'public',
  p_cover_image_url TEXT DEFAULT NULL,
  p_editor_metadata JSONB DEFAULT '{}'::jsonb,
  p_editor_state JSONB DEFAULT NULL,
  p_poll_options JSONB DEFAULT NULL,
  p_quiz_data JSONB DEFAULT NULL,
  p_wiki_data JSONB DEFAULT NULL,
  p_story_data JSONB DEFAULT NULL,
  p_draft_id UUID DEFAULT NULL,
  p_is_auto_save BOOLEAN DEFAULT FALSE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_draft_id UUID;
  v_result jsonb;
BEGIN
  -- Validar autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Validar draft_type
  IF p_draft_type NOT IN ('normal', 'blog', 'poll', 'quiz', 'wiki', 'story') THEN
    RAISE EXCEPTION 'Tipo de rascunho inválido';
  END IF;

  -- Se draft_id fornecido, atualizar; senão criar novo
  IF p_draft_id IS NOT NULL THEN
    -- Verificar se draft pertence ao usuário
    IF NOT EXISTS (
      SELECT 1 FROM public.post_drafts
      WHERE id = p_draft_id AND user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'Rascunho não encontrado';
    END IF;

    -- Atualizar draft existente
    UPDATE public.post_drafts
    SET
      draft_name = COALESCE(p_draft_name, draft_name),
      draft_type = COALESCE(p_draft_type, draft_type),
      title = COALESCE(p_title, title),
      content = COALESCE(p_content, content),
      content_blocks = COALESCE(p_content_blocks, content_blocks),
      media_urls = COALESCE(p_media_urls, media_urls),
      tags = COALESCE(p_tags, tags),
      visibility = COALESCE(p_visibility, visibility),
      cover_image_url = COALESCE(p_cover_image_url, cover_image_url),
      editor_metadata = COALESCE(p_editor_metadata, editor_metadata),
      editor_state = COALESCE(p_editor_state, editor_state),
      poll_options = COALESCE(p_poll_options, poll_options),
      quiz_data = COALESCE(p_quiz_data, quiz_data),
      wiki_data = COALESCE(p_wiki_data, wiki_data),
      story_data = COALESCE(p_story_data, story_data),
      is_auto_save = p_is_auto_save,
      last_auto_save_at = CASE WHEN p_is_auto_save THEN NOW() ELSE last_auto_save_at END,
      updated_at = NOW()
    WHERE id = p_draft_id
    RETURNING id INTO v_draft_id;
  ELSE
    -- Criar novo draft
    INSERT INTO public.post_drafts (
      user_id,
      community_id,
      draft_name,
      draft_type,
      title,
      content,
      content_blocks,
      media_urls,
      tags,
      visibility,
      cover_image_url,
      editor_metadata,
      editor_state,
      poll_options,
      quiz_data,
      wiki_data,
      story_data,
      is_auto_save,
      last_auto_save_at
    ) VALUES (
      v_user_id,
      p_community_id,
      p_draft_name,
      p_draft_type,
      p_title,
      p_content,
      p_content_blocks,
      p_media_urls,
      p_tags,
      p_visibility,
      p_cover_image_url,
      p_editor_metadata,
      p_editor_state,
      p_poll_options,
      p_quiz_data,
      p_wiki_data,
      p_story_data,
      p_is_auto_save,
      CASE WHEN p_is_auto_save THEN NOW() ELSE NULL END
    ) RETURNING id INTO v_draft_id;
  END IF;

  v_result := jsonb_build_object(
    'success', true,
    'draft_id', v_draft_id
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.save_draft(
  UUID, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, JSONB, TEXT, TEXT, JSONB, JSONB, JSONB, JSONB, JSONB, JSONB, UUID, BOOLEAN
) TO authenticated;

-- ========================
-- 4. RPC GET_DRAFTS
-- ========================

CREATE OR REPLACE FUNCTION public.get_drafts(
  p_community_id UUID DEFAULT NULL,
  p_draft_type TEXT DEFAULT NULL
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
    'drafts', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', pd.id,
          'draft_name', pd.draft_name,
          'draft_type', pd.draft_type,
          'title', pd.title,
          'community_id', pd.community_id,
          'created_at', pd.created_at,
          'updated_at', pd.updated_at,
          'is_auto_save', pd.is_auto_save,
          'last_auto_save_at', pd.last_auto_save_at
        )
        ORDER BY pd.updated_at DESC
      )
      FROM public.post_drafts pd
      WHERE pd.user_id = v_user_id
        AND (p_community_id IS NULL OR pd.community_id = p_community_id)
        AND (p_draft_type IS NULL OR pd.draft_type = p_draft_type)
    )
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_drafts(UUID, TEXT) TO authenticated;

-- ========================
-- 5. RPC GET_DRAFT
-- ========================

CREATE OR REPLACE FUNCTION public.get_draft(
  p_draft_id UUID
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

  -- Verificar se draft pertence ao usuário
  IF NOT EXISTS (
    SELECT 1 FROM public.post_drafts
    WHERE id = p_draft_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Rascunho não encontrado';
  END IF;

  v_result := (
    SELECT jsonb_build_object(
      'id', pd.id,
      'draft_name', pd.draft_name,
      'draft_type', pd.draft_type,
      'title', pd.title,
      'content', pd.content,
      'content_blocks', pd.content_blocks,
      'media_urls', pd.media_urls,
      'tags', pd.tags,
      'visibility', pd.visibility,
      'cover_image_url', pd.cover_image_url,
      'editor_metadata', pd.editor_metadata,
      'editor_state', pd.editor_state,
      'poll_options', pd.poll_options,
      'quiz_data', pd.quiz_data,
      'wiki_data', pd.wiki_data,
      'story_data', pd.story_data,
      'community_id', pd.community_id,
      'created_at', pd.created_at,
      'updated_at', pd.updated_at
    )
    FROM public.post_drafts pd
    WHERE pd.id = p_draft_id AND pd.user_id = v_user_id
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_draft(UUID) TO authenticated;

-- ========================
-- 6. RPC DELETE_DRAFT
-- ========================

CREATE OR REPLACE FUNCTION public.delete_draft(
  p_draft_id UUID
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

  -- Verificar se draft pertence ao usuário
  IF NOT EXISTS (
    SELECT 1 FROM public.post_drafts
    WHERE id = p_draft_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Rascunho não encontrado';
  END IF;

  -- Deletar draft
  DELETE FROM public.post_drafts
  WHERE id = p_draft_id AND user_id = v_user_id;

  v_result := jsonb_build_object(
    'success', true,
    'message', 'Rascunho deletado com sucesso'
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.delete_draft(UUID) TO authenticated;

-- ========================
-- 7. COMENTÁRIOS
-- ========================

COMMENT ON COLUMN public.post_drafts.draft_name IS 'Nome/identificador do rascunho para exibição ao usuário';
COMMENT ON COLUMN public.post_drafts.draft_type IS 'Tipo de rascunho: normal, blog, poll, quiz, wiki, story';
COMMENT ON COLUMN public.post_drafts.is_auto_save IS 'Indica se foi salvo automaticamente';
COMMENT ON COLUMN public.post_drafts.last_auto_save_at IS 'Timestamp do último auto-save';
COMMENT ON FUNCTION public.save_draft(UUID, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, JSONB, TEXT, TEXT, JSONB, JSONB, JSONB, JSONB, JSONB, JSONB, UUID, BOOLEAN) IS 'Salva ou atualiza um rascunho de post';
COMMENT ON FUNCTION public.get_drafts(UUID, TEXT) IS 'Obtém lista de rascunhos do usuário, opcionalmente filtrados por comunidade e tipo';
COMMENT ON FUNCTION public.get_draft(UUID) IS 'Obtém conteúdo completo de um rascunho específico';
COMMENT ON FUNCTION public.delete_draft(UUID) IS 'Deleta um rascunho';
