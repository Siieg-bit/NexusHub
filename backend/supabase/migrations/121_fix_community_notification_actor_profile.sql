-- =============================================================================
-- Migration 121: Correção de Perfil em Notificações de Comunidade
--
-- Problema: Notificações de comunidade exibem perfil global do ator em vez do
-- perfil local da comunidade.
--
-- Causa: A query estava fazendo JOIN com community_members usando user_id
-- (quem recebe) em vez de actor_id (quem fez a ação).
--
-- Solução: Criar uma RPC que busca notificações de comunidade com o perfil
-- local correto do ator (quem fez a ação).
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: get_community_notifications
-- Busca notificações de uma comunidade com perfil local correto do ator
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_community_notifications(
  p_community_id UUID,
  p_limit INT DEFAULT 30,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  actor_id UUID,
  community_id UUID,
  type TEXT,
  title TEXT,
  body TEXT,
  image_url TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMPTZ,
  group_key TEXT,
  action_url TEXT,
  post_id UUID,
  wiki_id UUID,
  comment_id UUID,
  chat_thread_id UUID,
  -- Dados do perfil local do ator (quem fez a ação)
  actor_local_nickname TEXT,
  actor_local_icon_url TEXT,
  -- Dados do perfil global do ator (fallback)
  actor_global_nickname TEXT,
  actor_global_icon_url TEXT
)
LANGUAGE SQL
SECURITY DEFINER
STABLE
AS $$
  SELECT
    n.id,
    n.user_id,
    n.actor_id,
    n.community_id,
    n.type,
    n.title,
    n.body,
    n.image_url,
    n.is_read,
    n.created_at,
    n.group_key,
    n.action_url,
    n.post_id,
    n.wiki_id,
    n.comment_id,
    n.chat_thread_id,
    -- Perfil local do ator (se existir)
    cm.local_nickname AS actor_local_nickname,
    cm.local_icon_url AS actor_local_icon_url,
    -- Perfil global do ator (fallback)
    p.nickname AS actor_global_nickname,
    p.icon_url AS actor_global_icon_url
  FROM public.notifications n
  LEFT JOIN public.community_members cm
    ON cm.user_id = n.actor_id
    AND cm.community_id = n.community_id
  LEFT JOIN public.profiles p
    ON p.id = n.actor_id
  WHERE
    n.user_id = auth.uid()
    AND n.community_id = p_community_id
  ORDER BY n.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_notifications TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: get_community_notifications_count
-- Conta notificações não lidas de uma comunidade
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_community_notifications_count(
  p_community_id UUID
)
RETURNS INT
LANGUAGE SQL
SECURITY DEFINER
STABLE
AS $$
  SELECT COUNT(*)::INT
  FROM public.notifications
  WHERE
    user_id = auth.uid()
    AND community_id = p_community_id
    AND is_read = FALSE;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_notifications_count TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: get_community_notifications_by_category
-- Busca notificações de comunidade filtradas por categoria
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_community_notifications_by_category(
  p_community_id UUID,
  p_category TEXT DEFAULT 'all',
  p_limit INT DEFAULT 30,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  actor_id UUID,
  community_id UUID,
  type TEXT,
  title TEXT,
  body TEXT,
  image_url TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMPTZ,
  group_key TEXT,
  action_url TEXT,
  post_id UUID,
  wiki_id UUID,
  comment_id UUID,
  chat_thread_id UUID,
  actor_local_nickname TEXT,
  actor_local_icon_url TEXT,
  actor_global_nickname TEXT,
  actor_global_icon_url TEXT
)
LANGUAGE SQL
SECURITY DEFINER
STABLE
AS $$
  SELECT
    n.id,
    n.user_id,
    n.actor_id,
    n.community_id,
    n.type,
    n.title,
    n.body,
    n.image_url,
    n.is_read,
    n.created_at,
    n.group_key,
    n.action_url,
    n.post_id,
    n.wiki_id,
    n.comment_id,
    n.chat_thread_id,
    cm.local_nickname AS actor_local_nickname,
    cm.local_icon_url AS actor_local_icon_url,
    p.nickname AS actor_global_nickname,
    p.icon_url AS actor_global_icon_url
  FROM public.notifications n
  LEFT JOIN public.community_members cm
    ON cm.user_id = n.actor_id
    AND cm.community_id = n.community_id
  LEFT JOIN public.profiles p
    ON p.id = n.actor_id
  WHERE
    n.user_id = auth.uid()
    AND n.community_id = p_community_id
    AND (
      p_category = 'all'
      OR (p_category = 'social' AND n.type IN ('like', 'comment', 'follow', 'mention', 'wall_post'))
      OR (p_category = 'chat' AND n.type IN ('chat_message', 'chat_mention', 'dm_invite'))
      OR (p_category = 'community' AND n.type IN ('community_invite', 'community_update', 'join_request', 'role_change'))
      OR (p_category = 'system' AND n.type IN ('level_up', 'achievement', 'check_in_streak', 'moderation', 'strike', 'ban', 'broadcast', 'wiki_approved', 'wiki_rejected', 'tip'))
    )
  ORDER BY n.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_notifications_by_category TO authenticated;

-- =============================================================================
-- RESULTADO:
-- - Notificações de comunidade agora trazem o perfil local correto do ator
-- - Fallback automático para perfil global se não houver perfil local
-- - Suporte a filtros por categoria
-- - RLS automática via auth.uid()
-- =============================================================================
