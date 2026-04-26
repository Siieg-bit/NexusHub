-- Migration 170: Modo RPG e Roles de Comunidade
-- Permite que comunidades ativem um modo RPG com roles (classes/papéis)
-- que os membros podem escolher ao entrar ou dentro da comunidade.

-- ── Tabela de roles da comunidade ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.community_roles (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id  UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  description   TEXT,
  icon_url      TEXT,           -- URL de ícone/emoji customizado
  color         TEXT,           -- Hex color, ex: '#FF5733'
  max_members   INT,            -- NULL = ilimitado
  sort_order    INT NOT NULL DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_community_roles_community
  ON public.community_roles (community_id, is_active, sort_order);

-- ── Tabela de membros com roles ───────────────────────────────────────────────
-- Adicionar coluna role_id em community_members se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'community_members'
      AND column_name = 'role_id'
  ) THEN
    ALTER TABLE public.community_members
      ADD COLUMN role_id UUID REFERENCES public.community_roles(id) ON DELETE SET NULL;
  END IF;
END$$;

-- ── Ativar modo RPG na comunidade ─────────────────────────────────────────────
-- Adicionar coluna rpg_mode_enabled em communities se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'communities'
      AND column_name = 'rpg_mode_enabled'
  ) THEN
    ALTER TABLE public.communities
      ADD COLUMN rpg_mode_enabled BOOLEAN NOT NULL DEFAULT false;
  END IF;
END$$;

-- ── RLS ───────────────────────────────────────────────────────────────────────
ALTER TABLE public.community_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "community_roles_select" ON public.community_roles
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "community_roles_insert" ON public.community_roles
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_roles.community_id
        AND user_id = auth.uid()
        AND role IN ('host', 'co_host')
    )
  );

CREATE POLICY "community_roles_update" ON public.community_roles
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_roles.community_id
        AND user_id = auth.uid()
        AND role IN ('host', 'co_host')
    )
  );

CREATE POLICY "community_roles_delete" ON public.community_roles
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = community_roles.community_id
        AND user_id = auth.uid()
        AND role IN ('host', 'co_host')
    )
  );

-- ── RPC: escolher role ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.select_community_role(
  p_community_id UUID,
  p_role_id      UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_max        INT;
  v_current    INT;
  v_role_name  TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  -- Verificar se o role pertence à comunidade e está ativo
  SELECT name, max_members INTO v_role_name, v_max
  FROM public.community_roles
  WHERE id = p_role_id AND community_id = p_community_id AND is_active = true;

  IF v_role_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'role_not_found');
  END IF;

  -- Verificar limite de membros
  IF v_max IS NOT NULL THEN
    SELECT COUNT(*) INTO v_current
    FROM public.community_members
    WHERE community_id = p_community_id AND role_id = p_role_id;
    IF v_current >= v_max THEN
      RETURN jsonb_build_object('success', false, 'error', 'role_full');
    END IF;
  END IF;

  -- Atribuir role
  UPDATE public.community_members
  SET role_id = p_role_id
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  RETURN jsonb_build_object('success', true, 'role_name', v_role_name);
END;
$$;

GRANT EXECUTE ON FUNCTION public.select_community_role(UUID, UUID) TO authenticated;
