-- Migration 087: Desativar expiração temporal dos destaques
-- ============================================================================
-- Criado em: 2026-04-12
-- Descrição: Atualiza a rotina master_cleanup para preservar posts destacados
--              até substituição manual ou entrada de novos destaques.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.master_cleanup()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_expired_stories INT;
  v_expired_bans INT;
  v_expired_mutes INT;
BEGIN
  -- 1. Limpar rate_limit_log (>24h) e security_logs (>90d)
  PERFORM public.cleanup_old_logs();

  -- 2. Desativar stories expirados
  UPDATE public.stories
  SET is_active = false
  WHERE is_active = true
    AND expires_at IS NOT NULL
    AND expires_at < NOW();
  GET DIAGNOSTICS v_expired_stories = ROW_COUNT;

  -- 3. Desbanir membros com ban expirado
  UPDATE public.community_members
  SET is_banned = false, ban_expires_at = NULL
  WHERE is_banned = true
    AND ban_expires_at IS NOT NULL
    AND ban_expires_at < NOW();
  GET DIAGNOSTICS v_expired_bans = ROW_COUNT;

  -- 4. Desmutar membros com mute expirado
  UPDATE public.community_members
  SET is_muted = false, mute_expires_at = NULL
  WHERE is_muted = true
    AND mute_expires_at IS NOT NULL
    AND mute_expires_at < NOW();
  GET DIAGNOSTICS v_expired_mutes = ROW_COUNT;

  -- 5. Remover notificações lidas com mais de 30 dias
  DELETE FROM public.notifications
  WHERE is_read = true
    AND created_at < NOW() - INTERVAL '30 days';

  -- 6. Destaques deixam de expirar por tempo.
  --    A permanência passa a ser controlada por substituição/remoção explícita.

  RAISE NOTICE 'Cleanup: stories=%, bans=%, mutes=%',
    v_expired_stories, v_expired_bans, v_expired_mutes;
END;
$$;
