-- ============================================================
-- NexusHub — Migração 006: Notificações, Shared Folder, Leaderboards
-- ============================================================

-- ========================
-- 1. NOTIFICAÇÕES (notifications)
-- ========================

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Tipo
  type TEXT NOT NULL,                              -- 'like', 'comment', 'follow', 'mention', 'tip', 'strike', 'broadcast', 'chat_invite', 'wiki_approved', 'wiki_rejected', 'role_change', 'join_request'
  
  -- Conteúdo
  title TEXT NOT NULL,
  body TEXT DEFAULT '',
  image_url TEXT,
  
  -- Referências
  actor_id UUID REFERENCES public.profiles(id),    -- Quem causou a notificação
  community_id UUID REFERENCES public.communities(id),
  post_id UUID REFERENCES public.posts(id),
  wiki_id UUID REFERENCES public.wiki_entries(id),
  comment_id UUID REFERENCES public.comments(id),
  chat_thread_id UUID REFERENCES public.chat_threads(id),
  
  -- Deep link
  action_url TEXT,                                 -- Rota interna do app
  
  -- Status
  is_read BOOLEAN DEFAULT FALSE,
  
  -- Agrupamento (ex: "5 pessoas curtiram seu post")
  group_key TEXT,                                  -- Chave de agrupamento
  group_count INTEGER DEFAULT 1,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON public.notifications(user_id);
CREATE INDEX idx_notifications_read ON public.notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_created ON public.notifications(created_at DESC);

-- ========================
-- 2. PUSH TOKENS (tokens de push notification)
-- ========================

CREATE TABLE public.push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL,                          -- 'ios', 'android', 'web'
  device_id TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, token)
);

-- ========================
-- 3. SHARED FOLDER (pasta compartilhada da comunidade)
-- ========================

CREATE TABLE public.shared_folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'Shared Folder',
  description TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(community_id)
);

CREATE TABLE public.shared_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  folder_id UUID NOT NULL REFERENCES public.shared_folders(id) ON DELETE CASCADE,
  uploader_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Arquivo
  file_url TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT,                                  -- MIME type
  file_size INTEGER,                               -- Bytes
  thumbnail_url TEXT,
  
  -- Metadata
  description TEXT DEFAULT '',
  downloads_count INTEGER DEFAULT 0,
  status public.content_status DEFAULT 'ok',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 4. LEADERBOARDS (rankings)
-- ========================

CREATE TABLE public.leaderboard_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Tipo de ranking
  board_type TEXT NOT NULL,                        -- 'checkin', 'quiz', 'reputation', 'hall_of_fame'
  
  -- Pontuação
  score INTEGER DEFAULT 0,
  rank INTEGER,
  
  -- Período
  period TEXT DEFAULT 'all_time',                  -- 'daily', 'weekly', 'monthly', 'all_time'
  period_start DATE,
  period_end DATE,
  
  -- Metadata
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(community_id, user_id, board_type, period, period_start)
);

CREATE INDEX idx_leaderboard_community ON public.leaderboard_entries(community_id);
CREATE INDEX idx_leaderboard_type ON public.leaderboard_entries(board_type);
CREATE INDEX idx_leaderboard_score ON public.leaderboard_entries(score DESC);

-- ========================
-- 5. FEATURED CONTENT (conteúdo destacado)
-- ========================

CREATE TABLE public.featured_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  
  -- Alvo
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  wiki_id UUID REFERENCES public.wiki_entries(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,       -- Featured Member
  
  -- Tipo
  type TEXT NOT NULL,                              -- 'post', 'wiki', 'member'
  
  -- Quem destacou
  featured_by UUID NOT NULL REFERENCES public.profiles(id),
  
  -- Metadata
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

-- ========================
-- 6. DEVICE FINGERPRINTS (anti-bot)
-- ========================

CREATE TABLE public.device_fingerprints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Fingerprint
  device_id TEXT NOT NULL,
  device_model TEXT,
  os_version TEXT,
  app_version TEXT,
  ip_address INET,
  
  -- Status
  is_banned BOOLEAN DEFAULT FALSE,
  banned_reason TEXT,
  
  -- Metadata
  first_seen_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_device_fp_device ON public.device_fingerprints(device_id);
CREATE INDEX idx_device_fp_user ON public.device_fingerprints(user_id);
CREATE INDEX idx_device_fp_banned ON public.device_fingerprints(is_banned) WHERE is_banned = TRUE;

-- ========================
-- 7. RATE LIMITING (controle de taxa)
-- ========================

CREATE TABLE public.rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  ip_address INET,
  
  -- Ação
  action_type TEXT NOT NULL,                       -- 'create_post', 'create_comment', 'send_message', 'register', 'login', 'flag'
  
  -- Contagem
  request_count INTEGER DEFAULT 1,
  window_start TIMESTAMPTZ DEFAULT NOW(),
  window_end TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_rate_limits_user ON public.rate_limits(user_id);
CREATE INDEX idx_rate_limits_ip ON public.rate_limits(ip_address);
CREATE INDEX idx_rate_limits_window ON public.rate_limits(window_start, window_end);

-- ========================
-- 8. CONFIGURAÇÕES DO USUÁRIO (user_settings)
-- ========================

CREATE TABLE public.user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Notificações
  push_enabled BOOLEAN DEFAULT TRUE,
  push_likes BOOLEAN DEFAULT TRUE,
  push_comments BOOLEAN DEFAULT TRUE,
  push_follows BOOLEAN DEFAULT TRUE,
  push_chat BOOLEAN DEFAULT TRUE,
  push_tips BOOLEAN DEFAULT TRUE,
  push_community_updates BOOLEAN DEFAULT TRUE,
  
  -- Aparência
  theme_mode TEXT DEFAULT 'dark',                  -- 'dark', 'light', 'system'
  language TEXT DEFAULT 'pt-BR',
  
  -- Privacidade
  show_online_status BOOLEAN DEFAULT TRUE,
  allow_dm_from TEXT DEFAULT 'everyone',           -- 'everyone', 'following', 'none'
  
  -- Metadata
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id)
);

-- ========================
-- 9. AGENT TRANSFER REQUESTS (transferência de posse)
-- ========================

CREATE TABLE public.agent_transfer_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  from_agent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Status
  status INTEGER DEFAULT 0,                        -- 0=pending, 1=accepted, 2=rejected, 3=cancelled
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ
);
