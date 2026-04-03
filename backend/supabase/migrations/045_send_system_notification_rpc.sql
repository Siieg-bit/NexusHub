-- ============================================================================
-- Migration 045: Send system notification RPC
-- Centraliza notificações sistêmicas no backend para evitar inserts diretos
-- do cliente em notifications.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.send_system_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT DEFAULT '',
  p_community_id UUID DEFAULT NULL,
  p_post_id UUID DEFAULT NULL,
  p_wiki_id UUID DEFAULT NULL,
  p_chat_thread_id UUID DEFAULT NULL,
  p_action_url TEXT DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_notification_id UUID;
  v_is_system_account BOOLEAN := FALSE;
  v_is_community_moderator BOOLEAN := FALSE;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT COALESCE(is_system_account, FALSE)
    INTO v_is_system_account
  FROM public.profiles
  WHERE id = v_actor_id;

  IF p_community_id IS NOT NULL THEN
    v_is_community_moderator := public.is_community_moderator(p_community_id);
  END IF;

  IF NOT (public.is_team_member() OR v_is_system_account OR v_is_community_moderator) THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'insufficient_permissions'
    );
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'missing_target_user'
    );
  END IF;

  IF COALESCE(NULLIF(btrim(p_type), ''), '') = '' THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'missing_type'
    );
  END IF;

  IF COALESCE(NULLIF(btrim(p_title), ''), '') = '' THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'missing_title'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = p_user_id
  ) THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'target_user_not_found'
    );
  END IF;

  INSERT INTO public.notifications (
    user_id,
    actor_id,
    type,
    title,
    body,
    image_url,
    community_id,
    post_id,
    wiki_id,
    chat_thread_id,
    action_url
  )
  VALUES (
    p_user_id,
    v_actor_id,
    btrim(p_type),
    btrim(p_title),
    COALESCE(p_body, ''),
    p_image_url,
    p_community_id,
    p_post_id,
    p_wiki_id,
    p_chat_thread_id,
    p_action_url
  )
  RETURNING id INTO v_notification_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'notification_id', v_notification_id
  );
END;
$$;
