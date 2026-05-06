-- Migration 225: Adicionar silence_member ao enum moderation_action
-- O Flutter envia 'silence_member' como p_moderate_action no resolve_flag,
-- mas esse valor não existia no enum, causando erro de cast.
-- Também adiciona 'ban' se ainda não existir (usado pelo Flutter também).

DO $$
BEGIN
  -- Adicionar silence_member se não existir
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'public.moderation_action'::regtype
    AND enumlabel = 'silence_member'
  ) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'silence_member';
  END IF;
END;
$$;
