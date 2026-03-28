-- ============================================================================
-- Migration 020: Community Home Layout (customizável pelo líder)
-- ============================================================================
-- Adiciona coluna home_layout JSONB na tabela communities para permitir
-- que líderes customizem a ordem e visibilidade das seções da página inicial.
-- ============================================================================

-- Adicionar coluna home_layout com valor padrão
ALTER TABLE public.communities
ADD COLUMN IF NOT EXISTS home_layout JSONB DEFAULT '{
  "sections_order": ["header", "check_in", "live_chats", "tabs"],
  "sections_visible": {
    "check_in": true,
    "live_chats": true,
    "featured_posts": true,
    "latest_feed": true,
    "public_chats": true,
    "guidelines": true
  },
  "featured_type": "list",
  "welcome_banner": {
    "enabled": false,
    "image_url": null,
    "text": null,
    "link": null
  },
  "pinned_chat_ids": [],
  "bottom_bar": {
    "show_online_count": true,
    "show_create_button": true
  }
}'::jsonb;

-- Função para atualizar o home_layout (só líderes/agents)
CREATE OR REPLACE FUNCTION public.update_community_home_layout(
  p_community_id UUID,
  p_user_id UUID,
  p_home_layout JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
BEGIN
  -- Verificar se o usuário é líder ou agent
  SELECT role INTO v_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = p_user_id;

  IF v_role IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Não é membro da comunidade');
  END IF;

  IF v_role NOT IN ('agent', 'leader') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Apenas líderes podem customizar a home');
  END IF;

  -- Atualizar home_layout
  UPDATE public.communities
  SET home_layout = p_home_layout,
      updated_at = NOW()
  WHERE id = p_community_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Função para obter o home_layout de uma comunidade
CREATE OR REPLACE FUNCTION public.get_community_home_layout(
  p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_layout JSONB;
BEGIN
  SELECT home_layout INTO v_layout
  FROM public.communities
  WHERE id = p_community_id;

  IF v_layout IS NULL THEN
    -- Retornar layout padrão
    RETURN '{
      "sections_order": ["header", "check_in", "live_chats", "tabs"],
      "sections_visible": {
        "check_in": true,
        "live_chats": true,
        "featured_posts": true,
        "latest_feed": true,
        "public_chats": true,
        "guidelines": true
      },
      "featured_type": "list",
      "welcome_banner": {
        "enabled": false,
        "image_url": null,
        "text": null,
        "link": null
      },
      "pinned_chat_ids": [],
      "bottom_bar": {
        "show_online_count": true,
        "show_create_button": true
      }
    }'::jsonb;
  END IF;

  RETURN v_layout;
END;
$$;
