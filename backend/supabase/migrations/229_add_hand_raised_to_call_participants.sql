-- Migration 229: Adicionar coluna hand_raised em call_participants
-- A migration 154 definia a coluna mas não foi aplicada corretamente no banco.
-- Esta migration garante a existência da coluna de forma idempotente.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'call_participants'
      AND column_name  = 'hand_raised'
  ) THEN
    ALTER TABLE public.call_participants
      ADD COLUMN hand_raised BOOLEAN NOT NULL DEFAULT false;
    RAISE NOTICE 'Coluna hand_raised adicionada com sucesso.';
  ELSE
    RAISE NOTICE 'Coluna hand_raised já existe — nenhuma ação.';
  END IF;
END;
$$;
