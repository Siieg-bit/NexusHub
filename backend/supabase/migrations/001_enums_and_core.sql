-- ============================================================
-- NexusHub — Migração 001: Enums e Tabelas Core
-- Baseado na engenharia reversa do APK Amino (com.narvii.amino.master)
-- ============================================================

-- ========================
-- 1. TIPOS ENUMERADOS
-- ========================

-- Roles baseados nos valores exatos do APK (User.smali)
-- 0=member, 100=leader, 101=curator, 102=agent, 200=moderator, 201=admin, 253=news_feed, 254=system
CREATE TYPE public.user_role AS ENUM (
  'member',        -- 0: Membro comum
  'leader',        -- 100: Leader da comunidade
  'curator',       -- 101: Curator da comunidade
  'agent',         -- 102: Agent (criador/dono) da comunidade
  'moderator',     -- 200: Team NexusHub - Moderador global
  'admin',         -- 201: Team NexusHub - Admin global
  'news_feed',     -- 253: Conta de sistema para feed automático
  'system'         -- 254: Conta do sistema interno
);

-- Tipos de post (Blog.smali)
CREATE TYPE public.post_type AS ENUM (
  'normal',        -- 0
  'crosspost',     -- 1
  'repost',        -- 2
  'qa',            -- 3: Perguntas e Respostas
  'poll',          -- 4: Enquete
  'link',          -- 5: Post com link externo
  'quiz',          -- 6: Quiz interativo
  'image',         -- 7: Post de imagem
  'external'       -- 8: Post externo
);

-- Status de conteúdo (NVObject.smali)
CREATE TYPE public.content_status AS ENUM (
  'ok',            -- 0: Normal
  'pending',       -- 5: Aguardando aprovação
  'closed',        -- 3: Fechado
  'disabled',      -- 9: Desabilitado por moderação
  'deleted'        -- 10: Deletado
);

-- Tipos de chat thread (ChatThread.smali)
CREATE TYPE public.chat_thread_type AS ENUM (
  'dm',            -- 0: Mensagem direta (1:1)
  'group',         -- 1: Grupo privado
  'public'         -- 2: Chat público da comunidade
);

-- Tipos de mensagem de chat (ChatMessage.smali)
CREATE TYPE public.chat_message_type AS ENUM (
  'text',              -- 0: Texto normal
  'strike',            -- 1: Strike/aviso
  'voice_note',        -- 2: Nota de voz
  'sticker',           -- 3: Sticker
  'video',             -- 4: Mensagem de vídeo
  'share_url',         -- 50: Compartilhar URL
  'share_user',        -- 51: Compartilhar perfil
  'system_deleted',    -- 100: Mensagem deletada
  'system_join',       -- 101: Membro entrou
  'system_leave',      -- 102: Membro saiu
  'system_voice_start',-- 107: Voice chat iniciado
  'system_voice_end',  -- 110: Voice chat encerrado
  'system_screen_start',-- 114: Screening Room iniciado
  'system_screen_end', -- 115: Screening Room encerrado
  'system_tip',        -- 120: Gorjeta enviada
  'system_pin',        -- 121: Anúncio fixado
  'system_unpin',      -- 127: Anúncio desfixado
  'system_removed',    -- 117: Removido à força
  'system_admin_delete'-- 119: Deletado por admin
);

-- Tipo de join da comunidade (Community.smali)
CREATE TYPE public.community_join_type AS ENUM (
  'open',          -- 0: Qualquer um entra
  'request',       -- 1: Requer aprovação
  'invite'         -- 2: Somente convite
);

-- Status de listagem da comunidade
CREATE TYPE public.community_listed_status AS ENUM (
  'none',          -- 0
  'unlisted',      -- 1: Não aparece na busca
  'listed'         -- 2: Visível na busca
);

-- Tipos de flag/denúncia (extraído das strings do APK)
CREATE TYPE public.flag_type AS ENUM (
  'bullying',
  'art_theft',
  'inappropriate_content',
  'off_topic',
  'spam',
  'other'
);

-- Status da flag
CREATE TYPE public.flag_status AS ENUM (
  'pending',
  'resolved',
  'dismissed'
);

-- Nível de moderação (ModerationHistory.smali)
CREATE TYPE public.moderation_level AS ENUM (
  'none',          -- 0
  'curator',       -- 1
  'leader',        -- 2
  'team'           -- 3: Team NexusHub (iMod)
);

-- Severidade de moderação
CREATE TYPE public.moderation_severity AS ENUM (
  'default',
  'success',
  'warning',
  'danger'
);

-- Tipo de ação de moderação
CREATE TYPE public.moderation_action AS ENUM (
  'warn',
  'strike',
  'mute',
  'ban',
  'unban',
  'hide_post',
  'unhide_post',
  'feature_post',
  'unfeature_post',
  'promote',
  'demote',
  'delete_content',
  'transfer_agent'
);

-- Tipo de prêmio do Lucky Draw (LotteryLog.smali)
CREATE TYPE public.lottery_award_type AS ENUM (
  'none',          -- 0
  'coin',          -- 1
  'product'        -- 2
);

-- Tipo de item da loja
CREATE TYPE public.store_item_type AS ENUM (
  'avatar_frame',  -- 122
  'chat_bubble',   -- 116
  'sticker_pack',  -- 114
  'profile_background',
  'chat_background'
);

-- Nível de privacidade (User.smali)
CREATE TYPE public.privacy_level AS ENUM (
  'everyone',      -- 1: PRIVILEGE_EVERYONE
  'following',     -- 2: PRIVILEGE_MY_FOLLOWING
  'none'           -- 3: PRIVILEGE_NONE
);

-- Nível de segurança da conta
CREATE TYPE public.account_security_level AS ENUM (
  'ok',            -- 1
  'warning',       -- 2
  'danger'         -- 3
);

-- Status de membership do chat
CREATE TYPE public.chat_membership_status AS ENUM (
  'none',          -- 0
  'active',        -- 1
  'invite_sent',   -- 2
  'join_requested' -- 3
);

-- Status de following
CREATE TYPE public.following_status AS ENUM (
  'none',          -- 0
  'backward',      -- 1: Ele te segue
  'forward',       -- 2: Você segue ele
  'mutual'         -- 3: Mútuo
);

-- ========================
-- 2. TABELA DE PERFIS (profiles)
-- ========================
-- Estende auth.users do Supabase com campos do Amino User model

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  amino_id TEXT UNIQUE,                          -- ID customizável (@nickname)
  nickname TEXT NOT NULL DEFAULT '',
  is_nickname_verified BOOLEAN DEFAULT FALSE,
  icon_url TEXT,                                  -- Avatar
  banner_url TEXT,                                -- Banner do perfil global
  bio TEXT DEFAULT '',
  
  -- Roles globais (Team NexusHub)
  is_team_admin BOOLEAN DEFAULT FALSE,            -- role 201
  is_team_moderator BOOLEAN DEFAULT FALSE,        -- role 200
  is_system_account BOOLEAN DEFAULT FALSE,        -- roles 253/254
  
  -- Gamificação global
  level INTEGER DEFAULT 1,
  reputation INTEGER DEFAULT 0,
  
  -- Economia
  coins INTEGER DEFAULT 0,
  coins_float DOUBLE PRECISION DEFAULT 0.0,
  business_coins INTEGER DEFAULT 0,
  is_premium BOOLEAN DEFAULT FALSE,               -- Amino+ / NexusHub+
  premium_expires_at TIMESTAMPTZ,
  
  -- Estatísticas globais
  blogs_count INTEGER DEFAULT 0,
  posts_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  items_count INTEGER DEFAULT 0,                   -- Wiki entries
  joined_communities_count INTEGER DEFAULT 0,
  followers_count INTEGER DEFAULT 0,
  following_count INTEGER DEFAULT 0,
  
  -- Customização visual
  active_avatar_frame_id UUID,
  active_mood_sticker_id UUID,
  
  -- Privacidade
  privilege_chat_invite public.privacy_level DEFAULT 'everyone',
  privilege_comment_profile public.privacy_level DEFAULT 'everyone',
  
  -- Segurança
  security_level public.account_security_level DEFAULT 'ok',
  
  -- Check-in global
  consecutive_checkin_days INTEGER DEFAULT 0,
  last_checkin_at TIMESTAMPTZ,
  broken_streaks INTEGER DEFAULT 0,
  
  -- Onboarding
  has_completed_onboarding BOOLEAN DEFAULT FALSE,
  selected_interests JSONB DEFAULT '[]'::jsonb,
  
  -- Metadata
  online_status INTEGER DEFAULT 2,                 -- 1=Online, 2=Offline
  last_seen_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 3. TABELA DE COMUNIDADES (communities)
-- ========================

CREATE TABLE public.communities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  tagline TEXT DEFAULT '',
  description TEXT DEFAULT '',
  icon_url TEXT,
  banner_url TEXT,
  endpoint TEXT UNIQUE,                            -- Slug único da comunidade
  link TEXT,                                       -- Link de convite
  
  -- Configuração de acesso
  join_type public.community_join_type DEFAULT 'open',
  listed_status public.community_listed_status DEFAULT 'listed',
  is_searchable BOOLEAN DEFAULT TRUE,
  
  -- Estatísticas
  members_count INTEGER DEFAULT 0,
  posts_count INTEGER DEFAULT 0,
  community_heat REAL DEFAULT 0.0,                 -- Nível de atividade
  
  -- Idioma e categorias
  primary_language TEXT DEFAULT 'pt',
  category TEXT DEFAULT 'general',
  
  -- Referência ao Agent (criador/dono)
  agent_id UUID REFERENCES public.profiles(id),
  
  -- Tema visual customizado (ACM)
  theme_color TEXT DEFAULT '#0B0B0B',
  theme_pack JSONB DEFAULT '{}'::jsonb,
  
  -- Módulos configuráveis (ACM - Module.smali)
  configuration JSONB DEFAULT '{
    "post": true,
    "chat": true,
    "catalog": true,
    "featured": true,
    "ranking": true,
    "sharedFolder": true,
    "influencer": false,
    "externalContent": false,
    "topicCategories": true,
    "audioChat": true,
    "videoChat": false,
    "screenRoom": false,
    "publicChatRoom": true,
    "featuredPosts": true,
    "featuredMembers": true
  }'::jsonb,
  
  -- Status
  status public.content_status DEFAULT 'ok',
  probation_status INTEGER DEFAULT 0,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 4. MEMBROS DA COMUNIDADE (community_members)
-- ========================
-- Relacionamento N:N entre profiles e communities, com role LOCAL

CREATE TABLE public.community_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Role LOCAL dentro desta comunidade
  role public.user_role DEFAULT 'member',
  
  -- Perfil local (diferente do global)
  local_nickname TEXT,
  local_icon_url TEXT,
  local_banner_url TEXT,
  local_bio TEXT,
  
  -- Gamificação local
  local_level INTEGER DEFAULT 1,
  local_reputation INTEGER DEFAULT 0,
  xp INTEGER DEFAULT 0,
  
  -- Check-in local
  consecutive_checkin_days INTEGER DEFAULT 0,
  last_checkin_at TIMESTAMPTZ,
  has_checkin_today BOOLEAN DEFAULT FALSE,
  
  -- Títulos customizados (dados por Leaders)
  custom_titles JSONB DEFAULT '[]'::jsonb,         -- Array de {title, color}
  
  -- Customização local
  active_avatar_frame_id UUID,
  active_chat_bubble_id UUID,
  
  -- Status
  is_banned BOOLEAN DEFAULT FALSE,
  ban_expires_at TIMESTAMPTZ,
  is_muted BOOLEAN DEFAULT FALSE,
  mute_expires_at TIMESTAMPTZ,
  strike_count INTEGER DEFAULT 0,
  
  -- Metadata
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  last_active_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(community_id, user_id)
);

-- Índices para performance
CREATE INDEX idx_community_members_community ON public.community_members(community_id);
CREATE INDEX idx_community_members_user ON public.community_members(user_id);
CREATE INDEX idx_community_members_role ON public.community_members(role);

-- ========================
-- 5. INTERESSES (interests)
-- ========================
-- Para o onboarding (InterestData.smali)

CREATE TABLE public.interests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_name TEXT,
  category TEXT NOT NULL,                          -- Ex: "Fashion", "Spirituality"
  background_color TEXT DEFAULT '#333333',
  background_image TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 6. FOLLOWS (seguir/seguido)
-- ========================

CREATE TABLE public.follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);

CREATE INDEX idx_follows_follower ON public.follows(follower_id);
CREATE INDEX idx_follows_following ON public.follows(following_id);

-- ========================
-- 7. BLOQUEIOS (blocks)
-- ========================

CREATE TABLE public.blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id)
);

-- ========================
-- 8. PEDIDOS DE ENTRADA (community_join_requests)
-- ========================

CREATE TABLE public.community_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message TEXT DEFAULT '',
  status INTEGER DEFAULT 0,                        -- 0=pending, 1=approved, 2=rejected
  reviewed_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
