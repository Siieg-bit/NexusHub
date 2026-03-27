-- NexusHub — Migração 014: Security Enhancements
-- ============================================================================

-- Tabela de logs de segurança
CREATE TABLE IF NOT EXISTS public.security_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event TEXT NOT NULL,
  details TEXT,
  ip_address INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.security_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "security_logs_insert" ON public.security_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "security_logs_select_own" ON public.security_logs
  FOR SELECT USING (auth.uid() = user_id);

-- Tabela de rate limit log (server-side tracking)
CREATE TABLE IF NOT EXISTS public.rate_limit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.rate_limit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rate_limit_log_insert" ON public.rate_limit_log
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Índice para queries rápidas de rate limit
CREATE INDEX IF NOT EXISTS idx_rate_limit_user_action
  ON public.rate_limit_log(user_id, action, created_at DESC);

-- Índice para limpeza de logs antigos
CREATE INDEX IF NOT EXISTS idx_security_logs_created
  ON public.security_logs(created_at);

-- Adicionar coluna fcm_token ao profiles se não existir
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='fcm_token')
  THEN
    ALTER TABLE public.profiles ADD COLUMN fcm_token TEXT;
  END IF;
END $$;

-- Adicionar coluna is_amino_plus ao profiles se não existir
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='is_amino_plus')
  THEN
    ALTER TABLE public.profiles ADD COLUMN is_amino_plus BOOLEAN DEFAULT false;
  END IF;
END $$;

-- Função para limpar logs antigos (rodar via cron job)
CREATE OR REPLACE FUNCTION public.cleanup_old_logs()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Limpar rate limit logs com mais de 24h
  DELETE FROM public.rate_limit_log WHERE created_at < now() - interval '24 hours';
  -- Limpar security logs com mais de 90 dias
  DELETE FROM public.security_logs WHERE created_at < now() - interval '90 days';
END;
$$;
