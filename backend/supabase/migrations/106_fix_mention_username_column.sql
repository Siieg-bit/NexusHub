-- =============================================================================
-- Migration 106: Corrigir erro de coluna "username" nas triggers de menção
--
-- Corrige:
-- 1. Trigger de comentários que tenta usar coluna "username" que não existe
-- 2. Trigger de posts que tenta usar coluna "username" que não existe
-- 3. Usar "nickname" em vez de "username" para buscar menções
-- =============================================================================

-- ========================
-- Trigger: comments_mention_trigger (corrigido)
-- ========================
CREATE OR REPLACE FUNCTION public.comments_mention_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_mentioned_id UUID;
  v_mention TEXT;
  v_actor_name TEXT;
  v_post_id UUID;
BEGIN
  IF NEW.content IS NULL OR NEW.content = '' THEN
    RETURN NEW;
  END IF;

  -- Buscar nome do autor
  SELECT nickname INTO v_actor_name
  FROM public.profiles
  WHERE id = NEW.author_id;

  -- Processar menções @nickname no conteúdo do comentário
  FOR v_mention IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_]+)', 'g'))[1]
  LOOP
    SELECT id INTO v_mentioned_id
    FROM public.profiles
    WHERE lower(nickname) = lower(v_mention)
      AND id != NEW.author_id
    LIMIT 1;

    IF v_mentioned_id IS NOT NULL THEN
      -- Buscar o post_id se não estiver definido
      SELECT post_id INTO v_post_id FROM public.comments WHERE id = NEW.id;
      
      PERFORM public.upsert_grouped_notification(
        p_user_id    => v_mentioned_id,
        p_actor_id   => NEW.author_id,
        p_type       => 'mention',
        p_title      => COALESCE(v_actor_name, 'Alguém') || ' te mencionou em um comentário',
        p_body       => LEFT(COALESCE(NEW.content, ''), 100),
        p_reference_id => v_post_id,
        p_community_id => (SELECT community_id FROM public.posts WHERE id = v_post_id LIMIT 1)
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;

-- ========================
-- Trigger: posts_mention_trigger (corrigido)
-- ========================
CREATE OR REPLACE FUNCTION public.posts_mention_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_mentioned_id UUID;
  v_mention TEXT;
  v_actor_name TEXT;
BEGIN
  IF NEW.content IS NULL OR NEW.content = '' THEN
    RETURN NEW;
  END IF;

  -- Buscar nome do autor
  SELECT nickname INTO v_actor_name
  FROM public.profiles
  WHERE id = NEW.author_id;

  -- Processar menções @nickname
  FOR v_mention IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_]+)', 'g'))[1]
  LOOP
    SELECT id INTO v_mentioned_id
    FROM public.profiles
    WHERE lower(nickname) = lower(v_mention)
      AND id != NEW.author_id
    LIMIT 1;

    IF v_mentioned_id IS NOT NULL THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id    => v_mentioned_id,
        p_actor_id   => NEW.author_id,
        p_type       => 'mention',
        p_title      => COALESCE(v_actor_name, 'Alguém') || ' te mencionou em um post',
        p_body       => LEFT(COALESCE(NEW.content, ''), 100),
        p_reference_id => NEW.id,
        p_community_id => NEW.community_id
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;
