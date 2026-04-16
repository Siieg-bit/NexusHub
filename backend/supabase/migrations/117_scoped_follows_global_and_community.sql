-- =============================================================================
-- Migration 117: Scoped follows (global + community)
-- =============================================================================
-- Objetivo:
-- 1. Garantir que follows possam existir separadamente no escopo global e no
--    escopo de uma comunidade específica.
-- 2. Remover o conflito da UNIQUE antiga (follower_id, following_id), que
--    impedia coexistência entre follow global e follow comunitário.
-- 3. Atualizar a RPC toggle_follow_with_reputation para respeitar community_id.
-- =============================================================================

ALTER TABLE public.follows
  ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE;

COMMENT ON COLUMN public.follows.community_id IS
  'NULL = follow global; UUID preenchido = follow contextual dentro de uma comunidade específica.';

-- Remover UNIQUE antiga, se existir.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'follows_follower_id_following_id_key'
      AND conrelid = 'public.follows'::regclass
  ) THEN
    ALTER TABLE public.follows
      DROP CONSTRAINT follows_follower_id_following_id_key;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Garantir unicidade por escopo.
-- Para o escopo global, usamos um UUID sentinela apenas na expressão do índice,
-- sem gravá-lo na coluna.
CREATE UNIQUE INDEX IF NOT EXISTS idx_follows_scope_unique
  ON public.follows (
    follower_id,
    following_id,
    COALESCE(community_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

CREATE INDEX IF NOT EXISTS idx_follows_following_scope
  ON public.follows (following_id, community_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_follows_follower_scope
  ON public.follows (follower_id, community_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.toggle_follow_with_reputation(
  p_community_id UUID,
  p_follower_id UUID,
  p_following_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing UUID;
  v_result JSONB;
  v_scope UUID := COALESCE(p_community_id, '00000000-0000-0000-0000-000000000000'::uuid);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF auth.uid() <> p_follower_id THEN
    RAISE EXCEPTION 'Cannot follow on behalf of another user';
  END IF;

  IF p_follower_id = p_following_id THEN
    RAISE EXCEPTION 'Cannot follow yourself';
  END IF;

  SELECT id INTO v_existing
  FROM public.follows
  WHERE follower_id = p_follower_id
    AND following_id = p_following_id
    AND COALESCE(community_id, '00000000-0000-0000-0000-000000000000'::uuid) = v_scope
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    DELETE FROM public.follows
    WHERE id = v_existing;

    -- Contadores em profiles continuam representando o escopo global.
    IF p_community_id IS NULL THEN
      UPDATE public.profiles
      SET followers_count = GREATEST(followers_count - 1, 0)
      WHERE id = p_following_id;

      UPDATE public.profiles
      SET following_count = GREATEST(following_count - 1, 0)
      WHERE id = p_follower_id;
    END IF;

    v_result := jsonb_build_object('following', false);
  ELSE
    INSERT INTO public.follows (
      follower_id,
      following_id,
      community_id
    ) VALUES (
      p_follower_id,
      p_following_id,
      p_community_id
    );

    -- Contadores em profiles continuam representando o escopo global.
    IF p_community_id IS NULL THEN
      UPDATE public.profiles
      SET followers_count = followers_count + 1
      WHERE id = p_following_id;

      UPDATE public.profiles
      SET following_count = following_count + 1
      WHERE id = p_follower_id;
    END IF;

    IF p_community_id IS NOT NULL THEN
      PERFORM public.add_reputation(
        p_follower_id,
        p_community_id,
        'follow_user',
        1,
        p_following_id
      );
    END IF;

    v_result := jsonb_build_object('following', true);
  END IF;

  RETURN v_result;
END;
$$;
