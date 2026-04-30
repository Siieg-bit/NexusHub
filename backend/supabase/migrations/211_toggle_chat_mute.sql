-- Migration 211: RPC toggle_chat_mute
-- Permite que um usuário silenciar/dessilenciar notificações de um chat específico.
-- A coluna is_muted já existe em chat_members (criada em migration anterior).
-- O trigger trg_notify_on_chat_message já respeita is_muted = FALSE.
-- Atualizando trg_notify_on_chat_mention para também respeitar is_muted.
CREATE OR REPLACE FUNCTION public.trg_notify_on_chat_mention()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name    TEXT;
  v_thread_title  TEXT;
  v_mention       TEXT;
  v_mentioned_id  UUID;
  v_community_id  UUID;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;
  IF NEW.content IS NULL OR NEW.content NOT LIKE '%@%' THEN
    RETURN NEW;
  END IF;
  SELECT COALESCE(NULLIF(nickname, ''), NULLIF(amino_id, ''), 'Alguém')
    INTO v_actor_name
  FROM public.profiles WHERE id = NEW.author_id;
  SELECT title, community_id INTO v_thread_title, v_community_id
  FROM public.chat_threads WHERE id = NEW.thread_id;
  -- Processar menções @nickname
  FOR v_mention IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_]+)', 'g'))[1]
  LOOP
    SELECT p.id INTO v_mentioned_id
    FROM public.profiles p
    INNER JOIN public.chat_members cm ON cm.user_id = p.id
    WHERE (lower(p.nickname) = lower(v_mention) OR lower(p.amino_id) = lower(v_mention))
      AND cm.thread_id = NEW.thread_id
      AND p.id != NEW.author_id
      AND cm.is_muted = FALSE -- RESPEITAR MUTE
    LIMIT 1;
    IF v_mentioned_id IS NOT NULL THEN
      PERFORM public.upsert_grouped_notification(
        p_user_id        => v_mentioned_id,
        p_actor_id       => NEW.author_id,
        p_type           => 'chat_mention',
        p_title          => COALESCE(v_actor_name, 'Alguém') || ' te mencionou em ' || COALESCE(v_thread_title, 'um chat'),
        p_body           => LEFT(COALESCE(NEW.content, ''), 100),
        p_group_key      => 'chat_mention_' || NEW.thread_id || '_' || v_mentioned_id,
        p_community_id   => v_community_id,
        p_chat_thread_id => NEW.thread_id,
        p_action_url     => '/chat/' || NEW.thread_id
      );
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.toggle_chat_mute(
  p_thread_id UUID,
  p_muted     BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar se o usuário é membro do chat
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id = v_user_id
      AND status = 'active'
  ) THEN
    -- Para DMs e chats sem membership explícita, verificar se é host
    IF NOT EXISTS (
      SELECT 1 FROM public.chat_threads
      WHERE id = p_thread_id
        AND (host_id = v_user_id OR p_thread_id::text = ANY(
          SELECT thread_id::text FROM public.chat_members WHERE user_id = v_user_id
        ))
    ) THEN
      RAISE EXCEPTION 'Você não é membro deste chat';
    END IF;
  END IF;

  -- Atualizar is_muted
  UPDATE public.chat_members
  SET is_muted = p_muted
  WHERE thread_id = p_thread_id
    AND user_id = v_user_id;

  -- Se não existe registro de membro (ex: host sem entrada em chat_members), inserir
  IF NOT FOUND THEN
    INSERT INTO public.chat_members (thread_id, user_id, is_muted, status)
    VALUES (p_thread_id, v_user_id, p_muted, 'active')
    ON CONFLICT (thread_id, user_id) DO UPDATE
      SET is_muted = EXCLUDED.is_muted;
  END IF;

  RETURN jsonb_build_object('is_muted', p_muted);
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_chat_mute TO authenticated;
