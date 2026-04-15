-- =============================================================================
-- Migration 110: Fix community_members SELECT policy recursion
--
-- Problema:
--   A policy cm_select_members_visible criada na migration 109 consulta a própria
--   tabela community_members dentro da expressão USING. Em consultas normais via
--   PostgREST/Supabase com RLS ativo, isso pode disparar recursão/infinite
--   recursion na avaliação da policy e quebrar carregamentos que dependem de
--   community_members, como a lista inicial de comunidades do usuário.
--
-- Solução:
--   Recriar a policy usando apenas funções SECURITY DEFINER já existentes
--   (get_community_role e is_team_member), evitando subquery direta na mesma
--   tabela dentro da policy.
-- =============================================================================

DROP POLICY IF EXISTS "cm_select_members_visible" ON public.community_members;
DROP POLICY IF EXISTS "hide_hidden_profiles" ON public.community_members;

CREATE POLICY "cm_select_members_visible"
  ON public.community_members
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR is_hidden = FALSE
    OR public.get_community_role(community_id) IN (
      'agent'::public.user_role,
      'leader'::public.user_role,
      'curator'::public.user_role,
      'moderator'::public.user_role
    )
    OR public.is_team_member()
  );
