-- Migration 051: Blog system RPCs e pinagem no perfil
-- ==================================================

-- ---------------------------------------------------------------------------
-- 1. Atualizar create_post_with_reputation para aceitar content_blocks
--    e permitir fixação no perfil no momento da criação do blog.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_post_with_reputation(
  uuid, text, text, text, jsonb, uuid, jsonb, jsonb,
  text, text, text, text, text, text, text, boolean, uuid, uuid
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
  p_is_pinned_profile     boolean     DEFAULT false
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
    is_pinned_profile
  ) VALUES (
    p_community_id,
    v_user_id,
    p_title,
    COALESCE(p_content, ''),
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
    p_is_pinned_profile
  ) RETURNING id INTO v_post_id;

  IF p_poll_options IS NOT NULL AND jsonb_typeof(p_poll_options) = 'array' AND jsonb_array_length(p_poll_options) > 0 THEN
    INSERT INTO public.poll_options (post_id, text, sort_order)
    SELECT v_post_id, elem->>'text', (row_number() OVER ())::int
    FROM jsonb_array_elements(p_poll_options) AS elem;
  END IF;

  PERFORM public.add_reputation(v_user_id, p_community_id, 'create_post', 15, v_post_id);

  RETURN v_post_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_post_with_reputation(
  uuid, text, text, text, jsonb, uuid, jsonb, jsonb,
  text, text, text, text, text, text, text, boolean, uuid, uuid, jsonb, boolean
) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. RPC para fixar/desafixar um blog no perfil.
--    Mantém apenas um blog fixado por usuário para destaque consistente.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.toggle_profile_blog_pin(
  p_post_id uuid,
  p_is_pinned boolean DEFAULT true
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_author_id uuid;
  v_post_type public.post_type;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT author_id, type
  INTO v_author_id, v_post_type
  FROM public.posts
  WHERE id = p_post_id
    AND status = 'ok';

  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Post não encontrado';
  END IF;

  IF v_author_id <> v_user_id THEN
    RAISE EXCEPTION 'Sem permissão para alterar este blog';
  END IF;

  IF v_post_type <> 'blog'::public.post_type THEN
    RAISE EXCEPTION 'Apenas blogs podem ser fixados no perfil';
  END IF;

  IF p_is_pinned THEN
    UPDATE public.posts
    SET is_pinned_profile = false,
        updated_at = now()
    WHERE author_id = v_user_id
      AND is_pinned_profile = true;
  END IF;

  UPDATE public.posts
  SET is_pinned_profile = p_is_pinned,
      updated_at = now()
  WHERE id = p_post_id;

  RETURN p_is_pinned;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.toggle_profile_blog_pin(uuid, boolean) TO authenticated;
