-- ============================================================
-- Migration 209: Tabela push_logs para rastrear envios FCM
-- ============================================================

-- Tabela de logs de push notifications
CREATE TABLE IF NOT EXISTS public.push_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  notification_id UUID REFERENCES public.notifications(id) ON DELETE SET NULL,
  notification_type TEXT,
  fcm_message_id  TEXT,          -- ID retornado pelo FCM em caso de sucesso
  status          TEXT NOT NULL DEFAULT 'pending', -- sent | failed | skipped | no_token | disabled
  error_code      TEXT,          -- código de erro FCM (ex: messaging/invalid-registration-token)
  error_message   TEXT,          -- mensagem de erro detalhada
  fcm_token_prefix TEXT,         -- primeiros 20 chars do token (para debug sem expor o token)
  platform        TEXT,          -- android | ios | web (inferido do token)
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para consultas de debug
CREATE INDEX IF NOT EXISTS idx_push_logs_user_id    ON public.push_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_push_logs_created_at ON public.push_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_push_logs_status     ON public.push_logs(status);
CREATE INDEX IF NOT EXISTS idx_push_logs_notif_id   ON public.push_logs(notification_id);

-- RLS: apenas service role pode inserir; usuário pode ver seus próprios logs
ALTER TABLE public.push_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "push_logs_service_insert"
  ON public.push_logs FOR INSERT
  TO service_role WITH CHECK (true);

CREATE POLICY "push_logs_user_select"
  ON public.push_logs FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Limpeza automática: manter apenas 30 dias de logs
CREATE OR REPLACE FUNCTION public.cleanup_push_logs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.push_logs
  WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$;

-- Adicionar ao master_cleanup existente (se não existir já)
-- A função master_cleanup já chama cleanup_old_logs; adicionamos push_logs aqui
DO $$
BEGIN
  -- Verificar se a função master_cleanup existe e adicionar chamada ao cleanup_push_logs
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'master_cleanup'
  ) THEN
    -- Não modificamos master_cleanup aqui; o cron daily-deep-cleanup pode chamar
    -- cleanup_push_logs separadamente se necessário
    NULL;
  END IF;
END;
$$;
