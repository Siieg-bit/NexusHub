-- Migration 112: Persistência de votos para enquetes em mensagens de chat
--
-- Objetivo:
-- 1. Permitir que enquetes enviadas no chat (type = 'poll') sejam votáveis.
-- 2. Garantir 1 voto por usuário em cada mensagem-enquete.
-- 3. Permitir leitura pública dos votos para renderização em tempo real no app.

CREATE TABLE IF NOT EXISTS public.chat_poll_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  option_index INTEGER NOT NULL CHECK (option_index >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_poll_votes_message_id
  ON public.chat_poll_votes(message_id);

CREATE INDEX IF NOT EXISTS idx_chat_poll_votes_message_option
  ON public.chat_poll_votes(message_id, option_index);

ALTER TABLE public.chat_poll_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_poll_votes_select_all" ON public.chat_poll_votes;
CREATE POLICY "chat_poll_votes_select_all"
  ON public.chat_poll_votes
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "chat_poll_votes_insert_own" ON public.chat_poll_votes;
CREATE POLICY "chat_poll_votes_insert_own"
  ON public.chat_poll_votes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);
