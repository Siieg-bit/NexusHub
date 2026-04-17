-- =============================================================================
-- Migration 075: Web Push Subscriptions
--
-- Tabela para armazenar subscriptions de Web Push Notifications
-- Permite enviar notificações push em navegadores web mesmo com app fechado
--
-- Estrutura:
-- - endpoint: URL única do navegador para receber push
-- - auth: Chave de autenticação para validar push
-- - p256dh: Chave de criptografia Diffie-Hellman
-- - platform: 'web', 'android', 'ios'
-- - is_active: Se a subscription está ativa
--
-- Índices:
-- - user_id: Para buscar subscriptions de um usuário
-- - platform: Para filtrar por plataforma
-- - endpoint: Para validar duplicatas
-- =============================================================================

-- ─── Criar tabela push_subscriptions ──────────────────────────────────────
CREATE TABLE public.push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Referência ao usuário
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Dados da subscription (Web Push)
  endpoint TEXT NOT NULL,
  auth TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  
  -- Plataforma
  platform TEXT NOT NULL DEFAULT 'web',
  CHECK (platform IN ('web', 'android', 'ios')),
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  
  -- Constraint: Não permitir duplicatas por user + platform + endpoint
  UNIQUE(user_id, platform, endpoint)
);

-- ─── Índices para performance ────────────────────────────────────────────
CREATE INDEX idx_push_subscriptions_user ON public.push_subscriptions(user_id);
CREATE INDEX idx_push_subscriptions_platform ON public.push_subscriptions(platform);
CREATE INDEX idx_push_subscriptions_active ON public.push_subscriptions(is_active);
CREATE INDEX idx_push_subscriptions_user_platform ON public.push_subscriptions(user_id, platform);

-- ─── Função para atualizar updated_at ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_update_push_subscriptions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ─── Trigger para updated_at ────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_update_push_subscriptions_updated_at ON public.push_subscriptions;
CREATE TRIGGER trg_update_push_subscriptions_updated_at
  BEFORE UPDATE ON public.push_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_update_push_subscriptions_updated_at();

-- ─── Função para marcar subscription como usada ──────────────────────────
CREATE OR REPLACE FUNCTION public.mark_push_subscription_used(
  p_subscription_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.push_subscriptions
  SET last_used_at = NOW()
  WHERE id = p_subscription_id;
END;
$$;

-- ─── Função para limpar subscriptions inativas ────────────────────────────
CREATE OR REPLACE FUNCTION public.cleanup_inactive_push_subscriptions()
RETURNS TABLE(deleted_count INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INT;
BEGIN
  -- Deletar subscriptions inativas por mais de 30 dias
  DELETE FROM public.push_subscriptions
  WHERE is_active = FALSE
    AND updated_at < NOW() - INTERVAL '30 days';
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN QUERY SELECT v_deleted_count;
END;
$$;

-- ─── RLS Policies ────────────────────────────────────────────────────────

-- Usuários podem ver suas próprias subscriptions
CREATE POLICY "Users can view their own push subscriptions"
  ON public.push_subscriptions
  FOR SELECT
  USING (auth.uid() = user_id);

-- Usuários podem inserir suas próprias subscriptions
CREATE POLICY "Users can insert their own push subscriptions"
  ON public.push_subscriptions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Usuários podem atualizar suas próprias subscriptions
CREATE POLICY "Users can update their own push subscriptions"
  ON public.push_subscriptions
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Usuários podem deletar suas próprias subscriptions
CREATE POLICY "Users can delete their own push subscriptions"
  ON public.push_subscriptions
  FOR DELETE
  USING (auth.uid() = user_id);

-- Service role pode fazer qualquer coisa (para Edge Functions)
CREATE POLICY "Service role can manage all push subscriptions"
  ON public.push_subscriptions
  FOR ALL
  USING (current_setting('role') = 'service_role')
  WITH CHECK (current_setting('role') = 'service_role');

-- ─── Ativar RLS ──────────────────────────────────────────────────────────
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- RESULTADO:
-- - Tabela push_subscriptions criada com campos para Web Push
-- - Índices para performance
-- - Triggers para updated_at
-- - Funções para marcar como usada e limpar inativas
-- - RLS policies para segurança
-- =============================================================================
