-- =============================================================================
-- Migration 161: Trigger de menção @usuario no corpo dos posts
-- =============================================================================
-- O banco já processa menções em comentários (migration 061) e no chat.
-- Esta migration adiciona o mesmo mecanismo para o corpo dos posts,
-- disparando notificações do tipo 'mention' quando um post é criado ou
-- atualizado com @username no conteúdo.
-- =============================================================================

-- Função que processa menções no conteúdo de um post
CREATE OR REPLACE FUNCTION public.trg_notify_on_post_mention()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name    TEXT;
  v_mention       TEXT;
  v_mentioned_id  UUID;
  v_action_url    TEXT;
BEGIN
  -- Só processa INSERT ou UPDATE onde o conteúdo mudou
  IF TG_OP = 'UPDATE' AND OLD.content IS NOT DISTINCT FROM NEW.content THEN
    RETURN NEW;
  END IF;

  -- Posts deletados ou não publicados não disparam notificações
  IF NEW.status IS NOT NULL AND NEW.status NOT IN ('ok', 'published', 'active') THEN
    RETURN NEW;
  END IF;

  -- Conteúdo sem @ não precisa ser processado
  IF NEW.content IS NULL OR NEW.content NOT LIKE '%@%' THEN
    RETURN NEW;
  END IF;

  -- Buscar nome do autor
  SELECT COALESCE(NULLIF(nickname, ''), amino_id, 'Alguém')
  INTO v_actor_name
  FROM public.profiles
  WHERE id = NEW.author_id;

  v_action_url := '/post/' || NEW.id;

  -- Processar cada @username encontrado no conteúdo
  FOR v_mention IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_]+)', 'g'))[1]
  LOOP
    -- Buscar o usuário pelo amino_id ou nickname (case-insensitive)
    SELECT id INTO v_mentioned_id
    FROM public.profiles
    WHERE (lower(amino_id) = lower(v_mention) OR lower(nickname) = lower(v_mention))
      AND id != NEW.author_id
    LIMIT 1;

    IF v_mentioned_id IS NOT NULL THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id    => v_mentioned_id,
        p_actor_id   => NEW.author_id,
        p_type       => 'mention',
        p_title      => COALESCE(v_actor_name, 'Alguém') || ' te mencionou em um post',
        p_body       => LEFT(COALESCE(NEW.title, NEW.content, ''), 100),
        p_group_key  => 'mention_post_' || NEW.id || '_' || v_mentioned_id,
        p_post_id    => NEW.id,
        p_action_url => v_action_url
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

-- Remover trigger anterior se existir
DROP TRIGGER IF EXISTS trg_mention_on_post ON public.posts;

-- Criar trigger para INSERT e UPDATE
CREATE TRIGGER trg_mention_on_post
  AFTER INSERT OR UPDATE OF content ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_on_post_mention();

COMMENT ON FUNCTION public.trg_notify_on_post_mention() IS
  'Dispara notificação do tipo mention para cada @usuario encontrado no conteúdo de um post novo ou editado.';
