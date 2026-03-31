-- ============================================================================
-- Migration 031: Fix double-counting of likes
-- ============================================================================
-- PROBLEMA: O trigger `trg_like_insert` (migration 008) incrementa likes_count
-- na tabela posts/comments/wiki_entries quando um like é inserido. Porém, a RPC
-- `toggle_like_with_reputation` (migration 021) TAMBÉM faz o UPDATE manualmente.
-- Resultado: likes_count é incrementado/decrementado DUAS vezes por operação.
--
-- SOLUÇÃO: Dropar os triggers antigos, pois a RPC já gerencia os contadores.
-- ============================================================================

-- Dropar triggers de like que causam double-counting
DROP TRIGGER IF EXISTS trg_like_insert ON public.likes;
DROP TRIGGER IF EXISTS trg_like_delete ON public.likes;

-- A função handle_like_change() pode ser mantida (não causa dano sem trigger),
-- mas vamos removê-la por limpeza.
DROP FUNCTION IF EXISTS public.handle_like_change() CASCADE;
