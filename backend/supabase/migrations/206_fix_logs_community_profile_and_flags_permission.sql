-- =============================================================================
-- Migration 206: Correções de logs e central de denúncias
-- =============================================================================
-- 1. get_management_logs: usar perfil da comunidade (local_nickname / local_icon_url)
--    com fallback para perfil global quando o perfil local não estiver preenchido.
-- 2. get_community_flags: adicionar 'admin' na lista de roles permitidos.
-- 3. get_management_logs: restringir acesso apenas a leader e agent (+ team admin),
--    alinhando com a regra do drawer Flutter.
-- =============================================================================

-- =============================================================================
-- 1 + 3. Recriar get_management_logs com perfil da comunidade e acesso restrito
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_management_logs(
  p_community_id  UUID    DEFAULT NULL,
  p_action_filter TEXT    DEFAULT 'all',
  p_actor_filter  UUID    DEFAULT NULL,
  p_limit         INTEGER DEFAULT 50,
  p_offset        INTEGER DEFAULT 0
)
RETURNS TABLE (
  log_id             UUID,
  action             TEXT,
  severity           TEXT,
  actor_id           UUID,
  actor_nickname     TEXT,
  actor_avatar       TEXT,
  target_user_id     UUID,
  target_nickname    TEXT,
  target_avatar      TEXT,
  target_post_id     UUID,
  target_comment_id  UUID,
  target_wiki_id     UUID,
  target_story_id    UUID,
  reason             TEXT,
  details            JSONB,
  duration_hours     INTEGER,
  expires_at         TIMESTAMP WITH TIME ZONE,
  is_automated       BOOLEAN,
  flag_id            UUID,
  appeal_id          UUID,
  created_at         TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_caller_id          UUID    := auth.uid();
  v_is_team_admin      BOOLEAN := FALSE;
  v_is_community_leader BOOLEAN := FALSE;
BEGIN
  IF v_caller_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;

  -- Verificar se é team admin (Manus team)
  SELECT COALESCE(p.is_team_admin, FALSE)
    INTO v_is_team_admin
    FROM public.profiles p WHERE p.id = v_caller_id;

  -- Verificar se é líder ou agent na comunidade (apenas esses cargos têm acesso)
  IF p_community_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.community_members cm
       WHERE cm.community_id = p_community_id
         AND cm.user_id      = v_caller_id
         AND cm.role IN ('leader', 'agent')
         AND cm.is_banned IS NOT TRUE
    ) INTO v_is_community_leader;
  END IF;

  IF NOT (v_is_team_admin OR v_is_community_leader) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  RETURN QUERY
  SELECT
    ml.id                                                    AS log_id,
    ml.action::TEXT,
    ml.severity::TEXT,
    COALESCE(ml.actor_id, ml.moderator_id)                   AS actor_id,
    -- Perfil do ator: preferir local_nickname da comunidade, fallback global
    COALESCE(
      NULLIF(TRIM(actor_cm.local_nickname), ''),
      actor_p.nickname
    )                                                        AS actor_nickname,
    COALESCE(
      NULLIF(TRIM(actor_cm.local_icon_url), ''),
      actor_p.icon_url
    )                                                        AS actor_avatar,
    ml.target_user_id,
    -- Perfil do alvo: preferir local_nickname da comunidade, fallback global
    COALESCE(
      NULLIF(TRIM(tgt_cm.local_nickname), ''),
      tgt_p.nickname
    )                                                        AS target_nickname,
    COALESCE(
      NULLIF(TRIM(tgt_cm.local_icon_url), ''),
      tgt_p.icon_url
    )                                                        AS target_avatar,
    ml.target_post_id,
    ml.target_comment_id,
    ml.target_wiki_id,
    ml.target_story_id,
    ml.reason,
    ml.details,
    ml.duration_hours,
    ml.expires_at,
    ml.is_automated,
    ml.flag_id,
    ml.appeal_id,
    ml.created_at
  FROM public.moderation_logs ml
  -- Perfil global do ator
  LEFT JOIN public.profiles actor_p
         ON actor_p.id = COALESCE(ml.actor_id, ml.moderator_id)
  -- Perfil local do ator na comunidade
  LEFT JOIN public.community_members actor_cm
         ON actor_cm.user_id      = COALESCE(ml.actor_id, ml.moderator_id)
        AND actor_cm.community_id = ml.community_id
  -- Perfil global do alvo
  LEFT JOIN public.profiles tgt_p
         ON tgt_p.id = ml.target_user_id
  -- Perfil local do alvo na comunidade
  LEFT JOIN public.community_members tgt_cm
         ON tgt_cm.user_id      = ml.target_user_id
        AND tgt_cm.community_id = ml.community_id
  WHERE (p_community_id IS NULL OR ml.community_id = p_community_id)
    AND (p_action_filter = 'all' OR ml.action::TEXT = p_action_filter)
    AND (p_actor_filter  IS NULL
         OR COALESCE(ml.actor_id, ml.moderator_id) = p_actor_filter)
  ORDER BY ml.created_at DESC
  LIMIT  p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_management_logs(UUID, TEXT, UUID, INTEGER, INTEGER) TO authenticated;

-- =============================================================================
-- 2. Corrigir get_community_flags: adicionar 'admin' na verificação de permissão
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_community_flags(
  p_community_id UUID,
  p_status       TEXT    DEFAULT 'pending',
  p_limit        INTEGER DEFAULT 30,
  p_offset       INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role    TEXT;
  v_flags   JSONB;
  v_total   BIGINT;
  v_is_team_admin BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  -- Verificar se é team admin
  SELECT COALESCE(p.is_team_admin, FALSE)
    INTO v_is_team_admin
    FROM public.profiles p WHERE p.id = v_user_id;

  -- Buscar role na comunidade
  SELECT role::TEXT INTO v_role
    FROM public.community_members
   WHERE community_id = p_community_id AND user_id = v_user_id;

  -- Permitir: team admin OU roles de staff (incluindo admin)
  IF NOT (v_is_team_admin OR v_role IN ('agent', 'leader', 'curator', 'moderator', 'admin')) THEN
    RAISE EXCEPTION 'Sem permissão';
  END IF;

  SELECT COUNT(*) INTO v_total
    FROM public.flags
   WHERE community_id = p_community_id
     AND (p_status = 'all' OR status = p_status::public.flag_status);

  SELECT jsonb_agg(row_to_json(t)) INTO v_flags
  FROM (
    SELECT
      f.id,
      f.flag_type,
      f.reason,
      f.status,
      f.bot_verdict,
      f.bot_score,
      f.auto_actioned,
      f.snapshot_captured,
      f.created_at,
      f.resolved_at,
      f.target_post_id,
      f.target_comment_id,
      f.target_chat_message_id,
      f.target_user_id,
      f.target_wiki_id,
      f.target_story_id,
      -- Reporter
      jsonb_build_object(
        'id',       rp.id,
        'nickname', COALESCE(rp.nickname, 'Anônimo'),
        'avatar',   rp.icon_url
      ) AS reporter,
      -- Snapshot com preview do conteúdo
      (SELECT jsonb_build_object(
        'id',           cs.id,
        'content_type', cs.content_type,
        'bot_verdict',  cs.bot_verdict,
        'captured_at',  cs.captured_at,
        'preview', CASE
          WHEN cs.content_type IN ('post', 'wiki')
            THEN LEFT(COALESCE(cs.snapshot_data->>'body', cs.snapshot_data->>'content', cs.snapshot_data->>'title', ''), 200)
          WHEN cs.content_type = 'comment'
            THEN LEFT(COALESCE(cs.snapshot_data->>'body', ''), 200)
          WHEN cs.content_type IN ('chat_message', 'story')
            THEN LEFT(COALESCE(cs.snapshot_data->>'content', cs.snapshot_data->>'text_content', ''), 200)
          ELSE ''
        END,
        'author_nickname', COALESCE(
          cs.snapshot_data->>'author_nickname',
          cs.snapshot_data->>'sender_nickname',
          'Desconhecido'
        ),
        'has_media', (
          (cs.snapshot_data->'image_urls') IS NOT NULL
          OR (cs.snapshot_data->>'media_url') IS NOT NULL
          OR (cs.snapshot_data->>'cover_image_url') IS NOT NULL
        )
      )
      FROM public.content_snapshots cs
      WHERE cs.flag_id = f.id
      ORDER BY cs.captured_at DESC LIMIT 1
      ) AS snapshot_preview
    FROM public.flags f
    LEFT JOIN public.profiles rp ON rp.id = f.reporter_id
    WHERE f.community_id = p_community_id
      AND (p_status = 'all' OR f.status = p_status::public.flag_status)
    ORDER BY f.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN jsonb_build_object(
    'flags',  COALESCE(v_flags, '[]'::jsonb),
    'total',  v_total,
    'limit',  p_limit,
    'offset', p_offset
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_flags(UUID, TEXT, INTEGER, INTEGER) TO authenticated;
