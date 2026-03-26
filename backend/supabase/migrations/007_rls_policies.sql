-- ============================================================
-- NexusHub — Migração 007: Row Level Security (RLS) Policies
-- Segurança rigorosa baseada na hierarquia de roles do APK
-- ============================================================

-- ========================
-- HABILITAR RLS EM TODAS AS TABELAS
-- ========================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wiki_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wiki_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_bubbles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strikes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guidelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avatar_frames ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sticker_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stickers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lottery_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streak_repairs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iap_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_reward_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.featured_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_fingerprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_transfer_requests ENABLE ROW LEVEL SECURITY;

-- ========================
-- FUNÇÕES AUXILIARES DE SEGURANÇA
-- ========================

-- Verificar se o usuário é Team NexusHub (admin ou moderator global)
CREATE OR REPLACE FUNCTION public.is_team_member()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND (is_team_admin = TRUE OR is_team_moderator = TRUE)
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Verificar o role do usuário em uma comunidade específica
CREATE OR REPLACE FUNCTION public.get_community_role(p_community_id UUID)
RETURNS public.user_role AS $$
  SELECT COALESCE(
    (SELECT role FROM public.community_members
     WHERE community_id = p_community_id AND user_id = auth.uid()),
    'member'::public.user_role
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Verificar se é moderador da comunidade (agent, leader ou curator)
CREATE OR REPLACE FUNCTION public.is_community_moderator(p_community_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
    AND user_id = auth.uid()
    AND role IN ('agent', 'leader', 'curator')
  ) OR public.is_team_member();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Verificar se é leader ou agent da comunidade
CREATE OR REPLACE FUNCTION public.is_community_leader(p_community_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
    AND user_id = auth.uid()
    AND role IN ('agent', 'leader')
  ) OR public.is_team_member();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Verificar se é o agent (dono) da comunidade
CREATE OR REPLACE FUNCTION public.is_community_agent(p_community_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
    AND user_id = auth.uid()
    AND role = 'agent'
  ) OR public.is_team_member();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Verificar se o usuário é membro da comunidade
CREATE OR REPLACE FUNCTION public.is_community_member(p_community_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
    AND user_id = auth.uid()
    AND is_banned = FALSE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ========================
-- PROFILES
-- ========================

CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT USING (TRUE);

CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (id = auth.uid() OR public.is_team_member());

-- ========================
-- COMMUNITIES
-- ========================

CREATE POLICY "communities_select_all" ON public.communities
  FOR SELECT USING (TRUE);

CREATE POLICY "communities_insert_auth" ON public.communities
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "communities_update_agent" ON public.communities
  FOR UPDATE USING (
    public.is_community_agent(id) OR public.is_team_member()
  );

CREATE POLICY "communities_delete_team" ON public.communities
  FOR DELETE USING (public.is_team_member());

-- ========================
-- COMMUNITY MEMBERS
-- ========================

CREATE POLICY "cm_select_members" ON public.community_members
  FOR SELECT USING (TRUE);

CREATE POLICY "cm_insert_join" ON public.community_members
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "cm_update_self_or_mod" ON public.community_members
  FOR UPDATE USING (
    user_id = auth.uid()
    OR public.is_community_leader(community_id)
  );

CREATE POLICY "cm_delete_self_or_mod" ON public.community_members
  FOR DELETE USING (
    user_id = auth.uid()
    OR public.is_community_leader(community_id)
  );

-- ========================
-- POSTS
-- ========================

CREATE POLICY "posts_select_visible" ON public.posts
  FOR SELECT USING (
    status = 'ok' OR status = 'pending'
    OR author_id = auth.uid()
    OR public.is_community_moderator(community_id)
  );

CREATE POLICY "posts_insert_member" ON public.posts
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND public.is_community_member(community_id)
  );

CREATE POLICY "posts_update_own_or_mod" ON public.posts
  FOR UPDATE USING (
    author_id = auth.uid()
    OR public.is_community_moderator(community_id)
  );

CREATE POLICY "posts_delete_own_or_mod" ON public.posts
  FOR DELETE USING (
    author_id = auth.uid()
    OR public.is_community_moderator(community_id)
  );

-- ========================
-- WIKI ENTRIES
-- ========================

CREATE POLICY "wiki_select_visible" ON public.wiki_entries
  FOR SELECT USING (
    status = 'ok'
    OR author_id = auth.uid()
    OR public.is_community_moderator(community_id)
  );

CREATE POLICY "wiki_insert_member" ON public.wiki_entries
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND public.is_community_member(community_id)
  );

CREATE POLICY "wiki_update_own_or_mod" ON public.wiki_entries
  FOR UPDATE USING (
    author_id = auth.uid()
    OR public.is_community_moderator(community_id)
  );

-- ========================
-- COMMENTS
-- ========================

CREATE POLICY "comments_select_visible" ON public.comments
  FOR SELECT USING (status = 'ok' OR author_id = auth.uid());

CREATE POLICY "comments_insert_auth" ON public.comments
  FOR INSERT WITH CHECK (author_id = auth.uid());

CREATE POLICY "comments_update_own" ON public.comments
  FOR UPDATE USING (author_id = auth.uid());

CREATE POLICY "comments_delete_own_or_mod" ON public.comments
  FOR DELETE USING (author_id = auth.uid());

-- ========================
-- LIKES
-- ========================

CREATE POLICY "likes_select_all" ON public.likes
  FOR SELECT USING (TRUE);

CREATE POLICY "likes_insert_own" ON public.likes
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "likes_delete_own" ON public.likes
  FOR DELETE USING (user_id = auth.uid());

-- ========================
-- BOOKMARKS
-- ========================

CREATE POLICY "bookmarks_select_own" ON public.bookmarks
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "bookmarks_insert_own" ON public.bookmarks
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "bookmarks_delete_own" ON public.bookmarks
  FOR DELETE USING (user_id = auth.uid());

-- ========================
-- DRAFTS
-- ========================

CREATE POLICY "drafts_select_own" ON public.drafts
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "drafts_insert_own" ON public.drafts
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "drafts_update_own" ON public.drafts
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "drafts_delete_own" ON public.drafts
  FOR DELETE USING (user_id = auth.uid());

-- ========================
-- CHAT THREADS
-- ========================

CREATE POLICY "chat_threads_select_member" ON public.chat_threads
  FOR SELECT USING (
    type = 'public'
    OR EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE thread_id = id AND user_id = auth.uid()
    )
    OR public.is_team_member()
  );

CREATE POLICY "chat_threads_insert_auth" ON public.chat_threads
  FOR INSERT WITH CHECK (host_id = auth.uid());

CREATE POLICY "chat_threads_update_host" ON public.chat_threads
  FOR UPDATE USING (
    host_id = auth.uid()
    OR (community_id IS NOT NULL AND public.is_community_moderator(community_id))
  );

-- ========================
-- CHAT MESSAGES
-- ========================

CREATE POLICY "chat_messages_select_member" ON public.chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE thread_id = chat_messages.thread_id AND user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.chat_threads
      WHERE id = chat_messages.thread_id AND type = 'public'
    )
  );

CREATE POLICY "chat_messages_insert_member" ON public.chat_messages
  FOR INSERT WITH CHECK (author_id = auth.uid());

CREATE POLICY "chat_messages_update_own" ON public.chat_messages
  FOR UPDATE USING (author_id = auth.uid());

-- ========================
-- FLAGS (denúncias)
-- ========================

CREATE POLICY "flags_select_mod" ON public.flags
  FOR SELECT USING (
    reporter_id = auth.uid()
    OR public.is_community_moderator(community_id)
  );

CREATE POLICY "flags_insert_auth" ON public.flags
  FOR INSERT WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "flags_update_mod" ON public.flags
  FOR UPDATE USING (public.is_community_leader(community_id));

-- ========================
-- MODERATION LOGS
-- ========================

CREATE POLICY "mod_logs_select_mod" ON public.moderation_logs
  FOR SELECT USING (
    public.is_community_moderator(community_id)
    OR public.is_team_member()
  );

CREATE POLICY "mod_logs_insert_mod" ON public.moderation_logs
  FOR INSERT WITH CHECK (
    public.is_community_moderator(community_id)
    OR public.is_team_member()
  );

-- ========================
-- STRIKES
-- ========================

CREATE POLICY "strikes_select_target_or_mod" ON public.strikes
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_community_leader(community_id)
  );

CREATE POLICY "strikes_insert_leader" ON public.strikes
  FOR INSERT WITH CHECK (public.is_community_leader(community_id));

CREATE POLICY "strikes_update_leader" ON public.strikes
  FOR UPDATE USING (public.is_community_leader(community_id));

-- ========================
-- BANS
-- ========================

CREATE POLICY "bans_select_target_or_mod" ON public.bans
  FOR SELECT USING (
    user_id = auth.uid()
    OR (community_id IS NOT NULL AND public.is_community_leader(community_id))
    OR public.is_team_member()
  );

CREATE POLICY "bans_insert_leader" ON public.bans
  FOR INSERT WITH CHECK (
    (community_id IS NOT NULL AND public.is_community_leader(community_id))
    OR public.is_team_member()
  );

CREATE POLICY "bans_update_leader" ON public.bans
  FOR UPDATE USING (
    (community_id IS NOT NULL AND public.is_community_leader(community_id))
    OR public.is_team_member()
  );

-- ========================
-- NOTIFICATIONS
-- ========================

CREATE POLICY "notifications_select_own" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "notifications_update_own" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- ========================
-- COIN TRANSACTIONS
-- ========================

CREATE POLICY "coin_tx_select_own" ON public.coin_transactions
  FOR SELECT USING (user_id = auth.uid() OR public.is_team_member());

-- ========================
-- STORE ITEMS
-- ========================

CREATE POLICY "store_items_select_all" ON public.store_items
  FOR SELECT USING (is_active = TRUE OR public.is_team_member());

CREATE POLICY "store_items_manage_team" ON public.store_items
  FOR ALL USING (public.is_team_member());

-- ========================
-- USER PURCHASES
-- ========================

CREATE POLICY "purchases_select_own" ON public.user_purchases
  FOR SELECT USING (user_id = auth.uid());

-- ========================
-- FOLLOWS
-- ========================

CREATE POLICY "follows_select_all" ON public.follows
  FOR SELECT USING (TRUE);

CREATE POLICY "follows_insert_own" ON public.follows
  FOR INSERT WITH CHECK (follower_id = auth.uid());

CREATE POLICY "follows_delete_own" ON public.follows
  FOR DELETE USING (follower_id = auth.uid());

-- ========================
-- BLOCKS
-- ========================

CREATE POLICY "blocks_select_own" ON public.blocks
  FOR SELECT USING (blocker_id = auth.uid());

CREATE POLICY "blocks_insert_own" ON public.blocks
  FOR INSERT WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "blocks_delete_own" ON public.blocks
  FOR DELETE USING (blocker_id = auth.uid());

-- ========================
-- INTERESTS
-- ========================

CREATE POLICY "interests_select_all" ON public.interests
  FOR SELECT USING (TRUE);

CREATE POLICY "interests_manage_team" ON public.interests
  FOR ALL USING (public.is_team_member());

-- ========================
-- CHAT BUBBLES
-- ========================

CREATE POLICY "bubbles_select_all" ON public.chat_bubbles
  FOR SELECT USING (is_active = TRUE OR public.is_team_member());

-- ========================
-- AVATAR FRAMES
-- ========================

CREATE POLICY "frames_select_all" ON public.avatar_frames
  FOR SELECT USING (is_active = TRUE OR public.is_team_member());

-- ========================
-- STICKER PACKS & STICKERS
-- ========================

CREATE POLICY "sticker_packs_select_all" ON public.sticker_packs
  FOR SELECT USING (is_active = TRUE OR public.is_team_member());

CREATE POLICY "stickers_select_all" ON public.stickers
  FOR SELECT USING (TRUE);

-- ========================
-- TIPS
-- ========================

CREATE POLICY "tips_select_involved" ON public.tips
  FOR SELECT USING (sender_id = auth.uid() OR receiver_id = auth.uid());

-- ========================
-- CHECKINS
-- ========================

CREATE POLICY "checkins_select_own" ON public.checkins
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "checkins_insert_own" ON public.checkins
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ========================
-- LOTTERY LOGS
-- ========================

CREATE POLICY "lottery_select_own" ON public.lottery_logs
  FOR SELECT USING (user_id = auth.uid());

-- ========================
-- USER SETTINGS
-- ========================

CREATE POLICY "settings_select_own" ON public.user_settings
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "settings_insert_own" ON public.user_settings
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "settings_update_own" ON public.user_settings
  FOR UPDATE USING (user_id = auth.uid());

-- ========================
-- GUIDELINES
-- ========================

CREATE POLICY "guidelines_select_all" ON public.guidelines
  FOR SELECT USING (TRUE);

CREATE POLICY "guidelines_manage_leader" ON public.guidelines
  FOR ALL USING (public.is_community_leader(community_id));

-- ========================
-- BROADCASTS
-- ========================

CREATE POLICY "broadcasts_select_all" ON public.broadcasts
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY "broadcasts_manage_team" ON public.broadcasts
  FOR ALL USING (public.is_team_member());

-- ========================
-- SHARED FOLDERS & FILES
-- ========================

CREATE POLICY "shared_folders_select_member" ON public.shared_folders
  FOR SELECT USING (public.is_community_member(community_id));

CREATE POLICY "shared_files_select_member" ON public.shared_files
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.shared_folders sf
      WHERE sf.id = folder_id AND public.is_community_member(sf.community_id)
    )
  );

CREATE POLICY "shared_files_insert_member" ON public.shared_files
  FOR INSERT WITH CHECK (uploader_id = auth.uid());

-- ========================
-- LEADERBOARD
-- ========================

CREATE POLICY "leaderboard_select_all" ON public.leaderboard_entries
  FOR SELECT USING (TRUE);

-- ========================
-- FEATURED CONTENT
-- ========================

CREATE POLICY "featured_select_all" ON public.featured_content
  FOR SELECT USING (TRUE);

CREATE POLICY "featured_manage_mod" ON public.featured_content
  FOR ALL USING (public.is_community_moderator(community_id));

-- ========================
-- DEVICE FINGERPRINTS
-- ========================

CREATE POLICY "device_fp_select_team" ON public.device_fingerprints
  FOR SELECT USING (user_id = auth.uid() OR public.is_team_member());

-- ========================
-- PUSH TOKENS
-- ========================

CREATE POLICY "push_tokens_select_own" ON public.push_tokens
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "push_tokens_insert_own" ON public.push_tokens
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "push_tokens_update_own" ON public.push_tokens
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "push_tokens_delete_own" ON public.push_tokens
  FOR DELETE USING (user_id = auth.uid());

-- ========================
-- POLL VOTES, QUIZ ATTEMPTS, JOIN REQUESTS, AGENT TRANSFERS
-- ========================

CREATE POLICY "poll_options_select_all" ON public.poll_options
  FOR SELECT USING (TRUE);

CREATE POLICY "poll_votes_select_all" ON public.poll_votes
  FOR SELECT USING (TRUE);

CREATE POLICY "poll_votes_insert_own" ON public.poll_votes
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "quiz_questions_select_all" ON public.quiz_questions
  FOR SELECT USING (TRUE);

CREATE POLICY "quiz_options_select_all" ON public.quiz_options
  FOR SELECT USING (TRUE);

CREATE POLICY "quiz_attempts_select_own" ON public.quiz_attempts
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "quiz_attempts_insert_own" ON public.quiz_attempts
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "post_categories_select_all" ON public.post_categories
  FOR SELECT USING (TRUE);

CREATE POLICY "post_categories_manage_mod" ON public.post_categories
  FOR ALL USING (public.is_community_moderator(community_id));

CREATE POLICY "wiki_categories_select_all" ON public.wiki_categories
  FOR SELECT USING (TRUE);

CREATE POLICY "wiki_categories_manage_mod" ON public.wiki_categories
  FOR ALL USING (public.is_community_moderator(community_id));

CREATE POLICY "join_requests_select" ON public.community_join_requests
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_community_leader(community_id)
  );

CREATE POLICY "join_requests_insert" ON public.community_join_requests
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "join_requests_update_leader" ON public.community_join_requests
  FOR UPDATE USING (public.is_community_leader(community_id));

CREATE POLICY "agent_transfer_select" ON public.agent_transfer_requests
  FOR SELECT USING (
    from_agent_id = auth.uid() OR to_user_id = auth.uid()
  );

CREATE POLICY "agent_transfer_insert" ON public.agent_transfer_requests
  FOR INSERT WITH CHECK (from_agent_id = auth.uid());

CREATE POLICY "agent_transfer_update" ON public.agent_transfer_requests
  FOR UPDATE USING (to_user_id = auth.uid() OR from_agent_id = auth.uid());

-- ========================
-- RATE LIMITS & AD REWARDS & IAP & STREAK REPAIRS
-- ========================

CREATE POLICY "rate_limits_team" ON public.rate_limits
  FOR ALL USING (public.is_team_member());

CREATE POLICY "ad_rewards_select_own" ON public.ad_reward_logs
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "iap_select_own" ON public.iap_receipts
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "streak_repairs_select_own" ON public.streak_repairs
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "call_sessions_select" ON public.call_sessions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE thread_id = call_sessions.thread_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "chat_members_select" ON public.chat_members
  FOR SELECT USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.chat_members cm2
      WHERE cm2.thread_id = chat_members.thread_id AND cm2.user_id = auth.uid()
    )
  );

CREATE POLICY "chat_members_insert" ON public.chat_members
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "chat_members_update" ON public.chat_members
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "chat_members_delete" ON public.chat_members
  FOR DELETE USING (user_id = auth.uid());
