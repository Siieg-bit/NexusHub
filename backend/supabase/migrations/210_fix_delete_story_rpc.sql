-- Migration 210: Criar RPC delete_story e políticas RLS de UPDATE para stories
-- A migration 131 definiu esta RPC mas não foi aplicada no banco.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. RPC: delete_story
--    Remove (desativa) um story. Apenas o autor ou moderadores da comunidade
--    podem executar. Registra log de moderação quando feito por staff.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_story(
  p_story_id   UUID,
  p_reason     TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_author_id    UUID;
  v_community_id UUID;
  v_is_author    BOOLEAN;
  v_is_mod       BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Buscar dados do story
  SELECT author_id, community_id
  INTO v_author_id, v_community_id
  FROM public.stories
  WHERE id = p_story_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Story não encontrado ou já removido';
  END IF;

  v_is_author := (v_user_id = v_author_id);
  v_is_mod    := public.is_community_moderator(v_community_id)
                 OR public.is_team_member();

  -- Autor pode deletar seu próprio story; moderadores podem deletar qualquer story
  IF NOT (v_is_author OR v_is_mod) THEN
    RAISE EXCEPTION 'Sem permissão para remover este story';
  END IF;

  -- Desativar o story
  UPDATE public.stories
  SET is_active = FALSE
  WHERE id = p_story_id;

  -- Registrar log de moderação apenas quando feito por staff (não pelo próprio autor)
  IF v_is_mod AND NOT v_is_author THEN
    PERFORM public.log_moderation_action(
      p_community_id    => v_community_id,
      p_action          => 'delete_story',
      p_target_story_id => p_story_id,
      p_target_user_id  => v_author_id,
      p_reason          => COALESCE(p_reason, 'Story removido por moderação')
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_story TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Políticas RLS UPDATE em stories
--    Moderadores precisam de UPDATE para que o SECURITY DEFINER funcione
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  DROP POLICY IF EXISTS stories_update_author ON public.stories;
  DROP POLICY IF EXISTS stories_update_mod    ON public.stories;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Autor pode atualizar seus próprios stories
CREATE POLICY stories_update_author ON public.stories
  FOR UPDATE
  USING (auth.uid() = author_id);

-- Moderadores e admins podem atualizar qualquer story da comunidade
CREATE POLICY stories_update_mod ON public.stories
  FOR UPDATE
  USING (
    public.is_community_moderator(community_id)
    OR public.is_team_member()
  );
