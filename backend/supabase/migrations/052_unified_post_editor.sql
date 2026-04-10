-- =============================================================================
-- MIGRATION 052 — Unified Post Editor
-- Suporte para criação/edição rica de Story, Pergunta, Chat Público, Imagem,
-- Link, Quiz, Enquete, Wiki, Blog e Rascunhos a partir de uma base unificada.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. POSTS: metadados do editor unificado e variantes funcionais
-- -----------------------------------------------------------------------------
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS editor_type TEXT,
  ADD COLUMN IF NOT EXISTS post_variant TEXT,
  ADD COLUMN IF NOT EXISTS editor_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS editor_state JSONB,
  ADD COLUMN IF NOT EXISTS story_data JSONB,
  ADD COLUMN IF NOT EXISTS chat_data JSONB,
  ADD COLUMN IF NOT EXISTS wiki_data JSONB;

ALTER TABLE public.posts
  ALTER COLUMN editor_metadata SET DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_posts_editor_type
  ON public.posts(editor_type);

CREATE INDEX IF NOT EXISTS idx_posts_post_variant
  ON public.posts(post_variant);

CREATE INDEX IF NOT EXISTS idx_posts_editor_metadata_gin
  ON public.posts USING gin(editor_metadata);

-- -----------------------------------------------------------------------------
-- 2. POST_DRAFTS: estado completo do editor unificado
-- -----------------------------------------------------------------------------
ALTER TABLE public.post_drafts
  ADD COLUMN IF NOT EXISTS subtitle TEXT,
  ADD COLUMN IF NOT EXISTS editor_type TEXT,
  ADD COLUMN IF NOT EXISTS post_variant TEXT,
  ADD COLUMN IF NOT EXISTS editor_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
  ADD COLUMN IF NOT EXISTS background_url TEXT,
  ADD COLUMN IF NOT EXISTS external_url TEXT,
  ADD COLUMN IF NOT EXISTS poll_data JSONB,
  ADD COLUMN IF NOT EXISTS quiz_data JSONB,
  ADD COLUMN IF NOT EXISTS story_data JSONB,
  ADD COLUMN IF NOT EXISTS chat_data JSONB,
  ADD COLUMN IF NOT EXISTS wiki_data JSONB,
  ADD COLUMN IF NOT EXISTS editor_state JSONB,
  ADD COLUMN IF NOT EXISTS comments_blocked BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS pin_to_profile BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.post_drafts
  ALTER COLUMN editor_metadata SET DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_post_drafts_editor_type
  ON public.post_drafts(editor_type);

CREATE INDEX IF NOT EXISTS idx_post_drafts_post_variant
  ON public.post_drafts(post_variant);

-- -----------------------------------------------------------------------------
-- 3. CREATE_POST_WITH_REPUTATION: aceitar o payload completo do editor unificado
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_post_with_reputation(
  uuid, text, text, text, jsonb, uuid, jsonb, jsonb,
  text, text, text, text, text, text, text, boolean, uuid, uuid, jsonb, boolean
);

CREATE OR REPLACE FUNCTION public.create_post_with_reputation(
  p_community_id          uuid,
  p_title                 text,
  p_content               text        DEFAULT NULL,
  p_type                  text        DEFAULT 'normal',
  p_media_list            jsonb       DEFAULT '[]'::jsonb,
  p_category_id           uuid        DEFAULT NULL,
  p_poll_options          jsonb       DEFAULT NULL,
  p_tags                  jsonb       DEFAULT '[]'::jsonb,
  p_cover_image_url       text        DEFAULT NULL,
  p_background_url        text        DEFAULT NULL,
  p_external_url          text        DEFAULT NULL,
  p_gif_url               text        DEFAULT NULL,
  p_music_url             text        DEFAULT NULL,
  p_music_title           text        DEFAULT NULL,
  p_visibility            text        DEFAULT 'public',
  p_comments_blocked      boolean     DEFAULT false,
  p_original_post_id      uuid        DEFAULT NULL,
  p_original_community_id uuid        DEFAULT NULL,
  p_content_blocks        jsonb       DEFAULT '[]'::jsonb,
  p_is_pinned_profile     boolean     DEFAULT false,
  p_editor_type           text        DEFAULT NULL,
  p_post_variant          text        DEFAULT NULL,
  p_editor_metadata       jsonb       DEFAULT '{}'::jsonb,
  p_editor_state          jsonb       DEFAULT NULL,
  p_story_data            jsonb       DEFAULT NULL,
  p_chat_data             jsonb       DEFAULT NULL,
  p_wiki_data             jsonb       DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_post_id         uuid;
  v_user_id         uuid := auth.uid();
  v_is_member       boolean;
  v_media_list      jsonb := COALESCE(p_media_list, '[]'::jsonb);
  v_tags            jsonb := COALESCE(p_tags, '[]'::jsonb);
  v_content_blocks  jsonb := COALESCE(p_content_blocks, '[]'::jsonb);
  v_editor_metadata jsonb := COALESCE(p_editor_metadata, '{}'::jsonb);
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF jsonb_typeof(v_media_list) <> 'array' THEN
    RAISE EXCEPTION 'p_media_list must be a JSON array';
  END IF;

  IF jsonb_typeof(v_tags) <> 'array' THEN
    RAISE EXCEPTION 'p_tags must be a JSON array';
  END IF;

  IF jsonb_typeof(v_content_blocks) <> 'array' THEN
    RAISE EXCEPTION 'p_content_blocks must be a JSON array';
  END IF;

  IF jsonb_typeof(v_editor_metadata) <> 'object' THEN
    RAISE EXCEPTION 'p_editor_metadata must be a JSON object';
  END IF;

  SELECT EXISTS(
    SELECT 1
    FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = false
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this community';
  END IF;

  IF p_is_pinned_profile THEN
    UPDATE public.posts
    SET is_pinned_profile = false,
        updated_at = now()
    WHERE author_id = v_user_id
      AND is_pinned_profile = true;
  END IF;

  INSERT INTO public.posts (
    community_id,
    author_id,
    title,
    content,
    type,
    media_list,
    category_id,
    tags,
    status,
    cover_image_url,
    background_url,
    external_url,
    gif_url,
    music_url,
    music_title,
    visibility,
    comments_blocked,
    original_post_id,
    original_community_id,
    content_blocks,
    is_pinned_profile,
    editor_type,
    post_variant,
    editor_metadata,
    editor_state,
    story_data,
    chat_data,
    wiki_data
  ) VALUES (
    p_community_id,
    v_user_id,
    p_title,
    p_content,
    p_type::public.post_type,
    v_media_list,
    p_category_id,
    v_tags,
    'ok',
    p_cover_image_url,
    p_background_url,
    p_external_url,
    p_gif_url,
    p_music_url,
    p_music_title,
    p_visibility::public.post_visibility,
    p_comments_blocked,
    p_original_post_id,
    p_original_community_id,
    CASE WHEN jsonb_array_length(v_content_blocks) > 0 THEN v_content_blocks ELSE NULL END,
    p_is_pinned_profile,
    COALESCE(p_editor_type, p_post_variant, p_type),
    COALESCE(p_post_variant, p_editor_type),
    v_editor_metadata,
    p_editor_state,
    p_story_data,
    p_chat_data,
    p_wiki_data
  ) RETURNING id INTO v_post_id;

  IF p_poll_options IS NOT NULL
     AND jsonb_typeof(p_poll_options) = 'array'
     AND jsonb_array_length(p_poll_options) > 0 THEN
    INSERT INTO public.poll_options (post_id, text, sort_order)
    SELECT v_post_id, COALESCE(elem->>'text', ''), (row_number() OVER ())::int
    FROM jsonb_array_elements(p_poll_options) AS elem;
  END IF;

  PERFORM public.add_reputation(v_user_id, p_community_id, 'create_post', 15, v_post_id);

  RETURN v_post_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_post_with_reputation(
  uuid, text, text, text, jsonb, uuid, jsonb, jsonb,
  text, text, text, text, text, text, text, boolean,
  uuid, uuid, jsonb, boolean, text, text, jsonb, jsonb, jsonb, jsonb, jsonb
) TO authenticated;

-- -----------------------------------------------------------------------------
-- 4. EDIT_POST: edição completa com paridade à criação rica
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.edit_post(uuid, text, text);

CREATE OR REPLACE FUNCTION public.edit_post(
  p_post_id               uuid,
  p_title                 text        DEFAULT NULL,
  p_content               text        DEFAULT NULL,
  p_type                  text        DEFAULT NULL,
  p_media_list            jsonb       DEFAULT NULL,
  p_category_id           uuid        DEFAULT NULL,
  p_poll_options          jsonb       DEFAULT NULL,
  p_tags                  jsonb       DEFAULT NULL,
  p_cover_image_url       text        DEFAULT NULL,
  p_background_url        text        DEFAULT NULL,
  p_external_url          text        DEFAULT NULL,
  p_gif_url               text        DEFAULT NULL,
  p_music_url             text        DEFAULT NULL,
  p_music_title           text        DEFAULT NULL,
  p_visibility            text        DEFAULT NULL,
  p_comments_blocked      boolean     DEFAULT NULL,
  p_content_blocks        jsonb       DEFAULT NULL,
  p_is_pinned_profile     boolean     DEFAULT NULL,
  p_editor_type           text        DEFAULT NULL,
  p_post_variant          text        DEFAULT NULL,
  p_editor_metadata       jsonb       DEFAULT NULL,
  p_editor_state          jsonb       DEFAULT NULL,
  p_story_data            jsonb       DEFAULT NULL,
  p_chat_data             jsonb       DEFAULT NULL,
  p_wiki_data             jsonb       DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id     uuid;
  v_current_type  public.post_type;
  v_next_type     public.post_type;
BEGIN
  SELECT author_id, type
    INTO v_author_id, v_current_type
  FROM public.posts
  WHERE id = p_post_id
  FOR UPDATE;

  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Post não encontrado';
  END IF;

  IF v_author_id <> auth.uid() THEN
    RAISE EXCEPTION 'Post não encontrado ou sem permissão';
  END IF;

  v_next_type := COALESCE(p_type, v_current_type::text)::public.post_type;

  IF p_is_pinned_profile IS TRUE THEN
    UPDATE public.posts
    SET is_pinned_profile = false,
        updated_at = now()
    WHERE author_id = v_author_id
      AND id <> p_post_id
      AND is_pinned_profile = true;
  END IF;

  UPDATE public.posts
  SET
    title = COALESCE(p_title, title),
    content = COALESCE(p_content, content),
    type = v_next_type,
    media_list = COALESCE(p_media_list, media_list),
    category_id = COALESCE(p_category_id, category_id),
    tags = COALESCE(p_tags, tags),
    cover_image_url = COALESCE(p_cover_image_url, cover_image_url),
    background_url = COALESCE(p_background_url, background_url),
    external_url = COALESCE(p_external_url, external_url),
    gif_url = COALESCE(p_gif_url, gif_url),
    music_url = COALESCE(p_music_url, music_url),
    music_title = COALESCE(p_music_title, music_title),
    visibility = COALESCE(p_visibility::public.post_visibility, visibility),
    comments_blocked = COALESCE(p_comments_blocked, comments_blocked),
    content_blocks = COALESCE(p_content_blocks, content_blocks),
    is_pinned_profile = COALESCE(p_is_pinned_profile, is_pinned_profile),
    editor_type = COALESCE(p_editor_type, editor_type, p_post_variant),
    post_variant = COALESCE(p_post_variant, post_variant, p_editor_type),
    editor_metadata = COALESCE(p_editor_metadata, editor_metadata, '{}'::jsonb),
    editor_state = COALESCE(p_editor_state, editor_state),
    story_data = COALESCE(p_story_data, story_data),
    chat_data = COALESCE(p_chat_data, chat_data),
    wiki_data = COALESCE(p_wiki_data, wiki_data),
    updated_at = NOW()
  WHERE id = p_post_id;

  IF p_poll_options IS NOT NULL THEN
    DELETE FROM public.poll_options
    WHERE post_id = p_post_id;

    IF jsonb_typeof(p_poll_options) = 'array' AND jsonb_array_length(p_poll_options) > 0 THEN
      INSERT INTO public.poll_options (post_id, text, sort_order)
      SELECT p_post_id, COALESCE(elem->>'text', ''), (row_number() OVER ())::int
      FROM jsonb_array_elements(p_poll_options) AS elem;
    END IF;
  END IF;

  RETURN p_post_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.edit_post(
  uuid, text, text, text, jsonb, uuid, jsonb, jsonb,
  text, text, text, text, text, text, text, boolean,
  jsonb, boolean, text, text, jsonb, jsonb, jsonb, jsonb, jsonb
) TO authenticated;
