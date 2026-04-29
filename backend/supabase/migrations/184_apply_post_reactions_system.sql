-- =============================================================================
-- Migration 184: Aplica o sistema de post_reactions em produção
--
-- As migrations 165 e 174 nunca foram aplicadas em produção.
-- Esta migration consolida ambas com correções:
--   - Migration 165: tabela post_reactions, view, RPC toggle_post_reaction
--     BUG CORRIGIDO: notificação usava recipient_id (não existe) → user_id
--   - Migration 174: colunas love_count/haha_count/wow_count/sad_count/angry_count
--     em posts, trigger de atualização automática, toggle_reaction_with_reputation
--   - Migração dos likes existentes (post_likes não existe em produção,
--     mas o sistema legado usa likes_count na tabela posts — mantido)
-- =============================================================================

-- ─── 1. Tabela post_reactions ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.post_reactions (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID        NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type       TEXT        NOT NULL DEFAULT 'like'
               CHECK (type IN ('like', 'love', 'haha', 'wow', 'sad', 'angry')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_reactions_post_id ON public.post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_post_reactions_user_id ON public.post_reactions(user_id);

ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'post_reactions'
      AND policyname = 'Anyone can view reactions'
  ) THEN
    CREATE POLICY "Anyone can view reactions"
      ON public.post_reactions FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'post_reactions'
      AND policyname = 'User can manage own reactions'
  ) THEN
    CREATE POLICY "User can manage own reactions"
      ON public.post_reactions FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END$$;

-- ─── 2. View de contagens por tipo ───────────────────────────────────────────
CREATE OR REPLACE VIEW public.post_reaction_counts AS
SELECT
  post_id,
  COUNT(*) FILTER (WHERE type = 'like')  AS like_count,
  COUNT(*) FILTER (WHERE type = 'love')  AS love_count,
  COUNT(*) FILTER (WHERE type = 'haha')  AS haha_count,
  COUNT(*) FILTER (WHERE type = 'wow')   AS wow_count,
  COUNT(*) FILTER (WHERE type = 'sad')   AS sad_count,
  COUNT(*) FILTER (WHERE type = 'angry') AS angry_count,
  COUNT(*)                               AS total_count
FROM public.post_reactions
GROUP BY post_id;

-- ─── 3. Colunas desnormalizadas em posts ─────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'love_count'
  ) THEN
    ALTER TABLE public.posts ADD COLUMN love_count  INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE public.posts ADD COLUMN haha_count  INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE public.posts ADD COLUMN wow_count   INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE public.posts ADD COLUMN sad_count   INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE public.posts ADD COLUMN angry_count INTEGER NOT NULL DEFAULT 0;
  END IF;
END$$;

-- ─── 4. Trigger para manter contagens atualizadas ────────────────────────────
CREATE OR REPLACE FUNCTION public.update_post_reaction_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_post_id := OLD.post_id;
  ELSE
    v_post_id := NEW.post_id;
  END IF;

  UPDATE public.posts
  SET
    love_count  = (SELECT COUNT(*) FROM public.post_reactions WHERE post_id = v_post_id AND type = 'love'),
    haha_count  = (SELECT COUNT(*) FROM public.post_reactions WHERE post_id = v_post_id AND type = 'haha'),
    wow_count   = (SELECT COUNT(*) FROM public.post_reactions WHERE post_id = v_post_id AND type = 'wow'),
    sad_count   = (SELECT COUNT(*) FROM public.post_reactions WHERE post_id = v_post_id AND type = 'sad'),
    angry_count = (SELECT COUNT(*) FROM public.post_reactions WHERE post_id = v_post_id AND type = 'angry')
  WHERE id = v_post_id;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_post_reaction_counts ON public.post_reactions;
CREATE TRIGGER trg_update_post_reaction_counts
  AFTER INSERT OR UPDATE OR DELETE ON public.post_reactions
  FOR EACH ROW EXECUTE FUNCTION public.update_post_reaction_counts();

-- ─── 5. RPC toggle_post_reaction ─────────────────────────────────────────────
-- BUG CORRIGIDO da migration 165:
--   - notifications usa user_id (não recipient_id)
--   - posts usa author_id (não user_id)
--   - Atualiza likes_count para compatibilidade com sistema legado
CREATE OR REPLACE FUNCTION public.toggle_post_reaction(
  p_post_id UUID,
  p_type    TEXT DEFAULT 'like'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_existing   TEXT;
  v_action     TEXT;
  v_new_type   TEXT;
  v_likes_delta INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Verificar reaction existente
  SELECT type INTO v_existing
    FROM public.post_reactions
   WHERE post_id = p_post_id AND user_id = v_user_id;

  IF v_existing IS NULL THEN
    -- Inserir nova reaction
    INSERT INTO public.post_reactions (post_id, user_id, type)
    VALUES (p_post_id, v_user_id, p_type);
    v_action   := 'added';
    v_new_type := p_type;
    IF p_type = 'like' THEN v_likes_delta := 1; END IF;

    -- Notificar autor do post (apenas para 'like' e 'love')
    -- CORRIGIDO: user_id (não recipient_id), author_id (não user_id)
    IF p_type IN ('like', 'love') THEN
      INSERT INTO public.notifications (user_id, actor_id, type, post_id)
      SELECT p.author_id, v_user_id, 'like', p_post_id
        FROM public.posts p
       WHERE p.id = p_post_id
         AND p.author_id <> v_user_id
      ON CONFLICT DO NOTHING;
    END IF;

  ELSIF v_existing = p_type THEN
    -- Remover reaction (toggle off)
    DELETE FROM public.post_reactions
     WHERE post_id = p_post_id AND user_id = v_user_id;
    v_action   := 'removed';
    v_new_type := NULL;
    IF p_type = 'like' THEN v_likes_delta := -1; END IF;

  ELSE
    -- Trocar tipo de reaction
    UPDATE public.post_reactions
       SET type = p_type
     WHERE post_id = p_post_id AND user_id = v_user_id;
    v_action   := 'changed';
    v_new_type := p_type;
    IF v_existing = 'like' THEN v_likes_delta := -1;
    ELSIF p_type = 'like' THEN v_likes_delta := 1;
    END IF;
  END IF;

  -- Atualizar likes_count (compatibilidade com sistema legado)
  IF v_likes_delta != 0 THEN
    UPDATE public.posts
       SET likes_count = GREATEST(likes_count + v_likes_delta, 0)
     WHERE id = p_post_id;
  END IF;

  -- Retornar contagens atualizadas
  RETURN (
    SELECT jsonb_build_object(
      'action',      v_action,
      'type',        v_new_type,
      'like_count',  COUNT(*) FILTER (WHERE type = 'like'),
      'love_count',  COUNT(*) FILTER (WHERE type = 'love'),
      'haha_count',  COUNT(*) FILTER (WHERE type = 'haha'),
      'wow_count',   COUNT(*) FILTER (WHERE type = 'wow'),
      'sad_count',   COUNT(*) FILTER (WHERE type = 'sad'),
      'angry_count', COUNT(*) FILTER (WHERE type = 'angry'),
      'total_count', COUNT(*)
    )
    FROM public.post_reactions
    WHERE post_id = p_post_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_post_reaction(UUID, TEXT) TO authenticated;

-- ─── 6. RPC toggle_reaction_with_reputation ──────────────────────────────────
-- Versão com reputação — usada pelo community_feed_tab.dart
-- CORRIGIDO: author_id (não user_id) na tabela posts
CREATE OR REPLACE FUNCTION public.toggle_reaction_with_reputation(
  p_community_id UUID,
  p_user_id      UUID,
  p_post_id      UUID DEFAULT NULL,
  p_type         TEXT DEFAULT 'like'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_type TEXT;
  v_target_author UUID;
  v_action        TEXT;
  v_likes_delta   INT := 0;
  v_new_likes     INT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;
  IF p_post_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_target');
  END IF;

  -- Buscar autor do post (CORRIGIDO: author_id, não user_id)
  SELECT author_id INTO v_target_author FROM public.posts WHERE id = p_post_id;
  IF v_target_author IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_not_found');
  END IF;

  -- Verificar reaction existente
  SELECT type INTO v_existing_type
    FROM public.post_reactions
   WHERE post_id = p_post_id AND user_id = p_user_id;

  IF v_existing_type IS NULL THEN
    -- Adicionar nova reaction
    INSERT INTO public.post_reactions (post_id, user_id, type)
    VALUES (p_post_id, p_user_id, p_type);
    v_action := 'added';
    IF p_type = 'like' THEN v_likes_delta := 1; END IF;

    -- Reputação ao autor (não ao próprio usuário)
    IF v_target_author != p_user_id AND p_community_id IS NOT NULL THEN
      PERFORM public.add_reputation(
        v_target_author, p_community_id, 'receive_post_like', 2, p_post_id
      );
    END IF;

    -- Notificação (CORRIGIDO: user_id e author_id)
    IF p_type IN ('like', 'love') THEN
      INSERT INTO public.notifications (user_id, actor_id, type, post_id)
      VALUES (v_target_author, p_user_id, 'like', p_post_id)
      ON CONFLICT DO NOTHING;
    END IF;

  ELSIF v_existing_type = p_type THEN
    -- Toggle off (remover)
    DELETE FROM public.post_reactions WHERE post_id = p_post_id AND user_id = p_user_id;
    v_action := 'removed';
    IF p_type = 'like' THEN v_likes_delta := -1; END IF;

  ELSE
    -- Trocar tipo
    UPDATE public.post_reactions SET type = p_type
     WHERE post_id = p_post_id AND user_id = p_user_id;
    v_action := 'changed';
    IF v_existing_type = 'like' THEN v_likes_delta := -1;
    ELSIF p_type = 'like' THEN v_likes_delta := 1;
    END IF;
  END IF;

  -- Atualizar likes_count (compatibilidade)
  IF v_likes_delta != 0 THEN
    UPDATE public.posts
       SET likes_count = GREATEST(likes_count + v_likes_delta, 0)
     WHERE id = p_post_id
     RETURNING likes_count INTO v_new_likes;
  ELSE
    SELECT likes_count INTO v_new_likes FROM public.posts WHERE id = p_post_id;
  END IF;

  RETURN jsonb_build_object(
    'success',     true,
    'action',      v_action,
    'type',        p_type,
    'liked',       v_action != 'removed',
    'likes_count', COALESCE(v_new_likes, 0)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_reaction_with_reputation(UUID, UUID, UUID, TEXT) TO authenticated;

-- ─── 7. RPC get_my_reactions ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_reactions(p_post_ids UUID[])
RETURNS TABLE (post_id UUID, reaction_type TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT post_id, type AS reaction_type
    FROM public.post_reactions
   WHERE user_id = auth.uid()
     AND post_id = ANY(p_post_ids);
$$;
GRANT EXECUTE ON FUNCTION public.get_my_reactions(UUID[]) TO authenticated;

-- ─── 8. Atualizar toggle_post_like para delegar ao novo sistema ───────────────
-- Mantém compatibilidade com o post_provider.dart que ainda chama toggle_post_like
CREATE OR REPLACE FUNCTION public.toggle_post_like(p_post_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_community_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT community_id INTO v_community_id FROM public.posts WHERE id = p_post_id;

  RETURN public.toggle_reaction_with_reputation(
    p_community_id := v_community_id,
    p_user_id      := v_user_id,
    p_post_id      := p_post_id,
    p_type         := 'like'
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_post_like(UUID) TO authenticated;

-- ─── 9. Forçar reload do schema cache ────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
