-- ============================================================
-- NexusHub — Migração 011: RPCs Faltantes
-- Cria todas as RPCs referenciadas pelo Flutter que não existiam
-- ============================================================

-- ========================
-- 1. transfer_coins — Transferir moedas entre usuários
-- ========================
CREATE OR REPLACE FUNCTION public.transfer_coins(
  p_receiver_id UUID,
  p_amount INTEGER
)
RETURNS JSONB AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_sender_balance INTEGER;
BEGIN
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('error', 'invalid_amount');
  END IF;

  IF v_sender_id = p_receiver_id THEN
    RETURN jsonb_build_object('error', 'cannot_transfer_to_self');
  END IF;

  -- Verificar se o receiver existe
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_receiver_id) THEN
    RETURN jsonb_build_object('error', 'user_not_found');
  END IF;

  SELECT coins INTO v_sender_balance FROM public.profiles WHERE id = v_sender_id;

  IF v_sender_balance < p_amount THEN
    RETURN jsonb_build_object('error', 'insufficient_coins', 'balance', v_sender_balance);
  END IF;

  -- Debitar sender
  UPDATE public.profiles
  SET coins = coins - p_amount, coins_float = coins_float - p_amount
  WHERE id = v_sender_id;

  -- Creditar receiver
  UPDATE public.profiles
  SET coins = coins + p_amount, coins_float = coins_float + p_amount
  WHERE id = p_receiver_id;

  -- Registrar transações
  INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, reference_id, description)
  VALUES
    (v_sender_id, -p_amount,
      (SELECT coins FROM public.profiles WHERE id = v_sender_id),
      'transfer_sent', p_receiver_id, 'Transferência enviada'),
    (p_receiver_id, p_amount,
      (SELECT coins FROM public.profiles WHERE id = p_receiver_id),
      'transfer_received', v_sender_id, 'Transferência recebida');

  RETURN jsonb_build_object('success', TRUE, 'amount', p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- 2. toggle_post_like — Curtir/descurtir post
-- ========================
CREATE OR REPLACE FUNCTION public.toggle_post_like(p_post_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.likes
    WHERE user_id = v_user_id AND post_id = p_post_id
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.likes WHERE user_id = v_user_id AND post_id = p_post_id;
    RETURN jsonb_build_object('liked', FALSE);
  ELSE
    INSERT INTO public.likes (user_id, post_id)
    VALUES (v_user_id, p_post_id)
    ON CONFLICT (user_id, post_id) DO NOTHING;
    RETURN jsonb_build_object('liked', TRUE);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- 3. get_user_profile — Buscar perfil completo de um usuário
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
    'nickname', v_profile.nickname,
    'icon_url', v_profile.icon_url,
    'bio', v_profile.bio,
    'amino_id', v_profile.amino_id,
    'level', v_profile.level,
    'xp', v_profile.xp,
    'coins', v_profile.coins,
    'global_role', v_profile.global_role,
    'is_verified', v_profile.is_verified,
    'is_online', v_profile.is_online,
    'last_online_at', v_profile.last_online_at,
    'created_at', v_profile.created_at,
    'followers_count', v_followers,
    'following_count', v_following,
    'posts_count', v_posts,
    'is_following', v_is_following,
    'is_blocked', v_is_blocked,
    'consecutive_checkin_days', v_profile.consecutive_checkin_days,
    'media_list', v_profile.media_list,
    'background_url', v_profile.background_url
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- 4. get_community_leaderboard — Ranking da comunidade
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
        'level', cm.level,
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

-- ========================
-- 5. delete_user_account — Excluir conta permanentemente
-- ========================
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Remover dados em ordem de dependência
  DELETE FROM public.likes WHERE user_id = v_user_id;
  DELETE FROM public.comments WHERE author_id = v_user_id;
  DELETE FROM public.bookmarks WHERE user_id = v_user_id;
  DELETE FROM public.poll_votes WHERE user_id = v_user_id;
  DELETE FROM public.quiz_attempts WHERE user_id = v_user_id;
  DELETE FROM public.follows WHERE follower_id = v_user_id OR following_id = v_user_id;
  DELETE FROM public.blocks WHERE blocker_id = v_user_id OR blocked_id = v_user_id;
  DELETE FROM public.tips WHERE sender_id = v_user_id OR receiver_id = v_user_id;
  DELETE FROM public.coin_transactions WHERE user_id = v_user_id;
  DELETE FROM public.user_purchases WHERE user_id = v_user_id;
  DELETE FROM public.checkins WHERE user_id = v_user_id;
  DELETE FROM public.lottery_logs WHERE user_id = v_user_id;
  DELETE FROM public.streak_repairs WHERE user_id = v_user_id;
  DELETE FROM public.chat_members WHERE user_id = v_user_id;
  DELETE FROM public.chat_messages WHERE sender_id = v_user_id;
  DELETE FROM public.notifications WHERE user_id = v_user_id OR actor_id = v_user_id;
  DELETE FROM public.push_tokens WHERE user_id = v_user_id;
  DELETE FROM public.device_fingerprints WHERE user_id = v_user_id;
  DELETE FROM public.flags WHERE reporter_id = v_user_id;
  DELETE FROM public.moderation_logs WHERE moderator_id = v_user_id;
  DELETE FROM public.strikes WHERE user_id = v_user_id;
  DELETE FROM public.leaderboard_entries WHERE user_id = v_user_id;
  DELETE FROM public.community_members WHERE user_id = v_user_id;
  DELETE FROM public.posts WHERE author_id = v_user_id;
  DELETE FROM public.wiki_entries WHERE author_id = v_user_id;
  DELETE FROM public.drafts WHERE user_id = v_user_id;
  DELETE FROM public.user_settings WHERE user_id = v_user_id;
  DELETE FROM public.ad_reward_logs WHERE user_id = v_user_id;
  DELETE FROM public.iap_receipts WHERE user_id = v_user_id;

  -- Deletar o perfil
  DELETE FROM public.profiles WHERE id = v_user_id;

  RETURN jsonb_build_object('success', TRUE, 'message', 'Conta excluída permanentemente');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- 6. request_data_export — Solicitar exportação de dados (LGPD)
-- ========================
CREATE OR REPLACE FUNCTION public.request_data_export()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_profile JSONB;
  v_posts JSONB;
  v_comments JSONB;
  v_messages JSONB;
  v_transactions JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Coletar perfil
  SELECT to_jsonb(p.*) INTO v_profile FROM public.profiles p WHERE id = v_user_id;

  -- Coletar posts (últimos 1000)
  SELECT COALESCE(jsonb_agg(to_jsonb(p.*)), '[]'::jsonb) INTO v_posts
  FROM (SELECT * FROM public.posts WHERE author_id = v_user_id ORDER BY created_at DESC LIMIT 1000) p;

  -- Coletar comentários (últimos 1000)
  SELECT COALESCE(jsonb_agg(to_jsonb(c.*)), '[]'::jsonb) INTO v_comments
  FROM (SELECT * FROM public.comments WHERE author_id = v_user_id ORDER BY created_at DESC LIMIT 1000) c;

  -- Coletar mensagens (últimas 1000)
  SELECT COALESCE(jsonb_agg(to_jsonb(m.*)), '[]'::jsonb) INTO v_messages
  FROM (SELECT * FROM public.chat_messages WHERE sender_id = v_user_id ORDER BY created_at DESC LIMIT 1000) m;

  -- Coletar transações (últimas 500)
  SELECT COALESCE(jsonb_agg(to_jsonb(t.*)), '[]'::jsonb) INTO v_transactions
  FROM (SELECT * FROM public.coin_transactions WHERE user_id = v_user_id ORDER BY created_at DESC LIMIT 500) t;

  -- Registrar notificação
  INSERT INTO public.notifications (user_id, type, title, body)
  VALUES (v_user_id, 'system', 'Exportação de Dados', 'Seus dados foram exportados com sucesso.');

  RETURN jsonb_build_object(
    'success', TRUE,
    'profile', v_profile,
    'posts', v_posts,
    'comments', v_comments,
    'messages', v_messages,
    'transactions', v_transactions,
    'exported_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- 7. revoke_all_other_sessions — Revogar todos os outros dispositivos
-- ========================
CREATE OR REPLACE FUNCTION public.revoke_all_other_sessions()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_deleted INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Deletar todos os fingerprints exceto o mais recente
  WITH latest AS (
    SELECT id FROM public.device_fingerprints
    WHERE user_id = v_user_id
    ORDER BY last_seen_at DESC
    LIMIT 1
  )
  DELETE FROM public.device_fingerprints
  WHERE user_id = v_user_id
    AND id NOT IN (SELECT id FROM latest);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('success', TRUE, 'revoked_count', v_deleted);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- 8. accept_invite — Aceitar convite para comunidade
-- ========================
CREATE OR REPLACE FUNCTION public.accept_invite(p_invite_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_community_id UUID;
  v_community_name TEXT;
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

  -- Adicionar como membro
  INSERT INTO public.community_members (community_id, user_id, role)
  VALUES (v_community_id, v_user_id, 'member');

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

-- ========================
-- 9. check_rate_limit — Verificar e registrar rate limit
-- ========================
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_action TEXT,
  p_max_requests INTEGER DEFAULT 60,
  p_window_minutes INTEGER DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_window_start TIMESTAMPTZ := NOW() - (p_window_minutes || ' minutes')::interval;
  v_count INTEGER;
BEGIN
  -- Contar requisições na janela
  SELECT COUNT(*) INTO v_count
  FROM public.rate_limits
  WHERE user_id = v_user_id
    AND action = p_action
    AND window_start >= v_window_start;

  IF v_count >= p_max_requests THEN
    RETURN jsonb_build_object('allowed', FALSE, 'retry_after_seconds', p_window_minutes * 60);
  END IF;

  -- Registrar requisição
  INSERT INTO public.rate_limits (user_id, action, window_start, window_end, request_count)
  VALUES (v_user_id, p_action, NOW(), NOW() + (p_window_minutes || ' minutes')::interval, 1)
  ON CONFLICT (user_id, action, window_start) DO UPDATE SET request_count = rate_limits.request_count + 1;

  RETURN jsonb_build_object('allowed', TRUE, 'remaining', p_max_requests - v_count - 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- 10. Enforce Privacy Levels — Verificar permissão de privacidade
-- ========================
CREATE OR REPLACE FUNCTION public.check_privacy_permission(
  p_target_user_id UUID,
  p_privilege_field TEXT  -- 'privilege_chat_invite' ou 'privilege_comment_profile'
)
RETURNS JSONB AS $$
DECLARE
  v_viewer_id UUID := auth.uid();
  v_level TEXT;
  v_is_following BOOLEAN;
BEGIN
  -- Buscar nível de privacidade
  EXECUTE format('SELECT %I FROM public.profiles WHERE id = $1', p_privilege_field)
  INTO v_level USING p_target_user_id;

  -- everyone = permitido
  IF v_level = 'everyone' THEN
    RETURN jsonb_build_object('allowed', TRUE);
  END IF;

  -- none = bloqueado
  IF v_level = 'none' THEN
    RETURN jsonb_build_object('allowed', FALSE, 'reason', 'privacy_blocked');
  END IF;

  -- following = verificar se o viewer segue o target
  SELECT EXISTS(
    SELECT 1 FROM public.follows
    WHERE follower_id = p_target_user_id AND following_id = v_viewer_id
  ) INTO v_is_following;

  IF v_is_following THEN
    RETURN jsonb_build_object('allowed', TRUE);
  ELSE
    RETURN jsonb_build_object('allowed', FALSE, 'reason', 'not_following');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
