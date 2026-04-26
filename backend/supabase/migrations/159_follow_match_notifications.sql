-- ============================================================
-- NexusHub — Migração 159: Notificações de Follow e Match Mútuo
-- ============================================================
-- Atualiza o trigger handle_follow_change para:
-- 1. Inserir notificação de 'follow' quando alguém segue outro usuário
-- 2. Inserir notificação de 'match' quando o follow é mútuo (ambos se seguem)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_follow_change()
RETURNS TRIGGER AS $$
DECLARE
  v_follower_nickname  TEXT;
  v_follower_icon_url  TEXT;
  v_following_nickname TEXT;
  v_following_icon_url TEXT;
  v_is_mutual          BOOLEAN;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Atualizar contadores
    UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    UPDATE public.profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;

    -- Buscar dados do seguidor
    SELECT nickname, icon_url
      INTO v_follower_nickname, v_follower_icon_url
      FROM public.profiles
      WHERE id = NEW.follower_id;

    -- Notificação de follow para quem foi seguido
    INSERT INTO public.notifications (
      user_id, type, title, body, image_url, actor_id, action_url
    ) VALUES (
      NEW.following_id,
      'follow',
      COALESCE(v_follower_nickname, 'Alguém') || ' começou a te seguir',
      'Toque para ver o perfil',
      v_follower_icon_url,
      NEW.follower_id,
      '/profile/' || NEW.follower_id::TEXT
    );

    -- Verificar se o follow é mútuo
    SELECT EXISTS(
      SELECT 1 FROM public.follows
      WHERE follower_id = NEW.following_id
        AND following_id = NEW.follower_id
    ) INTO v_is_mutual;

    IF v_is_mutual THEN
      -- Buscar dados de quem foi seguido (para a notificação do seguidor)
      SELECT nickname, icon_url
        INTO v_following_nickname, v_following_icon_url
        FROM public.profiles
        WHERE id = NEW.following_id;

      -- Notificação de match para o seguidor
      INSERT INTO public.notifications (
        user_id, type, title, body, image_url, actor_id, action_url
      ) VALUES (
        NEW.follower_id,
        'match',
        'Você e ' || COALESCE(v_following_nickname, 'alguém') || ' se seguem mutuamente!',
        'Que tal iniciar uma conversa?',
        v_following_icon_url,
        NEW.following_id,
        '/profile/' || NEW.following_id::TEXT
      );

      -- Notificação de match para quem foi seguido
      INSERT INTO public.notifications (
        user_id, type, title, body, image_url, actor_id, action_url
      ) VALUES (
        NEW.following_id,
        'match',
        'Você e ' || COALESCE(v_follower_nickname, 'alguém') || ' se seguem mutuamente!',
        'Que tal iniciar uma conversa?',
        v_follower_icon_url,
        NEW.follower_id,
        '/profile/' || NEW.follower_id::TEXT
      );
    END IF;

    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET following_count = GREATEST(following_count - 1, 0) WHERE id = OLD.follower_id;
    UPDATE public.profiles SET followers_count = GREATEST(followers_count - 1, 0) WHERE id = OLD.following_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atualizar comentário do tipo na tabela
COMMENT ON COLUMN public.notifications.type IS
  'Tipos: like, comment, follow, match, mention, tip, strike, broadcast, chat_invite, wiki_approved, wiki_rejected, role_change, join_request, achievement, level_up, moderation, economy, story, repost';
