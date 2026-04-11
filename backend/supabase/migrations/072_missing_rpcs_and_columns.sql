-- ============================================================================
-- MIGRAÇÃO 072: RPCs faltando e colunas ausentes
-- Corrige:
--   1. Coluna welcome_message em communities
--   2. RPC manage_community_category (criar/editar/excluir categorias)
--   3. RPC assign_post_category (atribuir categoria a um post)
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Coluna welcome_message em communities
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.communities
  ADD COLUMN IF NOT EXISTS welcome_message TEXT DEFAULT '';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RPC manage_community_category
--    Ações: create | update | delete
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.manage_community_category(
  p_community_id  UUID,
  p_action        TEXT,            -- 'create' | 'update' | 'delete'
  p_category_id   UUID    DEFAULT NULL,
  p_name          TEXT    DEFAULT NULL,
  p_description   TEXT    DEFAULT '',
  p_color         TEXT    DEFAULT '#7C4DFF',
  p_icon          TEXT    DEFAULT NULL,
  p_sort_order    INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id   UUID := auth.uid();
  v_role        TEXT;
  v_cat_id      UUID;
BEGIN
  -- Verificar se o chamador é staff da comunidade
  SELECT role INTO v_role
  FROM community_members
  WHERE community_id = p_community_id
    AND user_id = v_caller_id;

  IF v_role NOT IN ('agent', 'leader', 'moderator', 'curator') THEN
    RETURN jsonb_build_object('success', false, 'error', 'permission_denied');
  END IF;

  IF p_action = 'create' THEN
    IF p_name IS NULL OR trim(p_name) = '' THEN
      RETURN jsonb_build_object('success', false, 'error', 'name_required');
    END IF;
    INSERT INTO community_categories (community_id, name, description, color, icon, sort_order)
    VALUES (p_community_id, trim(p_name), COALESCE(trim(p_description), ''), p_color, p_icon, p_sort_order)
    RETURNING id INTO v_cat_id;
    RETURN jsonb_build_object('success', true, 'id', v_cat_id);

  ELSIF p_action = 'update' THEN
    IF p_category_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'category_id_required');
    END IF;
    UPDATE community_categories
    SET
      name        = COALESCE(NULLIF(trim(p_name), ''), name),
      description = COALESCE(p_description, description),
      color       = COALESCE(p_color, color),
      icon        = COALESCE(p_icon, icon),
      sort_order  = COALESCE(p_sort_order, sort_order),
      updated_at  = now()
    WHERE id = p_category_id AND community_id = p_community_id;
    RETURN jsonb_build_object('success', true);

  ELSIF p_action = 'delete' THEN
    IF p_category_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'category_id_required');
    END IF;
    -- Desassociar posts desta categoria antes de excluir
    UPDATE posts SET category_id = NULL WHERE category_id = p_category_id AND community_id = p_community_id;
    DELETE FROM community_categories WHERE id = p_category_id AND community_id = p_community_id;
    RETURN jsonb_build_object('success', true);

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid_action');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_community_category TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RPC assign_post_category
--    Atribui uma categoria a um post e registra no log de moderação
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.assign_post_category(
  p_community_id  UUID,
  p_post_id       UUID,
  p_category_id   UUID    -- NULL para remover categoria
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_role      TEXT;
  v_cat_name  TEXT;
BEGIN
  -- Verificar se o chamador é staff da comunidade
  SELECT role INTO v_role
  FROM community_members
  WHERE community_id = p_community_id
    AND user_id = v_caller_id;

  IF v_role NOT IN ('agent', 'leader', 'moderator', 'curator') THEN
    RETURN jsonb_build_object('success', false, 'error', 'permission_denied');
  END IF;

  -- Verificar se o post pertence à comunidade
  IF NOT EXISTS (
    SELECT 1 FROM posts WHERE id = p_post_id AND community_id = p_community_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_not_found');
  END IF;

  -- Obter nome da categoria (se fornecida)
  IF p_category_id IS NOT NULL THEN
    SELECT name INTO v_cat_name FROM community_categories WHERE id = p_category_id AND community_id = p_community_id;
    IF v_cat_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'category_not_found');
    END IF;
  END IF;

  -- Atualizar o post
  UPDATE posts SET category_id = p_category_id WHERE id = p_post_id;

  -- Registrar no log de moderação
  PERFORM log_moderation_action(
    p_community_id    := p_community_id,
    p_action          := 'assign_category',
    p_target_post_id  := p_post_id,
    p_reason          := CASE
      WHEN p_category_id IS NULL THEN 'Categoria removida'
      ELSE 'Categoria definida: ' || COALESCE(v_cat_name, '')
    END
  );

  RETURN jsonb_build_object('success', true, 'category_name', v_cat_name);
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_post_category TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Garantir que community_categories tem coluna updated_at
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.community_categories
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Trigger para atualizar updated_at automaticamente
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'set_community_categories_updated_at'
  ) THEN
    CREATE TRIGGER set_community_categories_updated_at
      BEFORE UPDATE ON public.community_categories
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END;
$$;
