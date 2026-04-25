-- =============================================================================
-- MIGRATION 136 — Corrige toggle_wiki_canonical e hide_wiki_entry
-- =============================================================================
-- Problema: a migration 131 não foi aplicada corretamente no banco.
-- O log_moderation_action atual tem 8 parâmetros (sem target_story_id),
-- e os RPCs toggle_wiki_canonical e hide_wiki_entry não existem.
-- Esta migration:
--   1. Adiciona target_story_id em moderation_logs (se não existir)
--   2. Recria log_moderation_action com 9 parâmetros (+ target_story_id)
--   3. Cria toggle_wiki_canonical
--   4. Cria hide_wiki_entry
-- =============================================================================

-- ── 1. Adicionar target_story_id em moderation_logs ─────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'moderation_logs'
      AND column_name = 'target_story_id'
  ) THEN
    ALTER TABLE public.moderation_logs
      ADD COLUMN target_story_id UUID;
  END IF;
END $$;

-- ── 2. Recriar log_moderation_action com target_story_id ────────────────────
-- Primeiro dropar a versão antiga (8 parâmetros)
DROP FUNCTION IF EXISTS public.log_moderation_action(
  UUID, TEXT, UUID, UUID, UUID, UUID, TEXT, INT
);

CREATE OR REPLACE FUNCTION public.log_moderation_action(
  p_community_id       UUID,
  p_action             TEXT,
  p_target_user_id     UUID  DEFAULT NULL,
  p_target_post_id     UUID  DEFAULT NULL,
  p_target_wiki_id     UUID  DEFAULT NULL,
  p_target_comment_id  UUID  DEFAULT NULL,
  p_target_story_id    UUID  DEFAULT NULL,
  p_reason             TEXT  DEFAULT NULL,
  p_duration_hours     INT   DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_log_id  UUID;
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;
  INSERT INTO public.moderation_logs (
    community_id, moderator_id, action,
    target_user_id, target_post_id, target_wiki_id,
    target_comment_id, target_story_id,
    reason, duration_hours
  ) VALUES (
    p_community_id, v_user_id, p_action::public.moderation_action,
    p_target_user_id, p_target_post_id, p_target_wiki_id,
    p_target_comment_id, p_target_story_id,
    p_reason, p_duration_hours
  ) RETURNING id INTO v_log_id;
  RETURN v_log_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_moderation_action TO authenticated;

-- ── 3. Criar hide_wiki_entry ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hide_wiki_entry(
  p_wiki_id UUID,
  p_hide    BOOLEAN DEFAULT TRUE,
  p_reason  TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_community_id UUID;
  v_action       TEXT := CASE WHEN p_hide THEN 'hide_wiki' ELSE 'unhide_wiki' END;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;
  SELECT community_id INTO v_community_id
  FROM public.wiki_entries WHERE id = p_wiki_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wiki não encontrada';
  END IF;
  IF NOT (public.is_community_moderator(v_community_id) OR public.is_team_member()) THEN
    RAISE EXCEPTION 'Sem permissão para ocultar esta wiki';
  END IF;
  UPDATE public.wiki_entries
  SET status = CASE WHEN p_hide THEN 'disabled' ELSE 'ok' END
  WHERE id = p_wiki_id;
  IF v_community_id IS NOT NULL THEN
    PERFORM public.log_moderation_action(
      p_community_id   => v_community_id,
      p_action         => v_action,
      p_target_wiki_id => p_wiki_id,
      p_reason         => COALESCE(p_reason,
        CASE WHEN p_hide THEN 'Wiki ocultada' ELSE 'Wiki reexibida' END)
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.hide_wiki_entry TO authenticated;

-- ── 4. Criar toggle_wiki_canonical ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_wiki_canonical(
  p_wiki_id    UUID,
  p_canonical  BOOLEAN DEFAULT TRUE,
  p_reason     TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_community_id UUID;
  v_action       TEXT := CASE WHEN p_canonical THEN 'canonize_wiki' ELSE 'decanonize_wiki' END;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;
  SELECT community_id INTO v_community_id
  FROM public.wiki_entries WHERE id = p_wiki_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wiki não encontrada';
  END IF;
  IF NOT (public.is_community_moderator(v_community_id) OR public.is_team_member()) THEN
    RAISE EXCEPTION 'Sem permissão para canonizar esta wiki';
  END IF;
  UPDATE public.wiki_entries
  SET is_canonical = p_canonical
  WHERE id = p_wiki_id;
  IF v_community_id IS NOT NULL THEN
    PERFORM public.log_moderation_action(
      p_community_id   => v_community_id,
      p_action         => v_action,
      p_target_wiki_id => p_wiki_id,
      p_reason         => COALESCE(p_reason,
        CASE WHEN p_canonical THEN 'Wiki canonizada'
             ELSE 'Canonização removida' END)
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_wiki_canonical TO authenticated;
