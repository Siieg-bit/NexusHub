-- ============================================================
-- Migration 067: Campos extras para perfil de comunidade
--
-- Adiciona campos que faltavam na tabela community_members
-- para suportar a tela de edição de perfil estilo Amino:
--   - local_background_url: plano de fundo do perfil (opcional)
--   - local_gallery:        galeria de fotos do membro (array de URLs)
--   - local_nickname_style: estilo visual do nickname (cor, fonte, etc.)
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Novos campos na tabela community_members
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.community_members
  ADD COLUMN IF NOT EXISTS local_background_url TEXT,
  ADD COLUMN IF NOT EXISTS local_gallery         JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS local_nickname_style  JSONB DEFAULT '{}'::jsonb;

-- local_background_url: URL da imagem de fundo do perfil local
-- local_gallery:        Array de URLs de fotos da galeria do membro
--                       Ex: ["https://...", "https://..."]
-- local_nickname_style: Objeto com configurações visuais do nickname
--                       Ex: {"color": "#FF5722", "font": "bold", "prefix": "🍁"}

COMMENT ON COLUMN public.community_members.local_background_url IS
  'Plano de fundo customizado do perfil local na comunidade (opcional)';
COMMENT ON COLUMN public.community_members.local_gallery IS
  'Galeria de fotos do membro nesta comunidade. Array de URLs de imagens.';
COMMENT ON COLUMN public.community_members.local_nickname_style IS
  'Estilo visual do nickname local. Ex: {"color":"#FF5722","prefix":"🍁","bold":true}';

-- ─────────────────────────────────────────────────────────────
-- 2. Função RPC para atualizar perfil de comunidade
--    (inclui todos os campos editáveis de uma vez)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_community_profile(
  p_community_id       UUID,
  p_local_nickname     TEXT     DEFAULT NULL,
  p_local_bio          TEXT     DEFAULT NULL,
  p_local_icon_url     TEXT     DEFAULT NULL,
  p_local_banner_url   TEXT     DEFAULT NULL,
  p_local_background_url TEXT   DEFAULT NULL,
  p_local_gallery      JSONB    DEFAULT NULL,
  p_local_nickname_style JSONB  DEFAULT NULL
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
    local_nickname        = COALESCE(p_local_nickname, local_nickname),
    local_bio             = COALESCE(p_local_bio, local_bio),
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

-- ─────────────────────────────────────────────────────────────
-- 3. Índice para galeria (para buscas futuras)
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_community_members_gallery
  ON public.community_members USING GIN (local_gallery)
  WHERE local_gallery IS NOT NULL AND local_gallery != '[]'::jsonb;
