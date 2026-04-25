-- =============================================================================
-- Migration 137: Suporte completo a snapshots de denúncias
-- • Adiciona target_story_id na tabela flags
-- • Adiciona original_wiki_id e original_story_id em content_snapshots
-- • Expande CHECK de content_type para incluir 'story'
-- • Cria _capture_wiki_snapshot e _capture_story_snapshot
-- • Atualiza submit_flag para capturar snapshots de wiki e story
-- • Atualiza get_community_flags para retornar preview do snapshot
-- • Atualiza get_flag_detail para incluir dados de wiki/story
-- =============================================================================

-- ============================================================================
-- 1. Adicionar target_story_id na tabela flags (se não existir)
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'flags' AND column_name = 'target_story_id'
  ) THEN
    ALTER TABLE public.flags
      ADD COLUMN target_story_id UUID REFERENCES public.stories(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_flags_story ON public.flags(target_story_id)
  WHERE target_story_id IS NOT NULL;

-- ============================================================================
-- 2. Adicionar colunas de referência em content_snapshots para wiki e story
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'content_snapshots' AND column_name = 'original_wiki_id'
  ) THEN
    ALTER TABLE public.content_snapshots
      ADD COLUMN original_wiki_id UUID REFERENCES public.wiki_entries(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'content_snapshots' AND column_name = 'original_story_id'
  ) THEN
    ALTER TABLE public.content_snapshots
      ADD COLUMN original_story_id UUID REFERENCES public.stories(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_snapshots_wiki  ON public.content_snapshots(original_wiki_id)  WHERE original_wiki_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_snapshots_story ON public.content_snapshots(original_story_id) WHERE original_story_id IS NOT NULL;

-- ============================================================================
-- 3. Expandir CHECK de content_type para incluir 'story'
-- ============================================================================
DO $$
DECLARE
  v_constraint_name TEXT;
BEGIN
  SELECT c.conname INTO v_constraint_name
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
   WHERE t.relname = 'content_snapshots'
     AND c.contype = 'c'
     AND pg_get_constraintdef(c.oid) LIKE '%content_type%'
   LIMIT 1;

  IF v_constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.content_snapshots DROP CONSTRAINT %I', v_constraint_name);
  END IF;

  ALTER TABLE public.content_snapshots
    ADD CONSTRAINT content_snapshots_content_type_check
    CHECK (content_type IN ('post', 'comment', 'chat_message', 'profile', 'wiki', 'story'));
END $$;

-- ============================================================================
-- 4. FUNÇÃO AUXILIAR: capturar snapshot de uma entrada wiki
-- ============================================================================
CREATE OR REPLACE FUNCTION public._capture_wiki_snapshot(
  p_flag_id    UUID,
  p_wiki_id    UUID,
  p_captured_by UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_wiki        RECORD;
  v_author      RECORD;
  v_snapshot_id UUID;
BEGIN
  SELECT w.*, p.nickname AS author_nickname, p.icon_url AS author_avatar
    INTO v_wiki
    FROM public.wiki_entries w
    LEFT JOIN public.profiles p ON p.id = w.author_id
   WHERE w.id = p_wiki_id;

  IF NOT FOUND THEN
    -- Wiki já foi excluída antes do snapshot
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_wiki_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'wiki', p_wiki_id,
      jsonb_build_object(
        'error', true,
        'note', 'Wiki foi excluída antes do snapshot ser capturado'
      ),
      p_captured_by
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_wiki_id, snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'wiki', p_wiki_id,
    jsonb_build_object(
      'title',           v_wiki.title,
      'content',         v_wiki.content,
      'cover_image_url', v_wiki.cover_image_url,
      'tags',            v_wiki.tags,
      'author_id',       v_wiki.author_id,
      'author_nickname', v_wiki.author_nickname,
      'author_avatar',   v_wiki.author_avatar,
      'created_at',      v_wiki.created_at
    ),
    p_captured_by
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public._capture_wiki_snapshot TO authenticated;

-- ============================================================================
-- 5. FUNÇÃO AUXILIAR: capturar snapshot de um story
-- ============================================================================
CREATE OR REPLACE FUNCTION public._capture_story_snapshot(
  p_flag_id    UUID,
  p_story_id   UUID,
  p_captured_by UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_story       RECORD;
  v_snapshot_id UUID;
BEGIN
  SELECT s.*, p.nickname AS author_nickname, p.icon_url AS author_avatar
    INTO v_story
    FROM public.stories s
    LEFT JOIN public.profiles p ON p.id = s.author_id
   WHERE s.id = p_story_id;

  IF NOT FOUND THEN
    INSERT INTO public.content_snapshots (
      flag_id, content_type, original_story_id, snapshot_data, captured_by
    ) VALUES (
      p_flag_id, 'story', p_story_id,
      jsonb_build_object(
        'error', true,
        'note', 'Story foi excluído antes do snapshot ser capturado'
      ),
      p_captured_by
    ) RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
  END IF;

  INSERT INTO public.content_snapshots (
    flag_id, content_type, original_story_id, snapshot_data, captured_by
  ) VALUES (
    p_flag_id, 'story', p_story_id,
    jsonb_build_object(
      'type',             v_story.type,
      'media_url',        v_story.media_url,
      'text_content',     v_story.text_content,
      'background_color', v_story.background_color,
      'author_id',        v_story.author_id,
      'author_nickname',  v_story.author_nickname,
      'author_avatar',    v_story.author_avatar,
      'created_at',       v_story.created_at
    ),
    p_captured_by
  ) RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public._capture_story_snapshot TO authenticated;

-- ============================================================================
-- 6. Atualizar submit_flag para capturar snapshots de wiki e story
-- (remover versão antiga com assinatura diferente)
-- ============================================================================
DROP FUNCTION IF EXISTS public.submit_flag(
  UUID, TEXT, TEXT, UUID, UUID, UUID, UUID
);
CREATE OR REPLACE FUNCTION public.submit_flag(
  p_community_id           UUID,
  p_flag_type              TEXT,
  p_reason                 TEXT    DEFAULT NULL,
  p_target_post_id         UUID    DEFAULT NULL,
  p_target_comment_id      UUID    DEFAULT NULL,
  p_target_chat_message_id UUID    DEFAULT NULL,
  p_target_user_id         UUID    DEFAULT NULL,
  p_target_wiki_id         UUID    DEFAULT NULL,
  p_target_story_id        UUID    DEFAULT NULL
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

  -- Verificar duplicata pendente por tipo de alvo
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

  IF p_target_chat_message_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_chat_message_id = p_target_chat_message_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou esta mensagem';
    END IF;
  END IF;

  IF p_target_wiki_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_wiki_id = p_target_wiki_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou esta wiki';
    END IF;
  END IF;

  IF p_target_story_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_story_id = p_target_story_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou este story';
    END IF;
  END IF;

  IF p_target_user_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.flags
       WHERE reporter_id = v_user_id
         AND target_user_id = p_target_user_id
         AND status = 'pending'
    ) THEN
      RAISE EXCEPTION 'Você já denunciou este usuário';
    END IF;
  END IF;

  -- Inserir a flag
  INSERT INTO public.flags (
    community_id, reporter_id, flag_type, reason, status,
    target_post_id, target_comment_id, target_chat_message_id,
    target_user_id, target_wiki_id, target_story_id
  ) VALUES (
    p_community_id, v_user_id, p_flag_type::public.flag_type, p_reason, 'pending',
    p_target_post_id, p_target_comment_id, p_target_chat_message_id,
    p_target_user_id, p_target_wiki_id, p_target_story_id
  ) RETURNING id INTO v_flag_id;

  -- Capturar snapshot do conteúdo imediatamente
  IF p_target_post_id IS NOT NULL THEN
    v_snapshot_id := public._capture_post_snapshot(v_flag_id, p_target_post_id, v_user_id);
  ELSIF p_target_comment_id IS NOT NULL THEN
    v_snapshot_id := public._capture_comment_snapshot(v_flag_id, p_target_comment_id, v_user_id);
  ELSIF p_target_chat_message_id IS NOT NULL THEN
    v_snapshot_id := public._capture_chat_snapshot(v_flag_id, p_target_chat_message_id, v_user_id);
  ELSIF p_target_wiki_id IS NOT NULL THEN
    v_snapshot_id := public._capture_wiki_snapshot(v_flag_id, p_target_wiki_id, v_user_id);
  ELSIF p_target_story_id IS NOT NULL THEN
    v_snapshot_id := public._capture_story_snapshot(v_flag_id, p_target_story_id, v_user_id);
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
-- 7. Atualizar get_flag_detail para incluir dados de wiki/story no snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_flag_detail(p_flag_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role    TEXT;
  v_flag    RECORD;
  v_snap    RECORD;
  v_bot     JSONB;
  v_reporter RECORD;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  SELECT * INTO v_flag FROM public.flags WHERE id = p_flag_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Denúncia não encontrada'; END IF;

  -- Verificar permissão: staff da comunidade ou o próprio reporter
  SELECT role INTO v_role
    FROM public.community_members
   WHERE community_id = v_flag.community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent','leader','curator','moderator')
     AND v_flag.reporter_id <> v_user_id THEN
    RAISE EXCEPTION 'Sem permissão';
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
      'reasoning',      ba.reasoning,
      'review_outcome', ba.review_outcome,
      'created_at',     ba.created_at
    ) ORDER BY ba.created_at DESC
  ) INTO v_bot
  FROM public.bot_actions ba
  WHERE ba.flag_id = p_flag_id;

  -- Buscar reporter
  SELECT nickname, icon_url INTO v_reporter
    FROM public.profiles WHERE id = v_flag.reporter_id;

  RETURN jsonb_build_object(
    'flag', jsonb_build_object(
      'id',                v_flag.id,
      'community_id',      v_flag.community_id,
      'flag_type',         v_flag.flag_type,
      'reason',            v_flag.reason,
      'status',            v_flag.status,
      'bot_verdict',       v_flag.bot_verdict,
      'bot_score',         v_flag.bot_score,
      'auto_actioned',     v_flag.auto_actioned,
      'snapshot_captured', v_flag.snapshot_captured,
      'created_at',        v_flag.created_at,
      'resolved_at',       v_flag.resolved_at,
      'target_post_id',         v_flag.target_post_id,
      'target_comment_id',      v_flag.target_comment_id,
      'target_chat_message_id', v_flag.target_chat_message_id,
      'target_user_id',         v_flag.target_user_id,
      'target_wiki_id',         v_flag.target_wiki_id,
      'target_story_id',        v_flag.target_story_id,
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
-- 8. Atualizar get_community_flags para usar RPC e retornar preview do snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_community_flags(
  p_community_id UUID,
  p_status       TEXT    DEFAULT 'pending',
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
GRANT EXECUTE ON FUNCTION public.get_community_flags TO authenticated;

-- ============================================================================
-- 9. RLS: content_snapshots — garantir que líderes/moderadores podem ler
-- ============================================================================
DROP POLICY IF EXISTS "snapshots_staff_read" ON public.content_snapshots;
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
    EXISTS (
      SELECT 1 FROM public.flags f
      WHERE f.id = content_snapshots.flag_id
        AND f.reporter_id = auth.uid()
    )
  );
