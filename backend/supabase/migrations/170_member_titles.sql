-- Migration 168: Member Titles (Títulos de Membros Customizados)
-- Admins de comunidade podem criar títulos customizados e atribuí-los a membros.

-- Tabela de títulos de membros
CREATE TABLE IF NOT EXISTS public.community_member_titles (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id          UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  name                  TEXT NOT NULL,
  emoji                 TEXT,
  color                 TEXT NOT NULL DEFAULT '#6366F1',
  auto_assign_after_days INT,  -- NULL = somente atribuição manual
  created_by            UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (community_id, name)
);

CREATE INDEX IF NOT EXISTS idx_community_member_titles_community
  ON public.community_member_titles (community_id);

-- Tabela de atribuições de títulos
CREATE TABLE IF NOT EXISTS public.member_title_assignments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title_id    UUID NOT NULL REFERENCES public.community_member_titles(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, community_id)  -- Um título por usuário por comunidade
);

CREATE INDEX IF NOT EXISTS idx_member_title_assignments_user_community
  ON public.member_title_assignments (user_id, community_id);

-- RLS
ALTER TABLE public.community_member_titles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_title_assignments ENABLE ROW LEVEL SECURITY;

-- Membros podem ver os títulos da comunidade
CREATE POLICY "member_titles_read" ON public.community_member_titles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_member_titles.community_id
        AND user_id = auth.uid()
        AND status = 'active'
    )
  );

-- Apenas líderes e co-líderes podem criar/editar títulos
CREATE POLICY "member_titles_admin_write" ON public.community_member_titles
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_member_titles.community_id
        AND user_id = auth.uid()
        AND role IN ('leader', 'co_leader')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_member_titles.community_id
        AND user_id = auth.uid()
        AND role IN ('leader', 'co_leader')
    )
  );

-- Membros podem ver suas próprias atribuições
CREATE POLICY "title_assignments_read" ON public.member_title_assignments
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = member_title_assignments.community_id
        AND user_id = auth.uid()
        AND status = 'active'
    )
  );

-- Apenas líderes e moderadores podem atribuir títulos
CREATE POLICY "title_assignments_admin_write" ON public.member_title_assignments
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = member_title_assignments.community_id
        AND user_id = auth.uid()
        AND role IN ('leader', 'co_leader', 'moderator')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = member_title_assignments.community_id
        AND user_id = auth.uid()
        AND role IN ('leader', 'co_leader', 'moderator')
    )
  );

-- RPC: buscar título do membro em uma comunidade
CREATE OR REPLACE FUNCTION public.get_member_title(
  p_user_id     UUID,
  p_community_id UUID
)
RETURNS TABLE (
  title_name  TEXT,
  title_emoji TEXT,
  title_color TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT t.name, t.emoji, t.color
  FROM public.member_title_assignments a
  JOIN public.community_member_titles t ON t.id = a.title_id
  WHERE a.user_id = p_user_id
    AND a.community_id = p_community_id
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_member_title(UUID, UUID) TO authenticated;

-- RPC: atribuir título a um membro
CREATE OR REPLACE FUNCTION public.assign_member_title(
  p_user_id     UUID,
  p_title_id    UUID,
  p_community_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_is_admin BOOLEAN;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_actor_id
      AND role IN ('leader', 'co_leader', 'moderator')
  ) INTO v_is_admin;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'insufficient_permissions'; END IF;
  INSERT INTO public.member_title_assignments
    (title_id, user_id, community_id, assigned_by)
  VALUES (p_title_id, p_user_id, p_community_id, v_actor_id)
  ON CONFLICT (user_id, community_id)
  DO UPDATE SET title_id = EXCLUDED.title_id, assigned_by = EXCLUDED.assigned_by, assigned_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_member_title(UUID, UUID, UUID) TO authenticated;

-- RPC: remover título de um membro
CREATE OR REPLACE FUNCTION public.remove_member_title(
  p_user_id     UUID,
  p_community_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_is_admin BOOLEAN;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = v_actor_id
      AND role IN ('leader', 'co_leader', 'moderator')
  ) INTO v_is_admin;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'insufficient_permissions'; END IF;
  DELETE FROM public.member_title_assignments
  WHERE user_id = p_user_id AND community_id = p_community_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_member_title(UUID, UUID) TO authenticated;
