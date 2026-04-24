-- =============================================================================
-- Migration 123: Corrige exibição do perfil local nas notificações da comunidade
--
-- Problema identificado:
--   A query de notificações buscava apenas profiles!notifications_actor_id_fkey
--   (perfil global), ignorando o perfil local do ator dentro da comunidade.
--
-- Solução:
--   Criar/atualizar as RPCs get_community_notifications e
--   get_community_notifications_by_category para incluir LEFT JOIN em
--   community_members e retornar local_nickname / local_icon_url do ator.
--   O frontend já está preparado para consumir esses campos e priorizar o
--   perfil local sobre o global.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: get_community_notifications
-- Busca notificações de uma comunidade com perfil local do ator
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_community_notifications(
  p_community_id UUID,
  p_limit        INT DEFAULT 30,
  p_offset       INT DEFAULT 0
)
RETURNS TABLE (
  id               UUID,
  user_id          UUID,
  actor_id         UUID,
  community_id     UUID,
  type             TEXT,
  title            TEXT,
  body             TEXT,
  image_url        TEXT,
  is_read          BOOLEAN,
  created_at       TIMESTAMPTZ,
  group_key        TEXT,
  action_url       TEXT,
  post_id          UUID,
  wiki_id          UUID,
  comment_id       UUID,
  chat_thread_id   UUID,
  -- Perfil local do ator (quem executou a ação dentro da comunidade)
  actor_local_nickname  TEXT,
  actor_local_icon_url  TEXT,
  -- Perfil global do ator (fallback quando não há perfil local)
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
    -- Perfil local: busca o membro dentro da mesma comunidade da notificação
    cm.local_nickname AS actor_local_nickname,
    cm.local_icon_url AS actor_local_icon_url,
    -- Perfil global: fallback
    p.nickname  AS actor_global_nickname,
    p.icon_url  AS actor_global_icon_url
  FROM public.notifications n
  LEFT JOIN public.community_members cm
    ON  cm.user_id      = n.actor_id
    AND cm.community_id = n.community_id
  LEFT JOIN public.profiles p
    ON  p.id = n.actor_id
  WHERE
    n.user_id      = auth.uid()
    AND n.community_id = p_community_id
  ORDER BY n.created_at DESC
  LIMIT  p_limit
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
    user_id      = auth.uid()
    AND community_id = p_community_id
    AND is_read  = FALSE;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_notifications_count TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: get_community_notifications_by_category
-- Busca notificações de comunidade filtradas por categoria, com perfil local
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_community_notifications_by_category(
  p_community_id UUID,
  p_category     TEXT DEFAULT 'all',
  p_limit        INT  DEFAULT 30,
  p_offset       INT  DEFAULT 0
)
RETURNS TABLE (
  id               UUID,
  user_id          UUID,
  actor_id         UUID,
  community_id     UUID,
  type             TEXT,
  title            TEXT,
  body             TEXT,
  image_url        TEXT,
  is_read          BOOLEAN,
  created_at       TIMESTAMPTZ,
  group_key        TEXT,
  action_url       TEXT,
  post_id          UUID,
  wiki_id          UUID,
  comment_id       UUID,
  chat_thread_id   UUID,
  actor_local_nickname  TEXT,
  actor_local_icon_url  TEXT,
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
    p.nickname        AS actor_global_nickname,
    p.icon_url        AS actor_global_icon_url
  FROM public.notifications n
  LEFT JOIN public.community_members cm
    ON  cm.user_id      = n.actor_id
    AND cm.community_id = n.community_id
  LEFT JOIN public.profiles p
    ON  p.id = n.actor_id
  WHERE
    n.user_id      = auth.uid()
    AND n.community_id = p_community_id
    AND (
      p_category = 'all'
      OR (p_category = 'social'    AND n.type IN ('like', 'comment', 'follow', 'mention', 'wall_post'))
      OR (p_category = 'chat'      AND n.type IN ('chat_message', 'chat_mention', 'dm_invite'))
      OR (p_category = 'community' AND n.type IN ('community_invite', 'community_update', 'join_request', 'role_change'))
      OR (p_category = 'system'    AND n.type IN ('level_up', 'achievement', 'check_in_streak', 'moderation', 'strike', 'ban', 'broadcast', 'wiki_approved', 'wiki_rejected', 'tip'))
    )
  ORDER BY n.created_at DESC
  LIMIT  p_limit
  OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_notifications_by_category TO authenticated;

-- =============================================================================
-- RESULTADO:
--   - Notificações da comunidade agora retornam o perfil local do ator
--     (local_nickname, local_icon_url de community_members) quando disponível.
--   - Fallback automático para perfil global (profiles) quando não há perfil local.
--   - O frontend já consome actor_local_nickname / actor_local_icon_url e
--     prioriza esses valores sobre os globais na renderização.
-- =============================================================================
