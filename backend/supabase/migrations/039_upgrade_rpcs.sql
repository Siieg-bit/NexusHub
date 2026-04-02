-- ============================================================
-- Migration 039: Upgrade RPCs para suportar todos os campos
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. DROP overload antigo de create_post_with_reputation (com p_author_id)
--    Mantemos apenas o overload moderno que usa auth.uid()
-- ─────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.create_post_with_reputation(uuid, uuid, text, text, text, jsonb, uuid, jsonb);

-- ─────────────────────────────────────────────────────────────
-- 2. DROP e recriar create_post_with_reputation com TODOS os campos
--    que o Flutter envia (gif_url, music_url, music_title,
--    cover_image_url, background_url, visibility, comments_blocked, etc.)
-- ─────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.create_post_with_reputation(uuid, text, text, text, jsonb, uuid, jsonb, jsonb, jsonb, text, text, text, text, boolean, uuid);

CREATE OR REPLACE FUNCTION public.create_post_with_reputation(
  p_community_id        uuid,
  p_title               text,
  p_content             text        DEFAULT NULL,
  p_type                text        DEFAULT 'normal',
  p_media_list          jsonb       DEFAULT '[]'::jsonb,
  p_category_id         uuid        DEFAULT NULL,
  p_poll_options         jsonb       DEFAULT NULL,
  p_tags                jsonb       DEFAULT '[]'::jsonb,
  p_cover_image_url     text        DEFAULT NULL,
  p_background_url      text        DEFAULT NULL,
  p_external_url        text        DEFAULT NULL,
  p_gif_url             text        DEFAULT NULL,
  p_music_url           text        DEFAULT NULL,
  p_music_title         text        DEFAULT NULL,
  p_visibility          text        DEFAULT 'public',
  p_comments_blocked    boolean     DEFAULT false,
  p_original_post_id    uuid        DEFAULT NULL,
  p_original_community_id uuid      DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_post_id   UUID;
  v_user_id   UUID := auth.uid();
  v_is_member BOOLEAN;
BEGIN
  -- Verificar autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar se é membro ativo da comunidade
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = false
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this community';
  END IF;

  -- Inserir o post com todos os campos
  INSERT INTO public.posts (
    community_id, author_id, title, content, type,
    media_list, category_id, tags, status,
    cover_image_url, background_url, external_url,
    gif_url, music_url, music_title,
    visibility, comments_blocked,
    original_post_id, original_community_id
  ) VALUES (
    p_community_id, v_user_id, p_title, p_content,
    p_type::public.post_type,
    p_media_list, p_category_id, p_tags, 'ok',
    p_cover_image_url, p_background_url, p_external_url,
    p_gif_url, p_music_url, p_music_title,
    p_visibility::public.post_visibility, p_comments_blocked,
    p_original_post_id, p_original_community_id
  ) RETURNING id INTO v_post_id;

  -- Criar opções de enquete se fornecidas
  IF p_poll_options IS NOT NULL AND jsonb_array_length(p_poll_options) > 0 THEN
    INSERT INTO public.poll_options (post_id, text, sort_order)
    SELECT v_post_id, elem->>'text', (row_number() OVER ())::int
    FROM jsonb_array_elements(p_poll_options) AS elem;
  END IF;

  -- Adicionar reputação
  PERFORM public.add_reputation(v_user_id, p_community_id, 'create_post', 15, v_post_id);

  RETURN v_post_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────
-- 3. Criar RPC create_crosspost para posts espelho
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_crosspost(
  p_target_community_id   uuid,
  p_original_post_id      uuid,
  p_original_community_id uuid,
  p_title                 text        DEFAULT NULL,
  p_content               text        DEFAULT NULL,
  p_media_list            jsonb       DEFAULT '[]'::jsonb,
  p_cover_image_url       text        DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_post_id   UUID;
  v_user_id   UUID := auth.uid();
  v_is_member BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_target_community_id
      AND user_id = v_user_id
      AND is_banned = false
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of target community';
  END IF;

  INSERT INTO public.posts (
    community_id, author_id, type, title, content,
    media_list, cover_image_url,
    original_post_id, original_community_id, status
  ) VALUES (
    p_target_community_id, v_user_id, 'crosspost'::public.post_type,
    p_title, p_content, p_media_list, p_cover_image_url,
    p_original_post_id, p_original_community_id, 'ok'
  ) RETURNING id INTO v_post_id;

  RETURN v_post_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────
-- 4. Criar RPC create_story para stories
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_story(
  p_community_id    uuid,
  p_media_url       text,
  p_media_type      text        DEFAULT 'image',
  p_caption         text        DEFAULT NULL,
  p_background_color text       DEFAULT NULL,
  p_text_overlay    text        DEFAULT NULL,
  p_sticker_data    jsonb       DEFAULT NULL,
  p_duration_seconds int        DEFAULT 5,
  p_expires_at      timestamptz DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_story_id  UUID;
  v_user_id   UUID := auth.uid();
  v_is_member BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = false
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this community';
  END IF;

  INSERT INTO public.stories (
    community_id, author_id, media_url, media_type,
    caption, background_color, text_overlay,
    sticker_data, duration_seconds, expires_at
  ) VALUES (
    p_community_id, v_user_id, p_media_url, p_media_type,
    p_caption, p_background_color, p_text_overlay,
    p_sticker_data, p_duration_seconds,
    COALESCE(p_expires_at, NOW() + INTERVAL '24 hours')
  ) RETURNING id INTO v_story_id;

  -- Reputação por criar story
  PERFORM public.add_reputation(v_user_id, p_community_id, 'create_post', 5, v_story_id);

  RETURN v_story_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────
-- 5. Criar RPC post_wall_comment para comentários no mural
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.post_wall_comment(
  p_profile_user_id uuid,
  p_community_id    uuid,
  p_content         text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_comment_id UUID;
  v_user_id    UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF trim(p_content) = '' THEN
    RAISE EXCEPTION 'Conteúdo não pode ser vazio';
  END IF;

  INSERT INTO public.comments (
    author_id, profile_wall_id, community_id, content
  ) VALUES (
    v_user_id, p_profile_user_id, p_community_id, trim(p_content)
  ) RETURNING id INTO v_comment_id;

  RETURN v_comment_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────
-- 6. Criar RPC submit_flag para denúncias
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_flag(
  p_community_id          uuid,
  p_flag_type             text,
  p_reason                text        DEFAULT NULL,
  p_target_post_id        uuid        DEFAULT NULL,
  p_target_comment_id     uuid        DEFAULT NULL,
  p_target_chat_message_id uuid       DEFAULT NULL,
  p_target_user_id        uuid        DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_flag_id UUID;
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar se já denunciou o mesmo alvo
  IF p_target_post_id IS NOT NULL THEN
    IF EXISTS(SELECT 1 FROM public.flags WHERE reporter_id = v_user_id AND target_post_id = p_target_post_id AND status = 'pending') THEN
      RAISE EXCEPTION 'Você já denunciou este conteúdo';
    END IF;
  END IF;

  INSERT INTO public.flags (
    community_id, reporter_id, flag_type, reason, status,
    target_post_id, target_comment_id, target_chat_message_id, target_user_id
  ) VALUES (
    p_community_id, v_user_id, p_flag_type, p_reason, 'pending',
    p_target_post_id, p_target_comment_id, p_target_chat_message_id, p_target_user_id
  ) RETURNING id INTO v_flag_id;

  RETURN v_flag_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────
-- 7. Criar RPC log_moderation_action para logs de moderação
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.log_moderation_action(
  p_community_id       uuid,
  p_action             text,
  p_target_user_id     uuid        DEFAULT NULL,
  p_target_post_id     uuid        DEFAULT NULL,
  p_target_wiki_id     uuid        DEFAULT NULL,
  p_target_comment_id  uuid        DEFAULT NULL,
  p_reason             text        DEFAULT NULL,
  p_duration_hours     int         DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_log_id  UUID;
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action,
    target_user_id, target_post_id, target_wiki_id, target_comment_id,
    reason, duration_hours
  ) VALUES (
    p_community_id, v_user_id, p_action::public.moderation_action,
    p_target_user_id, p_target_post_id, p_target_wiki_id, p_target_comment_id,
    p_reason, p_duration_hours
  ) RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────
-- 8. Criar RPC submit_wiki_entry para criação de wikis
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_wiki_entry(
  p_community_id    uuid,
  p_title           text,
  p_content         text,
  p_category_id     uuid        DEFAULT NULL,
  p_cover_image_url text        DEFAULT NULL,
  p_infobox         jsonb       DEFAULT NULL,
  p_custom_fields   jsonb       DEFAULT NULL,
  p_tags            jsonb       DEFAULT NULL,
  p_media_list      jsonb       DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_entry_id  UUID;
  v_user_id   UUID := auth.uid();
  v_is_member BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = false
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this community';
  END IF;

  INSERT INTO public.wiki_entries (
    community_id, author_id, title, content,
    category_id, cover_image_url, infobox,
    custom_fields, tags, media_list, status
  ) VALUES (
    p_community_id, v_user_id, trim(p_title), p_content,
    p_category_id, p_cover_image_url, p_infobox,
    p_custom_fields, p_tags, p_media_list, 'pending'
  ) RETURNING id INTO v_entry_id;

  -- Reputação por criar wiki
  PERFORM public.add_reputation(v_user_id, p_community_id, 'create_post', 20, v_entry_id);

  RETURN v_entry_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────
-- 9. Configurar pg_cron para rotinas de limpeza
-- ─────────────────────────────────────────────────────────────
-- Nota: pg_cron precisa estar habilitado no projeto Supabase.
-- Se não estiver, estas chamadas falharão silenciosamente.
DO $$
BEGIN
  -- Limpar logs antigos a cada dia às 3h da manhã
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'cleanup-old-logs',
      '0 3 * * *',
      'SELECT public.cleanup_old_logs()'
    );
    -- Limpar stickers não usados semanalmente
    PERFORM cron.schedule(
      'trim-stickers',
      '0 4 * * 0',
      'SELECT public.trim_recently_used_stickers()'
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron não disponível, pulando agendamento';
END;
$$;
