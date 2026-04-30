-- Migration 169: Chat Requests
-- Quando privilege_chat_invite = 'following', usuários não seguidos precisam
-- enviar uma solicitação de chat que pode ser aceita ou recusada.

-- Tabela de solicitações de chat
CREATE TABLE IF NOT EXISTS public.chat_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message       TEXT,                   -- Mensagem opcional de apresentação
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'declined')),
  thread_id     UUID REFERENCES public.chat_threads(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (sender_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_requests_receiver
  ON public.chat_requests (receiver_id, status);

CREATE INDEX IF NOT EXISTS idx_chat_requests_sender
  ON public.chat_requests (sender_id, status);

-- RLS
ALTER TABLE public.chat_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_requests_select" ON public.chat_requests
  FOR SELECT TO authenticated
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

CREATE POLICY "chat_requests_insert" ON public.chat_requests
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY "chat_requests_update" ON public.chat_requests
  FOR UPDATE TO authenticated
  USING (receiver_id = auth.uid());

-- RPC: enviar solicitação de chat
CREATE OR REPLACE FUNCTION public.send_chat_request(
  p_receiver_id UUID,
  p_message     TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id       UUID := auth.uid();
  v_receiver_priv   public.privacy_level;
  v_is_following    BOOLEAN;
  v_existing_req    UUID;
  v_thread_id       UUID;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;
  IF v_sender_id = p_receiver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_self_request');
  END IF;

  -- Verificar se já existe um DM ativo entre os dois
  SELECT ct.id INTO v_thread_id
  FROM public.chat_threads ct
  JOIN public.chat_members ctm1 ON ctm1.thread_id = ct.id AND ctm1.user_id = v_sender_id
  JOIN public.chat_members ctm2 ON ctm2.thread_id = ct.id AND ctm2.user_id = p_receiver_id
  WHERE ct.type = 'dm'
  LIMIT 1;

  IF v_thread_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'action', 'existing_dm', 'thread_id', v_thread_id);
  END IF;

  -- Verificar privilégio de chat do receptor
  SELECT privilege_chat_invite INTO v_receiver_priv
  FROM public.profiles
  WHERE id = p_receiver_id;

  -- Se 'everyone', criar DM diretamente
  IF v_receiver_priv = 'everyone' OR v_receiver_priv IS NULL THEN
    SELECT public.get_or_create_dm_thread(v_sender_id, p_receiver_id) INTO v_thread_id;
    RETURN jsonb_build_object('success', true, 'action', 'dm_created', 'thread_id', v_thread_id);
  END IF;

  -- Se 'none', bloquear
  IF v_receiver_priv = 'none' THEN
    RETURN jsonb_build_object('success', false, 'error', 'messages_disabled');
  END IF;

  -- Se 'following', verificar se sender segue receiver
  SELECT EXISTS (
    SELECT 1 FROM public.follows
    WHERE follower_id = v_sender_id AND following_id = p_receiver_id
  ) INTO v_is_following;

  IF v_is_following THEN
    SELECT public.get_or_create_dm_thread(v_sender_id, p_receiver_id) INTO v_thread_id;
    RETURN jsonb_build_object('success', true, 'action', 'dm_created', 'thread_id', v_thread_id);
  END IF;

  -- Verificar se já existe solicitação pendente
  SELECT id INTO v_existing_req
  FROM public.chat_requests
  WHERE sender_id = v_sender_id AND receiver_id = p_receiver_id;

  IF v_existing_req IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_already_sent', 'request_id', v_existing_req);
  END IF;

  -- Criar solicitação
  INSERT INTO public.chat_requests (sender_id, receiver_id, message)
  VALUES (v_sender_id, p_receiver_id, p_message)
  RETURNING id INTO v_existing_req;

  -- Notificar o receptor
  INSERT INTO public.notifications (user_id, type, actor_id, title, body, action_url)
  VALUES (
    p_receiver_id,
    'chat_request',
    v_sender_id,
    'Nova solicitação de chat',
    (SELECT nickname FROM public.profiles WHERE id = v_sender_id) || ' quer conversar com você',
    '/chat/requests'
  )
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object('success', true, 'action', 'request_sent', 'request_id', v_existing_req);
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_chat_request(UUID, TEXT) TO authenticated;

-- RPC: responder a uma solicitação de chat
CREATE OR REPLACE FUNCTION public.respond_chat_request(
  p_request_id UUID,
  p_accept     BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_sender_id UUID;
  v_thread_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT sender_id INTO v_sender_id
  FROM public.chat_requests
  WHERE id = p_request_id AND receiver_id = v_user_id AND status = 'pending';

  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF p_accept THEN
    -- Criar DM
    SELECT public.get_or_create_dm_thread(v_sender_id, v_user_id) INTO v_thread_id;
    UPDATE public.chat_requests
    SET status = 'accepted', thread_id = v_thread_id, updated_at = now()
    WHERE id = p_request_id;
    RETURN jsonb_build_object('success', true, 'action', 'accepted', 'thread_id', v_thread_id);
  ELSE
    UPDATE public.chat_requests
    SET status = 'declined', updated_at = now()
    WHERE id = p_request_id;
    RETURN jsonb_build_object('success', true, 'action', 'declined');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.respond_chat_request(UUID, BOOLEAN) TO authenticated;

-- Nota: o sistema de notificações usa TEXT para o campo 'type', não um enum SQL.
-- Portanto, nenhuma alteração de tipo é necessária.
