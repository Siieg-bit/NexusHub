-- =============================================================================
-- Migration 198: Logs de Moderação Aprimorados
-- =============================================================================
-- Adiciona colunas faltantes na tabela moderation_logs e cria RPCs robustas
-- para o histórico de ações de moderação (management-logs).
-- Roles válidos: leader, curator, agent, moderator, admin
-- Actions válidas: warn, strike, mute, ban, unban, hide_post, unhide_post,
--   feature_post, unfeature_post, promote, demote, delete_content,
--   transfer_agent, wiki_approve, wiki_reject, kick, pin_post, unpin_post,
--   delete_post, canonize_wiki, decanonize_wiki
-- =============================================================================

-- Adicionar colunas faltantes na tabela existente
ALTER TABLE public.moderation_logs
  ADD COLUMN IF NOT EXISTS actor_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS flag_id      UUID REFERENCES public.flags(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_automated BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Adicionar coluna appeal_id após a tabela ban_appeals ser criada (migration 196)
DO $$ BEGIN
  ALTER TABLE public.moderation_logs
    ADD COLUMN appeal_id UUID REFERENCES public.ban_appeals(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_moderation_logs_community ON public.moderation_logs(community_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_actor     ON public.moderation_logs(actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_target    ON public.moderation_logs(target_user_id, created_at DESC);

-- RLS na tabela de logs
ALTER TABLE public.moderation_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "moderation_logs_select_staff" ON public.moderation_logs;
CREATE POLICY "moderation_logs_select_staff" ON public.moderation_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.community_members cm
      WHERE cm.community_id = moderation_logs.community_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
        AND cm.is_banned IS NOT TRUE
    )
  );

DROP POLICY IF EXISTS "moderation_logs_insert_rpc" ON public.moderation_logs;
CREATE POLICY "moderation_logs_insert_rpc" ON public.moderation_logs
  FOR INSERT WITH CHECK (false);

-- =============================================================================
-- RPC: get_management_logs
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_management_logs(UUID, TEXT, UUID, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION public.get_management_logs(
  p_community_id  UUID,
  p_action_filter TEXT    DEFAULT 'all',
  p_actor_filter  UUID    DEFAULT NULL,
  p_limit         INTEGER DEFAULT 30,
  p_offset        INTEGER DEFAULT 0
)
RETURNS TABLE (
  id                  UUID,
  action              TEXT,
  severity            TEXT,
  actor_id            UUID,
  actor_name          TEXT,
  actor_icon          TEXT,
  target_user_id      UUID,
  target_user_name    TEXT,
  target_user_icon    TEXT,
  target_post_id      UUID,
  target_comment_id   UUID,
  target_wiki_id      UUID,
  target_story_id     UUID,
  target_chat_id      UUID,
  reason              TEXT,
  details             JSONB,
  duration_hours      INTEGER,
  expires_at          TIMESTAMP WITH TIME ZONE,
  is_automated        BOOLEAN,
  flag_id             UUID,
  appeal_id           UUID,
  created_at          TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = auth.uid()
      AND role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
      AND is_banned IS NOT TRUE
  ) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  RETURN QUERY
  SELECT
    ml.id,
    ml.action::TEXT,
    ml.severity::TEXT,
    ml.actor_id,
    COALESCE(NULLIF(actor_p.nickname, ''), actor_p.amino_id, 'Sistema') AS actor_name,
    actor_p.icon_url AS actor_icon,
    ml.target_user_id,
    COALESCE(NULLIF(target_p.nickname, ''), target_p.amino_id, NULL) AS target_user_name,
    target_p.icon_url AS target_user_icon,
    ml.target_post_id,
    ml.target_comment_id,
    ml.target_wiki_id,
    ml.target_story_id,
    ml.target_chat_thread_id AS target_chat_id,
    ml.reason,
    ml.details,
    ml.duration_hours,
    ml.expires_at,
    COALESCE(ml.is_automated, FALSE) AS is_automated,
    ml.flag_id,
    ml.appeal_id,
    ml.created_at
  FROM public.moderation_logs ml
  LEFT JOIN public.profiles actor_p  ON actor_p.id  = ml.actor_id
  LEFT JOIN public.profiles target_p ON target_p.id = ml.target_user_id
  WHERE ml.community_id = p_community_id
    AND (p_action_filter = 'all' OR ml.action::TEXT = p_action_filter)
    AND (p_actor_filter IS NULL OR ml.actor_id = p_actor_filter)
  ORDER BY ml.created_at DESC
  LIMIT LEAST(p_limit, 100) OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_management_logs(UUID, TEXT, UUID, INTEGER, INTEGER) TO authenticated;

-- =============================================================================
-- RPC: get_management_logs_stats
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_management_logs_stats(p_community_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_stats JSONB;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id = auth.uid()
      AND role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
      AND is_banned IS NOT TRUE
  ) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  SELECT jsonb_build_object(
    'total_actions', COUNT(*),
    'last_30d',      COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days'),
    'bans',          COUNT(*) FILTER (WHERE action::TEXT = 'ban'),
    'unbans',        COUNT(*) FILTER (WHERE action::TEXT = 'unban'),
    'warnings',      COUNT(*) FILTER (WHERE action::TEXT = 'warn'),
    'removals',      COUNT(*) FILTER (WHERE action::TEXT IN ('delete_post', 'delete_content')),
    'pending_appeals', (
      SELECT COUNT(*) FROM public.ban_appeals
      WHERE community_id = p_community_id AND status = 'pending'
    ),
    'pending_flags', (
      SELECT COUNT(*) FROM public.flags
      WHERE community_id = p_community_id AND status = 'pending'
    )
  )
  INTO v_stats
  FROM public.moderation_logs
  WHERE community_id = p_community_id;

  RETURN v_stats;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_management_logs_stats(UUID) TO authenticated;

-- =============================================================================
-- Atualizar log_moderation_action para incluir actor_id automaticamente
-- =============================================================================
DROP FUNCTION IF EXISTS public.log_moderation_action(UUID, TEXT, UUID, UUID, UUID, UUID, UUID, TEXT, TEXT, INTEGER, TIMESTAMP WITH TIME ZONE, JSONB);
CREATE OR REPLACE FUNCTION public.log_moderation_action(
  p_community_id       UUID,
  p_action             TEXT,
  p_target_user_id     UUID    DEFAULT NULL,
  p_target_post_id     UUID    DEFAULT NULL,
  p_target_wiki_id     UUID    DEFAULT NULL,
  p_target_comment_id  UUID    DEFAULT NULL,
  p_target_story_id    UUID    DEFAULT NULL,
  p_reason             TEXT    DEFAULT NULL,
  p_severity           TEXT    DEFAULT NULL,
  p_duration_hours     INTEGER DEFAULT NULL,
  p_expires_at         TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_details            JSONB   DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO public.moderation_logs (
    community_id, moderator_id, actor_id, action, severity,
    target_user_id, target_post_id, target_wiki_id,
    target_comment_id, target_story_id,
    reason, duration_hours, expires_at, details
  ) VALUES (
    p_community_id,
    auth.uid(),
    auth.uid(),
    p_action::moderation_action,
    p_severity::moderation_severity,
    p_target_user_id,
    p_target_post_id,
    p_target_wiki_id,
    p_target_comment_id,
    p_target_story_id,
    p_reason,
    p_duration_hours,
    p_expires_at,
    p_details
  ) RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_moderation_action(UUID, TEXT, UUID, UUID, UUID, UUID, UUID, TEXT, TEXT, INTEGER, TIMESTAMP WITH TIME ZONE, JSONB) TO authenticated;
