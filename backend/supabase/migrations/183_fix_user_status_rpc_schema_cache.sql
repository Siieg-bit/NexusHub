-- =============================================================================
-- Migration 183: Corrige set_user_status e clear_user_status no schema cache
--
-- Problema:
--   Após a migration 155 ser reaplicada manualmente, o PostgREST não
--   reconhecia as funções set_user_status e clear_user_status no schema
--   cache (erro PGRST202: "Could not find the function...").
--
-- Causa:
--   As funções foram criadas sem SET search_path = public, o que pode
--   causar inconsistências no schema cache do PostgREST em alguns cenários.
--   Além disso, o cache não foi recarregado após a criação.
--
-- Correção:
--   1. Recriar ambas as funções com DROP/CREATE explícito + SET search_path
--   2. GRANT EXECUTE explícito para authenticated
--   3. NOTIFY pgrst para forçar reload do schema cache
-- =============================================================================

-- 1. Recriar set_user_status
DROP FUNCTION IF EXISTS public.set_user_status(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.set_user_status(
  p_emoji TEXT DEFAULT NULL,
  p_text  TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_text IS NOT NULL AND char_length(p_text) > 60 THEN
    RAISE EXCEPTION 'status_text exceeds 60 characters';
  END IF;
  UPDATE public.profiles
  SET
    status_emoji = p_emoji,
    status_text  = p_text,
    updated_at   = NOW()
  WHERE id = auth.uid();
END;
$$;

-- 2. Recriar clear_user_status
DROP FUNCTION IF EXISTS public.clear_user_status();
CREATE OR REPLACE FUNCTION public.clear_user_status()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET
    status_emoji = NULL,
    status_text  = NULL,
    updated_at   = NOW()
  WHERE id = auth.uid();
END;
$$;

-- 3. Permissões explícitas
GRANT EXECUTE ON FUNCTION public.set_user_status(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_user_status() TO authenticated;

-- 4. Forçar reload do schema cache do PostgREST
NOTIFY pgrst, 'reload schema';
