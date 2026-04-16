-- =============================================================================
-- Migration 116: Garantir que o criador do chat seja host em chat_members
-- Corrige o fluxo em que create_public_chat criava o thread com host_id correto,
-- mas inseria o criador em chat_members sem role='host', quebrando RPCs e
-- permissões de edição pós-criação (capa, título, anúncios, etc.).
-- =============================================================================

-- 1) Backfill: sincronizar roles de host/co_host na tabela chat_members para
-- chats já existentes.
UPDATE public.chat_members cm
SET role = 'host'
FROM public.chat_threads ct
WHERE cm.thread_id = ct.id
  AND cm.user_id = ct.host_id
  AND cm.role IS DISTINCT FROM 'host';

UPDATE public.chat_members cm
SET role = 'co_host'
FROM public.chat_threads ct
WHERE cm.thread_id = ct.id
  AND ct.co_hosts ? cm.user_id::text
  AND cm.role IS DISTINCT FROM 'co_host'
  AND cm.user_id IS DISTINCT FROM ct.host_id;

-- 2) Recriar create_public_chat garantindo o criador como host também em
-- chat_members para todos os novos chats.
DROP FUNCTION IF EXISTS public.create_public_chat(uuid, text, text, text, text, text, text, integer, boolean, boolean, boolean, boolean);
CREATE OR REPLACE FUNCTION public.create_public_chat(
  p_community_id           UUID,
  p_title                  TEXT,
  p_description            TEXT    DEFAULT NULL,
  p_icon_url               TEXT    DEFAULT NULL,
  p_background_url         TEXT    DEFAULT NULL,
  p_cover_image_url        TEXT    DEFAULT NULL,
  p_category               TEXT    DEFAULT 'general',
  p_slow_mode_interval     INTEGER DEFAULT 0,
  p_is_announcement_only   BOOLEAN DEFAULT FALSE,
  p_is_voice_enabled       BOOLEAN DEFAULT TRUE,
  p_is_video_enabled       BOOLEAN DEFAULT FALSE,
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

  SELECT EXISTS (
    SELECT 1
    FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = FALSE
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE id = v_user_id
        AND (is_team_admin = TRUE OR is_team_moderator = TRUE)
    ) INTO v_is_member;
  END IF;

  IF NOT v_is_member THEN
    RETURN json_build_object('success', false, 'error', 'not_a_member');
  END IF;

  INSERT INTO public.chat_threads (
    community_id,
    host_id,
    title,
    description,
    icon_url,
    background_url,
    cover_image_url,
    category,
    slow_mode_interval,
    is_announcement_only,
    is_voice_enabled,
    is_video_enabled,
    is_screen_room_enabled,
    type,
    members_count
  ) VALUES (
    p_community_id,
    v_user_id,
    trim(p_title),
    p_description,
    p_icon_url,
    p_background_url,
    p_cover_image_url,
    COALESCE(p_category, 'general'),
    COALESCE(p_slow_mode_interval, 0),
    COALESCE(p_is_announcement_only, FALSE),
    COALESCE(p_is_voice_enabled, TRUE),
    COALESCE(p_is_video_enabled, FALSE),
    COALESCE(p_is_screen_room_enabled, FALSE),
    'public',
    1
  )
  RETURNING id INTO v_thread_id;

  INSERT INTO public.chat_members (
    thread_id,
    user_id,
    status,
    role
  ) VALUES (
    v_thread_id,
    v_user_id,
    'active',
    'host'
  )
  ON CONFLICT (thread_id, user_id) DO UPDATE
  SET status = EXCLUDED.status,
      role = EXCLUDED.role;

  RETURN json_build_object('success', true, 'thread_id', v_thread_id);
END;
$$;
