-- ========================
-- Fix: get_user_profile referenciava colunas inexistentes na tabela profiles:
--   xp, global_role, is_verified, is_online, last_online_at, media_list, background_url
-- Colunas corretas do schema:
--   level (existe), reputation, banner_url, online_status, last_seen_at,
--   is_nickname_verified, is_team_admin, is_team_moderator, is_system_account,
--   is_premium, coins_float, business_coins, premium_expires_at,
--   blogs_count, comments_count, items_count, joined_communities_count,
--   broken_streaks, last_checkin_at, has_completed_onboarding, updated_at
-- Status de posts usa enum content_status com valor 'ok' (não 'published')
-- ========================
CREATE OR REPLACE FUNCTION public.get_user_profile(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_viewer_id UUID := auth.uid();
  v_profile RECORD;
  v_followers INTEGER;
  v_following INTEGER;
  v_posts INTEGER;
  v_is_following BOOLEAN := FALSE;
  v_is_blocked BOOLEAN := FALSE;
BEGIN
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'user_not_found');
  END IF;

  SELECT COUNT(*) INTO v_followers FROM public.follows WHERE following_id = p_user_id;
  SELECT COUNT(*) INTO v_following FROM public.follows WHERE follower_id = p_user_id;
  SELECT COUNT(*) INTO v_posts FROM public.posts WHERE author_id = p_user_id AND status = 'ok';

  IF v_viewer_id IS NOT NULL AND v_viewer_id != p_user_id THEN
    SELECT EXISTS(
      SELECT 1 FROM public.follows WHERE follower_id = v_viewer_id AND following_id = p_user_id
    ) INTO v_is_following;

    SELECT EXISTS(
      SELECT 1 FROM public.blocks WHERE blocker_id = v_viewer_id AND blocked_id = p_user_id
    ) INTO v_is_blocked;
  END IF;

  RETURN jsonb_build_object(
    'id', v_profile.id,
    'amino_id', v_profile.amino_id,
    'nickname', v_profile.nickname,
    'is_nickname_verified', v_profile.is_nickname_verified,
    'icon_url', v_profile.icon_url,
    'banner_url', v_profile.banner_url,
    'bio', v_profile.bio,
    -- Roles globais
    'is_team_admin', v_profile.is_team_admin,
    'is_team_moderator', v_profile.is_team_moderator,
    'is_system_account', v_profile.is_system_account,
    -- Gamificação
    'level', v_profile.level,
    'reputation', v_profile.reputation,
    -- Economia
    'coins', v_profile.coins,
    'coins_float', v_profile.coins_float,
    'business_coins', v_profile.business_coins,
    'is_premium', v_profile.is_premium,
    'premium_expires_at', v_profile.premium_expires_at,
    -- Estatísticas
    'blogs_count', v_profile.blogs_count,
    'posts_count', v_posts,
    'comments_count', v_profile.comments_count,
    'items_count', v_profile.items_count,
    'joined_communities_count', v_profile.joined_communities_count,
    'followers_count', v_followers,
    'following_count', v_following,
    -- Check-in
    'consecutive_checkin_days', v_profile.consecutive_checkin_days,
    'last_checkin_at', v_profile.last_checkin_at,
    'broken_streaks', v_profile.broken_streaks,
    -- Onboarding
    'has_completed_onboarding', v_profile.has_completed_onboarding,
    -- Metadata
    'online_status', v_profile.online_status,
    'last_seen_at', v_profile.last_seen_at,
    'created_at', v_profile.created_at,
    'updated_at', v_profile.updated_at,
    -- Campos calculados
    'is_following', v_is_following,
    'is_blocked', v_is_blocked
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
