-- ============================================================
-- 077 — Correções de RLS e cosméticos da loja
-- ============================================================
-- 1. Adiciona políticas de UPDATE e INSERT na user_purchases
--    (necessário para equipar/desequipar itens via Dart direto)
-- 2. Remove itens profile_background do banco (funcionalidade removida)
-- 3. Limpa referências remanescentes de profile_background
-- ============================================================

-- ── 1. RLS: user_purchases — UPDATE (para equipar/desequipar) ──
-- O purchase_store_item RPC usa SECURITY DEFINER (contorna RLS para INSERT).
-- Mas o _equipItem no Dart faz UPDATE direto, então precisa de política.
DROP POLICY IF EXISTS "purchases_update_own" ON public.user_purchases;
CREATE POLICY "purchases_update_own"
  ON public.user_purchases
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ── 2. Remove profile_background do banco ──
-- (já removido da UI, agora remove do banco para consistência)
DELETE FROM public.store_items WHERE type = 'profile_background';
DELETE FROM public.store_items WHERE type = 'chat_background';

-- ── 3. Garante que store_items tem política de SELECT para todos ──
-- (já existe, mas garante que itens is_active=true são visíveis)
-- Nada a fazer — política store_items_select_all já existe.

-- ── 4. Atualiza asset_config dos frames para usar 'procedural:' ──
-- Os frames atuais usam URLs de emoji como frame_url, o que não funciona
-- como moldura real. Atualiza para usar estilo procedural até que assets
-- reais sejam criados.
UPDATE public.store_items
SET asset_config = jsonb_set(
  asset_config,
  '{frame_style}',
  '"sparkle"'
)
WHERE id = 'c3333333-3333-3333-3333-333333333331'::UUID; -- Spark Frame

UPDATE public.store_items
SET asset_config = jsonb_set(
  asset_config,
  '{frame_style}',
  '"fire"'
)
WHERE id = 'c3333333-3333-3333-3333-333333333332'::UUID; -- Flame Frame

-- ── 5. Garante que recently_used_stickers tem INSERT WITH CHECK correto ──
-- A política recently_used_stickers_insert não tem WITH CHECK, o que pode
-- permitir inserções para outros usuários. Corrige:
DROP POLICY IF EXISTS "recently_used_stickers_insert" ON public.recently_used_stickers;
CREATE POLICY "recently_used_stickers_insert"
  ON public.recently_used_stickers
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);
