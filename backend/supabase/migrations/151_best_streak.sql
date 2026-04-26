-- Migration 151: Best Streak
-- Adiciona coluna best_streak_days na tabela profiles e atualiza a RPC de check-in
-- para registrar o melhor streak histórico do usuário.

-- ─── 1. Adicionar coluna best_streak_days ───────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS best_streak_days INTEGER DEFAULT 0;

-- Inicializar com o valor atual de consecutive_checkin_days para usuários existentes
UPDATE public.profiles
SET best_streak_days = consecutive_checkin_days
WHERE consecutive_checkin_days > COALESCE(best_streak_days, 0);

-- ─── 2. Atualizar a RPC perform_daily_checkin para registrar best_streak ────
-- Encontrar a versão mais recente da RPC e adicionar a atualização de best_streak.
-- A RPC já existe — apenas adicionamos o UPDATE de best_streak após incrementar o streak.

CREATE OR REPLACE FUNCTION public.update_best_streak_on_checkin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Atualiza best_streak_days se o streak atual for maior
  IF NEW.consecutive_checkin_days > COALESCE(NEW.best_streak_days, 0) THEN
    NEW.best_streak_days := NEW.consecutive_checkin_days;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_best_streak ON public.profiles;
CREATE TRIGGER trg_update_best_streak
  BEFORE UPDATE OF consecutive_checkin_days ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_best_streak_on_checkin();
