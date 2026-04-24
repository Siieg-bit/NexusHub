-- =============================================================================
-- Migration 130: Suporte a denúncia de stories
-- Adiciona target_story_id na tabela flags e atualiza o RPC submit_flag
-- =============================================================================

-- 1. Adicionar coluna target_story_id na tabela flags
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'flags' AND column_name = 'target_story_id'
  ) THEN
    ALTER TABLE public.flags
      ADD COLUMN target_story_id UUID REFERENCES public.stories(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_flags_story ON public.flags(target_story_id)
  WHERE target_story_id IS NOT NULL;

-- 2. Atualizar o RPC submit_flag para aceitar p_target_story_id
CREATE OR REPLACE FUNCTION public.submit_flag(
  p_community_id           UUID,
  p_flag_type              TEXT,
  p_reason                 TEXT    DEFAULT NULL,
  p_target_post_id         UUID    DEFAULT NULL,
  p_target_comment_id      UUID    DEFAULT NULL,
  p_target_chat_message_id UUID    DEFAULT NULL,
  p_target_user_id         UUID    DEFAULT NULL,
  p_target_wiki_id         UUID    DEFAULT NULL,
  p_target_story_id        UUID    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_flag_id     UUID;
  v_snapshot_id UUID;
  v_user_id     UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar duplicata pendente por tipo de alvo
  IF p_target_post_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_post_id = p_target_post_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou este conteúdo';
    END IF;
  END IF;

  IF p_target_comment_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_comment_id = p_target_comment_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou este comentário';
    END IF;
  END IF;

  IF p_target_story_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_story_id = p_target_story_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou este story';
    END IF;
  END IF;

  -- Inserir a flag
  INSERT INTO public.flags (
    community_id, reporter_id, flag_type, reason, status,
    target_post_id, target_comment_id, target_chat_message_id,
    target_user_id, target_wiki_id, target_story_id
  ) VALUES (
    p_community_id, v_user_id, p_flag_type, p_reason, 'pending',
    p_target_post_id, p_target_comment_id, p_target_chat_message_id,
    p_target_user_id, p_target_wiki_id, p_target_story_id
  ) RETURNING id INTO v_flag_id;

  -- Capturar snapshot do conteúdo imediatamente (apenas para tipos suportados)
  IF p_target_post_id IS NOT NULL THEN
    v_snapshot_id := public._capture_post_snapshot(v_flag_id, p_target_post_id, v_user_id);
  ELSIF p_target_comment_id IS NOT NULL THEN
    v_snapshot_id := public._capture_comment_snapshot(v_flag_id, p_target_comment_id, v_user_id);
  ELSIF p_target_chat_message_id IS NOT NULL THEN
    v_snapshot_id := public._capture_chat_snapshot(v_flag_id, p_target_chat_message_id, v_user_id);
  END IF;

  -- Marcar flag como snapshot capturado
  IF v_snapshot_id IS NOT NULL THEN
    UPDATE public.flags SET snapshot_captured = TRUE WHERE id = v_flag_id;
  END IF;

  RETURN jsonb_build_object(
    'flag_id',     v_flag_id,
    'snapshot_id', v_snapshot_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_flag TO authenticated;
