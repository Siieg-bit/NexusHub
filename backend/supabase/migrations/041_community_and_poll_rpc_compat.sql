-- Migration 041: Compatibilidade de RPCs para comunidade e enquete
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Upgrade de create_community
--    Alinha a RPC ao frontend atual, aceitando theme_color e
--    primary_language, mantendo o fluxo atômico no servidor.
-- ─────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.create_community(text, text, text, text, public.community_join_type);
DROP FUNCTION IF EXISTS public.create_community(text, text, text, text, public.community_join_type, text, text);

CREATE OR REPLACE FUNCTION public.create_community(
  p_name TEXT,
  p_tagline TEXT DEFAULT '',
  p_description TEXT DEFAULT '',
  p_category TEXT DEFAULT 'general',
  p_join_type public.community_join_type DEFAULT 'open',
  p_theme_color TEXT DEFAULT '#6C5CE7',
  p_primary_language TEXT DEFAULT 'pt-BR'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_community_id UUID;
  v_name TEXT := NULLIF(trim(COALESCE(p_name, '')), '');
  v_tagline TEXT := NULLIF(trim(COALESCE(p_tagline, '')), '');
  v_description TEXT := NULLIF(trim(COALESCE(p_description, '')), '');
  v_category TEXT := COALESCE(NULLIF(trim(COALESCE(p_category, '')), ''), 'general');
  v_theme_color TEXT := COALESCE(NULLIF(trim(COALESCE(p_theme_color, '')), ''), '#6C5CE7');
  v_primary_language TEXT := COALESCE(NULLIF(trim(COALESCE(p_primary_language, '')), ''), 'pt-BR');
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF v_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'name_required');
  END IF;

  INSERT INTO public.communities (
    name,
    tagline,
    description,
    category,
    join_type,
    agent_id,
    theme_color,
    primary_language
  ) VALUES (
    v_name,
    v_tagline,
    v_description,
    v_category,
    COALESCE(p_join_type, 'open'::public.community_join_type),
    v_user_id,
    v_theme_color,
    v_primary_language
  )
  RETURNING id INTO v_community_id;

  INSERT INTO public.community_members (community_id, user_id, role)
  VALUES (v_community_id, v_user_id, 'agent');

  INSERT INTO public.guidelines (community_id, content)
  VALUES (v_community_id, '# Regras da Comunidade\n\nSeja respeitoso e siga as regras.');

  INSERT INTO public.shared_folders (community_id)
  VALUES (v_community_id);

  RETURN jsonb_build_object(
    'success', true,
    'community_id', v_community_id
  );
END;
$function$;

-- ─────────────────────────────────────────────────────────────
-- 2. Nova RPC vote_on_poll
--    Garante voto único por enquete e incremento atômico de
--    votes_count, evitando race conditions no Flutter.
-- ─────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.vote_on_poll(uuid);

CREATE OR REPLACE FUNCTION public.vote_on_poll(
  p_option_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_post_id UUID;
  v_existing_option_id UUID;
  v_option_votes INTEGER := 0;
  v_total_votes INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT post_id
    INTO v_post_id
  FROM public.poll_options
  WHERE id = p_option_id;

  IF v_post_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'option_not_found');
  END IF;

  -- Serializa a votação por enquete para evitar votos múltiplos em
  -- opções diferentes sob concorrência.
  PERFORM 1
  FROM public.poll_options
  WHERE post_id = v_post_id
  ORDER BY id
  FOR UPDATE;

  SELECT pv.option_id
    INTO v_existing_option_id
  FROM public.poll_votes pv
  JOIN public.poll_options po ON po.id = pv.option_id
  WHERE pv.user_id = v_user_id
    AND po.post_id = v_post_id
  LIMIT 1;

  IF v_existing_option_id IS NOT NULL THEN
    SELECT COALESCE(SUM(votes_count), 0)
      INTO v_total_votes
    FROM public.poll_options
    WHERE post_id = v_post_id;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_voted',
      'post_id', v_post_id,
      'option_id', v_existing_option_id,
      'total_votes', v_total_votes
    );
  END IF;

  INSERT INTO public.poll_votes (option_id, user_id)
  VALUES (p_option_id, v_user_id)
  ON CONFLICT (option_id, user_id) DO NOTHING;

  IF NOT FOUND THEN
    SELECT COALESCE(SUM(votes_count), 0)
      INTO v_total_votes
    FROM public.poll_options
    WHERE post_id = v_post_id;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_voted',
      'post_id', v_post_id,
      'option_id', p_option_id,
      'total_votes', v_total_votes
    );
  END IF;

  UPDATE public.poll_options
  SET votes_count = COALESCE(votes_count, 0) + 1
  WHERE id = p_option_id
  RETURNING votes_count INTO v_option_votes;

  SELECT COALESCE(SUM(votes_count), 0)
    INTO v_total_votes
  FROM public.poll_options
  WHERE post_id = v_post_id;

  RETURN jsonb_build_object(
    'success', true,
    'post_id', v_post_id,
    'option_id', p_option_id,
    'option_votes', COALESCE(v_option_votes, 0),
    'total_votes', v_total_votes
  );
END;
$function$;
