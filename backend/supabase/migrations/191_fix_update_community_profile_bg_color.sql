-- Migration 191: Adicionar p_local_background_color à RPC update_community_profile
-- O Flutter envia esse parâmetro mas a RPC não o aceitava, causando erro 404 no PostgREST.
-- Dropa a versão antiga (sem p_local_background_color) para evitar overload ambíguo.
DROP FUNCTION IF EXISTS public.update_community_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB);

CREATE OR REPLACE FUNCTION public.update_community_profile(
  p_community_id         UUID,
  p_local_nickname       TEXT    DEFAULT NULL,
  p_local_bio            TEXT    DEFAULT NULL,
  p_local_icon_url       TEXT    DEFAULT NULL,
  p_local_banner_url     TEXT    DEFAULT NULL,
  p_local_background_url TEXT    DEFAULT NULL,
  p_local_background_color TEXT  DEFAULT NULL,
  p_local_gallery        JSONB   DEFAULT NULL,
  p_local_nickname_style JSONB   DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  UPDATE public.community_members
  SET
    local_nickname        = p_local_nickname,
    local_bio             = p_local_bio,
    local_icon_url        = p_local_icon_url,
    local_banner_url      = p_local_banner_url,
    local_background_url  = p_local_background_url,
    local_background_color = p_local_background_color,
    local_gallery         = COALESCE(p_local_gallery, local_gallery),
    local_nickname_style  = COALESCE(p_local_nickname_style, local_nickname_style)
  WHERE
    community_id = p_community_id
    AND user_id  = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membership not found for community %', p_community_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_community_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB) TO authenticated;
