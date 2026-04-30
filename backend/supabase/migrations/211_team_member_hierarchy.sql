-- =============================================================================
-- Migration 211: Hierarquia completa de Team Members
-- =============================================================================
--
-- Cria o enum team_role e a coluna team_rank na tabela profiles.
-- Migra os dados existentes (is_team_admin → team_admin/rank 80,
-- is_team_moderator → trust_safety/rank 70).
-- Cria RPCs de gerenciamento de staff e atualiza get_moderation_rank.
--
-- Hierarquia (rank numérico):
--   100 → founder          (Fundador / CEO — borda branca)
--    90 → co_founder       (Co-Fundador / CTO — borda dourada)
--    80 → team_admin       (Admin da plataforma — borda vermelha)
--    70 → trust_safety     (Trust & Safety — borda azul escuro)
--    60 → support          (Suporte — borda azul claro)
--    50 → bug_bounty       (Bug Bounty — borda verde neon)
--    40 → community_manager(Community Manager — borda roxa)
--     0 → none             (Usuário normal)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Criar enum team_role
-- ─────────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE public.team_role AS ENUM (
    'none',
    'community_manager',
    'bug_bounty',
    'support',
    'trust_safety',
    'team_admin',
    'co_founder',
    'founder'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Adicionar colunas team_role e team_rank na tabela profiles
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS team_role  public.team_role DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS team_rank  INTEGER          DEFAULT 0;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Migrar dados existentes
--    is_team_admin      → team_admin (rank 80)
--    is_team_moderator  → trust_safety (rank 70)
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public.profiles
SET
  team_role = 'team_admin',
  team_rank = 80
WHERE is_team_admin = TRUE
  AND (team_rank IS NULL OR team_rank = 0);

UPDATE public.profiles
SET
  team_role = 'trust_safety',
  team_rank = 70
WHERE is_team_moderator = TRUE
  AND is_team_admin = FALSE
  AND (team_rank IS NULL OR team_rank = 0);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Manter is_team_admin e is_team_moderator sincronizados via trigger
--    (compatibilidade retroativa com código legado)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_team_flags()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Sincroniza is_team_admin e is_team_moderator com base no team_rank
  NEW.is_team_admin     := NEW.team_rank >= 80;
  NEW.is_team_moderator := NEW.team_rank >= 70 AND NEW.team_rank < 80;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_team_flags ON public.profiles;
CREATE TRIGGER trg_sync_team_flags
  BEFORE INSERT OR UPDATE OF team_rank, team_role
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_team_flags();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Atualizar get_moderation_rank para usar team_rank
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_moderation_rank(
  p_user_id      UUID,
  p_community_id UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_team_rank      INTEGER := 0;
  v_community_role TEXT    := 'member';
BEGIN
  -- Verificar rank global da equipe
  SELECT COALESCE(team_rank, 0)
  INTO v_team_rank
  FROM public.profiles
  WHERE id = p_user_id;

  -- Team members com rank >= 70 têm poder de moderação global
  -- Mapeamos para os ranks de moderação: founder/co_founder/team_admin → 5, trust_safety → 4
  IF v_team_rank >= 90 THEN RETURN 6; END IF;  -- founder / co_founder
  IF v_team_rank >= 80 THEN RETURN 5; END IF;  -- team_admin
  IF v_team_rank >= 70 THEN RETURN 4; END IF;  -- trust_safety

  -- Verificar role na comunidade (se fornecido)
  IF p_community_id IS NOT NULL THEN
    SELECT role INTO v_community_role
    FROM public.community_members
    WHERE community_id = p_community_id AND user_id = p_user_id;
  END IF;

  RETURN CASE COALESCE(v_community_role, 'member')
    WHEN 'agent'   THEN 3
    WHEN 'leader'  THEN 2
    WHEN 'curator' THEN 1
    ELSE 0
  END;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_moderation_rank(UUID, UUID) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RPC: set_team_role — Atribuir/remover cargo de equipe
--    Apenas usuários com team_rank > rank_alvo podem alterar o cargo.
--    O Founder (rank 100) é o único que pode nomear outros Founders.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_team_role(
  p_target_user_id UUID,
  p_new_role       public.team_role
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_id    UUID    := auth.uid();
  v_caller_rank  INTEGER := 0;
  v_target_rank  INTEGER := 0;
  v_new_rank     INTEGER := 0;
  v_old_role     public.team_role;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Rank do caller
  SELECT COALESCE(team_rank, 0) INTO v_caller_rank
  FROM public.profiles WHERE id = v_caller_id;

  -- Rank atual do alvo
  SELECT COALESCE(team_rank, 0), team_role
  INTO v_target_rank, v_old_role
  FROM public.profiles WHERE id = p_target_user_id;

  -- Mapear novo role para rank
  v_new_rank := CASE p_new_role
    WHEN 'founder'           THEN 100
    WHEN 'co_founder'        THEN 90
    WHEN 'team_admin'        THEN 80
    WHEN 'trust_safety'      THEN 70
    WHEN 'support'           THEN 60
    WHEN 'bug_bounty'        THEN 50
    WHEN 'community_manager' THEN 40
    ELSE 0
  END;

  -- Validações de hierarquia
  IF v_caller_rank < 80 THEN
    RETURN jsonb_build_object('error', 'insufficient_rank',
      'message', 'Apenas Team Admin ou superior pode gerenciar cargos da equipe');
  END IF;

  -- Não pode alterar alguém de rank igual ou superior
  IF v_target_rank >= v_caller_rank THEN
    RETURN jsonb_build_object('error', 'target_outranks_caller',
      'message', 'Você não pode alterar o cargo de alguém com rank igual ou superior ao seu');
  END IF;

  -- Não pode atribuir rank igual ou superior ao próprio
  IF v_new_rank >= v_caller_rank THEN
    RETURN jsonb_build_object('error', 'cannot_grant_equal_or_higher',
      'message', 'Você não pode atribuir um cargo de rank igual ou superior ao seu');
  END IF;

  -- Aplicar novo cargo e rank
  UPDATE public.profiles
  SET
    team_role = p_new_role,
    team_rank = v_new_rank
  WHERE id = p_target_user_id;

  -- Sincronizar badge de Team Member
  PERFORM public.sync_team_member_badge(p_target_user_id, v_new_rank > 0);

  -- Log da ação
  INSERT INTO public.auth_audit_log (user_id, action, metadata)
  VALUES (v_caller_id, 'set_team_role', jsonb_build_object(
    'target_user_id', p_target_user_id,
    'old_role', v_old_role::text,
    'new_role', p_new_role::text,
    'old_rank', v_target_rank,
    'new_rank', v_new_rank
  ));

  RETURN jsonb_build_object(
    'success', true,
    'new_role', p_new_role::text,
    'new_rank', v_new_rank
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_team_role(UUID, public.team_role) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RPC: get_team_members — Listar todos os membros da equipe
--    Apenas usuários com team_rank >= 80 podem ver a lista completa.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_team_members()
RETURNS TABLE (
  user_id    UUID,
  nickname   TEXT,
  icon_url   TEXT,
  amino_id   TEXT,
  team_role  public.team_role,
  team_rank  INTEGER,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_rank INTEGER := 0;
BEGIN
  SELECT COALESCE(p.team_rank, 0) INTO v_caller_rank
  FROM public.profiles p WHERE p.id = auth.uid();

  IF v_caller_rank < 80 THEN
    RAISE EXCEPTION 'Acesso negado: apenas Team Admin ou superior pode listar a equipe';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.nickname,
    p.icon_url,
    p.amino_id,
    p.team_role,
    p.team_rank,
    p.created_at
  FROM public.profiles p
  WHERE p.team_rank > 0
  ORDER BY p.team_rank DESC, p.nickname ASC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_team_members() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Atualizar sync_team_member_badge para receber rank em vez de booleano
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_team_member_badge(
  p_user_id UUID,
  p_is_team BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF p_is_team THEN
    INSERT INTO public.member_titles
      (community_id, user_id, issued_by, title, color, sort_order, is_role_badge)
    SELECT
      cm.community_id, p_user_id, p_user_id,
      'Team Member', '#FFFFFF', 0, TRUE
    FROM public.community_members cm
    WHERE cm.user_id = p_user_id
    ON CONFLICT (community_id, user_id, title) DO UPDATE
    SET color = '#FFFFFF', is_visible = TRUE, is_role_badge = TRUE;
  ELSE
    DELETE FROM public.member_titles
    WHERE user_id = p_user_id
      AND title = 'Team Member'
      AND is_role_badge = TRUE;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.sync_team_member_badge(UUID, BOOLEAN) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. Expor team_role e team_rank no get_user_profile
-- ─────────────────────────────────────────────────────────────────────────────
-- A RPC get_user_profile já retorna is_team_admin e is_team_moderator.
-- Precisamos adicionar team_role e team_rank ao resultado.
-- Buscamos a versão atual e a atualizamos.
CREATE OR REPLACE FUNCTION public.get_user_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_profile   public.profiles%ROWTYPE;
  v_result    JSONB;
BEGIN
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'user_not_found');
  END IF;

  v_result := jsonb_build_object(
    'id',                    v_profile.id,
    'amino_id',              v_profile.amino_id,
    'nickname',              v_profile.nickname,
    'is_nickname_verified',  v_profile.is_nickname_verified,
    'icon_url',              v_profile.icon_url,
    'banner_url',            v_profile.banner_url,
    'bio',                   v_profile.bio,
    'is_team_admin',         v_profile.is_team_admin,
    'is_team_moderator',     v_profile.is_team_moderator,
    'team_role',             v_profile.team_role::text,
    'team_rank',             v_profile.team_rank,
    'is_system_account',     v_profile.is_system_account,
    'level',                 v_profile.level,
    'reputation',            v_profile.reputation,
    'coins',                 v_profile.coins,
    'is_premium',            v_profile.is_premium,
    'premium_expires_at',    v_profile.premium_expires_at,
    'blogs_count',           v_profile.blogs_count,
    'posts_count',           v_profile.posts_count,
    'comments_count',        v_profile.comments_count,
    'items_count',           v_profile.items_count,
    'joined_communities_count', v_profile.joined_communities_count,
    'followers_count',       v_profile.followers_count,
    'following_count',       v_profile.following_count,
    'privilege_chat_invite', v_profile.privilege_chat_invite::text,
    'privilege_comment_profile', v_profile.privilege_comment_profile::text,
    'security_level',        v_profile.security_level::text,
    'consecutive_checkin_days', v_profile.consecutive_checkin_days,
    'last_checkin_at',       v_profile.last_checkin_at,
    'has_completed_onboarding', v_profile.has_completed_onboarding,
    'online_status',         v_profile.online_status,
    'last_seen_at',          v_profile.last_seen_at,
    'created_at',            v_profile.created_at,
    'is_amino_plus',         v_profile.is_amino_plus,
    'is_ghost_mode',         v_profile.is_ghost_mode,
    'disable_incoming_chats', v_profile.disable_incoming_chats,
    'disable_profile_comments', v_profile.disable_profile_comments,
    'status_emoji',          v_profile.status_emoji,
    'status_text',           v_profile.status_text,
    'best_streak_days',      v_profile.best_streak_days,
    'wall_comments_count',   v_profile.wall_comments_count
  );

  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_user_profile(UUID) TO authenticated, anon;
