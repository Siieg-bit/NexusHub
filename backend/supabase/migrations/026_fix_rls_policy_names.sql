-- ============================================================================
-- Migração 026: Corrigir políticas RLS de chat com nomes conflitantes
-- ============================================================================
-- Problema: A migração 010 tentou dropar políticas com nomes diferentes dos
-- criados na migração 007, resultando em políticas duplicadas/conflitantes.
--
-- Políticas da 007 que NÃO foram dropadas pela 010:
--   - chat_threads_select_member, chat_threads_insert_auth, chat_threads_update_host
--   - chat_messages_select_member, chat_messages_insert_member, chat_messages_update_own
--
-- Isso causa conflito com as políticas criadas pela 010:
--   - chat_threads_select, chat_threads_insert, chat_threads_update
--   - chat_messages_select, chat_messages_insert, chat_messages_update
--
-- Solução: Dropar as políticas antigas da 007 que ficaram órfãs.
-- ============================================================================

-- 1. Dropar políticas órfãs de chat_threads (da migração 007)
DROP POLICY IF EXISTS "chat_threads_select_member" ON public.chat_threads;
DROP POLICY IF EXISTS "chat_threads_insert_auth" ON public.chat_threads;
DROP POLICY IF EXISTS "chat_threads_update_host" ON public.chat_threads;

-- 2. Dropar políticas órfãs de chat_messages (da migração 007)
DROP POLICY IF EXISTS "chat_messages_select_member" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert_member" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_update_own" ON public.chat_messages;

-- 3. Garantir que as políticas corretas da 010 existem
-- (Recriar de forma idempotente caso não existam)

-- chat_messages
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_messages' AND policyname = 'chat_messages_insert'
  ) THEN
    CREATE POLICY "chat_messages_insert" ON public.chat_messages
      FOR INSERT WITH CHECK (auth.uid() = author_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_messages' AND policyname = 'chat_messages_select'
  ) THEN
    CREATE POLICY "chat_messages_select" ON public.chat_messages
      FOR SELECT USING (public.is_chat_member(thread_id, auth.uid()));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_messages' AND policyname = 'chat_messages_update'
  ) THEN
    CREATE POLICY "chat_messages_update" ON public.chat_messages
      FOR UPDATE USING (auth.uid() = author_id);
  END IF;
END $$;

-- chat_threads
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_threads' AND policyname = 'chat_threads_select'
  ) THEN
    CREATE POLICY "chat_threads_select" ON public.chat_threads
      FOR SELECT USING (true);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_threads' AND policyname = 'chat_threads_insert'
  ) THEN
    CREATE POLICY "chat_threads_insert" ON public.chat_threads
      FOR INSERT WITH CHECK (auth.uid() = host_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_threads' AND policyname = 'chat_threads_update'
  ) THEN
    CREATE POLICY "chat_threads_update" ON public.chat_threads
      FOR UPDATE USING (auth.uid() = host_id);
  END IF;
END $$;
