-- Garante que o @username global (profiles.amino_id) seja único no app inteiro,
-- de forma case-insensitive, e sempre armazenado em minúsculas.

BEGIN;

UPDATE public.profiles
SET amino_id = lower(amino_id)
WHERE amino_id IS NOT NULL
  AND amino_id <> lower(amino_id);

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_amino_id_key;

DROP INDEX IF EXISTS profiles_amino_id_lower_key;

CREATE UNIQUE INDEX profiles_amino_id_lower_key
  ON public.profiles ((lower(amino_id)))
  WHERE amino_id IS NOT NULL AND btrim(amino_id) <> '';

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_amino_id_format_check;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_amino_id_format_check
CHECK (
  amino_id IS NULL
  OR amino_id ~ '^[a-z0-9_]{3,30}$'
);

COMMIT;
