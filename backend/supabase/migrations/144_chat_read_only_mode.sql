-- Migration 144: Modo Somente Leitura (Read-Only) para chat rooms
-- Permite que o Host trave o envio de mensagens temporariamente.

-- 1. Adicionar coluna is_read_only na tabela chat_threads
ALTER TABLE public.chat_threads
  ADD COLUMN IF NOT EXISTS is_read_only BOOLEAN DEFAULT FALSE;

-- 2. RPC para ativar/desativar o modo somente leitura
-- Apenas o host ou co-hosts podem chamar esta função.
CREATE OR REPLACE FUNCTION public.toggle_chat_read_only(
  p_thread_id UUID,
  p_enabled   BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_thread    RECORD;
BEGIN
  -- Buscar o thread
  SELECT id, host_id, co_hosts, community_id
    INTO v_thread
    FROM public.chat_threads
   WHERE id = p_thread_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'thread_not_found');
  END IF;

  -- Verificar se o caller é host ou co-host
  IF v_caller_id IS DISTINCT FROM v_thread.host_id
     AND NOT (v_thread.co_hosts @> to_jsonb(v_caller_id::text)) THEN
    -- Verificar se é admin da comunidade
    IF v_thread.community_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.community_members
         WHERE community_id = v_thread.community_id
           AND user_id = v_caller_id
           AND role IN ('admin', 'moderator')
      ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
      END IF;
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
    END IF;
  END IF;

  -- Atualizar o modo somente leitura
  UPDATE public.chat_threads
     SET is_read_only = p_enabled,
         updated_at   = NOW()
   WHERE id = p_thread_id;

  -- Registrar ação de moderação
  PERFORM public.log_moderation_action(
    p_actor_id    := v_caller_id,
    p_target_id   := NULL,
    p_action      := CASE WHEN p_enabled THEN 'silence' ELSE 'unsilence' END,
    p_reason      := CASE WHEN p_enabled
                          THEN 'Read-only mode enabled'
                          ELSE 'Read-only mode disabled' END,
    p_community_id := v_thread.community_id,
    p_metadata    := jsonb_build_object('thread_id', p_thread_id)
  );

  RETURN jsonb_build_object(
    'success', true,
    'is_read_only', p_enabled
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_chat_read_only TO authenticated;
