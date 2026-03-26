-- ============================================================
-- NexusHub — Migração 003: Sistema de Chat
-- Baseado em ChatThread.smali e ChatMessage.smali
-- ============================================================

-- ========================
-- 1. CHAT THREADS (salas de chat)
-- ========================

CREATE TABLE public.chat_threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,  -- NULL para DMs globais
  
  -- Tipo de thread
  type public.chat_thread_type DEFAULT 'dm',
  
  -- Metadados do chat
  title TEXT,                                      -- Nome do chat (para grupo/público)
  icon_url TEXT,                                   -- Ícone do chat
  description TEXT DEFAULT '',
  background_url TEXT,                             -- Background customizado
  
  -- Configurações
  is_pinned BOOLEAN DEFAULT FALSE,
  is_announcement_only BOOLEAN DEFAULT FALSE,      -- Só admins podem falar
  is_voice_enabled BOOLEAN DEFAULT TRUE,
  is_video_enabled BOOLEAN DEFAULT FALSE,
  is_screen_room_enabled BOOLEAN DEFAULT FALSE,
  
  -- Moderação do chat
  host_id UUID REFERENCES public.profiles(id),     -- Criador/host do chat
  co_hosts JSONB DEFAULT '[]'::jsonb,              -- Array de UUIDs de co-hosts
  
  -- Anúncio fixado
  pinned_message_id UUID,                          -- Referência circular, será adicionada depois
  
  -- Estatísticas
  members_count INTEGER DEFAULT 0,
  last_message_at TIMESTAMPTZ,
  last_message_preview TEXT,
  last_message_author TEXT,
  
  -- Status
  status public.content_status DEFAULT 'ok',
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_threads_community ON public.chat_threads(community_id);
CREATE INDEX idx_chat_threads_type ON public.chat_threads(type);
CREATE INDEX idx_chat_threads_last_msg ON public.chat_threads(last_message_at DESC);

-- ========================
-- 2. MEMBROS DO CHAT (chat_members)
-- ========================

CREATE TABLE public.chat_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Status
  status public.chat_membership_status DEFAULT 'active',
  is_muted BOOLEAN DEFAULT FALSE,                  -- Notificações silenciadas
  
  -- Leitura
  last_read_at TIMESTAMPTZ DEFAULT NOW(),
  unread_count INTEGER DEFAULT 0,
  
  -- Metadata
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(thread_id, user_id)
);

CREATE INDEX idx_chat_members_thread ON public.chat_members(thread_id);
CREATE INDEX idx_chat_members_user ON public.chat_members(user_id);

-- ========================
-- 3. MENSAGENS DE CHAT (chat_messages)
-- ========================

CREATE TABLE public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Tipo de mensagem (ChatMessage.smali: 0-127)
  type public.chat_message_type DEFAULT 'text',
  
  -- Conteúdo
  content TEXT DEFAULT '',
  
  -- Mídia
  media_url TEXT,                                  -- URL da imagem/vídeo/áudio
  media_type TEXT,                                 -- 'image', 'video', 'audio', 'gif'
  media_duration INTEGER,                          -- Duração em segundos (voice note/video)
  media_thumbnail_url TEXT,
  
  -- Sticker
  sticker_id UUID,
  sticker_url TEXT,
  
  -- Reply (resposta a outra mensagem)
  reply_to_id UUID REFERENCES public.chat_messages(id),
  
  -- Compartilhamento
  shared_user_id UUID REFERENCES public.profiles(id),    -- Para type 'share_user'
  shared_url TEXT,                                        -- Para type 'share_url'
  shared_link_summary JSONB,                              -- {title, description, image}
  
  -- Gorjeta (para type 'system_tip')
  tip_amount INTEGER,
  
  -- Reações
  reactions JSONB DEFAULT '{}'::jsonb,             -- {"emoji": [user_id1, user_id2]}
  
  -- Status
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_by UUID REFERENCES public.profiles(id),
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_thread ON public.chat_messages(thread_id);
CREATE INDEX idx_chat_messages_created ON public.chat_messages(created_at DESC);
CREATE INDEX idx_chat_messages_author ON public.chat_messages(author_id);

-- Agora podemos adicionar a FK do pinned_message
ALTER TABLE public.chat_threads
  ADD CONSTRAINT fk_pinned_message
  FOREIGN KEY (pinned_message_id) REFERENCES public.chat_messages(id);

-- ========================
-- 4. CHAT BUBBLES (balões customizados)
-- ========================

CREATE TABLE public.chat_bubbles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  preview_url TEXT,                                -- Preview da bubble
  
  -- Assets
  bubble_image_url TEXT,                           -- Imagem 9-patch ou SVG
  bubble_config JSONB DEFAULT '{}'::jsonb,         -- {padding, borderRadius, colors, etc}
  
  -- Preço
  price_coins INTEGER DEFAULT 0,
  is_premium_only BOOLEAN DEFAULT FALSE,
  
  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 5. VOICE/VIDEO SESSIONS (sessões de chamada)
-- ========================

CREATE TABLE public.call_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  
  -- Tipo de chamada (1=Voice, 2=Video, 3=Avatar, 4=ScreenRoom)
  call_type INTEGER NOT NULL DEFAULT 1,
  
  -- Host
  host_id UUID NOT NULL REFERENCES public.profiles(id),
  
  -- Participantes atuais
  participants JSONB DEFAULT '[]'::jsonb,          -- Array de {user_id, joined_at, is_muted}
  max_participants INTEGER DEFAULT 10,
  
  -- Para Screening Room
  screen_room_url TEXT,                            -- URL do vídeo sendo assistido
  screen_room_position INTEGER DEFAULT 0,          -- Posição atual em segundos
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);
