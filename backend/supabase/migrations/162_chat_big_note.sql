-- =============================================================================
-- Migration 162: Big Note — nota de texto livre fixada no topo do chat
-- =============================================================================
-- O OluOlu tem /chat/:threadId/big-note — uma nota editorial fixada no topo
-- do chat, diferente de uma mensagem fixada. É texto livre, editável por
-- admins/hosts, visível para todos os membros como um banner destacado.
-- =============================================================================

-- 1. Adicionar coluna big_note à tabela chat_threads
ALTER TABLE public.chat_threads
  ADD COLUMN IF NOT EXISTS big_note TEXT,
  ADD COLUMN IF NOT EXISTS big_note_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS big_note_updated_by UUID REFERENCES public.profiles(id);

COMMENT ON COLUMN public.chat_threads.big_note IS
  'Nota de texto livre fixada no topo do chat, editável por host/co-hosts. Equivalente ao Big Note do OluOlu.';

-- 2. RPC para salvar/limpar a big_note (apenas host e co-hosts)
CREATE OR REPLACE FUNCTION public.set_chat_big_note(
  p_thread_id UUID,
  p_note      TEXT          -- NULL para remover a nota
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_host_id UUID;
  v_co_hosts JSONB;
BEGIN
  -- Buscar host e co-hosts do thread
  SELECT host_id, co_hosts
  INTO v_host_id, v_co_hosts
  FROM public.chat_threads
  WHERE id = p_thread_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Thread não encontrado';
  END IF;

  -- Verificar se o usuário é host ou co-host
  IF v_user_id != v_host_id
    AND NOT (v_co_hosts ? v_user_id::TEXT)
  THEN
    RAISE EXCEPTION 'Apenas o host ou co-hosts podem editar a Big Note';
  END IF;

  -- Atualizar a nota
  UPDATE public.chat_threads
  SET
    big_note            = NULLIF(TRIM(COALESCE(p_note, '')), ''),
    big_note_updated_at = CASE WHEN p_note IS NOT NULL AND TRIM(p_note) != '' THEN NOW() ELSE NULL END,
    big_note_updated_by = CASE WHEN p_note IS NOT NULL AND TRIM(p_note) != '' THEN v_user_id ELSE NULL END,
    updated_at          = NOW()
  WHERE id = p_thread_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_chat_big_note(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.set_chat_big_note IS
  'Define ou remove a Big Note de um chat. Apenas host e co-hosts podem chamar esta função.';
