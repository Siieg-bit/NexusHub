-- =============================================================================
-- Migration 155: Sistema de Mood/Status do Usuário
--
-- Adiciona dois campos à tabela profiles:
--   status_emoji  — um único emoji que representa o humor/estado atual
--   status_text   — texto curto descritivo (máx. 60 caracteres)
--
-- Ambos são opcionais e podem ser limpos a qualquer momento.
-- Exibidos no perfil e na lista de membros da comunidade.
-- =============================================================================

-- 1. Adicionar colunas à tabela profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS status_emoji TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS status_text  TEXT DEFAULT NULL;

-- 2. Constraint: status_text máximo de 60 caracteres
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_status_text_length
    CHECK (status_text IS NULL OR char_length(status_text) <= 60);

-- 3. RPC: set_user_status — atualiza o status do usuário autenticado
CREATE OR REPLACE FUNCTION public.set_user_status(
  p_emoji TEXT DEFAULT NULL,
  p_text  TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validar tamanho do texto
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

-- 4. RPC: clear_user_status — limpa o status do usuário autenticado
CREATE OR REPLACE FUNCTION public.clear_user_status()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
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

-- 5. Permissões
GRANT EXECUTE ON FUNCTION public.set_user_status(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_user_status() TO authenticated;
