-- ============================================================
-- Migration 068: Corrige a RPC update_community_profile
--
-- Problema: COALESCE em local_nickname e local_bio impedia
-- limpar os campos (passar NULL mantinha o valor antigo).
--
-- Solução: atribuição direta para todos os campos, permitindo
-- que o usuário limpe qualquer campo passando NULL.
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_community_profile(
  p_community_id         UUID,
  p_local_nickname       TEXT     DEFAULT NULL,
  p_local_bio            TEXT     DEFAULT NULL,
  p_local_icon_url       TEXT     DEFAULT NULL,
  p_local_banner_url     TEXT     DEFAULT NULL,
  p_local_background_url TEXT     DEFAULT NULL,
  p_local_gallery        JSONB    DEFAULT NULL,
  p_local_nickname_style JSONB    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.community_members
  SET
    -- Atribuição direta: NULL limpa o campo (volta ao perfil global)
    local_nickname        = p_local_nickname,
    local_bio             = p_local_bio,
    local_icon_url        = p_local_icon_url,
    local_banner_url      = p_local_banner_url,
    local_background_url  = p_local_background_url,
    -- Galeria: NULL mantém a lista atual; array vazio limpa
    local_gallery         = COALESCE(p_local_gallery, local_gallery),
    -- Estilo do nickname: NULL mantém o estilo atual
    local_nickname_style  = COALESCE(p_local_nickname_style, local_nickname_style)
  WHERE
    community_id = p_community_id
    AND user_id  = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membership not found for community %', p_community_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_community_profile TO authenticated;
