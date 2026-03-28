-- ========================
-- Fix: get_community_leaderboard usava cm.level (inexistente)
-- A coluna correta em community_members é cm.local_level
-- ========================
CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
  p_community_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_data ORDER BY rn) INTO v_result
  FROM (
    SELECT
      jsonb_build_object(
        'rank', ROW_NUMBER() OVER (ORDER BY cm.xp DESC, cm.local_reputation DESC),
        'user_id', cm.user_id,
        'nickname', p.nickname,
        'icon_url', p.icon_url,
        'level', cm.local_level,
        'xp', cm.xp,
        'community_reputation', cm.local_reputation,
        'role', cm.role::text,
        'consecutive_checkin_days', cm.consecutive_checkin_days
      ) AS row_data,
      ROW_NUMBER() OVER (ORDER BY cm.xp DESC, cm.local_reputation DESC) AS rn
    FROM public.community_members cm
    JOIN public.profiles p ON p.id = cm.user_id
    WHERE cm.community_id = p_community_id
      AND cm.is_banned = FALSE
    ORDER BY cm.xp DESC, cm.local_reputation DESC
    LIMIT p_limit
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
