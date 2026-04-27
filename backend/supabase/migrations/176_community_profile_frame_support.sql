-- ============================================================
-- Migration 176: Adiciona suporte a moldura local na RPC
--                update_community_profile
--
-- Problema: a RPC não aceitava parâmetros de moldura, então
-- o editor de perfil da comunidade não conseguia persistir
-- a seleção/remoção de moldura local.
--
-- Solução:
--   1. Adiciona p_active_avatar_frame_purchase_id (UUID) e
--      p_frame_changed (BOOLEAN) à assinatura da função.
--   2. Quando p_frame_changed = TRUE e
--      p_active_avatar_frame_purchase_id IS NULL, grava o
--      sentinel 'none' em active_avatar_frame_id para indicar
--      explicitamente "sem moldura nesta comunidade" (diferente
--      de NULL = "nunca configurado → usar moldura global").
--   3. Quando p_frame_changed = TRUE e
--      p_active_avatar_frame_purchase_id IS NOT NULL, grava o
--      UUID da compra normalmente.
--   4. Quando p_frame_changed = FALSE (ou NULL), não toca no
--      campo active_avatar_frame_id (preserva valor atual).
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_community_profile(
  p_community_id                    UUID,
  p_local_nickname                  TEXT     DEFAULT NULL,
  p_local_bio                       TEXT     DEFAULT NULL,
  p_local_icon_url                  TEXT     DEFAULT NULL,
  p_local_banner_url                TEXT     DEFAULT NULL,
  p_local_background_url            TEXT     DEFAULT NULL,
  p_local_gallery                   JSONB    DEFAULT NULL,
  p_local_nickname_style            JSONB    DEFAULT NULL,
  p_active_avatar_frame_purchase_id TEXT     DEFAULT NULL,
  p_frame_changed                   BOOLEAN  DEFAULT FALSE
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
    -- Campos de texto/mídia: atribuição direta (NULL limpa o campo)
    local_nickname        = p_local_nickname,
    local_bio             = p_local_bio,
    local_icon_url        = p_local_icon_url,
    local_banner_url      = p_local_banner_url,
    local_background_url  = p_local_background_url,
    -- Galeria: NULL preserva valor atual; array vazio limpa
    local_gallery         = COALESCE(p_local_gallery, local_gallery),
    -- Estilo do nickname: NULL preserva valor atual
    local_nickname_style  = COALESCE(p_local_nickname_style, local_nickname_style),
    -- Moldura local:
    --   p_frame_changed = FALSE → não altera (COALESCE preserva)
    --   p_frame_changed = TRUE e purchase_id IS NULL → sentinel 'none'
    --     (significa "sem moldura nesta comunidade, não usar global")
    --   p_frame_changed = TRUE e purchase_id IS NOT NULL → UUID da compra
    active_avatar_frame_id = CASE
      WHEN p_frame_changed = TRUE AND p_active_avatar_frame_purchase_id IS NULL
        THEN 'none'
      WHEN p_frame_changed = TRUE AND p_active_avatar_frame_purchase_id IS NOT NULL
        THEN p_active_avatar_frame_purchase_id::TEXT
      ELSE active_avatar_frame_id
    END
  WHERE
    community_id = p_community_id
    AND user_id  = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membership not found for community %', p_community_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_community_profile TO authenticated;
