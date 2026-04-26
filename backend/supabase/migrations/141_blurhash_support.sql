-- Migration 141: BlurHash support para posts e mensagens
-- Adiciona coluna media_blurhash em posts e chat_messages para
-- exibir placeholders visuais instantâneos enquanto a mídia carrega.

-- 1. Coluna em posts
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS media_blurhash TEXT DEFAULT NULL;

-- 2. Coluna em chat_messages
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS media_blurhash TEXT DEFAULT NULL;

-- 3. RPC para atualizar o blurhash de um post (chamado pela Edge Function após upload)
CREATE OR REPLACE FUNCTION public.set_post_blurhash(
  p_post_id UUID,
  p_blurhash TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.posts
  SET media_blurhash = p_blurhash
  WHERE id = p_post_id
    AND author_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_post_blurhash TO authenticated;

-- 4. RPC para atualizar o blurhash de uma mensagem (chamado pela Edge Function após upload)
CREATE OR REPLACE FUNCTION public.set_message_blurhash(
  p_message_id UUID,
  p_blurhash TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chat_messages
  SET media_blurhash = p_blurhash
  WHERE id = p_message_id
    AND author_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_message_blurhash TO authenticated;
