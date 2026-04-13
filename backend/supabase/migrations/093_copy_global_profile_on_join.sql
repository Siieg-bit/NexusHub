-- =============================================================================
-- Migration 093: Copiar perfil global como perfil inicial de comunidade no join
--
-- Objetivo: Quando um usuário entra em uma comunidade (via create_community,
-- accept_invite, ou qualquer outro caminho), os campos local_nickname,
-- local_bio, local_icon_url e local_banner_url são populados automaticamente
-- com os valores do perfil global (profiles) UMA ÚNICA VEZ.
--
-- Após o join, o usuário pode editar o perfil local livremente.
-- Não há mais sincronização nem fallback para o perfil global.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Corrigir create_community — criador entra como 'agent' com perfil local
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_community(text, text, text, text, public.community_join_type, text, text);

CREATE OR REPLACE FUNCTION public.create_community(
  p_name TEXT,
  p_tagline TEXT DEFAULT '',
  p_description TEXT DEFAULT '',
  p_category TEXT DEFAULT 'general',
  p_join_type public.community_join_type DEFAULT 'open',
  p_theme_color TEXT DEFAULT '#6C5CE7',
  p_primary_language TEXT DEFAULT 'pt-BR'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id       UUID := auth.uid();
  v_community_id  UUID;
  v_name          TEXT := NULLIF(trim(COALESCE(p_name, '')), '');
  v_tagline       TEXT := NULLIF(trim(COALESCE(p_tagline, '')), '');
  v_description   TEXT := NULLIF(trim(COALESCE(p_description, '')), '');
  v_category      TEXT := COALESCE(NULLIF(trim(COALESCE(p_category, '')), ''), 'general');
  v_theme_color   TEXT := COALESCE(NULLIF(trim(COALESCE(p_theme_color, '')), ''), '#6C5CE7');
  v_primary_lang  TEXT := COALESCE(NULLIF(trim(COALESCE(p_primary_language, '')), ''), 'pt-BR');
  -- Perfil global do criador
  v_nickname      TEXT;
  v_bio           TEXT;
  v_icon_url      TEXT;
  v_banner_url    TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;
  IF v_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'name_required');
  END IF;

  -- Buscar perfil global do criador para usar como perfil local inicial
  SELECT nickname, bio, icon_url, banner_url
    INTO v_nickname, v_bio, v_icon_url, v_banner_url
    FROM public.profiles
   WHERE id = v_user_id;

  -- Criar comunidade
  INSERT INTO public.communities (
    name, tagline, description, category, join_type,
    agent_id, theme_color, primary_language
  ) VALUES (
    v_name, v_tagline, v_description, v_category,
    COALESCE(p_join_type, 'open'::public.community_join_type),
    v_user_id, v_theme_color, v_primary_lang
  )
  RETURNING id INTO v_community_id;

  -- Adicionar criador como AGENT com perfil local = cópia do global (uma única vez)
  INSERT INTO public.community_members (
    community_id, user_id, role,
    local_nickname, local_bio, local_icon_url, local_banner_url
  ) VALUES (
    v_community_id, v_user_id, 'agent',
    v_nickname, v_bio, v_icon_url, v_banner_url
  );

  -- Criar guidelines padrão
  INSERT INTO public.guidelines (community_id, content)
  VALUES (v_community_id, '# Regras da Comunidade' || E'\n\n' || 'Seja respeitoso e siga as regras.');

  -- Criar shared folder
  INSERT INTO public.shared_folders (community_id)
  VALUES (v_community_id);

  RETURN jsonb_build_object('success', true, 'community_id', v_community_id);
END;
$function$;

-- -----------------------------------------------------------------------------
-- 2. Corrigir accept_invite — membro entra com perfil local = cópia do global
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_invite(p_invite_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_community_id   UUID;
  v_community_name TEXT;
  -- Perfil global do novo membro
  v_nickname       TEXT;
  v_bio            TEXT;
  v_icon_url       TEXT;
  v_banner_url     TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Buscar comunidade pelo invite code
  SELECT id, name INTO v_community_id, v_community_name
    FROM public.communities
   WHERE invite_code = p_invite_code AND is_deleted = FALSE;

  IF v_community_id IS NULL THEN
    RETURN jsonb_build_object('error', 'invalid_invite_code');
  END IF;

  -- Verificar se já é membro
  IF EXISTS (
    SELECT 1 FROM public.community_members
     WHERE community_id = v_community_id AND user_id = v_user_id
  ) THEN
    RETURN jsonb_build_object('error', 'already_member', 'community_id', v_community_id);
  END IF;

  -- Buscar perfil global para usar como perfil local inicial
  SELECT nickname, bio, icon_url, banner_url
    INTO v_nickname, v_bio, v_icon_url, v_banner_url
    FROM public.profiles
   WHERE id = v_user_id;

  -- Adicionar como membro com perfil local = cópia do global (uma única vez)
  INSERT INTO public.community_members (
    community_id, user_id, role,
    local_nickname, local_bio, local_icon_url, local_banner_url
  ) VALUES (
    v_community_id, v_user_id, 'member',
    v_nickname, v_bio, v_icon_url, v_banner_url
  );

  -- Incrementar contagem
  UPDATE public.communities
     SET member_count = member_count + 1
   WHERE id = v_community_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'community_id', v_community_id,
    'community_name', v_community_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 3. Backfill: preencher membros existentes que ainda têm local_nickname NULL
--    Copia nickname/icon_url/bio/banner_url do profiles para community_members
--    onde os campos locais estão vazios. Executado uma única vez.
-- -----------------------------------------------------------------------------
UPDATE public.community_members cm
   SET local_nickname   = p.nickname,
       local_bio        = p.bio,
       local_icon_url   = p.icon_url,
       local_banner_url = p.banner_url
  FROM public.profiles p
 WHERE cm.user_id = p.id
   AND (
     cm.local_nickname IS NULL
     OR cm.local_nickname = ''
   );
