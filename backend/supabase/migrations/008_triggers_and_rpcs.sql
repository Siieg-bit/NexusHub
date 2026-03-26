-- ============================================================
-- NexusHub — Migração 008: Triggers e Funções RPC
-- ============================================================

-- ========================
-- TRIGGER: Criar profile automaticamente ao registrar
-- ========================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, nickname, icon_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Novo Usuário'),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL)
  );
  
  -- Criar configurações padrão
  INSERT INTO public.user_settings (user_id)
  VALUES (NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ========================
-- TRIGGER: Atualizar updated_at automaticamente
-- ========================

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_communities_updated_at
  BEFORE UPDATE ON public.communities
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_posts_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_wiki_updated_at
  BEFORE UPDATE ON public.wiki_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_comments_updated_at
  BEFORE UPDATE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_chat_threads_updated_at
  BEFORE UPDATE ON public.chat_threads
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ========================
-- TRIGGER: Atualizar contadores de likes
-- ========================

CREATE OR REPLACE FUNCTION public.handle_like_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.post_id IS NOT NULL THEN
      UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF NEW.wiki_id IS NOT NULL THEN
      UPDATE public.wiki_entries SET likes_count = likes_count + 1 WHERE id = NEW.wiki_id;
    ELSIF NEW.comment_id IS NOT NULL THEN
      UPDATE public.comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.post_id IS NOT NULL THEN
      UPDATE public.posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
    ELSIF OLD.wiki_id IS NOT NULL THEN
      UPDATE public.wiki_entries SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.wiki_id;
    ELSIF OLD.comment_id IS NOT NULL THEN
      UPDATE public.comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.comment_id;
    END IF;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_like_insert
  AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.handle_like_change();

CREATE TRIGGER trg_like_delete
  AFTER DELETE ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.handle_like_change();

-- ========================
-- TRIGGER: Atualizar contadores de comentários
-- ========================

CREATE OR REPLACE FUNCTION public.handle_comment_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.post_id IS NOT NULL THEN
      UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF NEW.wiki_id IS NOT NULL THEN
      UPDATE public.wiki_entries SET comments_count = comments_count + 1 WHERE id = NEW.wiki_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.post_id IS NOT NULL THEN
      UPDATE public.posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.post_id;
    ELSIF OLD.wiki_id IS NOT NULL THEN
      UPDATE public.wiki_entries SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.wiki_id;
    END IF;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_comment_insert
  AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.handle_comment_change();

CREATE TRIGGER trg_comment_delete
  AFTER DELETE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.handle_comment_change();

-- ========================
-- TRIGGER: Atualizar contadores de membros da comunidade
-- ========================

CREATE OR REPLACE FUNCTION public.handle_member_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.communities SET members_count = members_count + 1 WHERE id = NEW.community_id;
    UPDATE public.profiles SET joined_communities_count = joined_communities_count + 1 WHERE id = NEW.user_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.communities SET members_count = GREATEST(members_count - 1, 0) WHERE id = OLD.community_id;
    UPDATE public.profiles SET joined_communities_count = GREATEST(joined_communities_count - 1, 0) WHERE id = OLD.user_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_member_insert
  AFTER INSERT ON public.community_members
  FOR EACH ROW EXECUTE FUNCTION public.handle_member_change();

CREATE TRIGGER trg_member_delete
  AFTER DELETE ON public.community_members
  FOR EACH ROW EXECUTE FUNCTION public.handle_member_change();

-- ========================
-- TRIGGER: Atualizar contadores de follows
-- ========================

CREATE OR REPLACE FUNCTION public.handle_follow_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    UPDATE public.profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET following_count = GREATEST(following_count - 1, 0) WHERE id = OLD.follower_id;
    UPDATE public.profiles SET followers_count = GREATEST(followers_count - 1, 0) WHERE id = OLD.following_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_follow_insert
  AFTER INSERT ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.handle_follow_change();

CREATE TRIGGER trg_follow_delete
  AFTER DELETE ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.handle_follow_change();

-- ========================
-- TRIGGER: Atualizar contadores de posts na comunidade
-- ========================

CREATE OR REPLACE FUNCTION public.handle_post_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.communities SET posts_count = posts_count + 1 WHERE id = NEW.community_id;
    UPDATE public.profiles SET posts_count = posts_count + 1 WHERE id = NEW.author_id;
    
    -- Incrementar XP do membro na comunidade
    UPDATE public.community_members
    SET xp = xp + 10, local_reputation = local_reputation + 5
    WHERE community_id = NEW.community_id AND user_id = NEW.author_id;
    
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.communities SET posts_count = GREATEST(posts_count - 1, 0) WHERE id = OLD.community_id;
    UPDATE public.profiles SET posts_count = GREATEST(posts_count - 1, 0) WHERE id = OLD.author_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_insert
  AFTER INSERT ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.handle_post_change();

CREATE TRIGGER trg_post_delete
  AFTER DELETE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.handle_post_change();

-- ========================
-- TRIGGER: Atualizar preview da última mensagem no chat
-- ========================

CREATE OR REPLACE FUNCTION public.handle_chat_message()
RETURNS TRIGGER AS $$
DECLARE
  v_nickname TEXT;
BEGIN
  SELECT nickname INTO v_nickname FROM public.profiles WHERE id = NEW.author_id;
  
  UPDATE public.chat_threads
  SET last_message_at = NEW.created_at,
      last_message_preview = LEFT(NEW.content, 100),
      last_message_author = v_nickname
  WHERE id = NEW.thread_id;
  
  -- Incrementar unread para todos os membros exceto o autor
  UPDATE public.chat_members
  SET unread_count = unread_count + 1
  WHERE thread_id = NEW.thread_id AND user_id != NEW.author_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_chat_message_insert
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_chat_message();

-- ========================
-- RPC: Check-in diário com Lucky Draw
-- ========================

CREATE OR REPLACE FUNCTION public.daily_checkin(p_community_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_streak INTEGER;
  v_coins_earned INTEGER;
  v_xp_earned INTEGER;
  v_last_checkin TIMESTAMPTZ;
  v_today DATE := CURRENT_DATE;
BEGIN
  -- Verificar se já fez check-in hoje
  IF p_community_id IS NULL THEN
    SELECT last_checkin_at, consecutive_checkin_days INTO v_last_checkin, v_streak
    FROM public.profiles WHERE id = v_user_id;
    
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = v_today THEN
      RETURN jsonb_build_object('error', 'already_checked_in');
    END IF;
    
    -- Calcular streak
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = v_today - 1 THEN
      v_streak := COALESCE(v_streak, 0) + 1;
    ELSE
      v_streak := 1;
    END IF;
    
    -- Recompensas baseadas no streak
    v_coins_earned := LEAST(5 + v_streak, 25);  -- 5 base + 1 por dia, max 25
    v_xp_earned := 10;
    
    -- Atualizar perfil
    UPDATE public.profiles
    SET consecutive_checkin_days = v_streak,
        last_checkin_at = NOW(),
        coins = coins + v_coins_earned,
        coins_float = coins_float + v_coins_earned
    WHERE id = v_user_id;
    
  ELSE
    -- Check-in na comunidade
    SELECT last_checkin_at, consecutive_checkin_days INTO v_last_checkin, v_streak
    FROM public.community_members
    WHERE community_id = p_community_id AND user_id = v_user_id;
    
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = v_today THEN
      RETURN jsonb_build_object('error', 'already_checked_in');
    END IF;
    
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = v_today - 1 THEN
      v_streak := COALESCE(v_streak, 0) + 1;
    ELSE
      v_streak := 1;
    END IF;
    
    v_coins_earned := LEAST(5 + v_streak, 25);
    v_xp_earned := 15;
    
    UPDATE public.community_members
    SET consecutive_checkin_days = v_streak,
        last_checkin_at = NOW(),
        has_checkin_today = TRUE,
        xp = xp + v_xp_earned,
        local_reputation = local_reputation + 2
    WHERE community_id = p_community_id AND user_id = v_user_id;
    
    UPDATE public.profiles
    SET coins = coins + v_coins_earned,
        coins_float = coins_float + v_coins_earned
    WHERE id = v_user_id;
  END IF;
  
  -- Registrar check-in
  INSERT INTO public.checkins (user_id, community_id, coins_earned, xp_earned, streak_day)
  VALUES (v_user_id, p_community_id, v_coins_earned, v_xp_earned, v_streak);
  
  -- Registrar transação de moedas
  INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, description)
  VALUES (v_user_id, v_coins_earned,
    (SELECT coins FROM public.profiles WHERE id = v_user_id),
    'checkin', 'Check-in diário (dia ' || v_streak || ')');
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'streak', v_streak,
    'coins_earned', v_coins_earned,
    'xp_earned', v_xp_earned
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- RPC: Lucky Draw (após check-in)
-- ========================

CREATE OR REPLACE FUNCTION public.play_lucky_draw()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_roll INTEGER;
  v_award public.lottery_award_type;
  v_coins_won INTEGER := 0;
  v_today DATE := CURRENT_DATE;
BEGIN
  -- Verificar se já jogou hoje
  IF EXISTS (
    SELECT 1 FROM public.lottery_logs
    WHERE user_id = v_user_id AND played_at::date = v_today
  ) THEN
    RETURN jsonb_build_object('error', 'already_played_today');
  END IF;
  
  -- Verificar se fez check-in hoje
  IF NOT EXISTS (
    SELECT 1 FROM public.checkins
    WHERE user_id = v_user_id AND checked_in_at::date = v_today
  ) THEN
    RETURN jsonb_build_object('error', 'checkin_required');
  END IF;
  
  -- Sortear prêmio (60% moedas, 10% produto, 30% nada)
  v_roll := floor(random() * 100)::int;
  
  IF v_roll < 60 THEN
    v_award := 'coin';
    v_coins_won := (floor(random() * 20) + 5)::int;  -- 5-25 moedas
    
    UPDATE public.profiles
    SET coins = coins + v_coins_won,
        coins_float = coins_float + v_coins_won
    WHERE id = v_user_id;
    
    INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, description)
    VALUES (v_user_id, v_coins_won,
      (SELECT coins FROM public.profiles WHERE id = v_user_id),
      'lucky_draw', 'Lucky Draw - ' || v_coins_won || ' moedas');
      
  ELSIF v_roll < 70 THEN
    v_award := 'product';
    -- Produto será atribuído pela lógica do app
  ELSE
    v_award := 'none';
  END IF;
  
  -- Registrar resultado
  INSERT INTO public.lottery_logs (user_id, award_type, coins_won)
  VALUES (v_user_id, v_award, v_coins_won);
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'award_type', v_award::text,
    'coins_won', v_coins_won
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- RPC: Enviar Props (gorjeta)
-- ========================

CREATE OR REPLACE FUNCTION public.send_tip(
  p_receiver_id UUID,
  p_amount INTEGER,
  p_post_id UUID DEFAULT NULL,
  p_chat_message_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_sender_balance INTEGER;
BEGIN
  -- Validações
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('error', 'invalid_amount');
  END IF;
  
  IF v_sender_id = p_receiver_id THEN
    RETURN jsonb_build_object('error', 'cannot_tip_self');
  END IF;
  
  -- Verificar saldo
  SELECT coins INTO v_sender_balance FROM public.profiles WHERE id = v_sender_id;
  
  IF v_sender_balance < p_amount THEN
    RETURN jsonb_build_object('error', 'insufficient_coins');
  END IF;
  
  -- Debitar do sender
  UPDATE public.profiles
  SET coins = coins - p_amount, coins_float = coins_float - p_amount
  WHERE id = v_sender_id;
  
  -- Creditar ao receiver
  UPDATE public.profiles
  SET coins = coins + p_amount, coins_float = coins_float + p_amount
  WHERE id = p_receiver_id;
  
  -- Registrar tip
  INSERT INTO public.tips (sender_id, receiver_id, amount, post_id, chat_message_id)
  VALUES (v_sender_id, p_receiver_id, p_amount, p_post_id, p_chat_message_id);
  
  -- Registrar transações
  INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, reference_id, description)
  VALUES
    (v_sender_id, -p_amount, (SELECT coins FROM public.profiles WHERE id = v_sender_id), 'tip_sent', p_receiver_id, 'Props enviados'),
    (p_receiver_id, p_amount, (SELECT coins FROM public.profiles WHERE id = p_receiver_id), 'tip_received', v_sender_id, 'Props recebidos');
  
  -- Atualizar total de tips no post
  IF p_post_id IS NOT NULL THEN
    UPDATE public.posts SET tips_total = tips_total + p_amount WHERE id = p_post_id;
  END IF;
  
  RETURN jsonb_build_object('success', TRUE, 'amount', p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- RPC: Comprar item da loja
-- ========================

CREATE OR REPLACE FUNCTION public.purchase_store_item(p_item_id UUID, p_community_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_item RECORD;
  v_balance INTEGER;
BEGIN
  -- Buscar item
  SELECT * INTO v_item FROM public.store_items WHERE id = p_item_id AND is_active = TRUE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'item_not_found');
  END IF;
  
  -- Verificar limite de compras
  IF v_item.max_purchases IS NOT NULL AND v_item.current_purchases >= v_item.max_purchases THEN
    RETURN jsonb_build_object('error', 'sold_out');
  END IF;
  
  -- Verificar se já comprou
  IF EXISTS (SELECT 1 FROM public.user_purchases WHERE user_id = v_user_id AND item_id = p_item_id) THEN
    RETURN jsonb_build_object('error', 'already_purchased');
  END IF;
  
  -- Verificar saldo
  SELECT coins INTO v_balance FROM public.profiles WHERE id = v_user_id;
  
  IF v_balance < v_item.price_coins THEN
    RETURN jsonb_build_object('error', 'insufficient_coins');
  END IF;
  
  -- Debitar
  UPDATE public.profiles
  SET coins = coins - v_item.price_coins, coins_float = coins_float - v_item.price_coins
  WHERE id = v_user_id;
  
  -- Registrar compra
  INSERT INTO public.user_purchases (user_id, item_id, price_paid, equipped_in_community)
  VALUES (v_user_id, p_item_id, v_item.price_coins, p_community_id);
  
  -- Atualizar contador de compras
  UPDATE public.store_items SET current_purchases = current_purchases + 1 WHERE id = p_item_id;
  
  -- Registrar transação
  INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, reference_id, description)
  VALUES (v_user_id, -v_item.price_coins,
    (SELECT coins FROM public.profiles WHERE id = v_user_id),
    'purchase', p_item_id, 'Compra: ' || v_item.name);
  
  RETURN jsonb_build_object('success', TRUE, 'item_name', v_item.name, 'price', v_item.price_coins);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- RPC: Ação de moderação
-- ========================

CREATE OR REPLACE FUNCTION public.moderate_user(
  p_community_id UUID,
  p_target_user_id UUID,
  p_action public.moderation_action,
  p_reason TEXT DEFAULT '',
  p_duration_hours INTEGER DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_moderator_id UUID := auth.uid();
  v_moderator_role public.user_role;
  v_target_role public.user_role;
  v_expires TIMESTAMPTZ;
BEGIN
  -- Obter roles
  SELECT role INTO v_moderator_role FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_moderator_id;
  
  SELECT role INTO v_target_role FROM public.community_members
  WHERE community_id = p_community_id AND user_id = p_target_user_id;
  
  -- Verificar hierarquia: não pode moderar alguém de cargo igual ou superior
  IF v_target_role IN ('agent', 'leader') AND v_moderator_role = 'curator' THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;
  
  IF v_target_role = 'agent' AND v_moderator_role = 'leader' THEN
    RETURN jsonb_build_object('error', 'cannot_moderate_agent');
  END IF;
  
  -- Calcular expiração
  IF p_duration_hours IS NOT NULL THEN
    v_expires := NOW() + (p_duration_hours || ' hours')::interval;
  END IF;
  
  -- Executar ação
  CASE p_action
    WHEN 'ban' THEN
      UPDATE public.community_members
      SET is_banned = TRUE, ban_expires_at = v_expires
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      
      INSERT INTO public.bans (community_id, user_id, banned_by, reason, is_permanent, expires_at)
      VALUES (p_community_id, p_target_user_id, v_moderator_id, p_reason, p_duration_hours IS NULL, v_expires);
      
    WHEN 'unban' THEN
      UPDATE public.community_members
      SET is_banned = FALSE, ban_expires_at = NULL
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      
      UPDATE public.bans SET is_active = FALSE, unbanned_by = v_moderator_id, unbanned_at = NOW()
      WHERE community_id = p_community_id AND user_id = p_target_user_id AND is_active = TRUE;
      
    WHEN 'mute' THEN
      UPDATE public.community_members
      SET is_muted = TRUE, mute_expires_at = v_expires
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      
    WHEN 'strike' THEN
      INSERT INTO public.strikes (community_id, user_id, issued_by, reason, expires_at)
      VALUES (p_community_id, p_target_user_id, v_moderator_id, p_reason, v_expires);
      
      UPDATE public.community_members
      SET strike_count = strike_count + 1
      WHERE community_id = p_community_id AND user_id = p_target_user_id;
      
    WHEN 'warn' THEN
      -- Apenas registra no log
      NULL;
      
    WHEN 'promote' THEN
      IF v_moderator_role NOT IN ('agent', 'leader') THEN
        RETURN jsonb_build_object('error', 'only_leaders_can_promote');
      END IF;
      -- Lógica de promoção será definida pelo caller
      
    WHEN 'demote' THEN
      IF v_moderator_role != 'agent' THEN
        RETURN jsonb_build_object('error', 'only_agent_can_demote');
      END IF;
      
    ELSE
      NULL;
  END CASE;
  
  -- Registrar no log
  INSERT INTO public.moderation_logs (community_id, moderator_id, action, target_user_id, reason, duration_hours, expires_at)
  VALUES (p_community_id, v_moderator_id, p_action, p_target_user_id, p_reason, p_duration_hours, v_expires);
  
  RETURN jsonb_build_object('success', TRUE, 'action', p_action::text);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- RPC: Criar comunidade (com Agent correto)
-- ========================

CREATE OR REPLACE FUNCTION public.create_community(
  p_name TEXT,
  p_tagline TEXT DEFAULT '',
  p_description TEXT DEFAULT '',
  p_category TEXT DEFAULT 'general',
  p_join_type public.community_join_type DEFAULT 'open'
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_community_id UUID;
BEGIN
  -- Criar comunidade
  INSERT INTO public.communities (name, tagline, description, category, join_type, agent_id)
  VALUES (p_name, p_tagline, p_description, p_category, p_join_type, v_user_id)
  RETURNING id INTO v_community_id;
  
  -- Adicionar criador como AGENT (não leader!)
  INSERT INTO public.community_members (community_id, user_id, role)
  VALUES (v_community_id, v_user_id, 'agent');
  
  -- Criar guidelines padrão
  INSERT INTO public.guidelines (community_id, content)
  VALUES (v_community_id, '# Regras da Comunidade\n\nSeja respeitoso e siga as regras.');
  
  -- Criar shared folder
  INSERT INTO public.shared_folders (community_id)
  VALUES (v_community_id);
  
  RETURN jsonb_build_object('success', TRUE, 'community_id', v_community_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- RPC: Streak Repair
-- ========================

CREATE OR REPLACE FUNCTION public.repair_streak(p_community_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_broken INTEGER;
  v_cost INTEGER;
  v_balance INTEGER;
BEGIN
  IF p_community_id IS NULL THEN
    SELECT broken_streaks, coins INTO v_broken, v_balance FROM public.profiles WHERE id = v_user_id;
  ELSE
    SELECT broken_streaks INTO v_broken FROM public.profiles WHERE id = v_user_id;
    SELECT coins INTO v_balance FROM public.profiles WHERE id = v_user_id;
  END IF;
  
  IF v_broken <= 0 THEN
    RETURN jsonb_build_object('error', 'no_broken_streak');
  END IF;
  
  -- Custo: 10 moedas por dia perdido
  v_cost := v_broken * 10;
  
  IF v_balance < v_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_coins', 'cost', v_cost);
  END IF;
  
  -- Debitar
  UPDATE public.profiles
  SET coins = coins - v_cost,
      coins_float = coins_float - v_cost,
      broken_streaks = 0
  WHERE id = v_user_id;
  
  -- Registrar
  INSERT INTO public.streak_repairs (user_id, broken_days, cost_coins)
  VALUES (v_user_id, v_broken, v_cost);
  
  INSERT INTO public.coin_transactions (user_id, amount, balance_after, source, description)
  VALUES (v_user_id, -v_cost,
    (SELECT coins FROM public.profiles WHERE id = v_user_id),
    'streak_repair', 'Reparo de ofensiva (' || v_broken || ' dias)');
  
  RETURN jsonb_build_object('success', TRUE, 'cost', v_cost, 'days_repaired', v_broken);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
