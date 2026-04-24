-- =============================================================================
-- Migration 131: RPCs corretos para comentários de wiki (sticker/mídia) e
--                remoção de story com log de moderação
-- =============================================================================
-- Elimina gambiarras de inserts diretos no frontend, centralizando toda a
-- lógica de negócio (validação de membro, reputação, log de moderação,
-- registro de sticker) em funções SECURITY DEFINER no banco.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Estender o enum moderation_action com valores de wiki e story
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'hide_wiki'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'hide_wiki';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'unhide_wiki'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'unhide_wiki';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'canonize_wiki'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'canonize_wiki';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'decanonize_wiki'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'decanonize_wiki';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'delete_story'
                 AND enumtypid = 'public.moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE 'delete_story';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Estender moderation_logs com target_story_id
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'moderation_logs' AND column_name = 'target_story_id'
  ) THEN
    ALTER TABLE public.moderation_logs
      ADD COLUMN target_story_id UUID REFERENCES public.stories(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Atualizar log_moderation_action para aceitar target_story_id
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.log_moderation_action(
  p_community_id       UUID,
  p_action             TEXT,
  p_target_user_id     UUID  DEFAULT NULL,
  p_target_post_id     UUID  DEFAULT NULL,
  p_target_wiki_id     UUID  DEFAULT NULL,
  p_target_comment_id  UUID  DEFAULT NULL,
  p_target_story_id    UUID  DEFAULT NULL,
  p_reason             TEXT  DEFAULT NULL,
  p_duration_hours     INT   DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_log_id  UUID;
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;
  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action,
    target_user_id, target_post_id, target_wiki_id,
    target_comment_id, target_story_id,
    reason, duration_hours
  ) VALUES (
    p_community_id, v_user_id, p_action::public.moderation_action,
    p_target_user_id, p_target_post_id, p_target_wiki_id,
    p_target_comment_id, p_target_story_id,
    p_reason, p_duration_hours
  ) RETURNING id INTO v_log_id;
  RETURN v_log_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_moderation_action TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. RPC: send_wiki_comment_with_sticker
--    Equivalente ao send_comment_with_sticker mas para wiki_id.
--    Valida autenticação, insere o comentário com todos os campos de sticker,
--    registra uso recente e incrementa uses_count — igual ao padrão de posts.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_wiki_comment_with_sticker(
  p_wiki_id      UUID,
  p_content      TEXT    DEFAULT '',
  p_parent_id    UUID    DEFAULT NULL,
  p_sticker_id   TEXT    DEFAULT NULL,
  p_sticker_url  TEXT    DEFAULT NULL,
  p_sticker_name TEXT    DEFAULT NULL,
  p_pack_id      TEXT    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_comment_id UUID;
  v_author_id  UUID := auth.uid();
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar que a wiki existe e está ativa
  IF NOT EXISTS (
    SELECT 1 FROM public.wiki_entries
    WHERE id = p_wiki_id AND status = 'ok'
  ) THEN
    RAISE EXCEPTION 'Wiki não encontrada ou indisponível';
  END IF;

  INSERT INTO public.comments (
    wiki_id, author_id, content, parent_id,
    sticker_id, sticker_url, sticker_name, pack_id
  ) VALUES (
    p_wiki_id, v_author_id,
    COALESCE(p_content, '[sticker]'),
    p_parent_id,
    p_sticker_id, p_sticker_url, p_sticker_name, p_pack_id
  ) RETURNING id INTO v_comment_id;

  -- Registrar uso do sticker nos recentes e incrementar contador
  IF p_sticker_id IS NOT NULL AND p_sticker_url IS NOT NULL THEN
    INSERT INTO public.recently_used_stickers (
      user_id, sticker_id, sticker_url, sticker_name, used_at
    ) VALUES (
      v_author_id, p_sticker_id, p_sticker_url,
      COALESCE(p_sticker_name, ''), NOW()
    )
    ON CONFLICT (user_id, sticker_id)
    DO UPDATE SET used_at = NOW();

    UPDATE public.stickers
    SET uses_count = uses_count + 1
    WHERE id = p_sticker_id::UUID;
  END IF;

  RETURN v_comment_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_wiki_comment_with_sticker TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RPC: send_wiki_media_comment
--    Insere um comentário com imagem ou vídeo em uma wiki.
--    Valida autenticação e existência da wiki antes de inserir.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_wiki_media_comment(
  p_wiki_id    UUID,
  p_media_url  TEXT,
  p_media_type TEXT    DEFAULT 'image',
  p_content    TEXT    DEFAULT NULL,
  p_parent_id  UUID    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_comment_id UUID;
  v_author_id  UUID := auth.uid();
BEGIN
  IF v_author_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_media_url IS NULL OR p_media_url = '' THEN
    RAISE EXCEPTION 'URL de mídia inválida';
  END IF;

  IF p_media_type NOT IN ('image', 'video') THEN
    RAISE EXCEPTION 'Tipo de mídia inválido: use image ou video';
  END IF;

  -- Verificar que a wiki existe e está ativa
  IF NOT EXISTS (
    SELECT 1 FROM public.wiki_entries
    WHERE id = p_wiki_id AND status = 'ok'
  ) THEN
    RAISE EXCEPTION 'Wiki não encontrada ou indisponível';
  END IF;

  INSERT INTO public.comments (
    wiki_id, author_id, content, media_url, media_type, parent_id
  ) VALUES (
    p_wiki_id, v_author_id,
    COALESCE(
      NULLIF(TRIM(p_content), ''),
      CASE p_media_type WHEN 'video' THEN '[video]' ELSE '[image]' END
    ),
    p_media_url, p_media_type, p_parent_id
  ) RETURNING id INTO v_comment_id;

  RETURN v_comment_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_wiki_media_comment TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RPC: delete_story
--    Remove (desativa) um story. Apenas o autor ou moderadores da comunidade
--    podem executar. Registra log de moderação quando feito por staff.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_story(
  p_story_id   UUID,
  p_reason     TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id     UUID := auth.uid();
  v_author_id   UUID;
  v_community_id UUID;
  v_is_author   BOOLEAN;
  v_is_mod      BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Buscar dados do story
  SELECT author_id, community_id
  INTO v_author_id, v_community_id
  FROM public.stories
  WHERE id = p_story_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Story não encontrado ou já removido';
  END IF;

  v_is_author := (v_user_id = v_author_id);
  v_is_mod    := public.is_community_moderator(v_community_id)
                 OR public.is_team_member();

  IF NOT (v_is_author OR v_is_mod) THEN
    RAISE EXCEPTION 'Sem permissão para remover este story';
  END IF;

  -- Desativar o story
  UPDATE public.stories
  SET is_active = FALSE
  WHERE id = p_story_id;

  -- Registrar log de moderação quando feito por staff (não pelo próprio autor)
  IF v_is_mod AND NOT v_is_author THEN
    PERFORM public.log_moderation_action(
      p_community_id   => v_community_id,
      p_action         => 'delete_story',
      p_target_story_id => p_story_id,
      p_target_user_id  => v_author_id,
      p_reason          => COALESCE(p_reason, 'Story removido por moderação')
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_story TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Política RLS UPDATE em stories para moderadores
--    (a política atual só permite o autor; moderadores precisam de UPDATE
--     para que o SECURITY DEFINER do delete_story funcione via is_active)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  DROP POLICY IF EXISTS stories_update_author ON public.stories;
  DROP POLICY IF EXISTS stories_update_mod    ON public.stories;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Autor pode atualizar seus próprios stories
CREATE POLICY stories_update_author ON public.stories
  FOR UPDATE
  USING (auth.uid() = author_id);

-- Moderadores e admins podem atualizar qualquer story da comunidade
CREATE POLICY stories_update_mod ON public.stories
  FOR UPDATE
  USING (
    public.is_community_moderator(community_id)
    OR public.is_team_member()
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. RPC: hide_wiki_entry
--    Oculta ou desoculta uma wiki entry. Apenas moderadores/admins.
--    Atualiza o status e registra log de moderação atomicamente.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hide_wiki_entry(
  p_wiki_id UUID,
  p_hide    BOOLEAN DEFAULT TRUE,
  p_reason  TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_community_id UUID;
  v_new_status   TEXT := CASE WHEN p_hide THEN 'disabled' ELSE 'ok' END;
  v_action       TEXT := CASE WHEN p_hide THEN 'hide_wiki' ELSE 'unhide_wiki' END;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT community_id INTO v_community_id
  FROM public.wiki_entries WHERE id = p_wiki_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wiki não encontrada';
  END IF;

  IF NOT (public.is_community_moderator(v_community_id) OR public.is_team_member()) THEN
    RAISE EXCEPTION 'Sem permissão para moderar esta wiki';
  END IF;

  -- Atualizar status
  UPDATE public.wiki_entries
  SET status = v_new_status
  WHERE id = p_wiki_id;

  -- Registrar log de moderação
  IF v_community_id IS NOT NULL THEN
    PERFORM public.log_moderation_action(
      p_community_id   => v_community_id,
      p_action         => v_action,
      p_target_wiki_id => p_wiki_id,
      p_reason         => COALESCE(p_reason,
        CASE WHEN p_hide THEN 'Wiki ocultada por moderação'
             ELSE 'Wiki tornada visível por moderação' END)
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.hide_wiki_entry TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. RPC: toggle_wiki_canonical
--    Canoniza ou descanoniza uma wiki entry. Apenas moderadores/admins.
--    Atualiza is_canonical e registra log de moderação atomicamente.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_wiki_canonical(
  p_wiki_id    UUID,
  p_canonical  BOOLEAN DEFAULT TRUE,
  p_reason     TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_community_id UUID;
  v_action       TEXT := CASE WHEN p_canonical THEN 'canonize_wiki' ELSE 'decanonize_wiki' END;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT community_id INTO v_community_id
  FROM public.wiki_entries WHERE id = p_wiki_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wiki não encontrada';
  END IF;

  IF NOT (public.is_community_moderator(v_community_id) OR public.is_team_member()) THEN
    RAISE EXCEPTION 'Sem permissão para canonizar esta wiki';
  END IF;

  -- Atualizar flag canonical
  UPDATE public.wiki_entries
  SET is_canonical = p_canonical
  WHERE id = p_wiki_id;

  -- Registrar log de moderação
  IF v_community_id IS NOT NULL THEN
    PERFORM public.log_moderation_action(
      p_community_id   => v_community_id,
      p_action         => v_action,
      p_target_wiki_id => p_wiki_id,
      p_reason         => COALESCE(p_reason,
        CASE WHEN p_canonical THEN 'Wiki canonizada'
             ELSE 'Canonização removida' END)
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_wiki_canonical TO authenticated;
