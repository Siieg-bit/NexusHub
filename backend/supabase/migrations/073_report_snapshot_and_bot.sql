-- ============================================================================
-- 073 — SISTEMA DE MODERAÇÃO AVANÇADO
-- • content_snapshots  : cópia imutável do conteúdo no momento da denúncia
-- • bot_actions        : log de todas as ações automáticas do bot de moderação
-- • Trigger automático : captura snapshot ao inserir flag
-- • RPC submit_flag    : atualizada para capturar snapshot + disparar bot
-- • RPC get_flag_detail: retorna flag + snapshot mesmo após exclusão do conteúdo
-- • RPC get_bot_stats  : estatísticas do bot para o painel admin
-- ============================================================================

-- ============================================================================
-- 1. ENUM: status do bot
-- ============================================================================
DO $$ BEGIN
  CREATE TYPE public.bot_verdict AS ENUM (
    'clean',        -- conteúdo aprovado pelo bot
    'suspicious',   -- marcado para revisão humana
    'auto_removed', -- removido automaticamente pelo bot
    'escalated'     -- escalado para moderador humano
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.bot_action_type AS ENUM (
    'scan_post',
    'scan_comment',
    'scan_chat_message',
    'scan_profile',
    'auto_remove',
    'auto_warn',
    'escalate_to_human',
    'clear_flag'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- 2. TABELA: content_snapshots
-- Armazena uma cópia imutável do conteúdo no momento da denúncia.
-- Mesmo que o post/comentário seja deletado, o snapshot permanece.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.content_snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Referência à denúncia (flag)
  flag_id         UUID NOT NULL REFERENCES public.flags(id) ON DELETE CASCADE,

  -- Tipo de conteúdo capturado
  content_type    TEXT NOT NULL CHECK (content_type IN (
    'post', 'comment', 'chat_message', 'profile', 'wiki'
  )),

  -- IDs originais (para rastreabilidade mesmo após exclusão)
  original_post_id         UUID REFERENCES public.posts(id) ON DELETE SET NULL,
  original_comment_id      UUID REFERENCES public.comments(id) ON DELETE SET NULL,
  original_chat_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  original_user_id         UUID REFERENCES public.profiles(id) ON DELETE SET NULL,

  -- Conteúdo capturado (cópia imutável)
  snapshot_data   JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- Estrutura esperada:
  -- post:    { title, body, image_urls[], author_id, author_nickname, created_at }
  -- comment: { body, image_urls[], author_id, author_nickname, post_id, created_at }
  -- chat:    { content, media_url, sender_id, sender_nickname, thread_id, created_at }
  -- profile: { nickname, bio, avatar_url, created_at }

  -- Metadados
  captured_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  captured_by     UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- NULL = sistema/bot

  -- Resultado da análise do bot (preenchido depois)
  bot_verdict     public.bot_verdict,
  bot_score       NUMERIC(4,3),   -- 0.000 a 1.000 (probabilidade de violação)
  bot_categories  JSONB DEFAULT '[]'::jsonb, -- ex: ["hate_speech", "spam"]
  bot_analyzed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_snapshots_flag    ON public.content_snapshots(flag_id);
CREATE INDEX IF NOT EXISTS idx_snapshots_type    ON public.content_snapshots(content_type);
CREATE INDEX IF NOT EXISTS idx_snapshots_post    ON public.content_snapshots(original_post_id) WHERE original_post_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_snapshots_user    ON public.content_snapshots(original_user_id) WHERE original_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_snapshots_verdict ON public.content_snapshots(bot_verdict) WHERE bot_verdict IS NOT NULL;

-- ============================================================================
-- 3. TABELA: bot_actions
-- Log de todas as ações tomadas pelo bot de moderação automática.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.bot_actions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Contexto
  community_id    UUID REFERENCES public.communities(id) ON DELETE CASCADE,
  flag_id         UUID REFERENCES public.flags(id) ON DELETE SET NULL,
  snapshot_id     UUID REFERENCES public.content_snapshots(id) ON DELETE SET NULL,

  -- Ação
  action_type     public.bot_action_type NOT NULL,
  verdict         public.bot_verdict,
  confidence      NUMERIC(4,3),   -- 0.000 a 1.000

  -- Alvo
  target_user_id  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  target_post_id  UUID REFERENCES public.posts(id) ON DELETE SET NULL,
  target_comment_id UUID REFERENCES public.comments(id) ON DELETE SET NULL,

  -- Detalhes da análise
  categories_detected JSONB DEFAULT '[]'::jsonb,
  reasoning       TEXT,           -- Explicação da decisão do bot
  raw_response    JSONB,          -- Resposta bruta da API de IA

  -- Revisão humana
  reviewed_by     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  review_outcome  TEXT CHECK (review_outcome IN ('confirmed', 'overturned', NULL)),
  reviewed_at     TIMESTAMPTZ,

  -- Metadata
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bot_actions_community ON public.bot_actions(community_id);
CREATE INDEX IF NOT EXISTS idx_bot_actions_flag      ON public.bot_actions(flag_id);
CREATE INDEX IF NOT EXISTS idx_bot_actions_verdict   ON public.bot_actions(verdict);
CREATE INDEX IF NOT EXISTS idx_bot_actions_created   ON public.bot_actions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bot_actions_target    ON public.bot_actions(target_user_id) WHERE target_user_id IS NOT NULL;

-- ============================================================================
-- 4. COLUNA EXTRA em flags: snapshot_captured + bot_analyzed
-- ============================================================================
ALTER TABLE public.flags
  ADD COLUMN IF NOT EXISTS snapshot_captured  BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS bot_analyzed       BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS bot_verdict        public.bot_verdict,
  ADD COLUMN IF NOT EXISTS bot_score          NUMERIC(4,3),
  ADD COLUMN IF NOT EXISTS auto_actioned      BOOLEAN DEFAULT FALSE;

-- ============================================================================
-- 5. FUNÇÃO AUXILIAR: capturar snapshot de um post
-- ============================================================================
CREATE OR REPLACE FUNCTION public._capture_post_snapshot(
  p_flag_id    UUID,
  p_post_id    UUID,
  p_capturer   UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_snapshot_id UUID;
  v_post        RECORD;
  v_author      RECORD;
BEGIN
  -- Buscar o post (mesmo que já esteja soft-deleted via content_status)
  SELECT p.*, p.content_status AS cstatus
    INTO v_post
    FROM public.posts p
   WHERE p.id = p_post_id;

  IF NOT FOUND THEN
    -- Post já foi hard-deleted; registrar snapshot vazio com aviso
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_post_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'post', p_post_id,
      jsonb_build_object(
        'error', 'post_not_found',
        'post_id', p_post_id,
        'note', 'Post foi excluído antes do snapshot ser capturado'
      ),
      p_capturer
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  -- Buscar autor
  SELECT nickname, icon_url INTO v_author
    FROM public.profiles WHERE id = v_post.author_id;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_post_id, original_user_id,
    snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'post', p_post_id, v_post.author_id,
    jsonb_build_object(
      'title',           v_post.title,
      'body',            v_post.body,
      'image_urls',      COALESCE(v_post.image_urls, '[]'::jsonb),
      'author_id',       v_post.author_id,
      'author_nickname', COALESCE(v_author.nickname, 'Desconhecido'),
      'author_avatar',   v_author.icon_url,
      'community_id',    v_post.community_id,
      'content_status',  v_post.cstatus,
      'created_at',      v_post.created_at,
      'captured_at',     NOW()
    ),
    p_capturer
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;

-- ============================================================================
-- 6. FUNÇÃO AUXILIAR: capturar snapshot de um comentário
-- ============================================================================
CREATE OR REPLACE FUNCTION public._capture_comment_snapshot(
  p_flag_id      UUID,
  p_comment_id   UUID,
  p_capturer     UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_snapshot_id UUID;
  v_comment     RECORD;
  v_author      RECORD;
BEGIN
  SELECT c.* INTO v_comment
    FROM public.comments c
   WHERE c.id = p_comment_id;

  IF NOT FOUND THEN
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_comment_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'comment', p_comment_id,
      jsonb_build_object(
        'error', 'comment_not_found',
        'comment_id', p_comment_id
      ),
      p_capturer
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  SELECT nickname, icon_url INTO v_author
    FROM public.profiles WHERE id = v_comment.author_id;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_comment_id, original_user_id,
    snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'comment', p_comment_id, v_comment.author_id,
    jsonb_build_object(
      'body',            v_comment.body,
      'image_urls',      COALESCE(v_comment.image_urls, '[]'::jsonb),
      'author_id',       v_comment.author_id,
      'author_nickname', COALESCE(v_author.nickname, 'Desconhecido'),
      'author_avatar',   v_author.icon_url,
      'post_id',         v_comment.post_id,
      'created_at',      v_comment.created_at,
      'captured_at',     NOW()
    ),
    p_capturer
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;

-- ============================================================================
-- 7. FUNÇÃO AUXILIAR: capturar snapshot de mensagem de chat
-- ============================================================================
CREATE OR REPLACE FUNCTION public._capture_chat_snapshot(
  p_flag_id    UUID,
  p_message_id UUID,
  p_capturer   UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_snapshot_id UUID;
  v_msg         RECORD;
  v_sender      RECORD;
BEGIN
  SELECT m.* INTO v_msg
    FROM public.chat_messages m
   WHERE m.id = p_message_id;

  IF NOT FOUND THEN
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_chat_message_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'chat_message', p_message_id,
      jsonb_build_object('error', 'message_not_found', 'message_id', p_message_id),
      p_capturer
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  SELECT nickname, icon_url INTO v_sender
    FROM public.profiles WHERE id = v_msg.sender_id;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_chat_message_id, original_user_id,
    snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'chat_message', p_message_id, v_msg.sender_id,
    jsonb_build_object(
      'content',         v_msg.content,
      'media_url',       v_msg.media_url,
      'sender_id',       v_msg.sender_id,
      'sender_nickname', COALESCE(v_sender.nickname, 'Desconhecido'),
      'sender_avatar',   v_sender.icon_url,
      'thread_id',       v_msg.thread_id,
      'created_at',      v_msg.created_at,
      'captured_at',     NOW()
    ),
    p_capturer
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;

-- ============================================================================
-- 8. RPC PRINCIPAL: submit_flag (atualizada — captura snapshot automaticamente)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.submit_flag(
  p_community_id           UUID,
  p_flag_type              TEXT,
  p_reason                 TEXT    DEFAULT NULL,
  p_target_post_id         UUID    DEFAULT NULL,
  p_target_comment_id      UUID    DEFAULT NULL,
  p_target_chat_message_id UUID    DEFAULT NULL,
  p_target_user_id         UUID    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_flag_id     UUID;
  v_snapshot_id UUID;
  v_user_id     UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar duplicata pendente
  IF p_target_post_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_post_id = p_target_post_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou este conteúdo';
    END IF;
  END IF;

  IF p_target_comment_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_comment_id = p_target_comment_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou este comentário';
    END IF;
  END IF;

  -- Inserir a flag
  INSERT INTO public.flags (
    community_id, reporter_id, flag_type, reason, status,
    target_post_id, target_comment_id, target_chat_message_id, target_user_id
  ) VALUES (
    p_community_id, v_user_id, p_flag_type, p_reason, 'pending',
    p_target_post_id, p_target_comment_id, p_target_chat_message_id, p_target_user_id
  ) RETURNING id INTO v_flag_id;

  -- Capturar snapshot do conteúdo imediatamente
  IF p_target_post_id IS NOT NULL THEN
    v_snapshot_id := public._capture_post_snapshot(v_flag_id, p_target_post_id, v_user_id);
  ELSIF p_target_comment_id IS NOT NULL THEN
    v_snapshot_id := public._capture_comment_snapshot(v_flag_id, p_target_comment_id, v_user_id);
  ELSIF p_target_chat_message_id IS NOT NULL THEN
    v_snapshot_id := public._capture_chat_snapshot(v_flag_id, p_target_chat_message_id, v_user_id);
  END IF;

  -- Marcar flag como snapshot capturado
  IF v_snapshot_id IS NOT NULL THEN
    UPDATE public.flags SET snapshot_captured = TRUE WHERE id = v_flag_id;
  END IF;

  RETURN jsonb_build_object(
    'flag_id',     v_flag_id,
    'snapshot_id', v_snapshot_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_flag TO authenticated;

-- ============================================================================
-- 9. RPC: get_flag_detail — retorna flag + snapshot + histórico de ações do bot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_flag_detail(p_flag_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_flag    RECORD;
  v_snap    RECORD;
  v_bot     JSONB;
  v_reporter RECORD;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  -- Buscar flag
  SELECT f.*, cm.role AS caller_role
    INTO v_flag
    FROM public.flags f
    LEFT JOIN public.community_members cm
      ON cm.community_id = f.community_id AND cm.user_id = v_user_id
   WHERE f.id = p_flag_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'Denúncia não encontrada'; END IF;

  -- Apenas staff ou o próprio denunciante pode ver os detalhes
  IF v_flag.reporter_id != v_user_id
     AND v_flag.caller_role NOT IN ('agent','leader','curator','moderator') THEN
    RAISE EXCEPTION 'Sem permissão para visualizar esta denúncia';
  END IF;

  -- Buscar snapshot
  SELECT * INTO v_snap
    FROM public.content_snapshots
   WHERE flag_id = p_flag_id
   ORDER BY captured_at DESC
   LIMIT 1;

  -- Buscar ações do bot
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',                 ba.id,
      'action_type',        ba.action_type,
      'verdict',            ba.verdict,
      'confidence',         ba.confidence,
      'categories',         ba.categories_detected,
      'reasoning',          ba.reasoning,
      'review_outcome',     ba.review_outcome,
      'created_at',         ba.created_at
    ) ORDER BY ba.created_at DESC
  ) INTO v_bot
  FROM public.bot_actions ba
  WHERE ba.flag_id = p_flag_id;

  -- Buscar reporter
  SELECT nickname, icon_url INTO v_reporter
    FROM public.profiles WHERE id = v_flag.reporter_id;

  RETURN jsonb_build_object(
    'flag',     jsonb_build_object(
      'id',               v_flag.id,
      'community_id',     v_flag.community_id,
      'flag_type',        v_flag.flag_type,
      'reason',           v_flag.reason,
      'status',           v_flag.status,
      'bot_verdict',      v_flag.bot_verdict,
      'bot_score',        v_flag.bot_score,
      'auto_actioned',    v_flag.auto_actioned,
      'snapshot_captured',v_flag.snapshot_captured,
      'created_at',       v_flag.created_at,
      'resolved_at',      v_flag.resolved_at,
      'reporter', jsonb_build_object(
        'id',       v_flag.reporter_id,
        'nickname', COALESCE(v_reporter.nickname, 'Anônimo'),
        'avatar',   v_reporter.icon_url
      )
    ),
    'snapshot', CASE WHEN v_snap.id IS NOT NULL THEN jsonb_build_object(
      'id',            v_snap.id,
      'content_type',  v_snap.content_type,
      'snapshot_data', v_snap.snapshot_data,
      'bot_verdict',   v_snap.bot_verdict,
      'bot_score',     v_snap.bot_score,
      'bot_categories',v_snap.bot_categories,
      'captured_at',   v_snap.captured_at
    ) ELSE NULL END,
    'bot_actions', COALESCE(v_bot, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_flag_detail TO authenticated;

-- ============================================================================
-- 10. RPC: get_community_flags — lista flags de uma comunidade (staff only)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_community_flags(
  p_community_id UUID,
  p_status       TEXT    DEFAULT 'pending',  -- 'pending','approved','rejected','all'
  p_limit        INT     DEFAULT 30,
  p_offset       INT     DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role    TEXT;
  v_flags   JSONB;
  v_total   BIGINT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  SELECT role INTO v_role
    FROM public.community_members
   WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent','leader','curator','moderator') THEN
    RAISE EXCEPTION 'Sem permissão';
  END IF;

  SELECT COUNT(*) INTO v_total
    FROM public.flags
   WHERE community_id = p_community_id
     AND (p_status = 'all' OR status = p_status);

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
      -- Reporter
      jsonb_build_object(
        'id',       rp.id,
        'nickname', rp.nickname,
        'avatar',   rp.icon_url
      ) AS reporter,
      -- Snapshot resumido
      (SELECT jsonb_build_object(
        'id',           cs.id,
        'content_type', cs.content_type,
        'bot_verdict',  cs.bot_verdict,
        'captured_at',  cs.captured_at,
        -- preview do conteúdo (primeiros 200 chars do body/content)
        'preview', CASE
          WHEN cs.content_type = 'post'
            THEN LEFT(cs.snapshot_data->>'body', 200)
          WHEN cs.content_type = 'comment'
            THEN LEFT(cs.snapshot_data->>'body', 200)
          WHEN cs.content_type = 'chat_message'
            THEN LEFT(cs.snapshot_data->>'content', 200)
          ELSE ''
        END
      )
      FROM public.content_snapshots cs
      WHERE cs.flag_id = f.id
      ORDER BY cs.captured_at DESC LIMIT 1
      ) AS snapshot_preview
    FROM public.flags f
    LEFT JOIN public.profiles rp ON rp.id = f.reporter_id
    WHERE f.community_id = p_community_id
      AND (p_status = 'all' OR f.status = p_status)
    ORDER BY f.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN jsonb_build_object(
    'flags', COALESCE(v_flags, '[]'::jsonb),
    'total', v_total,
    'limit', p_limit,
    'offset', p_offset
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_flags TO authenticated;

-- ============================================================================
-- 11. RPC: resolve_flag — resolve uma denúncia com ação opcional
-- ============================================================================
CREATE OR REPLACE FUNCTION public.resolve_flag(
  p_flag_id        UUID,
  p_action         TEXT,  -- 'approved' (tomar ação) ou 'rejected' (ignorar)
  p_resolution_note TEXT  DEFAULT NULL,
  -- Ação opcional sobre o conteúdo
  p_moderate_content BOOLEAN DEFAULT FALSE,
  p_moderate_action  TEXT    DEFAULT NULL  -- 'delete','warn','ban'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_flag    RECORD;
  v_role    TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  SELECT f.* INTO v_flag FROM public.flags f WHERE f.id = p_flag_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Denúncia não encontrada'; END IF;

  SELECT role INTO v_role
    FROM public.community_members
   WHERE community_id = v_flag.community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent','leader','curator','moderator') THEN
    RAISE EXCEPTION 'Sem permissão para resolver denúncias';
  END IF;

  -- Atualizar status da flag
  UPDATE public.flags SET
    status          = p_action,
    resolved_by     = v_user_id,
    resolution_note = COALESCE(p_resolution_note, resolution_note),
    resolved_at     = NOW()
  WHERE id = p_flag_id;

  -- Ação sobre o conteúdo (se solicitado)
  IF p_moderate_content AND p_moderate_action IS NOT NULL THEN
    IF p_moderate_action = 'delete' AND v_flag.target_post_id IS NOT NULL THEN
      UPDATE public.posts SET content_status = 'disabled'
       WHERE id = v_flag.target_post_id;
    END IF;
    -- Registrar no log de moderação
    INSERT INTO public.moderation_logs (
      community_id, moderator_id, action,
      target_post_id, target_user_id, reason
    ) VALUES (
      v_flag.community_id, v_user_id, p_moderate_action,
      v_flag.target_post_id, v_flag.target_user_id,
      COALESCE(p_resolution_note, 'Ação via resolução de denúncia')
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'flag_id', p_flag_id, 'new_status', p_action);
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_flag TO authenticated;

-- ============================================================================
-- 12. RPC: get_bot_stats — estatísticas do bot para o painel admin
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_bot_stats(
  p_community_id UUID DEFAULT NULL,
  p_days         INT  DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_since   TIMESTAMPTZ := NOW() - (p_days || ' days')::INTERVAL;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  RETURN jsonb_build_object(
    'period_days', p_days,
    'total_flags', (
      SELECT COUNT(*) FROM public.flags
       WHERE created_at >= v_since
         AND (p_community_id IS NULL OR community_id = p_community_id)
    ),
    'pending_flags', (
      SELECT COUNT(*) FROM public.flags
       WHERE status = 'pending'
         AND (p_community_id IS NULL OR community_id = p_community_id)
    ),
    'bot_analyzed', (
      SELECT COUNT(*) FROM public.flags
       WHERE bot_analyzed = TRUE
         AND created_at >= v_since
         AND (p_community_id IS NULL OR community_id = p_community_id)
    ),
    'auto_actioned', (
      SELECT COUNT(*) FROM public.flags
       WHERE auto_actioned = TRUE
         AND created_at >= v_since
         AND (p_community_id IS NULL OR community_id = p_community_id)
    ),
    'verdicts', (
      SELECT jsonb_object_agg(bot_verdict, cnt)
        FROM (
          SELECT bot_verdict, COUNT(*) AS cnt
            FROM public.content_snapshots
           WHERE bot_analyzed_at >= v_since
             AND bot_verdict IS NOT NULL
           GROUP BY bot_verdict
        ) t
    ),
    'top_categories', (
      SELECT jsonb_agg(cat ORDER BY freq DESC) FROM (
        SELECT cat_elem AS cat, COUNT(*) AS freq
          FROM public.content_snapshots,
               jsonb_array_elements_text(bot_categories) AS cat_elem
         WHERE bot_analyzed_at >= v_since
         GROUP BY cat_elem
         ORDER BY freq DESC
         LIMIT 10
      ) t
    ),
    'daily_flags', (
      SELECT jsonb_agg(
        jsonb_build_object('date', day::date, 'count', cnt)
        ORDER BY day
      )
      FROM (
        SELECT date_trunc('day', created_at) AS day, COUNT(*) AS cnt
          FROM public.flags
         WHERE created_at >= v_since
           AND (p_community_id IS NULL OR community_id = p_community_id)
         GROUP BY day
         ORDER BY day
      ) t
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_bot_stats TO authenticated;

-- ============================================================================
-- 13. RPC: record_bot_action — chamada pela Edge Function do bot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.record_bot_action(
  p_flag_id           UUID,
  p_snapshot_id       UUID,
  p_action_type       TEXT,
  p_verdict           TEXT,
  p_confidence        NUMERIC,
  p_categories        JSONB   DEFAULT '[]'::jsonb,
  p_reasoning         TEXT    DEFAULT NULL,
  p_raw_response      JSONB   DEFAULT NULL,
  p_auto_action       BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_bot_action_id UUID;
  v_flag          RECORD;
BEGIN
  SELECT * INTO v_flag FROM public.flags WHERE id = p_flag_id;

  -- Inserir ação do bot
  INSERT INTO public.bot_actions (
    community_id, flag_id, snapshot_id,
    action_type, verdict, confidence,
    categories_detected, reasoning, raw_response
  ) VALUES (
    v_flag.community_id, p_flag_id, p_snapshot_id,
    p_action_type::public.bot_action_type,
    p_verdict::public.bot_verdict,
    p_confidence,
    p_categories, p_reasoning, p_raw_response
  ) RETURNING id INTO v_bot_action_id;

  -- Atualizar snapshot com resultado da análise
  UPDATE public.content_snapshots SET
    bot_verdict     = p_verdict::public.bot_verdict,
    bot_score       = p_confidence,
    bot_categories  = p_categories,
    bot_analyzed_at = NOW()
  WHERE id = p_snapshot_id;

  -- Atualizar flag com resultado do bot
  UPDATE public.flags SET
    bot_analyzed = TRUE,
    bot_verdict  = p_verdict::public.bot_verdict,
    bot_score    = p_confidence,
    auto_actioned = p_auto_action
  WHERE id = p_flag_id;

  -- Se auto_action e conteúdo deve ser removido automaticamente
  IF p_auto_action AND p_verdict = 'auto_removed' THEN
    IF v_flag.target_post_id IS NOT NULL THEN
      UPDATE public.posts SET content_status = 'disabled'
       WHERE id = v_flag.target_post_id;
    END IF;
    -- Marcar flag como resolvida automaticamente
    UPDATE public.flags SET
      status      = 'approved',
      resolved_at = NOW(),
      resolution_note = 'Removido automaticamente pelo bot de moderação'
    WHERE id = p_flag_id;
  END IF;

  RETURN v_bot_action_id;
END;
$$;

-- Apenas service_role pode chamar (bot usa service_role)
GRANT EXECUTE ON FUNCTION public.record_bot_action TO service_role;

-- ============================================================================
-- 14. RLS: content_snapshots — staff pode ver, usuários só veem os próprios
-- ============================================================================
ALTER TABLE public.content_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "snapshots_staff_read" ON public.content_snapshots
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.flags f
      JOIN public.community_members cm
        ON cm.community_id = f.community_id
       AND cm.user_id = auth.uid()
       AND cm.role IN ('agent','leader','curator','moderator')
      WHERE f.id = content_snapshots.flag_id
    )
    OR
    -- Reporter pode ver o próprio snapshot
    EXISTS (
      SELECT 1 FROM public.flags f
      WHERE f.id = content_snapshots.flag_id
        AND f.reporter_id = auth.uid()
    )
  );

-- Service role pode tudo (bot)
CREATE POLICY "snapshots_service_role_all" ON public.content_snapshots
  FOR ALL USING (auth.role() = 'service_role');

-- ============================================================================
-- 15. RLS: bot_actions — staff pode ver
-- ============================================================================
ALTER TABLE public.bot_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bot_actions_staff_read" ON public.bot_actions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.community_members cm
      WHERE cm.community_id = bot_actions.community_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('agent','leader','curator','moderator')
    )
  );

CREATE POLICY "bot_actions_service_role_all" ON public.bot_actions
  FOR ALL USING (auth.role() = 'service_role');

-- ============================================================================
-- 16. ÍNDICE extra em flags para performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_flags_bot_analyzed ON public.flags(bot_analyzed) WHERE bot_analyzed = FALSE;
CREATE INDEX IF NOT EXISTS idx_flags_auto_actioned ON public.flags(auto_actioned) WHERE auto_actioned = TRUE;
