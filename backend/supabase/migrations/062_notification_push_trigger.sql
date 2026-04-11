-- =============================================================================
-- Migration 062: Trigger pg_net para disparar push FCM após inserir notificação
--
-- Após qualquer INSERT na tabela notifications, chama a Edge Function
-- push-notification via pg_net (assíncrono, não bloqueia a transação).
--
-- Requer: extensão pg_net habilitada (Supabase habilita por padrão)
-- =============================================================================

-- ─── Função que chama a Edge Function push-notification via pg_net ────────────
CREATE OR REPLACE FUNCTION public.trg_send_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supabase_url    TEXT := 'https://ylvzqqvcanzzswjkqeya.supabase.co';
  v_service_key     TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlsdnpxcXZjYW56enN3amtxZXlhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDU1OTcwNiwiZXhwIjoyMDkwMTM1NzA2fQ.II7p22vhDzSW8fy5AaOilG68dSMVOoIvJyyCKtcUoMM';
  v_payload         JSONB;
BEGIN
  -- Só processar INSERTs
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  -- Montar payload para a Edge Function
  v_payload := jsonb_build_object(
    'user_id',           NEW.user_id,
    'notification_type', NEW.type,
    'title',             COALESCE(NEW.title, 'NexusHub'),
    'content',           COALESCE(NEW.body, ''),
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
    -- Nunca deixar o push falhar silenciosamente bloquear a transação
    RAISE WARNING '[push_trigger] Falha ao disparar push para user %: %',
      NEW.user_id, SQLERRM;
    RETURN NEW;
END;
$$;

-- ─── Trigger na tabela notifications ─────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_send_push_on_notification ON public.notifications;
CREATE TRIGGER trg_send_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_send_push_on_notification();

-- =============================================================================
-- RESULTADO: Toda notificação inserida na tabela notifications automaticamente
-- dispara um push FCM via Edge Function push-notification.
-- O trigger é assíncrono (pg_net) e nunca bloqueia a transação principal.
-- =============================================================================
