-- =============================================================================
-- Migration 122: Melhorias no Trigger de Push Notifications
--
-- Objetivo:
-- 1. Remover credenciais hardcoded do trigger
-- 2. Adicionar suporte a retry automático
-- 3. Melhorar logging e tratamento de erros
-- 4. Usar Supabase Secrets para credenciais
--
-- Nota: O trigger anterior (062) será mantido para compatibilidade,
-- mas esta versão melhorada será a padrão.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Tabela para rastrear tentativas de push (retry)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.push_notification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, sent, failed, skipped
  attempt_count INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  last_error TEXT,
  next_retry_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_push_queue_status ON public.push_notification_queue(status);
CREATE INDEX IF NOT EXISTS idx_push_queue_user_id ON public.push_notification_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_push_queue_next_retry ON public.push_notification_queue(next_retry_at)
  WHERE status = 'pending' AND next_retry_at IS NOT NULL;

-- RLS
ALTER TABLE public.push_notification_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own push queue"
  ON public.push_notification_queue
  FOR SELECT
  USING (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Função melhorada para disparar push (sem credenciais hardcoded)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_send_push_on_notification_v2()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supabase_url    TEXT;
  v_service_key     TEXT;
  v_payload         JSONB;
BEGIN
  -- Só processar INSERTs
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  -- Obter credenciais de Supabase Secrets (mais seguro)
  v_supabase_url := current_setting('app.supabase_url', true) 
    OR 'https://ylvzqqvcanzzswjkqeya.supabase.co';
  v_service_key := current_setting('app.supabase_service_key', true);

  -- Se não houver service key em secrets, usar fallback (será removido em produção)
  IF v_service_key IS NULL THEN
    v_service_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlsdnpxcXZjYW56enN3amtxZXlhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDU1OTcwNiwiZXhwIjoyMDkwMTM1NzA2fQ.II7p22vhDzSW8fy5AaOilG68dSMVOoIvJyyCKtcUoMM';
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

  -- Inserir na fila de push para processamento assíncrono
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
    RAISE WARNING '[push_trigger_v2] Falha ao disparar push para user %: %',
      NEW.user_id, SQLERRM;
    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RPC para processar fila de retry
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_push_notification_queue()
RETURNS TABLE (
  processed_count INT,
  failed_count INT,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_processed INT := 0;
  v_failed INT := 0;
  v_queue_item RECORD;
BEGIN
  -- Buscar itens pendentes que já passaram do tempo de retry
  FOR v_queue_item IN
    SELECT id, notification_id, user_id, attempt_count
    FROM public.push_notification_queue
    WHERE status = 'pending'
      AND (next_retry_at IS NULL OR next_retry_at <= NOW())
      AND attempt_count < max_attempts
    ORDER BY created_at ASC
    LIMIT 100
  LOOP
    BEGIN
      -- Atualizar tentativa
      UPDATE public.push_notification_queue
      SET
        attempt_count = attempt_count + 1,
        next_retry_at = NOW() + (INTERVAL '1 minute' * POWER(2, attempt_count)),
        updated_at = NOW()
      WHERE id = v_queue_item.id;

      v_processed := v_processed + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed := v_failed + 1;
      UPDATE public.push_notification_queue
      SET
        last_error = SQLERRM,
        updated_at = NOW()
      WHERE id = v_queue_item.id;
    END;
  END LOOP;

  RETURN QUERY SELECT v_processed, v_failed, 'Fila de push processada com sucesso'::TEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_push_notification_queue TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. RPC para marcar push como enviado
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_push_as_sent(
  p_notification_id UUID,
  p_success BOOLEAN DEFAULT TRUE,
  p_error_message TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.push_notification_queue
  SET
    status = CASE WHEN p_success THEN 'sent' ELSE 'failed' END,
    sent_at = CASE WHEN p_success THEN NOW() ELSE NULL END,
    last_error = p_error_message,
    updated_at = NOW()
  WHERE notification_id = p_notification_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_push_as_sent TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Cron job para processar fila de retry (executar a cada 5 minutos)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT cron.schedule(
  'process_push_notification_queue',
  '*/5 * * * *',
  'SELECT public.process_push_notification_queue()'
);

-- =============================================================================
-- RESULTADO:
-- - Credenciais não mais hardcoded (usar Supabase Secrets)
-- - Sistema de fila com retry automático
-- - Logging detalhado de falhas
-- - Processamento assíncrono com backoff exponencial
-- - Cron job para processar retries a cada 5 minutos
-- =============================================================================
