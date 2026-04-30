-- =============================================================================
-- Migration 170: Member Title Templates (Adicional ao sistema de títulos)
-- =============================================================================
-- O sistema atual de títulos (member_titles) já funciona por atribuição direta:
-- cada linha representa um título de um usuário específico em uma comunidade.
-- Esta migration NÃO substitui esse sistema — ela o expande com a capacidade
-- de líderes criarem "templates" de títulos pré-definidos para a comunidade,
-- que podem ser atribuídos rapidamente a qualquer membro via manage_member_title.
--
-- Benefício: o líder define uma paleta de títulos oficiais da comunidade
-- (ex: "VIP", "Veterano", "Artista") e pode atribuí-los com um clique,
-- sem precisar digitar nome/cor a cada vez.
-- =============================================================================

-- Tabela de templates de títulos da comunidade
CREATE TABLE IF NOT EXISTS public.community_title_templates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id  UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  color         TEXT NOT NULL DEFAULT '#6366F1',
  icon          TEXT,                          -- emoji ou URL de ícone
  description   TEXT,                          -- descrição interna para o líder
  sort_order    INT NOT NULL DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_by    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (community_id, title)
);

CREATE INDEX IF NOT EXISTS idx_community_title_templates_community
  ON public.community_title_templates (community_id, is_active, sort_order);

-- Trigger de updated_at
CREATE TRIGGER trg_community_title_templates_updated_at
  BEFORE UPDATE ON public.community_title_templates
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- RLS
ALTER TABLE public.community_title_templates ENABLE ROW LEVEL SECURITY;

-- Membros da comunidade podem ver os templates ativos
CREATE POLICY "title_templates_read" ON public.community_title_templates
  FOR SELECT TO authenticated
  USING (
    is_active = true AND
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_title_templates.community_id
        AND user_id = auth.uid()
    )
  );

-- Líderes e curadores podem gerenciar templates
CREATE POLICY "title_templates_admin_write" ON public.community_title_templates
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_title_templates.community_id
        AND user_id = auth.uid()
        AND role IN ('leader', 'curator', 'agent')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_title_templates.community_id
        AND user_id = auth.uid()
        AND role IN ('leader', 'curator', 'agent')
    )
  );

-- =============================================================================
-- RPC: manage_title_template — criar, editar ou remover um template
-- =============================================================================
CREATE OR REPLACE FUNCTION public.manage_title_template(
  p_community_id  UUID,
  p_action        TEXT,         -- 'create' | 'update' | 'delete' | 'reorder'
  p_template_id   UUID  DEFAULT NULL,
  p_title         TEXT  DEFAULT NULL,
  p_color         TEXT  DEFAULT '#6366F1',
  p_icon          TEXT  DEFAULT NULL,
  p_description   TEXT  DEFAULT NULL,
  p_sort_order    INT   DEFAULT NULL,
  p_is_active     BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_new_id  UUID;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND role IN ('leader', 'curator', 'agent')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN RAISE EXCEPTION 'insufficient_permissions'; END IF;

  IF p_action = 'create' THEN
    IF p_title IS NULL THEN RAISE EXCEPTION 'title_required'; END IF;
    INSERT INTO public.community_title_templates
      (community_id, title, color, icon, description, sort_order, created_by)
    VALUES
      (p_community_id, p_title, COALESCE(p_color, '#6366F1'), p_icon, p_description,
       COALESCE(p_sort_order, (
         SELECT COALESCE(MAX(sort_order), 0) + 1
         FROM public.community_title_templates
         WHERE community_id = p_community_id
       )), v_user_id)
    RETURNING id INTO v_new_id;
    RETURN jsonb_build_object('success', true, 'id', v_new_id);

  ELSIF p_action = 'update' THEN
    IF p_template_id IS NULL THEN RAISE EXCEPTION 'template_id_required'; END IF;
    UPDATE public.community_title_templates
    SET
      title       = COALESCE(p_title, title),
      color       = COALESCE(p_color, color),
      icon        = COALESCE(p_icon, icon),
      description = COALESCE(p_description, description),
      sort_order  = COALESCE(p_sort_order, sort_order),
      is_active   = COALESCE(p_is_active, is_active),
      updated_at  = now()
    WHERE id = p_template_id AND community_id = p_community_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
    RETURN jsonb_build_object('success', true);

  ELSIF p_action = 'delete' THEN
    IF p_template_id IS NULL THEN RAISE EXCEPTION 'template_id_required'; END IF;
    DELETE FROM public.community_title_templates
    WHERE id = p_template_id AND community_id = p_community_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
    RETURN jsonb_build_object('success', true);

  ELSE
    RAISE EXCEPTION 'invalid_action: %', p_action;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_title_template(UUID, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, INT, BOOLEAN) TO authenticated;

-- =============================================================================
-- RPC: get_title_templates — listar templates de uma comunidade
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_title_templates(
  p_community_id UUID
)
RETURNS TABLE (
  id          UUID,
  title       TEXT,
  color       TEXT,
  icon        TEXT,
  description TEXT,
  sort_order  INT,
  is_active   BOOLEAN,
  created_at  TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    t.id, t.title, t.color, t.icon, t.description,
    t.sort_order, t.is_active, t.created_at
  FROM public.community_title_templates t
  WHERE t.community_id = p_community_id
    AND t.is_active = true
    AND EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = p_community_id AND user_id = auth.uid()
    )
  ORDER BY t.sort_order ASC, t.created_at ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_title_templates(UUID) TO authenticated;

-- =============================================================================
-- RPC: assign_title_from_template — atribuir título a partir de um template
-- Reutiliza manage_member_title internamente para manter consistência total.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.assign_title_from_template(
  p_community_id  UUID,
  p_target_user_id UUID,
  p_template_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_title   TEXT;
  v_color   TEXT;
  v_icon    TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_user_id
      AND role IN ('leader', 'curator', 'agent')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN RAISE EXCEPTION 'insufficient_permissions'; END IF;

  -- Buscar dados do template
  SELECT title, color, icon
  INTO v_title, v_color, v_icon
  FROM public.community_title_templates
  WHERE id = p_template_id AND community_id = p_community_id AND is_active = true;

  IF NOT FOUND THEN RAISE EXCEPTION 'template_not_found'; END IF;

  -- Delegar para manage_member_title (sistema atual) para manter cache e lógica unificados
  RETURN public.manage_member_title(
    p_community_id   := p_community_id,
    p_target_user_id := p_target_user_id,
    p_action         := 'add',
    p_title          := v_title,
    p_color          := v_color,
    p_icon           := v_icon
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_title_from_template(UUID, UUID, UUID) TO authenticated;
