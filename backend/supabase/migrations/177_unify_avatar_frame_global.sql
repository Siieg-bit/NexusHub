-- ============================================================
-- Migration 177: Unifica sistema de moldura para ser 100% global
--
-- Contexto:
--   A migration 176 adicionou suporte a moldura local por comunidade
--   (active_avatar_frame_id em community_members). Essa abordagem foi
--   descartada: a moldura deve ser única e global para o usuário.
--
-- O que esta migration faz:
--   1. Remove os parâmetros p_active_avatar_frame_purchase_id e
--      p_frame_changed da RPC update_community_profile (volta à
--      assinatura simples sem lógica de moldura local).
--   2. Limpa todos os valores de active_avatar_frame_id em
--      community_members (incluindo o sentinel 'none'), pois o campo
--      não é mais usado para controle de moldura.
--
-- A moldura agora é gerenciada exclusivamente via equip_store_item
-- (is_equipped em user_purchases), que é chamada tanto pelo inventário
-- quanto pelo editor de perfil da comunidade.
-- ============================================================

-- 1. Limpar active_avatar_frame_id em todos os registros existentes
UPDATE public.community_members
SET active_avatar_frame_id = NULL
WHERE active_avatar_frame_id IS NOT NULL;

-- 2. Recriar update_community_profile sem os parâmetros de moldura local
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

GRANT EXECUTE ON FUNCTION public.update_community_profile TO authenticated;
