-- ============================================================================
-- 092_reconcile_public_equipped_purchases_policy.sql
-- Reconcilia a policy pública de leitura de cosméticos equipados.
--
-- Auditoria funcional:
-- - O app consulta public.user_purchases filtrando user_id de terceiros e
--   is_equipped = true para renderizar cosméticos no chat e em outros contextos.
-- - O histórico local só garantia purchases_select_own, mas o comportamento
--   remoto auditado já expõe compras equipadas publicamente.
-- - Esta migration versiona esse comportamento de forma explícita e segura.
--
-- Observação:
-- - A policy purchases_select_own continua existindo e cobrindo as leituras do
--   próprio usuário. Esta policy apenas adiciona leitura pública das linhas
--   equipadas, mantendo o escopo mínimo necessário.
-- ============================================================================

DROP POLICY IF EXISTS "purchases_select_equipped_public" ON public.user_purchases;

CREATE POLICY "purchases_select_equipped_public"
  ON public.user_purchases
  FOR SELECT
  USING (is_equipped = TRUE);
