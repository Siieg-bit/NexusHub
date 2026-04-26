-- Migration 172: Adicionar colunas de contagem de reactions na tabela posts
-- Complementa a migration 163 (post_reactions) adicionando colunas desnormalizadas
-- para love_count, haha_count, wow_count, sad_count, angry_count.
-- O trigger atualiza essas colunas automaticamente quando uma reaction é
-- inserida, atualizada ou deletada.

-- 1. Adicionar colunas se não existirem
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

-- 2. Backfill a partir das reactions existentes
UPDATE public.posts p
SET
  love_count  = COALESCE((SELECT COUNT(*) FROM public.post_reactions WHERE post_id = p.id AND type = 'love'), 0),
  haha_count  = COALESCE((SELECT COUNT(*) FROM public.post_reactions WHERE post_id = p.id AND type = 'haha'), 0),
  wow_count   = COALESCE((SELECT COUNT(*) FROM public.post_reactions WHERE post_id = p.id AND type = 'wow'), 0),
  sad_count   = COALESCE((SELECT COUNT(*) FROM public.post_reactions WHERE post_id = p.id AND type = 'sad'), 0),
  angry_count = COALESCE((SELECT COUNT(*) FROM public.post_reactions WHERE post_id = p.id AND type = 'angry'), 0);

-- 3. Trigger para manter as colunas atualizadas
CREATE OR REPLACE FUNCTION public.update_post_reaction_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post_id UUID;
BEGIN
  -- Determinar o post_id afetado
  IF TG_OP = 'DELETE' THEN
    v_post_id := OLD.post_id;
  ELSE
    v_post_id := NEW.post_id;
  END IF;

  -- Recalcular todas as contagens para o post afetado
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

-- 4. Atualizar a RPC toggle_post_reaction para também atualizar likes_count
-- quando o tipo é 'like' (mantendo compatibilidade com o sistema antigo)
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
  v_user_id     UUID := auth.uid();
  v_existing    TEXT;
  v_action      TEXT;
  v_likes_delta INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Verificar reaction existente do usuário
  SELECT type INTO v_existing
    FROM public.post_reactions
   WHERE post_id = p_post_id AND user_id = v_user_id;

  IF v_existing IS NULL THEN
    -- Adicionar nova reaction
    INSERT INTO public.post_reactions (post_id, user_id, type)
    VALUES (p_post_id, v_user_id, p_type);
    v_action := 'added';
    IF p_type = 'like' THEN v_likes_delta := 1; END IF;
  ELSIF v_existing = p_type THEN
    -- Remover reaction (toggle off)
    DELETE FROM public.post_reactions
     WHERE post_id = p_post_id AND user_id = v_user_id;
    v_action := 'removed';
    IF p_type = 'like' THEN v_likes_delta := -1; END IF;
  ELSE
    -- Trocar tipo de reaction
    UPDATE public.post_reactions
       SET type = p_type
     WHERE post_id = p_post_id AND user_id = v_user_id;
    v_action := 'changed';
    -- Ajustar likes_count se mudou de/para 'like'
    IF v_existing = 'like' THEN v_likes_delta := -1;
    ELSIF p_type = 'like' THEN v_likes_delta := 1;
    END IF;
  END IF;

  -- Atualizar likes_count (compatibilidade)
  IF v_likes_delta != 0 THEN
    UPDATE public.posts
       SET likes_count = GREATEST(likes_count + v_likes_delta, 0)
     WHERE id = p_post_id;
  END IF;

  RETURN jsonb_build_object('action', v_action, 'type', p_type);
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_post_reaction(UUID, TEXT) TO authenticated;

-- 5. Atualizar a RPC de busca de posts para incluir my_reaction_type
-- (adicionada como coluna calculada via get_post_with_context se existir)
-- O _kPostSelect usa SELECT * que já inclui as novas colunas.
-- Para my_reaction_type, o post_provider já faz a busca separada de is_liked.
-- Adicionamos uma função auxiliar para buscar my_reaction_type em lote.
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

-- 6. RPC toggle_reaction_with_reputation
-- Substitui toggle_like_with_reputation para posts, suportando tipos de reaction.
-- Mantém compatibilidade: type='like' equivale ao comportamento anterior.
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

  -- Buscar autor do post
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
    'success', true,
    'action', v_action,
    'type', p_type,
    'liked', v_action != 'removed',
    'likes_count', COALESCE(v_new_likes, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_reaction_with_reputation(UUID, UUID, UUID, TEXT) TO authenticated;
