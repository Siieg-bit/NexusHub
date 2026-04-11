-- ============================================================================
-- Migração 071: Tabela de Categorias de Comunidade
-- ============================================================================
-- Cria a tabela community_categories para organizar posts por categorias
-- dentro de uma comunidade, e adiciona category_id em posts.
-- ============================================================================

-- ── 1. Tabela community_categories ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.community_categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    description TEXT DEFAULT '',
    color       TEXT DEFAULT '#7C4DFF',
    icon        TEXT DEFAULT 'label',
    sort_order  INTEGER DEFAULT 0,
    created_by  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(community_id, name)
);

ALTER TABLE public.community_categories ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_community_categories_community
    ON public.community_categories(community_id);

-- ── 2. Políticas RLS ────────────────────────────────────────────────────────

-- Membros podem ver as categorias da comunidade
CREATE POLICY community_categories_select
    ON public.community_categories
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.community_members cm
            WHERE cm.community_id = community_categories.community_id
            AND cm.user_id = auth.uid()
            AND cm.is_banned = FALSE
        )
    );

-- Apenas staff (agent, leader, curator) pode gerenciar categorias
CREATE POLICY community_categories_manage
    ON public.community_categories
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.community_members cm
            WHERE cm.community_id = community_categories.community_id
            AND cm.user_id = auth.uid()
            AND cm.role IN ('agent', 'leader', 'curator')
            AND cm.is_banned = FALSE
        )
    );

-- ── 3. Coluna category_id em posts ──────────────────────────────────────────
ALTER TABLE public.posts
    ADD COLUMN IF NOT EXISTS category_id UUID
        REFERENCES public.community_categories(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_posts_category
    ON public.posts(category_id) WHERE category_id IS NOT NULL;

-- ── 4. RPC: manage_community_category ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.manage_community_category(
    p_community_id  UUID,
    p_action        TEXT,   -- 'create' | 'update' | 'delete'
    p_category_id   UUID    DEFAULT NULL,
    p_name          TEXT    DEFAULT NULL,
    p_description   TEXT    DEFAULT '',
    p_color         TEXT    DEFAULT '#7C4DFF',
    p_icon          TEXT    DEFAULT 'label',
    p_sort_order    INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role    TEXT;
    v_cat_id  UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('error', 'not_authenticated');
    END IF;

    -- Verificar se o usuário é staff da comunidade
    SELECT role INTO v_role
    FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = FALSE;

    IF v_role NOT IN ('agent', 'leader', 'curator') THEN
        RETURN jsonb_build_object('error', 'insufficient_permissions');
    END IF;

    CASE p_action
        WHEN 'create' THEN
            IF p_name IS NULL OR trim(p_name) = '' THEN
                RETURN jsonb_build_object('error', 'name_required');
            END IF;
            INSERT INTO public.community_categories
                (community_id, name, description, color, icon, sort_order, created_by)
            VALUES
                (p_community_id, trim(p_name), p_description, p_color, p_icon, p_sort_order, v_user_id)
            RETURNING id INTO v_cat_id;
            RETURN jsonb_build_object('success', true, 'category_id', v_cat_id);

        WHEN 'update' THEN
            IF p_category_id IS NULL THEN
                RETURN jsonb_build_object('error', 'category_id_required');
            END IF;
            UPDATE public.community_categories
            SET
                name        = COALESCE(NULLIF(trim(p_name), ''), name),
                description = COALESCE(p_description, description),
                color       = COALESCE(p_color, color),
                icon        = COALESCE(p_icon, icon),
                sort_order  = COALESCE(p_sort_order, sort_order)
            WHERE id = p_category_id
              AND community_id = p_community_id;
            RETURN jsonb_build_object('success', true);

        WHEN 'delete' THEN
            IF p_category_id IS NULL THEN
                RETURN jsonb_build_object('error', 'category_id_required');
            END IF;
            -- Remove a categoria (posts ficam sem categoria via ON DELETE SET NULL)
            DELETE FROM public.community_categories
            WHERE id = p_category_id
              AND community_id = p_community_id;
            RETURN jsonb_build_object('success', true);

        ELSE
            RETURN jsonb_build_object('error', 'invalid_action');
    END CASE;
END;
$$;

-- ── 5. RPC: assign_post_category ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.assign_post_category(
    p_community_id UUID,
    p_post_id      UUID,
    p_category_id  UUID  -- NULL para remover categoria
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role    TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('error', 'not_authenticated');
    END IF;

    SELECT role INTO v_role
    FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND is_banned = FALSE;

    IF v_role NOT IN ('agent', 'leader', 'curator', 'moderator') THEN
        RETURN jsonb_build_object('error', 'insufficient_permissions');
    END IF;

    -- Verificar se a categoria pertence à comunidade (quando não é NULL)
    IF p_category_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.community_categories
            WHERE id = p_category_id AND community_id = p_community_id
        ) THEN
            RETURN jsonb_build_object('error', 'category_not_found');
        END IF;
    END IF;

    UPDATE public.posts
    SET category_id = p_category_id
    WHERE id = p_post_id
      AND community_id = p_community_id;

    -- Registrar no log de moderação
    PERFORM public.log_moderation_action(
        p_community_id  := p_community_id,
        p_action        := 'assign_category',
        p_target_post_id := p_post_id,
        p_reason        := CASE
            WHEN p_category_id IS NULL THEN 'Categoria removida'
            ELSE 'Categoria atribuída'
        END
    );

    RETURN jsonb_build_object('success', true);
END;
$$;
