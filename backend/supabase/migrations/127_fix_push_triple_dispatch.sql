-- =============================================================================
-- Migração 127: Corrigir triple-dispatch de push notifications
-- =============================================================================
-- Problema: cada INSERT em notifications disparava 3 pushes:
--   1. trg_send_push_on_notification   → net.http_post direto (legado)
--   2. trg_send_push_on_notification_v2 → INSERT na fila + net.http_post direto
--   3. process-push-queue (cron 1min)  → processa fila → net.http_post
--
-- Solução:
--   - Desabilitar trg_send_push_on_notification (legado, substituído pelo v2)
--   - Reescrever trg_send_push_on_notification_v2 para APENAS inserir na fila
--     (sem net.http_post direto — o cron cuida do envio)
--   - O cron process-push-queue continua como único responsável pelo envio
-- =============================================================================

-- 1. Desabilitar o trigger legado (não dropar para manter histórico de migrações)
ALTER TABLE public.notifications
    DISABLE TRIGGER trg_send_push_on_notification;

-- 2. Reescrever a função do v2 para APENAS enfileirar (sem net.http_post)
CREATE OR REPLACE FUNCTION public.trg_send_push_on_notification_v2()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Apenas enfileirar — o cron process-push-queue cuida do envio real.
    -- Isso evita triple-dispatch: legado (desabilitado) + v2 direto + cron.
    INSERT INTO public.push_notification_queue (
        notification_id,
        user_id,
        status,
        created_at
    ) VALUES (
        NEW.id,
        NEW.user_id,
        'pending',
        NOW()
    )
    ON CONFLICT DO NOTHING;  -- idempotência: evita duplicata se trigger rodar 2x

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '[push_trigger_v2] Falha ao enfileirar push para user %: %',
            NEW.user_id, SQLERRM;
        RETURN NEW;
END;
$$;

-- 3. Garantir que o trigger v2 está habilitado
ALTER TABLE public.notifications
    ENABLE TRIGGER trg_send_push_on_notification_v2;

-- 4. Adicionar constraint UNIQUE na fila para evitar duplicatas futuras
--    (notification_id deve aparecer apenas uma vez na fila)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'push_notification_queue_notification_id_key'
    ) THEN
        ALTER TABLE public.push_notification_queue
            ADD CONSTRAINT push_notification_queue_notification_id_key
            UNIQUE (notification_id);
    END IF;
END $$;
