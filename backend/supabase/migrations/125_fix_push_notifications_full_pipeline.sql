-- ============================================================================
-- Migração 125: Corrigir pipeline completo de push notifications
-- ============================================================================
--
-- Problemas corrigidos:
--
-- 1. pg_net não estava instalado → triggers usavam net.http_post que não existia,
--    falhavam silenciosamente no EXCEPTION e não disparavam nada.
--    Solução: pg_net instalado via API (CREATE EXTENSION pg_net SCHEMA extensions).
--    O schema 'net' já existe com owner supabase_admin e net.http_post funciona.
--
-- 2. process_push_notification_queue era um stub → marcava itens como 'sent'
--    sem realmente chamar a Edge Function.
--    Solução: reescrita para chamar push-notification via net.http_post.
--
-- 3. Cron job para processar a fila não existia → itens ficavam 'pending' para sempre.
--    Solução: cron job a cada 1 minuto para processar a fila.
--
-- 4. trg_send_push_on_notification_v2 inservia na fila mas não chamava a Edge Function.
--    Solução: o trigger v1 já chama diretamente; a fila é processada pelo cron.
--
-- ============================================================================

-- ============================================================================
-- Reescrever process_push_notification_queue para realmente enviar pushes
-- ============================================================================
DROP FUNCTION IF EXISTS public.process_push_notification_queue();
CREATE OR REPLACE FUNCTION public.process_push_notification_queue()
RETURNS TABLE(processed INT, success INT, skipped INT, errors INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net, extensions
AS $$
DECLARE
  v_processed   INT := 0;
  v_success     INT := 0;
  v_skipped     INT := 0;
  v_errors      INT := 0;
  v_queue_item  RECORD;
  v_notif       RECORD;
  v_fcm_token   TEXT;
  v_service_key TEXT;
  v_supabase_url TEXT := 'https://ylvzqqvcanzzswjkqeya.supabase.co';
  v_payload     JSONB;
BEGIN
  -- Ler service key do vault
  SELECT decrypted_secret
    INTO v_service_key
    FROM vault.decrypted_secrets
   WHERE name = 'supabase_service_key'
   LIMIT 1;

  IF v_service_key IS NULL THEN
    RAISE WARNING '[process_push_queue] Secret "supabase_service_key" não encontrado no vault.';
    RETURN QUERY SELECT 0, 0, 0, 0;
    RETURN;
  END IF;

  -- Processar até 50 itens pendentes por execução
  FOR v_queue_item IN
    SELECT pq.id, pq.notification_id, pq.user_id, pq.attempt_count
    FROM public.push_notification_queue pq
    WHERE pq.status = 'pending'
      AND (pq.next_retry_at IS NULL OR pq.next_retry_at <= NOW())
    ORDER BY pq.created_at ASC
    LIMIT 50
    FOR UPDATE SKIP LOCKED
  LOOP
    v_processed := v_processed + 1;

    -- Marcar como 'processing' para evitar processamento duplo
    UPDATE public.push_notification_queue
    SET status = 'processing',
        attempt_count = attempt_count + 1,
        updated_at = NOW()
    WHERE id = v_queue_item.id;

    -- Buscar FCM token do usuário
    SELECT fcm_token INTO v_fcm_token
    FROM public.profiles
    WHERE id = v_queue_item.user_id;

    IF v_fcm_token IS NULL THEN
      -- Usuário sem token: pular
      UPDATE public.push_notification_queue
      SET status = 'skipped',
          last_error = 'No FCM token',
          updated_at = NOW()
      WHERE id = v_queue_item.id;
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    -- Buscar dados da notificação
    SELECT n.type, n.title, n.body, n.community_id,
           n.post_id, n.wiki_id, n.comment_id,
           n.chat_thread_id, n.action_url, n.actor_id
    INTO v_notif
    FROM public.notifications n
    WHERE n.id = v_queue_item.notification_id;

    IF NOT FOUND THEN
      UPDATE public.push_notification_queue
      SET status = 'skipped',
          last_error = 'Notification not found',
          updated_at = NOW()
      WHERE id = v_queue_item.id;
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    -- Montar payload para a Edge Function
    v_payload := jsonb_build_object(
      'user_id',           v_queue_item.user_id,
      'notification_type', v_notif.type,
      'title',             COALESCE(v_notif.title, 'NexusHub'),
      'content',           COALESCE(v_notif.body, ''),
      'community_id',      v_notif.community_id,
      'data',              jsonb_build_object(
        'notification_id', v_queue_item.notification_id::TEXT,
        'type',            v_notif.type,
        'post_id',         COALESCE(v_notif.post_id::TEXT, ''),
        'wiki_id',         COALESCE(v_notif.wiki_id::TEXT, ''),
        'comment_id',      COALESCE(v_notif.comment_id::TEXT, ''),
        'community_id',    COALESCE(v_notif.community_id::TEXT, ''),
        'chat_thread_id',  COALESCE(v_notif.chat_thread_id::TEXT, ''),
        'action_url',      COALESCE(v_notif.action_url, ''),
        'actor_id',        COALESCE(v_notif.actor_id::TEXT, '')
      )
    );

    BEGIN
      -- Chamar Edge Function via net.http_post (assíncrono)
      PERFORM net.http_post(
        url     := v_supabase_url || '/functions/v1/push-notification',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_service_key
        ),
        body    := v_payload
      );

      -- Marcar como enviado
      UPDATE public.push_notification_queue
      SET status = 'sent',
          sent_at = NOW(),
          updated_at = NOW()
      WHERE id = v_queue_item.id;

      v_success := v_success + 1;

    EXCEPTION WHEN OTHERS THEN
      -- Falha: agendar retry exponencial (máx 3 tentativas)
      IF v_queue_item.attempt_count >= 3 THEN
        UPDATE public.push_notification_queue
        SET status = 'failed',
            last_error = SQLERRM,
            updated_at = NOW()
        WHERE id = v_queue_item.id;
      ELSE
        UPDATE public.push_notification_queue
        SET status = 'pending',
            last_error = SQLERRM,
            next_retry_at = NOW() + (INTERVAL '1 minute' * POWER(2, v_queue_item.attempt_count)),
            updated_at = NOW()
        WHERE id = v_queue_item.id;
      END IF;
      v_errors := v_errors + 1;
    END;
  END LOOP;

  RETURN QUERY SELECT v_processed, v_success, v_skipped, v_errors;
END;
$$;

-- ============================================================================
-- Cron job: processar fila de push a cada 1 minuto
-- ============================================================================
DO $$
BEGIN
  -- Remover cron job existente se houver
  PERFORM cron.unschedule('process-push-queue');
EXCEPTION WHEN OTHERS THEN
  NULL; -- ignora se não existia
END $$;

SELECT cron.schedule(
  'process-push-queue',
  '* * * * *',
  'SELECT public.process_push_notification_queue()'
);

-- ============================================================================
-- Reprocessar itens pendentes/travados imediatamente
-- ============================================================================
UPDATE public.push_notification_queue
SET next_retry_at = NOW(),
    attempt_count = 0,
    status = 'pending',
    updated_at = NOW()
WHERE status IN ('pending', 'processing', 'failed')
  AND attempt_count < 3;
