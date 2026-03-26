-- ============================================================
-- NexusHub — Migração 004: Moderação, Flags e Logs
-- Baseado em Flag.smali, ModerationHistory.smali
-- ============================================================

-- ========================
-- 1. FLAGS / DENÚNCIAS (flags)
-- ========================

CREATE TABLE public.flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Alvo da denúncia (polimórfico)
  target_user_id UUID REFERENCES public.profiles(id),
  target_post_id UUID REFERENCES public.posts(id),
  target_wiki_id UUID REFERENCES public.wiki_entries(id),
  target_comment_id UUID REFERENCES public.comments(id),
  target_chat_message_id UUID REFERENCES public.chat_messages(id),
  target_chat_thread_id UUID REFERENCES public.chat_threads(id),
  
  -- Detalhes
  flag_type public.flag_type NOT NULL,
  reason TEXT DEFAULT '',                          -- Descrição adicional do reporter
  evidence_urls JSONB DEFAULT '[]'::jsonb,         -- Screenshots de evidência
  
  -- Resolução
  status public.flag_status DEFAULT 'pending',
  resolved_by UUID REFERENCES public.profiles(id),
  resolution_note TEXT DEFAULT '',
  resolved_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_flags_community ON public.flags(community_id);
CREATE INDEX idx_flags_status ON public.flags(status);
CREATE INDEX idx_flags_created ON public.flags(created_at DESC);

-- ========================
-- 2. MODERATION LOG (histórico de ações)
-- ========================

CREATE TABLE public.moderation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,  -- NULL para ações globais
  moderator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Ação
  action public.moderation_action NOT NULL,
  severity public.moderation_severity DEFAULT 'default',
  
  -- Alvo
  target_user_id UUID REFERENCES public.profiles(id),
  target_post_id UUID REFERENCES public.posts(id),
  target_wiki_id UUID REFERENCES public.wiki_entries(id),
  target_comment_id UUID REFERENCES public.comments(id),
  target_chat_thread_id UUID REFERENCES public.chat_threads(id),
  
  -- Detalhes
  reason TEXT DEFAULT '',
  details JSONB DEFAULT '{}'::jsonb,               -- Dados extras (ex: duração do ban)
  
  -- Para bans/mutes temporários
  duration_hours INTEGER,
  expires_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mod_logs_community ON public.moderation_logs(community_id);
CREATE INDEX idx_mod_logs_moderator ON public.moderation_logs(moderator_id);
CREATE INDEX idx_mod_logs_target_user ON public.moderation_logs(target_user_id);
CREATE INDEX idx_mod_logs_created ON public.moderation_logs(created_at DESC);

-- ========================
-- 3. STRIKES (advertências)
-- ========================

CREATE TABLE public.strikes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  issued_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  reason TEXT NOT NULL,
  evidence_urls JSONB DEFAULT '[]'::jsonb,
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  revoked_by UUID REFERENCES public.profiles(id),
  revoked_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ                           -- Strikes podem expirar
);

CREATE INDEX idx_strikes_user ON public.strikes(user_id);
CREATE INDEX idx_strikes_community ON public.strikes(community_id);

-- ========================
-- 4. BANS (banimentos)
-- ========================

CREATE TABLE public.bans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,  -- NULL = ban global
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  banned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  reason TEXT NOT NULL,
  
  -- Tipo
  is_permanent BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMPTZ,
  
  -- Device ban (anti-bot)
  device_id TEXT,                                  -- Fingerprint do dispositivo
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  unbanned_by UUID REFERENCES public.profiles(id),
  unbanned_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bans_user ON public.bans(user_id);
CREATE INDEX idx_bans_community ON public.bans(community_id);
CREATE INDEX idx_bans_device ON public.bans(device_id) WHERE device_id IS NOT NULL;

-- ========================
-- 5. GUIDELINES (regras da comunidade)
-- ========================

CREATE TABLE public.guidelines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'Community Guidelines',
  content TEXT NOT NULL DEFAULT '',                 -- Markdown
  updated_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(community_id)
);

-- ========================
-- 6. BROADCASTS (anúncios globais do Team NexusHub)
-- ========================

CREATE TABLE public.broadcasts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Escopo
  community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,  -- NULL = global
  
  -- Conteúdo
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  image_url TEXT,
  action_url TEXT,                                 -- Deep link
  
  -- Targeting
  target_roles JSONB DEFAULT '["member"]'::jsonb,  -- Quais roles recebem
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);
