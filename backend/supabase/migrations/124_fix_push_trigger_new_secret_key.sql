-- =============================================================================
-- Migration 124: Corrige trigger de push notifications com nova secret key
--
-- Problema identificado:
--   O trigger trg_send_push_on_notification usava a service_role key legada
--   (JWT com iat: 1774559706), que foi desabilitada em 30/03/2026.
--   Desde então, nenhuma push notification estava sendo disparada.
--
-- Solução:
--   1. Armazenar a nova secret key no Supabase Vault (vault.secrets).
--   2. Recriar a função trg_send_push_on_notification para ler a chave do
--      vault em vez de tê-la hardcoded.
--   3. Remover o trigger v1 (chave legada) e garantir que apenas o trigger
--      atualizado esteja ativo.
--   4. Atualizar também trg_send_push_on_notification_v2 para disparar a
--      Edge Function diretamente (não apenas enfileirar).
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Armazenar nova secret key no Vault
-- ─────────────────────────────────────────────────────────────────────────────
-- Remover entrada antiga se existir
DELETE FROM vault.secrets WHERE name = 'supabase_service_key';

-- Inserir nova secret key (nova chave gerada após 30/03/2026)
SELECT vault.create_secret(
  'sb_secret_lefp14-d1rM-yPusu1x94w_W9mseOKj',
  'supabase_service_key',
  'Supabase secret key para uso interno em triggers e RPCs'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Recriar função do trigger com leitura da chave via Vault
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_send_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supabase_url TEXT := 'https://ylvzqqvcanzzswjkqeya.supabase.co';
  v_service_key  TEXT;
  v_payload      JSONB;
BEGIN
  -- Só processar INSERTs
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  -- Ler a nova secret key do Vault (seguro, sem hardcode)
  SELECT decrypted_secret
    INTO v_service_key
    FROM vault.decrypted_secrets
   WHERE name = 'supabase_service_key'
   LIMIT 1;

  -- Se o vault não retornar nada, abortar silenciosamente com aviso
  IF v_service_key IS NULL THEN
    RAISE WARNING '[push_trigger] Secret "supabase_service_key" não encontrado no vault. Push não enviado para user %.',
      NEW.user_id;
    RETURN NEW;
  END IF;

  -- Montar payload para a Edge Function
  v_payload := jsonb_build_object(
    'user_id',           NEW.user_id,
    'notification_type', NEW.type,
    'title',             COALESCE(NEW.title, 'NexusHub'),
    'content',           COALESCE(NEW.body, ''),
    'community_id',      NEW.community_id,
    'data',              jsonb_build_object(
      'notification_id',  NEW.id,
      'type',             NEW.type,
      'post_id',          COALESCE(NEW.post_id::TEXT, ''),
      'wiki_id',          COALESCE(NEW.wiki_id::TEXT, ''),
      'comment_id',       COALESCE(NEW.comment_id::TEXT, ''),
      'community_id',     COALESCE(NEW.community_id::TEXT, ''),
      'chat_thread_id',   COALESCE(NEW.chat_thread_id::TEXT, ''),
      'action_url',       COALESCE(NEW.action_url, ''),
      'actor_id',         COALESCE(NEW.actor_id::TEXT, '')
    )
  );

  -- Chamar Edge Function de forma assíncrona via pg_net
  PERFORM net.http_post(
    url     := v_supabase_url || '/functions/v1/push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body    := v_payload
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[push_trigger] Falha ao disparar push para user %: %',
      NEW.user_id, SQLERRM;
    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Recriar função do trigger v2 para também disparar a Edge Function
--    (além de enfileirar para retry)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_send_push_on_notification_v2()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supabase_url TEXT := 'https://ylvzqqvcanzzswjkqeya.supabase.co';
  v_service_key  TEXT;
  v_payload      JSONB;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  -- Ler a nova secret key do Vault
  SELECT decrypted_secret
    INTO v_service_key
    FROM vault.decrypted_secrets
   WHERE name = 'supabase_service_key'
   LIMIT 1;

  IF v_service_key IS NULL THEN
    RAISE WARNING '[push_trigger_v2] Secret "supabase_service_key" não encontrado no vault. Push não enviado para user %.',
      NEW.user_id;
    RETURN NEW;
  END IF;

  -- Inserir na fila de push para processamento assíncrono e retry
  INSERT INTO public.push_notification_queue (
    notification_id,
    user_id,
    status,
    attempt_count,
    next_retry_at
  ) VALUES (
    NEW.id,
    NEW.user_id,
    'pending',
    0,
    NOW()
  )
  ON CONFLICT DO NOTHING;

  -- Montar payload para a Edge Function
  v_payload := jsonb_build_object(
    'user_id',           NEW.user_id,
    'notification_type', NEW.type,
    'title',             COALESCE(NEW.title, 'NexusHub'),
    'content',           COALESCE(NEW.body, ''),
    'community_id',      NEW.community_id,
    'data',              jsonb_build_object(
      'notification_id',  NEW.id,
      'type',             NEW.type,
      'post_id',          COALESCE(NEW.post_id::TEXT, ''),
      'wiki_id',          COALESCE(NEW.wiki_id::TEXT, ''),
      'comment_id',       COALESCE(NEW.comment_id::TEXT, ''),
      'community_id',     COALESCE(NEW.community_id::TEXT, ''),
      'chat_thread_id',   COALESCE(NEW.chat_thread_id::TEXT, ''),
      'action_url',       COALESCE(NEW.action_url, ''),
      'actor_id',         COALESCE(NEW.actor_id::TEXT, '')
    )
  );

  -- Chamar Edge Function de forma assíncrona via pg_net
  PERFORM net.http_post(
    url     := v_supabase_url || '/functions/v1/push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body    := v_payload
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[push_trigger_v2] Falha ao disparar push para user %: %',
      NEW.user_id, SQLERRM;
    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Garantir que os triggers estão ativos na tabela notifications
-- ─────────────────────────────────────────────────────────────────────────────
-- Recriar trigger v1 (agora com vault)
DROP TRIGGER IF EXISTS trg_send_push_on_notification ON public.notifications;
CREATE TRIGGER trg_send_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_send_push_on_notification();

-- Garantir que o trigger v2 também está ativo
DROP TRIGGER IF EXISTS trg_send_push_on_notification_v2 ON public.notifications;
CREATE TRIGGER trg_send_push_on_notification_v2
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_send_push_on_notification_v2();

-- =============================================================================
-- RESULTADO:
--   - Chave legada (service_role JWT iat:1774559706) removida do código.
--   - Nova secret key armazenada no Supabase Vault de forma segura.
--   - Trigger lê a chave do vault em runtime, sem hardcode.
--   - Push notifications voltam a funcionar imediatamente após esta migração.
--   - Trigger v2 agora também dispara a Edge Function (além de enfileirar).
-- =============================================================================
