-- ============================================================================
-- Migração 010: Correção de recursão infinita nas políticas RLS de chat
-- ============================================================================
-- Problema: As políticas RLS de chat_members, chat_threads e chat_messages
-- causavam recursão infinita porque referenciavam umas às outras em loop.
-- Solução: Usar uma função SECURITY DEFINER para verificar membership sem RLS.
-- ============================================================================

-- 1. Criar função SECURITY DEFINER para verificar membership em chat
CREATE OR REPLACE FUNCTION public.is_chat_member(p_thread_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.chat_members 
        WHERE thread_id = p_thread_id AND user_id = p_user_id
    );
$$;

-- 2. Recriar políticas de chat_members (sem recursão)
DROP POLICY IF EXISTS "chat_members_select" ON public.chat_members;
DROP POLICY IF EXISTS "chat_members_insert" ON public.chat_members;
DROP POLICY IF EXISTS "chat_members_update" ON public.chat_members;
DROP POLICY IF EXISTS "chat_members_delete" ON public.chat_members;

CREATE POLICY "chat_members_select_own" ON public.chat_members
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "chat_members_select_thread" ON public.chat_members
    FOR SELECT USING (public.is_chat_member(thread_id, auth.uid()));

CREATE POLICY "chat_members_insert" ON public.chat_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "chat_members_update" ON public.chat_members
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "chat_members_delete" ON public.chat_members
    FOR DELETE USING (auth.uid() = user_id);

-- 3. Recriar políticas de chat_threads (simplificadas)
DROP POLICY IF EXISTS "chat_threads_select" ON public.chat_threads;
DROP POLICY IF EXISTS "chat_threads_select_member" ON public.chat_threads;
DROP POLICY IF EXISTS "chat_threads_insert" ON public.chat_threads;
DROP POLICY IF EXISTS "chat_threads_insert_auth" ON public.chat_threads;
DROP POLICY IF EXISTS "chat_threads_update" ON public.chat_threads;
DROP POLICY IF EXISTS "chat_threads_update_host" ON public.chat_threads;

CREATE POLICY "chat_threads_select" ON public.chat_threads
    FOR SELECT USING (true);

CREATE POLICY "chat_threads_insert" ON public.chat_threads
    FOR INSERT WITH CHECK (auth.uid() = host_id);

CREATE POLICY "chat_threads_update" ON public.chat_threads
    FOR UPDATE USING (auth.uid() = host_id);

-- 4. Recriar políticas de chat_messages (usando função SECURITY DEFINER)
DROP POLICY IF EXISTS "chat_messages_select" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_select_member" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert_member" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_update" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_update_own" ON public.chat_messages;

CREATE POLICY "chat_messages_select" ON public.chat_messages
    FOR SELECT USING (public.is_chat_member(thread_id, auth.uid()));

CREATE POLICY "chat_messages_insert" ON public.chat_messages
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "chat_messages_update" ON public.chat_messages
    FOR UPDATE USING (auth.uid() = author_id);
