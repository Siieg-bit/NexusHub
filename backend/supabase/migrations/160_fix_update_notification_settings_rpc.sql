-- ============================================================================
-- Migration 160: Corrigir RPC update_notification_settings
--
-- A migration 133 reescreveu a RPC usando INSERT INTO notification_settings
-- (user_id, settings) com uma coluna 'settings JSONB' que não existe na
-- tabela. A tabela real usa colunas individuais (push_likes, push_follows,
-- etc.) definidas nas migrations 028 e 061.
--
-- Esta migration substitui a RPC por uma versão correta que faz UPSERT
-- com colunas individuais, lendo os valores do JSONB recebido.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_notification_settings(
  p_settings JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  INSERT INTO public.notification_settings (
    user_id,
    push_enabled,
    push_likes,
    push_comments,
    push_follows,
    push_mentions,
    push_chat_messages,
    push_community_invites,
    push_achievements,
    push_level_up,
    push_moderation,
    push_economy,
    push_stories,
    in_app_sounds,
    in_app_vibration,
    only_friends_likes,
    only_friends_comments,
    only_friends_messages,
    pause_all_until,
    updated_at
  )
  VALUES (
    v_user_id,
    COALESCE((p_settings->>'push_enabled')::BOOLEAN,          TRUE),
    COALESCE((p_settings->>'push_likes')::BOOLEAN,            TRUE),
    COALESCE((p_settings->>'push_comments')::BOOLEAN,         TRUE),
    COALESCE((p_settings->>'push_follows')::BOOLEAN,          TRUE),
    COALESCE((p_settings->>'push_mentions')::BOOLEAN,         TRUE),
    COALESCE((p_settings->>'push_chat_messages')::BOOLEAN,    TRUE),
    COALESCE((p_settings->>'push_community_invites')::BOOLEAN,TRUE),
    COALESCE((p_settings->>'push_achievements')::BOOLEAN,     TRUE),
    COALESCE((p_settings->>'push_level_up')::BOOLEAN,         TRUE),
    COALESCE((p_settings->>'push_moderation')::BOOLEAN,       TRUE),
    COALESCE((p_settings->>'push_economy')::BOOLEAN,          TRUE),
    COALESCE((p_settings->>'push_stories')::BOOLEAN,          TRUE),
    COALESCE((p_settings->>'in_app_sounds')::BOOLEAN,         TRUE),
    COALESCE((p_settings->>'in_app_vibration')::BOOLEAN,      TRUE),
    COALESCE((p_settings->>'only_friends_likes')::BOOLEAN,    FALSE),
    COALESCE((p_settings->>'only_friends_comments')::BOOLEAN, FALSE),
    COALESCE((p_settings->>'only_friends_messages')::BOOLEAN, FALSE),
    NULLIF(p_settings->>'pause_all_until', '')::TIMESTAMPTZ,
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    push_enabled           = EXCLUDED.push_enabled,
    push_likes             = EXCLUDED.push_likes,
    push_comments          = EXCLUDED.push_comments,
    push_follows           = EXCLUDED.push_follows,
    push_mentions          = EXCLUDED.push_mentions,
    push_chat_messages     = EXCLUDED.push_chat_messages,
    push_community_invites = EXCLUDED.push_community_invites,
    push_achievements      = EXCLUDED.push_achievements,
    push_level_up          = EXCLUDED.push_level_up,
    push_moderation        = EXCLUDED.push_moderation,
    push_economy           = EXCLUDED.push_economy,
    push_stories           = EXCLUDED.push_stories,
    in_app_sounds          = EXCLUDED.in_app_sounds,
    in_app_vibration       = EXCLUDED.in_app_vibration,
    only_friends_likes     = EXCLUDED.only_friends_likes,
    only_friends_comments  = EXCLUDED.only_friends_comments,
    only_friends_messages  = EXCLUDED.only_friends_messages,
    pause_all_until        = EXCLUDED.pause_all_until,
    updated_at             = NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_notification_settings TO authenticated;

COMMENT ON FUNCTION public.update_notification_settings IS
  'Atualiza as configurações de notificação do usuário autenticado. '
  'Recebe um JSONB com os campos individuais e faz UPSERT na tabela '
  'notification_settings usando colunas individuais (não JSONB).';
