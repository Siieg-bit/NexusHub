-- =============================================================================
-- Migration 060: Melhorar create_public_chat com personalização avançada
-- Adiciona: cover_image_url, slow_mode, announcement_only, voice/video/screen
-- =============================================================================

-- Adicionar colunas faltantes em chat_threads (se não existirem)
ALTER TABLE public.chat_threads
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
  ADD COLUMN IF NOT EXISTS slow_mode_interval INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'general';

-- Recriar a RPC create_public_chat com parâmetros completos
DROP FUNCTION IF EXISTS public.create_public_chat(uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.create_public_chat(
  p_community_id          UUID,
  p_title                 TEXT,
  p_description           TEXT    DEFAULT NULL,
  p_icon_url              TEXT    DEFAULT NULL,
  p_background_url        TEXT    DEFAULT NULL,
  p_cover_image_url       TEXT    DEFAULT NULL,
  p_category              TEXT    DEFAULT 'general',
  p_slow_mode_interval    INTEGER DEFAULT 0,
  p_is_announcement_only  BOOLEAN DEFAULT FALSE,
  p_is_voice_enabled      BOOLEAN DEFAULT TRUE,
  p_is_video_enabled      BOOLEAN DEFAULT FALSE,
  p_is_screen_room_enabled BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_is_member BOOLEAN;
  v_thread_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'unauthenticated');
  END IF;
  IF p_title IS NULL OR trim(p_title) = '' THEN
    RETURN json_build_object('success', false, 'error', 'title_required');
  END IF;

  -- Verificar membership (is_banned = FALSE)
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = FALSE
  ) INTO v_is_member;

  -- Team admins/moderators podem criar em qualquer comunidade
  IF NOT v_is_member THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = v_user_id
        AND (is_team_admin = TRUE OR is_team_moderator = TRUE)
    ) INTO v_is_member;
  END IF;

  IF NOT v_is_member THEN
    RETURN json_build_object('success', false, 'error', 'not_a_member');
  END IF;

  INSERT INTO public.chat_threads (
    community_id, host_id, title, description,
    icon_url, background_url, cover_image_url,
    category, slow_mode_interval,
    is_announcement_only, is_voice_enabled,
    is_video_enabled, is_screen_room_enabled,
    type, members_count
  ) VALUES (
    p_community_id, v_user_id, trim(p_title), p_description,
    p_icon_url, p_background_url, p_cover_image_url,
    COALESCE(p_category, 'general'), COALESCE(p_slow_mode_interval, 0),
    COALESCE(p_is_announcement_only, FALSE), COALESCE(p_is_voice_enabled, TRUE),
    COALESCE(p_is_video_enabled, FALSE), COALESCE(p_is_screen_room_enabled, FALSE),
    'public', 1
  )
  RETURNING id INTO v_thread_id;

  INSERT INTO public.chat_members (thread_id, user_id, status)
  VALUES (v_thread_id, v_user_id, 'active');

  RETURN json_build_object('success', true, 'thread_id', v_thread_id);
END;
$$;
