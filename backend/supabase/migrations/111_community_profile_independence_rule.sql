-- =============================================================================
-- Migration 111: Regra estrutural de independência do perfil comunitário
--
-- Objetivo:
-- 1. Clonar o perfil global para o perfil local da comunidade UMA ÚNICA VEZ.
-- 2. Após a clonagem inicial, impedir qualquer resincronização automática.
-- 3. Garantir retrocompatibilidade para memberships legadas.
-- 4. Oferecer uma RPC para o app garantir que o perfil local do membro atual
--    foi inicializado antes de renderizar/editar telas em contexto de comunidade.
-- =============================================================================

ALTER TABLE public.community_members
  ADD COLUMN IF NOT EXISTS local_profile_initialized BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.community_members.local_profile_initialized IS
  'Marca se o perfil local da comunidade já foi inicializado a partir do perfil global. Após TRUE, o perfil local passa a ser totalmente independente.';

-- -----------------------------------------------------------------------------
-- 1. Trigger de hidratação única do perfil local ao inserir membership
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hydrate_community_member_local_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_nickname   TEXT;
  v_bio        TEXT;
  v_icon_url   TEXT;
  v_banner_url TEXT;
BEGIN
  IF COALESCE(NEW.local_profile_initialized, FALSE) THEN
    RETURN NEW;
  END IF;

  SELECT p.nickname, p.bio, p.icon_url, p.banner_url
    INTO v_nickname, v_bio, v_icon_url, v_banner_url
    FROM public.profiles p
   WHERE p.id = NEW.user_id;

  NEW.local_nickname := COALESCE(
    NULLIF(BTRIM(NEW.local_nickname), ''),
    NULLIF(BTRIM(v_nickname), '')
  );
  NEW.local_bio := COALESCE(
    NULLIF(BTRIM(NEW.local_bio), ''),
    NULLIF(BTRIM(v_bio), '')
  );
  NEW.local_icon_url := COALESCE(
    NULLIF(BTRIM(NEW.local_icon_url), ''),
    NULLIF(BTRIM(v_icon_url), '')
  );
  NEW.local_banner_url := COALESCE(
    NULLIF(BTRIM(NEW.local_banner_url), ''),
    NULLIF(BTRIM(v_banner_url), '')
  );
  NEW.local_profile_initialized := TRUE;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_hydrate_community_member_local_profile
  ON public.community_members;

CREATE TRIGGER trg_hydrate_community_member_local_profile
  BEFORE INSERT ON public.community_members
  FOR EACH ROW
  EXECUTE FUNCTION public.hydrate_community_member_local_profile();

-- -----------------------------------------------------------------------------
-- 2. RPC para garantir a inicialização do perfil local do membro atual
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ensure_my_community_profile(
  p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_member_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'unauthenticated');
  END IF;

  SELECT cm.id
    INTO v_member_id
    FROM public.community_members cm
   WHERE cm.community_id = p_community_id
     AND cm.user_id = v_user_id
   LIMIT 1;

  IF v_member_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'membership_not_found');
  END IF;

  UPDATE public.community_members cm
     SET local_nickname = COALESCE(
           NULLIF(BTRIM(cm.local_nickname), ''),
           NULLIF(BTRIM(p.nickname), '')
         ),
         local_bio = COALESCE(
           NULLIF(BTRIM(cm.local_bio), ''),
           NULLIF(BTRIM(p.bio), '')
         ),
         local_icon_url = COALESCE(
           NULLIF(BTRIM(cm.local_icon_url), ''),
           NULLIF(BTRIM(p.icon_url), '')
         ),
         local_banner_url = COALESCE(
           NULLIF(BTRIM(cm.local_banner_url), ''),
           NULLIF(BTRIM(p.banner_url), '')
         ),
         local_profile_initialized = TRUE
    FROM public.profiles p
   WHERE cm.id = v_member_id
     AND p.id = v_user_id
     AND COALESCE(cm.local_profile_initialized, FALSE) = FALSE;

  RETURN jsonb_build_object('success', TRUE, 'membership_id', v_member_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.ensure_my_community_profile(UUID) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. Backfill retrocompatível para memberships antigas
--    Preenche apenas campos locais ainda vazios e marca a linha como inicializada.
-- -----------------------------------------------------------------------------
UPDATE public.community_members cm
   SET local_nickname = COALESCE(
         NULLIF(BTRIM(cm.local_nickname), ''),
         NULLIF(BTRIM(p.nickname), '')
       ),
       local_bio = COALESCE(
         NULLIF(BTRIM(cm.local_bio), ''),
         NULLIF(BTRIM(p.bio), '')
       ),
       local_icon_url = COALESCE(
         NULLIF(BTRIM(cm.local_icon_url), ''),
         NULLIF(BTRIM(p.icon_url), '')
       ),
       local_banner_url = COALESCE(
         NULLIF(BTRIM(cm.local_banner_url), ''),
         NULLIF(BTRIM(p.banner_url), '')
       ),
       local_profile_initialized = TRUE
  FROM public.profiles p
 WHERE cm.user_id = p.id
   AND COALESCE(cm.local_profile_initialized, FALSE) = FALSE;
