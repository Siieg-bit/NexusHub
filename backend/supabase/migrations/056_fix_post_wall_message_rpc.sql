-- =============================================================================
-- Migration 056 — Corrigir RPC post_wall_message
-- Problema: o RPC usava reference_id e reference_type que não existem na
--           tabela notifications. Também faltava o campo title (NOT NULL).
-- Solução:  recriar o RPC usando comment_id e title corretos.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.post_wall_message(
  p_wall_user_id  UUID,
  p_content       TEXT    DEFAULT NULL,
  p_media_url     TEXT    DEFAULT NULL,
  p_media_type    TEXT    DEFAULT NULL,
  p_sticker_id    TEXT    DEFAULT NULL,
  p_sticker_url   TEXT    DEFAULT NULL,
  p_sticker_name  TEXT    DEFAULT NULL,
  p_pack_id       TEXT    DEFAULT NULL,
  p_emoji         TEXT    DEFAULT NULL,
  p_parent_id     UUID    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_comment_id   UUID;
  v_author_id    UUID := auth.uid();
  v_content      TEXT;
  v_author_nick  TEXT;
BEGIN
  -- Autenticação obrigatória
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Determinar conteúdo textual para armazenar
  v_content := COALESCE(
    NULLIF(TRIM(p_content), ''),
    CASE
      WHEN p_sticker_url IS NOT NULL THEN '[sticker]'
      WHEN p_media_url   IS NOT NULL THEN '[' || COALESCE(p_media_type, 'image') || ']'
      WHEN p_emoji       IS NOT NULL THEN p_emoji
      ELSE ''
    END
  );

  -- Validar que há algum conteúdo
  IF v_content = '' AND p_media_url IS NULL AND p_sticker_url IS NULL AND p_emoji IS NULL THEN
    RAISE EXCEPTION 'Mensagem não pode ser vazia';
  END IF;

  -- Inserir comentário no mural
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
  ) VALUES (
    v_author_id,
    -- profile_wall_id só vai no comentário raiz; replies usam parent_id
    CASE WHEN p_parent_id IS NULL THEN p_wall_user_id ELSE NULL END,
    p_parent_id,
    v_content,
    p_media_url,
    COALESCE(p_media_type, 'image'),
    p_sticker_id,
    p_sticker_url,
    p_sticker_name,
    p_pack_id,
    p_emoji,
    'ok'
  ) RETURNING id INTO v_comment_id;

  -- Registrar uso do sticker nos recentes (se aplicável)
  IF p_sticker_id IS NOT NULL AND p_sticker_url IS NOT NULL THEN
    INSERT INTO public.recently_used_stickers (
      user_id, sticker_id, sticker_url, sticker_name, used_at
    ) VALUES (
      v_author_id,
      p_sticker_id,
      p_sticker_url,
      COALESCE(p_sticker_name, ''),
      NOW()
    )
    ON CONFLICT (user_id, sticker_id)
    DO UPDATE SET used_at = NOW();
  END IF;

  -- Notificar dono do mural (apenas comentários raiz, não replies, e não notificar a si mesmo)
  IF p_wall_user_id IS DISTINCT FROM v_author_id AND p_parent_id IS NULL THEN
    -- Buscar nickname do autor para o título da notificação
    SELECT COALESCE(nickname, 'Alguém')
    INTO v_author_nick
    FROM public.profiles
    WHERE id = v_author_id;

    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      actor_id,
      comment_id
    ) VALUES (
      p_wall_user_id,
      'wall_comment',
      v_author_nick || ' comentou no seu mural',
      CASE
        WHEN p_sticker_url IS NOT NULL THEN 'Enviou uma figurinha'
        WHEN p_media_url   IS NOT NULL THEN 'Enviou uma mídia'
        ELSE LEFT(v_content, 100)
      END,
      v_author_id,
      v_comment_id
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_comment_id;
END;
$$;

-- Garantir permissão de execução para usuários autenticados
GRANT EXECUTE ON FUNCTION public.post_wall_message(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID
) TO authenticated;
