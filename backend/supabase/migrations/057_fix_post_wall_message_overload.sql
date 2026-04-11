-- ============================================================================
-- Migration 057: Corrigir overload do RPC post_wall_message (PGRST203)
-- 
-- Problema: migrations 055 e 056 criaram duas versões do RPC com assinaturas
-- diferentes mas compatíveis, causando "Multiple Choices" (PGRST203) no PostgREST.
-- Solução: dropar TODAS as versões e recriar apenas uma definitiva.
-- ============================================================================

-- Dropar TODAS as versões existentes do RPC
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, text, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.post_wall_message(uuid, text, text, text, text, text, text, text, text, uuid) CASCADE;

-- Recriar UMA única versão definitiva com todos os parâmetros necessários
CREATE OR REPLACE FUNCTION public.post_wall_message(
  p_wall_user_id  uuid,
  p_content       text    DEFAULT NULL,
  p_media_url     text    DEFAULT NULL,
  p_media_type    text    DEFAULT NULL,
  p_sticker_id    text    DEFAULT NULL,
  p_sticker_url   text    DEFAULT NULL,
  p_sticker_name  text    DEFAULT NULL,
  p_pack_id       text    DEFAULT NULL,
  p_emoji         text    DEFAULT NULL,
  p_parent_id     uuid    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id   uuid := auth.uid();
  v_comment_id  uuid;
  v_author_nick text;
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Validar que há conteúdo
  IF p_content IS NULL AND p_media_url IS NULL AND p_sticker_url IS NULL AND p_emoji IS NULL THEN
    RAISE EXCEPTION 'Comentário vazio';
  END IF;

  -- Buscar nickname do autor
  SELECT nickname INTO v_author_nick FROM public.profiles WHERE id = v_author_id;

  -- Inserir comentário
  INSERT INTO public.comments (
    author_id,
    profile_wall_id,
    parent_id,
    content,
    media_url,
    media_type,
    sticker_id,
    sticker_url,
    sticker_name,
    pack_id,
    emoji_reaction,
    status
  )
  VALUES (
    v_author_id,
    CASE WHEN p_parent_id IS NULL THEN p_wall_user_id ELSE NULL END,
    p_parent_id,
    p_content,
    p_media_url,
    p_media_type,
    p_sticker_id,
    p_sticker_url,
    p_sticker_name,
    p_pack_id,
    p_emoji,
    'ok'
  )
  RETURNING id INTO v_comment_id;

  -- Notificar dono do mural (só para comentários raiz, não para replies)
  IF p_parent_id IS NULL AND v_author_id <> p_wall_user_id THEN
    BEGIN
      INSERT INTO public.notifications (
        user_id,
        type,
        actor_id,
        comment_id,
        title,
        is_read
      )
      VALUES (
        p_wall_user_id,
        'wall_comment',
        v_author_id,
        v_comment_id,
        COALESCE(v_author_nick, 'Alguém') || ' comentou no seu mural',
        false
      );
    EXCEPTION WHEN OTHERS THEN
      -- Não falhar o comentário por causa da notificação
      RAISE WARNING 'Falha ao criar notificação: %', SQLERRM;
    END;
  END IF;

  RETURN v_comment_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.post_wall_message(uuid, text, text, text, text, text, text, text, text, uuid) TO authenticated;
