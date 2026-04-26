-- Migration 161: Big Note no Chat
-- Adiciona campo big_note e big_note_author_id na tabela chat_threads.
-- Apenas hosts e co-hosts podem definir a Big Note.

-- 1. Adicionar colunas na tabela chat_threads
ALTER TABLE public.chat_threads
  ADD COLUMN IF NOT EXISTS big_note TEXT,
  ADD COLUMN IF NOT EXISTS big_note_author_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 2. RPC para definir/limpar a Big Note de um chat
CREATE OR REPLACE FUNCTION public.set_chat_big_note(
  p_thread_id UUID,
  p_big_note  TEXT  -- NULL para limpar
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_host_id  UUID;
  v_co_hosts JSONB;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  SELECT host_id, co_hosts
    INTO v_host_id, v_co_hosts
    FROM public.chat_threads
   WHERE id = p_thread_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'thread_not_found';
  END IF;

  -- Verificar se é host ou co-host
  IF v_actor_id != v_host_id
    AND NOT (v_co_hosts @> to_jsonb(v_actor_id::text))
  THEN
    -- Verificar se é líder/moderador da comunidade associada
    IF NOT EXISTS (
      SELECT 1 FROM public.community_members cm
        JOIN public.chat_threads ct ON ct.community_id = cm.community_id
       WHERE ct.id = p_thread_id
         AND cm.user_id = v_actor_id
         AND cm.role IN ('leader', 'co_leader', 'moderator')
    ) THEN
      RAISE EXCEPTION 'insufficient_permissions';
    END IF;
  END IF;

  UPDATE public.chat_threads
     SET big_note           = p_big_note,
         big_note_author_id = CASE WHEN p_big_note IS NULL THEN NULL ELSE v_actor_id END,
         updated_at         = NOW()
   WHERE id = p_thread_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_chat_big_note(UUID, TEXT) TO authenticated;
