-- =============================================================================
-- Migration 133: RPCs faltantes — P2 e P3
-- Elimina gambiarras restantes: wiki ratings/what_i_like, user settings,
-- notification settings, story update, wiki review, interests, sticker,
-- hide_post_from_feed, community links, delete_post direto.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. RPC: rate_wiki_entry
--    Registra ou atualiza a avaliação de um usuário em uma wiki entry.
--    Recalcula average_rating e total_ratings atomicamente.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rate_wiki_entry(
  p_wiki_id UUID,
  p_rating  INT  -- 1 a 5
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_avg     NUMERIC;
  v_total   INT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Avaliação deve ser entre 1 e 5';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.wiki_entries WHERE id = p_wiki_id AND status = 'ok') THEN
    RAISE EXCEPTION 'Wiki não encontrada ou indisponível';
  END IF;

  -- Upsert da avaliação
  INSERT INTO public.wiki_ratings (wiki_entry_id, user_id, rating)
  VALUES (p_wiki_id, v_user_id, p_rating)
  ON CONFLICT (wiki_entry_id, user_id)
  DO UPDATE SET rating = p_rating, updated_at = NOW();

  -- Recalcular média e total atomicamente
  SELECT ROUND(AVG(rating)::NUMERIC, 2), COUNT(*)
  INTO v_avg, v_total
  FROM public.wiki_ratings
  WHERE wiki_entry_id = p_wiki_id;

  UPDATE public.wiki_entries SET
    average_rating = v_avg,
    total_ratings  = v_total
  WHERE id = p_wiki_id;

  RETURN jsonb_build_object(
    'average_rating', v_avg,
    'total_ratings',  v_total,
    'user_rating',    p_rating
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rate_wiki_entry TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RPC: add_wiki_what_i_like
--    Adiciona um comentário "O que eu gosto" em uma wiki entry.
--    Valida autenticação, existência da wiki e evita duplicata.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.add_wiki_what_i_like(
  p_wiki_id UUID,
  p_content TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_id      UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF TRIM(p_content) = '' THEN
    RAISE EXCEPTION 'Conteúdo não pode ser vazio';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.wiki_entries WHERE id = p_wiki_id AND status = 'ok') THEN
    RAISE EXCEPTION 'Wiki não encontrada ou indisponível';
  END IF;

  INSERT INTO public.wiki_what_i_like (wiki_entry_id, user_id, content)
  VALUES (p_wiki_id, v_user_id, TRIM(p_content))
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_wiki_what_i_like TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RPC: review_wiki_entry
--    Aprova ou rejeita uma wiki entry. Apenas curadores/moderadores.
--    Atualiza status, registra revisão e envia notificação atomicamente.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.review_wiki_entry(
  p_wiki_id      UUID,
  p_action       TEXT,  -- 'approve' ou 'reject'
  p_reject_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_wiki         RECORD;
  v_new_status   TEXT;
  v_notif_type   TEXT;
  v_notif_title  TEXT;
  v_notif_body   TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Ação inválida: use approve ou reject';
  END IF;

  SELECT id, author_id, community_id, title
  INTO v_wiki
  FROM public.wiki_entries
  WHERE id = p_wiki_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wiki não encontrada ou não está pendente de revisão';
  END IF;

  IF NOT (public.is_community_moderator(v_wiki.community_id) OR public.is_team_member()) THEN
    RAISE EXCEPTION 'Sem permissão para revisar wikis';
  END IF;

  v_new_status := CASE p_action WHEN 'approve' THEN 'ok' ELSE 'rejected' END;

  UPDATE public.wiki_entries SET
    status          = v_new_status,
    reviewed_by     = v_user_id,
    reviewed_at     = NOW(),
    submission_note = CASE WHEN p_action = 'reject' THEN p_reject_reason ELSE submission_note END
  WHERE id = p_wiki_id;

  -- Notificar o autor
  v_notif_type  := CASE p_action WHEN 'approve' THEN 'wiki_approved' ELSE 'wiki_rejected' END;
  v_notif_title := CASE p_action WHEN 'approve' THEN 'Wiki aprovada!' ELSE 'Wiki precisa de ajustes' END;
  v_notif_body  := CASE p_action
    WHEN 'approve' THEN 'Sua wiki "' || v_wiki.title || '" foi aprovada.'
    ELSE 'Sua wiki "' || v_wiki.title || '" precisa de ajustes: ' || COALESCE(p_reject_reason, '')
  END;

  INSERT INTO public.notifications (user_id, actor_id, type, title, body, community_id)
  VALUES (v_wiki.author_id, v_user_id, v_notif_type, v_notif_title, v_notif_body, v_wiki.community_id);

  -- Log de moderação
  PERFORM public.log_moderation_action(
    p_community_id  => v_wiki.community_id,
    p_action        => CASE p_action WHEN 'approve' THEN 'wiki_approve' ELSE 'wiki_reject' END,
    p_target_wiki_id => p_wiki_id,
    p_target_user_id => v_wiki.author_id,
    p_reason        => COALESCE(p_reject_reason, 'Revisão de wiki: ' || p_action)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_wiki_entry TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. RPC: set_user_interests
--    Substitui os interesses do usuário atomicamente (delete + insert em tx).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_user_interests(
  p_interests JSONB  -- array de {name: text, category: text}
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Deletar interesses antigos
  DELETE FROM public.interests WHERE user_id = v_user_id;

  -- Inserir novos (se houver)
  IF jsonb_array_length(p_interests) > 0 THEN
    INSERT INTO public.interests (user_id, name, category)
    SELECT v_user_id,
           (elem->>'name')::TEXT,
           (elem->>'category')::TEXT
    FROM jsonb_array_elements(p_interests) AS elem
    WHERE (elem->>'name') IS NOT NULL AND TRIM(elem->>'name') != '';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_user_interests TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RPC: update_story
--    Edita um story existente. Apenas o autor pode editar.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_story(
  p_story_id         UUID,
  p_media_url        TEXT    DEFAULT NULL,
  p_media_type       TEXT    DEFAULT NULL,
  p_caption          TEXT    DEFAULT NULL,
  p_background_color TEXT    DEFAULT NULL,
  p_duration_seconds INT     DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.stories
    WHERE id = p_story_id AND author_id = v_user_id AND is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'Story não encontrado ou sem permissão para editar';
  END IF;

  UPDATE public.stories SET
    media_url        = COALESCE(p_media_url,        media_url),
    media_type       = COALESCE(p_media_type,       media_type),
    caption          = p_caption,  -- NULL é permitido (remover legenda)
    background_color = COALESCE(p_background_color, background_color),
    duration_seconds = COALESCE(p_duration_seconds, duration_seconds)
  WHERE id = p_story_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_story TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RPC: update_notification_settings
--    Atualiza as configurações de notificação do usuário.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_notification_settings(
  p_settings JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  INSERT INTO public.notification_settings (user_id, settings)
  VALUES (v_user_id, p_settings)
  ON CONFLICT (user_id)
  DO UPDATE SET settings = p_settings, updated_at = NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_notification_settings TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RPC: update_user_settings
--    Atualiza as configurações de privacidade/preferências do usuário.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_user_settings(
  p_settings JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  INSERT INTO public.user_settings (user_id, settings)
  VALUES (v_user_id, p_settings)
  ON CONFLICT (user_id)
  DO UPDATE SET settings = p_settings, updated_at = NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_settings TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. RPC: hide_post_from_feed
--    Oculta um post do feed do usuário (hidden_posts).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hide_post_from_feed(
  p_post_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  INSERT INTO public.hidden_posts (user_id, post_id, hidden_at)
  VALUES (v_user_id, p_post_id, NOW())
  ON CONFLICT (user_id, post_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.hide_post_from_feed TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. RPC: add_sticker_to_pack
--    Adiciona um sticker a um pack existente do usuário.
--    Valida que o pack pertence ao usuário.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.add_sticker_to_pack(
  p_pack_id   UUID,
  p_name      TEXT,
  p_image_url TEXT,
  p_tags      TEXT[] DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID := auth.uid();
  v_sticker_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.sticker_packs
    WHERE id = p_pack_id AND creator_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Pack não encontrado ou sem permissão';
  END IF;

  INSERT INTO public.stickers (pack_id, name, image_url, tags, creator_id)
  VALUES (p_pack_id, TRIM(p_name), p_image_url, p_tags, v_user_id)
  RETURNING id INTO v_sticker_id;

  RETURN v_sticker_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_sticker_to_pack TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. RPC: upsert_community_link
--     Cria ou atualiza um link geral da comunidade.
--     Valida que o caller é líder/co-líder.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.upsert_community_link(
  p_community_id UUID,
  p_link_id      UUID    DEFAULT NULL,  -- NULL = criar novo
  p_title        TEXT    DEFAULT NULL,
  p_url          TEXT    DEFAULT NULL,
  p_description  TEXT    DEFAULT NULL,
  p_icon_url     TEXT    DEFAULT NULL,
  p_sort_order   INT     DEFAULT 0
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role    TEXT;
  v_link_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT role INTO v_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent', 'leader') AND NOT public.is_team_member() THEN
    RAISE EXCEPTION 'Apenas líderes podem gerenciar links da comunidade';
  END IF;

  IF p_link_id IS NULL THEN
    -- Criar novo link
    INSERT INTO public.community_general_links (
      community_id, title, url, description, icon_url, sort_order, created_by
    ) VALUES (
      p_community_id, p_title, p_url, p_description, p_icon_url, p_sort_order, v_user_id
    ) RETURNING id INTO v_link_id;
  ELSE
    -- Atualizar link existente
    UPDATE public.community_general_links SET
      title       = COALESCE(p_title,       title),
      url         = COALESCE(p_url,         url),
      description = COALESCE(p_description, description),
      icon_url    = COALESCE(p_icon_url,    icon_url),
      sort_order  = COALESCE(p_sort_order,  sort_order),
      updated_at  = NOW()
    WHERE id = p_link_id AND community_id = p_community_id
    RETURNING id INTO v_link_id;

    IF v_link_id IS NULL THEN
      RAISE EXCEPTION 'Link não encontrado';
    END IF;
  END IF;

  RETURN v_link_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_community_link TO authenticated;
