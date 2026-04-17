-- ============================================================================
-- Migration: performance_indexes.sql
-- Objetivo: Adicionar índices para as queries mais frequentes do NexusHub
-- ============================================================================

-- 1. Likes por post_id (usado em _injectIsLiked com inFilter)
CREATE INDEX IF NOT EXISTS idx_likes_post_id
  ON public.likes (post_id)
  WHERE post_id IS NOT NULL;

-- 2. Likes por wiki_id (usado em likes de wiki entries)
CREATE INDEX IF NOT EXISTS idx_likes_wiki_id
  ON public.likes (wiki_id)
  WHERE wiki_id IS NOT NULL;

-- 3. Story views por viewer_id + story_id (usado no userHasActiveStoryProvider)
CREATE INDEX IF NOT EXISTS idx_story_views_viewer_story
  ON public.story_views (viewer_id, story_id);

-- 4. Posts por community_id + status + created_at (query principal do feed)
CREATE INDEX IF NOT EXISTS idx_posts_community_status_created
  ON public.posts (community_id, status, created_at DESC)
  WHERE status = 'ok';

-- 5. Posts por author_id + community_id (perfil de usuário na comunidade)
CREATE INDEX IF NOT EXISTS idx_posts_author_community
  ON public.posts (author_id, community_id, created_at DESC)
  WHERE status = 'ok';

-- 6. Comments por profile_wall_id + community_id (mural de comunidade)
CREATE INDEX IF NOT EXISTS idx_comments_wall_community_created
  ON public.comments (profile_wall_id, community_id, created_at DESC)
  WHERE profile_wall_id IS NOT NULL;

-- 7. Community members por user_id (busca de membership do usuário)
CREATE INDEX IF NOT EXISTS idx_community_members_user_id
  ON public.community_members (user_id, community_id);

-- 8. Follows por community_id + following_id (contagem de seguidores)
CREATE INDEX IF NOT EXISTS idx_follows_community_following
  ON public.follows (community_id, following_id);

-- 9. Follows por community_id + follower_id (contagem de seguindo)
CREATE INDEX IF NOT EXISTS idx_follows_community_follower
  ON public.follows (community_id, follower_id);

-- 10. Notifications por user_id + created_at (lista de notificações)
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC)
  WHERE is_read = false;

-- 11. Stories por user_id + community_id + expires_at (stories ativos)
CREATE INDEX IF NOT EXISTS idx_stories_user_community_expires
  ON public.stories (user_id, community_id, expires_at DESC)
  WHERE expires_at > NOW();

-- 12. Chat messages por thread_id + created_at (histórico do chat)
CREATE INDEX IF NOT EXISTS idx_messages_thread_created
  ON public.messages (thread_id, created_at DESC);

-- 13. Chat members por user_id + status (unread count)
CREATE INDEX IF NOT EXISTS idx_chat_members_user_status
  ON public.chat_members (user_id, status)
  WHERE status = 'active';
