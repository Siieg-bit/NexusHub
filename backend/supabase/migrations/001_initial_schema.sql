-- ============================================================================
-- AMINO CLONE - MIGRATION 001: SCHEMA INICIAL
-- Plataforma de Comunidades Sociais com Chat, Feed e Gamificação
-- Backend: Supabase (PostgreSQL + Auth + Realtime + Storage)
-- ============================================================================

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE user_online_status AS ENUM ('online', 'offline', 'idle');
CREATE TYPE community_join_type AS ENUM ('open', 'request', 'invite_only');
CREATE TYPE member_role AS ENUM ('member', 'curator', 'leader', 'agent');
CREATE TYPE post_type AS ENUM ('blog', 'image', 'link', 'poll', 'quiz', 'wiki');
CREATE TYPE post_status AS ENUM ('published', 'draft', 'hidden', 'deleted');
CREATE TYPE feature_type AS ENUM ('none', 'featured', 'pinned');
CREATE TYPE comment_type AS ENUM ('text', 'sticker', 'image');
CREATE TYPE message_type AS ENUM ('text', 'image', 'sticker', 'system', 'voice');
CREATE TYPE chat_type AS ENUM ('community', 'private', 'group');
CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'resolved', 'dismissed');
CREATE TYPE moderation_action AS ENUM ('warn', 'mute', 'ban', 'delete_content');
CREATE TYPE notification_type AS ENUM (
    'like', 'comment', 'follow', 'mention',
    'chat_message', 'community_invite', 'level_up',
    'post_featured', 'moderation'
);

-- ============================================================================
-- TABELA: profiles (extensão do auth.users do Supabase)
-- ============================================================================

CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    amino_id VARCHAR(30) UNIQUE NOT NULL,
    nickname VARCHAR(50) NOT NULL,
    email VARCHAR(255),
    avatar_url TEXT,
    banner_url TEXT,
    bio TEXT DEFAULT '',
    global_level INT DEFAULT 1 CHECK (global_level >= 1),
    reputation INT DEFAULT 0 CHECK (reputation >= 0),
    xp INT DEFAULT 0 CHECK (xp >= 0),
    coins INT DEFAULT 0 CHECK (coins >= 0),
    online_status user_online_status DEFAULT 'offline',
    is_verified BOOLEAN DEFAULT FALSE,
    is_premium BOOLEAN DEFAULT FALSE,
    consecutive_check_in_days INT DEFAULT 0,
    last_check_in_at TIMESTAMPTZ,
    posts_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    followers_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    communities_count INT DEFAULT 0,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para profiles
CREATE INDEX idx_profiles_amino_id ON public.profiles(amino_id);
CREATE INDEX idx_profiles_nickname ON public.profiles(nickname);
CREATE INDEX idx_profiles_online_status ON public.profiles(online_status);
CREATE INDEX idx_profiles_global_level ON public.profiles(global_level DESC);
CREATE INDEX idx_profiles_reputation ON public.profiles(reputation DESC);

-- ============================================================================
-- TABELA: user_follows (sistema de seguidores)
-- ============================================================================

CREATE TABLE public.user_follows (
    follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id),
    CHECK (follower_id != following_id)
);

CREATE INDEX idx_user_follows_following ON public.user_follows(following_id);

-- ============================================================================
-- TABELA: communities
-- ============================================================================

CREATE TABLE public.communities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    tagline VARCHAR(200),
    description TEXT,
    icon_url TEXT,
    banner_url TEXT,
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    primary_language VARCHAR(10) DEFAULT 'pt-BR',
    join_type community_join_type DEFAULT 'open',
    is_searchable BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    members_count INT DEFAULT 0,
    posts_count INT DEFAULT 0,
    online_members_count INT DEFAULT 0,
    theme_color VARCHAR(7) DEFAULT '#6C5CE7',
    theme_config JSONB DEFAULT '{}',
    guidelines TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_communities_owner ON public.communities(owner_id);
CREATE INDEX idx_communities_name ON public.communities(name);
CREATE INDEX idx_communities_members_count ON public.communities(members_count DESC);
CREATE INDEX idx_communities_created_at ON public.communities(created_at DESC);
CREATE INDEX idx_communities_searchable ON public.communities(is_searchable) WHERE is_searchable = TRUE;

-- ============================================================================
-- TABELA: community_members
-- ============================================================================

CREATE TABLE public.community_members (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    role member_role DEFAULT 'member',
    reputation INT DEFAULT 0,
    xp INT DEFAULT 0,
    is_muted BOOLEAN DEFAULT FALSE,
    is_banned BOOLEAN DEFAULT FALSE,
    muted_until TIMESTAMPTZ,
    banned_until TIMESTAMPTZ,
    title VARCHAR(50),
    title_color VARCHAR(7),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, community_id)
);

CREATE INDEX idx_community_members_community ON public.community_members(community_id);
CREATE INDEX idx_community_members_role ON public.community_members(community_id, role);
CREATE INDEX idx_community_members_joined ON public.community_members(joined_at DESC);

-- ============================================================================
-- TABELA: posts (Feed/Blog/Wiki)
-- ============================================================================

CREATE TABLE public.posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title VARCHAR(300),
    content TEXT NOT NULL,
    media_urls JSONB DEFAULT '[]',
    post_type post_type DEFAULT 'blog',
    status post_status DEFAULT 'published',
    feature_type feature_type DEFAULT 'none',
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    views_count INT DEFAULT 0,
    share_count INT DEFAULT 0,
    is_global BOOLEAN DEFAULT FALSE,
    poll_options JSONB,
    quiz_questions JSONB,
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_posts_community ON public.posts(community_id, created_at DESC);
CREATE INDEX idx_posts_author ON public.posts(author_id, created_at DESC);
CREATE INDEX idx_posts_type ON public.posts(community_id, post_type);
CREATE INDEX idx_posts_featured ON public.posts(community_id, feature_type) WHERE feature_type != 'none';
CREATE INDEX idx_posts_status ON public.posts(status) WHERE status = 'published';
CREATE INDEX idx_posts_likes ON public.posts(community_id, likes_count DESC);
CREATE INDEX idx_posts_tags ON public.posts USING GIN(tags);

-- ============================================================================
-- TABELA: post_likes
-- ============================================================================

CREATE TABLE public.post_likes (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX idx_post_likes_post ON public.post_likes(post_id);

-- ============================================================================
-- TABELA: comments
-- ============================================================================

CREATE TABLE public.comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    comment_type comment_type DEFAULT 'text',
    media_url TEXT,
    sticker_id VARCHAR(50),
    likes_count INT DEFAULT 0,
    replies_count INT DEFAULT 0,
    is_hidden BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_comments_post ON public.comments(post_id, created_at ASC);
CREATE INDEX idx_comments_author ON public.comments(author_id);
CREATE INDEX idx_comments_parent ON public.comments(parent_id) WHERE parent_id IS NOT NULL;

-- ============================================================================
-- TABELA: comment_likes
-- ============================================================================

CREATE TABLE public.comment_likes (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    comment_id UUID NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, comment_id)
);

-- ============================================================================
-- TABELA: chat_rooms
-- ============================================================================

CREATE TABLE public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,
    name VARCHAR(100),
    description TEXT,
    icon_url TEXT,
    background_url TEXT,
    chat_type chat_type DEFAULT 'community',
    creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    members_count INT DEFAULT 0,
    max_members INT DEFAULT 1000,
    last_message_at TIMESTAMPTZ,
    last_message_preview TEXT,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_rooms_community ON public.chat_rooms(community_id);
CREATE INDEX idx_chat_rooms_type ON public.chat_rooms(chat_type);
CREATE INDEX idx_chat_rooms_last_message ON public.chat_rooms(last_message_at DESC);

-- ============================================================================
-- TABELA: chat_room_members
-- ============================================================================

CREATE TABLE public.chat_room_members (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    chat_room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    is_admin BOOLEAN DEFAULT FALSE,
    is_muted BOOLEAN DEFAULT FALSE,
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, chat_room_id)
);

CREATE INDEX idx_chat_room_members_room ON public.chat_room_members(chat_room_id);

-- ============================================================================
-- TABELA: messages (Chat Realtime)
-- ============================================================================

CREATE TABLE public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT,
    message_type message_type DEFAULT 'text',
    media_url TEXT,
    sticker_id VARCHAR(50),
    reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_chat_room ON public.messages(chat_room_id, created_at DESC);
CREATE INDEX idx_messages_sender ON public.messages(sender_id);
CREATE INDEX idx_messages_created ON public.messages(created_at DESC);

-- ============================================================================
-- TABELA: wiki_entries
-- ============================================================================

CREATE TABLE public.wiki_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title VARCHAR(300) NOT NULL,
    content TEXT NOT NULL,
    cover_image_url TEXT,
    category VARCHAR(100),
    tags TEXT[] DEFAULT '{}',
    views_count INT DEFAULT 0,
    is_published BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_wiki_community ON public.wiki_entries(community_id);
CREATE INDEX idx_wiki_author ON public.wiki_entries(author_id);
CREATE INDEX idx_wiki_category ON public.wiki_entries(community_id, category);
CREATE INDEX idx_wiki_tags ON public.wiki_entries USING GIN(tags);

-- ============================================================================
-- TABELA: check_in_history (Gamificação)
-- ============================================================================

CREATE TABLE public.check_in_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,
    checked_in_at DATE NOT NULL DEFAULT CURRENT_DATE,
    xp_earned INT DEFAULT 0,
    coins_earned INT DEFAULT 0,
    streak_day INT DEFAULT 1,
    UNIQUE (user_id, community_id, checked_in_at)
);

CREATE INDEX idx_checkin_user ON public.check_in_history(user_id, checked_in_at DESC);

-- ============================================================================
-- TABELA: xp_transactions (Log de Gamificação)
-- ============================================================================

CREATE TABLE public.xp_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    xp_amount INT NOT NULL,
    coins_amount INT DEFAULT 0,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_xp_transactions_user ON public.xp_transactions(user_id, created_at DESC);

-- ============================================================================
-- TABELA: notifications
-- ============================================================================

CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    notification_type notification_type NOT NULL,
    title VARCHAR(200),
    body TEXT,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON public.notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON public.notifications(user_id, is_read) WHERE is_read = FALSE;

-- ============================================================================
-- TABELA: reports (Moderação)
-- ============================================================================

CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reported_post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
    reported_comment_id UUID REFERENCES public.comments(id) ON DELETE SET NULL,
    reported_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    details TEXT,
    status report_status DEFAULT 'pending',
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reports_community ON public.reports(community_id, status);
CREATE INDEX idx_reports_status ON public.reports(status) WHERE status = 'pending';

-- ============================================================================
-- TABELA: moderation_logs (Auditoria)
-- ============================================================================

CREATE TABLE public.moderation_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    moderator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action moderation_action NOT NULL,
    reason TEXT,
    details JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mod_logs_community ON public.moderation_logs(community_id, created_at DESC);

-- ============================================================================
-- TABELA: bookmarks (Favoritos)
-- ============================================================================

CREATE TABLE public.bookmarks (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

-- ============================================================================
-- TRIGGER: Atualizar updated_at automaticamente
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_communities_updated_at
    BEFORE UPDATE ON public.communities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wiki_updated_at
    BEFORE UPDATE ON public.wiki_entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- TRIGGER: Criar perfil automaticamente ao criar usuário no Auth
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, amino_id, nickname, email, avatar_url)
    VALUES (
        NEW.id,
        'user_' || SUBSTR(NEW.id::TEXT, 1, 8),
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Novo Usuário'),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- TRIGGER: Atualizar contadores ao inserir/deletar likes
-- ============================================================================

CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
        -- Dar XP ao autor do post
        INSERT INTO public.xp_transactions (user_id, action, xp_amount, description)
        SELECT author_id, 'post_liked', 2, 'Post recebeu um like'
        FROM public.posts WHERE id = NEW.post_id;
        -- Atualizar XP do autor
        UPDATE public.profiles SET xp = xp + 2, reputation = reputation + 1
        WHERE id = (SELECT author_id FROM public.posts WHERE id = NEW.post_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_post_like_change
    AFTER INSERT OR DELETE ON public.post_likes
    FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

-- ============================================================================
-- TRIGGER: Atualizar contadores de comentários
-- ============================================================================

CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
        -- XP por comentar
        UPDATE public.profiles SET xp = xp + 3, reputation = reputation + 1
        WHERE id = NEW.author_id;
        IF NEW.parent_id IS NOT NULL THEN
            UPDATE public.comments SET replies_count = replies_count + 1 WHERE id = NEW.parent_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.post_id;
        IF OLD.parent_id IS NOT NULL THEN
            UPDATE public.comments SET replies_count = GREATEST(replies_count - 1, 0) WHERE id = OLD.parent_id;
        END IF;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_comment_change
    AFTER INSERT OR DELETE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

-- ============================================================================
-- TRIGGER: Atualizar contadores de membros da comunidade
-- ============================================================================

CREATE OR REPLACE FUNCTION update_community_members_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.communities SET members_count = members_count + 1 WHERE id = NEW.community_id;
        UPDATE public.profiles SET communities_count = communities_count + 1 WHERE id = NEW.user_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.communities SET members_count = GREATEST(members_count - 1, 0) WHERE id = OLD.community_id;
        UPDATE public.profiles SET communities_count = GREATEST(communities_count - 1, 0) WHERE id = OLD.user_id;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_community_member_change
    AFTER INSERT OR DELETE ON public.community_members
    FOR EACH ROW EXECUTE FUNCTION update_community_members_count();

-- ============================================================================
-- TRIGGER: Atualizar contadores de seguidores
-- ============================================================================

CREATE OR REPLACE FUNCTION update_follow_counts()
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

CREATE TRIGGER on_follow_change
    AFTER INSERT OR DELETE ON public.user_follows
    FOR EACH ROW EXECUTE FUNCTION update_follow_counts();

-- ============================================================================
-- TRIGGER: Atualizar last_message em chat_rooms
-- ============================================================================

CREATE OR REPLACE FUNCTION update_chat_room_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.chat_rooms
    SET last_message_at = NEW.created_at,
        last_message_preview = LEFT(NEW.content, 100)
    WHERE id = NEW.chat_room_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_message
    AFTER INSERT ON public.messages
    FOR EACH ROW EXECUTE FUNCTION update_chat_room_last_message();

-- ============================================================================
-- TRIGGER: XP por criar post
-- ============================================================================

CREATE OR REPLACE FUNCTION on_post_created()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles SET
        xp = xp + 10,
        reputation = reputation + 5,
        posts_count = posts_count + 1
    WHERE id = NEW.author_id;

    UPDATE public.communities SET posts_count = posts_count + 1
    WHERE id = NEW.community_id;

    INSERT INTO public.xp_transactions (user_id, community_id, action, xp_amount, description)
    VALUES (NEW.author_id, NEW.community_id, 'post_created', 10, 'Criou um novo post');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_post_insert
    AFTER INSERT ON public.posts
    FOR EACH ROW EXECUTE FUNCTION on_post_created();
