-- =============================================================================
-- Migration 114: Correções críticas — RLS recursion e device_fingerprints
--
-- Corrige:
--   1. Política RLS cm_select_members_visible (community_members)
--      A migration 110 foi pulada acidentalmente, mantendo a política da
--      migration 109 que contém uma subquery recursiva na própria tabela
--      community_members. Isso causa infinite recursion ao carregar a lista
--      de comunidades do usuário no app.
--
--   2. Constraint UNIQUE em device_fingerprints(user_id, device_id)
--      O DeviceFingerprintService usa upsert com onConflict: 'user_id,device_id'
--      mas a constraint UNIQUE correspondente nunca foi criada, causando erro
--      PostgrestException code 42P10 a cada login.
-- =============================================================================

-- ── 1. Fix RLS policy recursion em community_members ─────────────────────────
--
-- Remove a política problemática (com subquery na própria tabela) e recria
-- usando funções SECURITY DEFINER existentes (get_community_role, is_team_member)
-- que evitam a recursão.

DROP POLICY IF EXISTS "cm_select_members_visible" ON public.community_members;
DROP POLICY IF EXISTS "hide_hidden_profiles" ON public.community_members;

CREATE POLICY "cm_select_members_visible"
  ON public.community_members
  FOR SELECT
  USING (
    -- O próprio usuário sempre vê seu registro
    user_id = auth.uid()
    OR
    -- Perfis não ocultos são visíveis para todos os membros
    is_hidden = FALSE
    OR
    -- Staff da comunidade vê todos (via função SECURITY DEFINER — sem recursão)
    public.get_community_role(community_id) IN (
      'agent'::public.user_role,
      'leader'::public.user_role,
      'curator'::public.user_role,
      'moderator'::public.user_role
    )
    OR
    -- Membros da equipe global veem tudo
    public.is_team_member()
  );

-- ── 2. Adicionar constraint UNIQUE em device_fingerprints ────────────────────
--
-- Necessária para que o upsert com onConflict: 'user_id,device_id' funcione
-- corretamente no DeviceFingerprintService.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'device_fingerprints_user_device_unique'
      AND conrelid = 'public.device_fingerprints'::regclass
  ) THEN
    ALTER TABLE public.device_fingerprints
      ADD CONSTRAINT device_fingerprints_user_device_unique
      UNIQUE (user_id, device_id);
  END IF;
END $$;
