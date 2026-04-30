-- =============================================================================
-- Migration 196: Sistema de Apelações contra Banimentos
-- =============================================================================
-- Permite que membros banidos de uma comunidade enviem uma apelação formal.
-- O staff da comunidade (líder/curador/agent/moderator) pode aceitar ou rejeitar.
-- Uma apelação aceita remove automaticamente o banimento.
-- Roles válidos em user_role: member, leader, curator, agent, moderator, admin, news_feed, system
-- =============================================================================

-- Enum de status da apelação
DO $$ BEGIN
  CREATE TYPE appeal_status AS ENUM ('pending', 'accepted', 'rejected', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Tabela principal de apelações
CREATE TABLE IF NOT EXISTS public.ban_appeals (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id      UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  appellant_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewer_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status            appeal_status NOT NULL DEFAULT 'pending',
  reason            TEXT NOT NULL,
  additional_info   TEXT,
  reviewer_note     TEXT,
  reviewed_at       TIMESTAMP WITH TIME ZONE,
  created_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ban_reason        TEXT,
  ban_expires_at    TIMESTAMP WITH TIME ZONE
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_ban_appeals_community ON public.ban_appeals(community_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ban_appeals_appellant ON public.ban_appeals(appellant_id, created_at DESC);

-- RLS
ALTER TABLE public.ban_appeals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ban_appeals_select_own" ON public.ban_appeals
  FOR SELECT USING (appellant_id = auth.uid());

CREATE POLICY "ban_appeals_select_staff" ON public.ban_appeals
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.community_members cm
      WHERE cm.community_id = ban_appeals.community_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
        AND cm.is_banned IS NOT TRUE
    )
  );

CREATE POLICY "ban_appeals_insert_rpc" ON public.ban_appeals
  FOR INSERT WITH CHECK (false);

CREATE POLICY "ban_appeals_update_rpc" ON public.ban_appeals
  FOR UPDATE USING (false);

-- =============================================================================
-- RPC: submit_ban_appeal
-- =============================================================================
CREATE OR REPLACE FUNCTION public.submit_ban_appeal(
  p_community_id  UUID,
  p_reason        TEXT,
  p_additional    TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_is_banned    BOOLEAN;
  v_ban_expires  TIMESTAMP WITH TIME ZONE;
  v_ban_reason   TEXT;
  v_existing_id  UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'reason_too_short';
  END IF;

  SELECT is_banned, ban_expires_at, notes
  INTO v_is_banned, v_ban_expires, v_ban_reason
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF NOT FOUND OR v_is_banned IS NOT TRUE THEN
    RAISE EXCEPTION 'not_banned';
  END IF;

  IF v_ban_expires IS NOT NULL AND v_ban_expires < NOW() THEN
    RAISE EXCEPTION 'ban_already_expired';
  END IF;

  SELECT id INTO v_existing_id
  FROM public.ban_appeals
  WHERE community_id = p_community_id
    AND appellant_id = v_user_id
    AND status = 'pending';

  IF FOUND THEN
    RAISE EXCEPTION 'appeal_already_pending';
  END IF;

  INSERT INTO public.ban_appeals (
    community_id, appellant_id, status, reason, additional_info,
    ban_reason, ban_expires_at
  ) VALUES (
    p_community_id, v_user_id, 'pending', trim(p_reason), trim(p_additional),
    v_ban_reason, v_ban_expires
  );

  INSERT INTO public.notifications (
    user_id, actor_id, type, title, body, community_id, action_url
  )
  SELECT
    cm.user_id,
    v_user_id,
    'moderation_alert',
    'Nova apelação de banimento',
    'Um membro banido enviou uma apelação para revisão.',
    p_community_id,
    '/community/' || p_community_id || '/management-logs'
  FROM public.community_members cm
  WHERE cm.community_id = p_community_id
    AND cm.role = 'leader'
    AND cm.is_banned IS NOT TRUE
  LIMIT 3;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_ban_appeal(UUID, TEXT, TEXT) TO authenticated;

-- =============================================================================
-- RPC: review_ban_appeal
-- =============================================================================
CREATE OR REPLACE FUNCTION public.review_ban_appeal(
  p_appeal_id    UUID,
  p_action       TEXT,
  p_note         TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_reviewer_id  UUID := auth.uid();
  v_appeal       RECORD;
  v_is_staff     BOOLEAN;
BEGIN
  IF v_reviewer_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF p_action NOT IN ('accept', 'reject') THEN
    RAISE EXCEPTION 'invalid_action';
  END IF;

  SELECT * INTO v_appeal FROM public.ban_appeals WHERE id = p_appeal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'appeal_not_found'; END IF;
  IF v_appeal.status != 'pending' THEN RAISE EXCEPTION 'appeal_not_pending'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = v_appeal.community_id
      AND user_id = v_reviewer_id
      AND role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
      AND is_banned IS NOT TRUE
  ) INTO v_is_staff;

  IF NOT v_is_staff THEN RAISE EXCEPTION 'insufficient_permissions'; END IF;

  UPDATE public.ban_appeals SET
    status        = CASE WHEN p_action = 'accept' THEN 'accepted'::appeal_status ELSE 'rejected'::appeal_status END,
    reviewer_id   = v_reviewer_id,
    reviewer_note = p_note,
    reviewed_at   = NOW(),
    updated_at    = NOW()
  WHERE id = p_appeal_id;

  IF p_action = 'accept' THEN
    UPDATE public.community_members SET
      is_banned      = FALSE,
      ban_expires_at = NULL,
      updated_at     = NOW()
    WHERE community_id = v_appeal.community_id
      AND user_id      = v_appeal.appellant_id;

    PERFORM public.log_moderation_action(
      v_appeal.community_id,
      'unban',
      v_appeal.appellant_id,
      NULL, NULL, NULL, NULL,
      'Banimento removido via apelação aceita. Nota: ' || COALESCE(p_note, 'sem nota')
    );
  END IF;

  INSERT INTO public.notifications (
    user_id, actor_id, type, title, body, community_id, action_url
  ) VALUES (
    v_appeal.appellant_id,
    v_reviewer_id,
    'moderation_alert',
    CASE WHEN p_action = 'accept' THEN 'Sua apelação foi aceita!' ELSE 'Sua apelação foi rejeitada' END,
    CASE WHEN p_action = 'accept'
      THEN 'Seu banimento foi removido. Você pode voltar à comunidade.'
      ELSE COALESCE('Motivo: ' || p_note, 'Sua apelação não foi aprovada.')
    END,
    v_appeal.community_id,
    '/appeals'
  );

  RETURN jsonb_build_object('success', true, 'action', p_action);
END;
$$;
GRANT EXECUTE ON FUNCTION public.review_ban_appeal(UUID, TEXT, TEXT) TO authenticated;

-- =============================================================================
-- RPC: get_my_appeals
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_my_appeals()
RETURNS TABLE (
  id              UUID,
  community_id    UUID,
  community_name  TEXT,
  community_icon  TEXT,
  status          appeal_status,
  reason          TEXT,
  additional_info TEXT,
  reviewer_note   TEXT,
  ban_reason      TEXT,
  ban_expires_at  TIMESTAMP WITH TIME ZONE,
  reviewed_at     TIMESTAMP WITH TIME ZONE,
  created_at      TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.community_id,
    c.name AS community_name,
    c.icon_url AS community_icon,
    a.status,
    a.reason,
    a.additional_info,
    a.reviewer_note,
    a.ban_reason,
    a.ban_expires_at,
    a.reviewed_at,
    a.created_at
  FROM public.ban_appeals a
  JOIN public.communities c ON c.id = a.community_id
  WHERE a.appellant_id = auth.uid()
  ORDER BY a.created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_appeals() TO authenticated;

-- =============================================================================
-- RPC: get_community_appeals
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_community_appeals(
  p_community_id UUID,
  p_status       TEXT DEFAULT 'pending'
)
RETURNS TABLE (
  id              UUID,
  appellant_id    UUID,
  appellant_name  TEXT,
  appellant_icon  TEXT,
  status          appeal_status,
  reason          TEXT,
  additional_info TEXT,
  reviewer_note   TEXT,
  ban_reason      TEXT,
  ban_expires_at  TIMESTAMP WITH TIME ZONE,
  reviewed_at     TIMESTAMP WITH TIME ZONE,
  created_at      TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members cm
    WHERE cm.community_id = p_community_id
      AND cm.user_id = auth.uid()
      AND cm.role IN ('leader', 'curator', 'agent', 'moderator', 'admin')
      AND cm.is_banned IS NOT TRUE
  ) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.appellant_id,
    COALESCE(NULLIF(p.nickname, ''), p.amino_id, 'Usuário') AS appellant_name,
    p.icon_url AS appellant_icon,
    a.status,
    a.reason,
    a.additional_info,
    a.reviewer_note,
    a.ban_reason,
    a.ban_expires_at,
    a.reviewed_at,
    a.created_at
  FROM public.ban_appeals a
  JOIN public.profiles p ON p.id = a.appellant_id
  WHERE a.community_id = p_community_id
    AND (p_status = 'all' OR a.status::TEXT = p_status)
  ORDER BY a.created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_community_appeals(UUID, TEXT) TO authenticated;
