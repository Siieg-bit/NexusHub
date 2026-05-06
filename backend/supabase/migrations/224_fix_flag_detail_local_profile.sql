-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 224: Corrigir get_flag_detail para usar perfil local da comunidade
--
-- Problema: get_flag_detail buscava o nickname/avatar do reporter diretamente
--           de `profiles` (perfil global), ignorando o perfil local da
--           comunidade (community_members.local_nickname / local_icon_url).
--           Na tela "Detalhes da Denúncia" o moderador via o nome/foto global
--           do denunciante em vez do nome/foto que o usuário usa naquela
--           comunidade específica.
--
-- Correção: Fazer JOIN com community_members usando COALESCE para preferir
--           o perfil local quando disponível, com fallback para o global.
--           Mantém compatibilidade total com o frontend (mesmos campos).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_flag_detail(p_flag_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_role       TEXT;
  v_flag       RECORD;
  v_snap       RECORD;
  v_bot        JSONB;
  v_rep_nick   TEXT;
  v_rep_av     TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  SELECT * INTO v_flag FROM public.flags WHERE id = p_flag_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Denúncia não encontrada'; END IF;

  -- Verificar permissão: staff da comunidade ou o próprio reporter
  SELECT role::TEXT INTO v_role
    FROM public.community_members
   WHERE community_id = v_flag.community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent', 'leader', 'curator', 'moderator', 'admin')
     AND NOT public.is_team_member()
     AND v_flag.reporter_id <> v_user_id THEN
    RAISE EXCEPTION 'Sem permissão para visualizar esta denúncia';
  END IF;

  -- Buscar snapshot (mais recente)
  SELECT * INTO v_snap
    FROM public.content_snapshots
   WHERE flag_id = p_flag_id
   ORDER BY captured_at DESC
   LIMIT 1;

  -- Buscar ações do bot
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',             ba.id,
      'action_type',    ba.action_type,
      'verdict',        ba.verdict,
      'confidence',     ba.confidence,
      'categories',     ba.categories_detected,
      'reasoning',      ba.reasoning,
      'review_outcome', ba.review_outcome,
      'created_at',     ba.created_at
    ) ORDER BY ba.created_at DESC
  ) INTO v_bot
  FROM public.bot_actions ba
  WHERE ba.flag_id = p_flag_id;

  -- Buscar reporter preferindo perfil local da comunidade
  SELECT
    COALESCE(NULLIF(TRIM(cm.local_nickname), ''), p.nickname)   AS nick,
    COALESCE(NULLIF(TRIM(cm.local_icon_url),  ''), p.icon_url)  AS av
  INTO v_rep_nick, v_rep_av
  FROM public.profiles p
  LEFT JOIN public.community_members cm
    ON cm.user_id = p.id AND cm.community_id = v_flag.community_id
  WHERE p.id = v_flag.reporter_id;

  RETURN jsonb_build_object(
    'flag', jsonb_build_object(
      'id',                     v_flag.id,
      'community_id',           v_flag.community_id,
      'flag_type',              v_flag.flag_type,
      'reason',                 v_flag.reason,
      'status',                 v_flag.status,
      'bot_verdict',            v_flag.bot_verdict,
      'bot_score',              v_flag.bot_score,
      'auto_actioned',          v_flag.auto_actioned,
      'snapshot_captured',      v_flag.snapshot_captured,
      'created_at',             v_flag.created_at,
      'resolved_at',            v_flag.resolved_at,
      'target_post_id',         v_flag.target_post_id,
      'target_comment_id',      v_flag.target_comment_id,
      'target_chat_message_id', v_flag.target_chat_message_id,
      'target_user_id',         v_flag.target_user_id,
      'target_wiki_id',         v_flag.target_wiki_id,
      'target_story_id',        v_flag.target_story_id,
      'reporter', jsonb_build_object(
        'id',       v_flag.reporter_id,
        'nickname', COALESCE(v_rep_nick, 'Anônimo'),
        'avatar',   v_rep_av
      )
    ),
    'snapshot', CASE WHEN v_snap.id IS NOT NULL THEN jsonb_build_object(
      'id',             v_snap.id,
      'content_type',   v_snap.content_type,
      'snapshot_data',  v_snap.snapshot_data,
      'bot_verdict',    v_snap.bot_verdict,
      'bot_score',      v_snap.bot_score,
      'bot_categories', v_snap.bot_categories,
      'captured_at',    v_snap.captured_at
    ) ELSE NULL END,
    'bot_actions', COALESCE(v_bot, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_flag_detail(UUID) TO authenticated;
