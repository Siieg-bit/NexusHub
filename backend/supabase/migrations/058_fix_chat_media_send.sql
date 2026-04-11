-- ============================================================================
-- Migration 058: Fix chat media send — resolve overload conflict, adiciona
--                suporte a p_media_type/p_media_duration e corrige cast
--                TEXT→UUID do sticker_id que derrubava TODAS as mensagens.
-- ============================================================================
--
-- PROBLEMAS IDENTIFICADOS E CORRIGIDOS:
--
-- Bug #1 (CRÍTICO): column "sticker_id" is of type uuid but expression is of type text
--   A função recebia p_sticker_id como TEXT mas a coluna chat_messages.sticker_id
--   é UUID. O PostgreSQL NÃO faz cast implícito TEXT→UUID em PL/pgSQL, então o
--   INSERT falhava para TODAS as mensagens (inclusive texto simples).
--   Correção: converter com CASE/EXCEPTION WHEN invalid_text_representation.
--
-- Bug #2: Conflito de overload (PGRST203)
--   Existiam duas versões conflitantes da função com assinaturas diferentes.
--   Correção: remover ambas e recriar uma única versão unificada.
--
-- Bug #3: Função sem p_media_type e p_media_duration
--   A versão anterior (054) não salvava tipo de mídia nem duração do áudio.
--   Correção: adicionar esses parâmetros na nova versão unificada.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- PASSO 1: Remover versões conflitantes anteriores
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.send_chat_message_with_reputation(
  uuid, text, text, text, text, uuid, text, uuid, text, uuid, integer, uuid
);
DROP FUNCTION IF EXISTS public.send_chat_message_with_reputation(
  uuid, text, text, text, uuid, text, text, text, text
);

-- ─────────────────────────────────────────────────────────────────────────────
-- PASSO 2: Recriar a função unificada com cast seguro TEXT→UUID
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_chat_message_with_reputation(
  p_thread_id      UUID,
  p_content        TEXT,
  p_type           TEXT     DEFAULT 'text',
  p_media_url      TEXT     DEFAULT NULL,
  p_media_type     TEXT     DEFAULT NULL,
  p_media_duration INTEGER  DEFAULT NULL,
  p_reply_to       UUID     DEFAULT NULL,
  p_sticker_id     TEXT     DEFAULT NULL,
  p_sticker_url    TEXT     DEFAULT NULL,
  p_sticker_name   TEXT     DEFAULT NULL,
  p_pack_id        TEXT     DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_message_id   UUID;
  v_community_id UUID;
  v_is_member    BOOLEAN;
  v_author_id    UUID := auth.uid();
  v_mapped_type  TEXT;
  v_sticker_uuid UUID;
BEGIN
  -- Validar sessão
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Buscar community_id do chat
  SELECT community_id INTO v_community_id
  FROM public.chat_threads
  WHERE id = p_thread_id;

  -- Verificar se é membro ativo do chat
  SELECT EXISTS(
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id
      AND user_id = v_author_id
      AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this chat';
  END IF;

  -- Bug #1 fix: converter p_sticker_id (TEXT) para UUID com segurança.
  -- Se o valor não for UUID válido (ex: 'emoji_1'), retorna NULL sem falhar.
  BEGIN
    v_sticker_uuid := CASE
      WHEN p_sticker_id IS NULL OR p_sticker_id = '' THEN NULL
      ELSE p_sticker_id::UUID
    END;
  EXCEPTION WHEN invalid_text_representation THEN
    v_sticker_uuid := NULL;
  END;

  -- Mapear tipo para o enum (garantir compatibilidade com todos os tipos)
  v_mapped_type := CASE p_type
    WHEN 'image'               THEN 'image'
    WHEN 'gif'                 THEN 'gif'
    WHEN 'audio'               THEN 'audio'
    WHEN 'video'               THEN 'video'
    WHEN 'sticker'             THEN 'sticker'
    WHEN 'voice_note'          THEN 'voice_note'
    WHEN 'strike'              THEN 'strike'
    WHEN 'share_url'           THEN 'share_url'
    WHEN 'share_user'          THEN 'share_user'
    WHEN 'poll'                THEN 'poll'
    WHEN 'forward'             THEN 'forward'
    WHEN 'file'                THEN 'file'
    WHEN 'system_tip'          THEN 'system_tip'
    WHEN 'system_voice_start'  THEN 'system_voice_start'
    WHEN 'system_voice_end'    THEN 'system_voice_end'
    WHEN 'system_screen_start' THEN 'system_screen_start'
    WHEN 'system_screen_end'   THEN 'system_screen_end'
    WHEN 'system_pin'          THEN 'system_pin'
    WHEN 'system_unpin'        THEN 'system_unpin'
    WHEN 'system_join'         THEN 'system_join'
    WHEN 'system_leave'        THEN 'system_leave'
    WHEN 'system_removed'      THEN 'system_removed'
    WHEN 'system_admin_delete' THEN 'system_admin_delete'
    WHEN 'system_deleted'      THEN 'system_deleted'
    ELSE 'text'
  END;

  -- Inserir mensagem com todos os campos relevantes
  INSERT INTO public.chat_messages (
    thread_id,
    author_id,
    content,
    type,
    media_url,
    media_type,
    media_duration,
    reply_to_id,
    sticker_id,
    sticker_url,
    sticker_name,
    pack_id
  ) VALUES (
    p_thread_id,
    v_author_id,
    COALESCE(p_content, ''),
    v_mapped_type::public.chat_message_type,
    p_media_url,
    p_media_type,
    p_media_duration,
    p_reply_to,
    v_sticker_uuid,    -- UUID convertido com segurança (era TEXT direto antes)
    p_sticker_url,
    p_sticker_name,
    p_pack_id
  ) RETURNING id INTO v_message_id;

  -- Atualizar last_message_at do thread
  UPDATE public.chat_threads
  SET last_message_at = NOW()
  WHERE id = p_thread_id;

  -- Reputação (+1 por mensagem enviada)
  IF v_community_id IS NOT NULL THEN
    BEGIN
      PERFORM public.add_reputation(
        v_author_id,
        v_community_id,
        'chat_message',
        1,
        v_message_id
      );
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Não falhar o envio por causa da reputação
    END;
  END IF;

  -- Registrar uso do sticker nos recentes (se for sticker com UUID válido e URL)
  IF v_sticker_uuid IS NOT NULL AND p_sticker_url IS NOT NULL AND p_sticker_url <> '' THEN
    BEGIN
      INSERT INTO public.recently_used_stickers (
        user_id, sticker_id, sticker_url, sticker_name, used_at
      ) VALUES (
        v_author_id,
        v_sticker_uuid,
        p_sticker_url,
        COALESCE(p_sticker_name, ''),
        NOW()
      )
      ON CONFLICT (user_id, sticker_id)
      DO UPDATE SET used_at = NOW();

      -- Incrementar contador de usos do sticker
      UPDATE public.stickers
      SET uses_count = uses_count + 1
      WHERE id = v_sticker_uuid;
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Não falhar o envio por causa do sticker tracking
    END;
  END IF;

  RETURN v_message_id;
END;
$$;

-- Garantir permissões
GRANT EXECUTE ON FUNCTION public.send_chat_message_with_reputation(
  UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT, TEXT
) TO authenticated;

COMMENT ON FUNCTION public.send_chat_message_with_reputation IS
  'Envia uma mensagem de chat com suporte completo a mídia (image, gif, audio, video, sticker).
   Bug fix 058: corrige cast TEXT→UUID do sticker_id que derrubava TODAS as mensagens.
   Resolve o conflito de overload das migrations 021/032 e 054.
   Parâmetros: p_thread_id, p_content, p_type, p_media_url, p_media_type,
   p_media_duration, p_reply_to, p_sticker_id, p_sticker_url, p_sticker_name, p_pack_id.';
