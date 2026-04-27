-- ============================================================================
-- 179_matchmaking_and_temp_chat.sql
-- Feature "Encontrar Pessoas": fila de matchmaking por interesse,
-- chat temporário com timer de 24h, cancelamento e promoção para chat permanente.
-- ============================================================================

-- ── 1. Adicionar tipo 'match_dm' ao enum chat_thread_type ─────────────────────
DO $$ BEGIN
  ALTER TYPE public.chat_thread_type ADD VALUE IF NOT EXISTS 'match_dm';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 2. Colunas de chat temporário na tabela chat_threads ──────────────────────
ALTER TABLE public.chat_threads
  ADD COLUMN IF NOT EXISTS is_temporary        BOOLEAN     DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS temp_expires_at     TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS temp_promoted_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS match_interests     JSONB       DEFAULT '[]'::jsonb;

-- ── 3. Tabela de fila de matchmaking ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.match_queue (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  interests   JSONB       NOT NULL DEFAULT '[]'::jsonb,  -- snapshot dos interesses no momento da entrada
  entered_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)   -- cada usuário só pode estar na fila uma vez
);

CREATE INDEX IF NOT EXISTS idx_match_queue_entered ON public.match_queue(entered_at);

-- RLS: usuário só vê/manipula a própria entrada
ALTER TABLE public.match_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "match_queue_self" ON public.match_queue;
CREATE POLICY "match_queue_self" ON public.match_queue
  USING (user_id = auth.uid());

-- ── 4. RPC: entrar na fila de matchmaking ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enter_match_queue()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id          UUID := auth.uid();
  v_interests        JSONB;
  v_match            RECORD;
  v_thread_id        UUID;
  v_common_interests JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Buscar interesses do usuário
  SELECT selected_interests INTO v_interests
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_interests IS NULL OR jsonb_array_length(v_interests) = 0 THEN
    RAISE EXCEPTION 'Você precisa adicionar interesses ao seu perfil antes de entrar na fila.' USING ERRCODE = 'P0001';
  END IF;

  -- Verificar se já está em um match_dm temporário ativo
  IF EXISTS (
    SELECT 1 FROM public.chat_members cm
    JOIN public.chat_threads ct ON ct.id = cm.thread_id
    WHERE cm.user_id = v_user_id
      AND ct.type = 'match_dm'
      AND ct.is_temporary = TRUE
      AND ct.temp_expires_at > NOW()
  ) THEN
    RAISE EXCEPTION 'Você já possui um chat de match ativo. Cancele ou aguarde ele expirar.' USING ERRCODE = 'P0001';
  END IF;

  -- Inserir ou atualizar entrada na fila (upsert)
  INSERT INTO public.match_queue (user_id, interests, entered_at)
  VALUES (v_user_id, v_interests, NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET interests = EXCLUDED.interests, entered_at = NOW();

  -- Tentar encontrar um match: outro usuário na fila com pelo menos 1 interesse em comum
  SELECT mq.*
  INTO v_match
  FROM public.match_queue mq
  WHERE mq.user_id <> v_user_id
    -- Pelo menos 1 interesse em comum (interseção de arrays JSONB)
    AND EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(mq.interests) AS mi(val)
      WHERE mi.val IN (
        SELECT jsonb_array_elements_text(v_interests)
      )
    )
    -- Não está bloqueado pelo usuário atual nem bloqueou
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = v_user_id AND b.blocked_id = mq.user_id)
         OR (b.blocker_id = mq.user_id AND b.blocked_id = v_user_id)
    )
  ORDER BY (
    -- Pontuação: número de interesses em comum (maior = melhor)
    SELECT COUNT(*)
    FROM jsonb_array_elements_text(mq.interests) AS mi(val)
    WHERE mi.val IN (SELECT jsonb_array_elements_text(v_interests))
  ) DESC, mq.entered_at ASC
  LIMIT 1;

  IF v_match IS NULL THEN
    -- Nenhum match encontrado ainda, aguardar na fila
    RETURN jsonb_build_object('status', 'waiting');
  END IF;

  -- ── Match encontrado! ──────────────────────────────────────────────────────

  -- Calcular interesses em comum
  SELECT COALESCE(jsonb_agg(val), '[]'::jsonb)
  INTO v_common_interests
  FROM (
    SELECT mi.val
    FROM jsonb_array_elements_text(v_match.interests) AS mi(val)
    WHERE mi.val IN (SELECT jsonb_array_elements_text(v_interests))
  ) sub;

  -- Criar o chat temporário (match_dm)
  INSERT INTO public.chat_threads (
    type, is_temporary, temp_expires_at, match_interests,
    host_id, title, created_at, updated_at
  ) VALUES (
    'match_dm', TRUE, NOW() + INTERVAL '24 hours', v_common_interests,
    v_user_id, 'Chat de Match', NOW(), NOW()
  ) RETURNING id INTO v_thread_id;

  -- Adicionar ambos os usuários como membros
  INSERT INTO public.chat_members (thread_id, user_id, role, status, joined_at)
  VALUES
    (v_thread_id, v_user_id,    'member', 'active', NOW()),
    (v_thread_id, v_match.user_id, 'member', 'active', NOW());

  -- Remover ambos da fila
  DELETE FROM public.match_queue WHERE user_id IN (v_user_id, v_match.user_id);

  -- Mensagem de sistema de match
  INSERT INTO public.chat_messages (thread_id, author_id, type, content, created_at)
  VALUES (
    v_thread_id, v_user_id, 'system_join',
    'Vocês têm interesses em comum! Este chat expira em 24h se nenhum dos dois cancelar.',
    NOW()
  );

  RETURN jsonb_build_object(
    'status',    'matched',
    'thread_id', v_thread_id,
    'matched_user_id', v_match.user_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.enter_match_queue() TO authenticated;

-- ── 5. RPC: sair da fila de matchmaking ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.leave_match_queue()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;
  DELETE FROM public.match_queue WHERE user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.leave_match_queue() TO authenticated;

-- ── 6. RPC: verificar status na fila (polling) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.get_match_queue_status()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_in_queue BOOLEAN;
  v_thread   RECORD;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  -- Verificar se está na fila
  SELECT EXISTS(SELECT 1 FROM public.match_queue WHERE user_id = v_user_id)
  INTO v_in_queue;

  -- Verificar se tem um match_dm ativo
  SELECT ct.id, ct.temp_expires_at, ct.match_interests, ct.is_temporary, ct.temp_promoted_at
  INTO v_thread
  FROM public.chat_members cm
  JOIN public.chat_threads ct ON ct.id = cm.thread_id
  WHERE cm.user_id = v_user_id
    AND ct.type = 'match_dm'
  ORDER BY ct.created_at DESC
  LIMIT 1;

  IF v_thread.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status',          CASE WHEN v_thread.is_temporary THEN 'matched' ELSE 'promoted' END,
      'thread_id',       v_thread.id,
      'expires_at',      v_thread.temp_expires_at,
      'promoted_at',     v_thread.temp_promoted_at,
      'match_interests', v_thread.match_interests
    );
  END IF;

  IF v_in_queue THEN
    RETURN jsonb_build_object('status', 'waiting');
  END IF;

  RETURN jsonb_build_object('status', 'idle');
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_match_queue_status() TO authenticated;

-- ── 7. RPC: cancelar chat de match (apaga para ambos) ────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_match_chat(p_thread_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  -- Verificar que o usuário é membro deste chat
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Você não é membro deste chat.' USING ERRCODE = 'P0001';
  END IF;

  -- Verificar que é um match_dm temporário
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_threads
    WHERE id = p_thread_id AND type = 'match_dm' AND is_temporary = TRUE
  ) THEN
    RAISE EXCEPTION 'Este chat não pode ser cancelado.' USING ERRCODE = 'P0001';
  END IF;

  -- Deletar mensagens do chat
  DELETE FROM public.chat_messages WHERE thread_id = p_thread_id;

  -- Deletar membros
  DELETE FROM public.chat_members WHERE thread_id = p_thread_id;

  -- Deletar o thread
  DELETE FROM public.chat_threads WHERE id = p_thread_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.cancel_match_chat(UUID) TO authenticated;

-- ── 8. RPC: promover chat temporário para permanente ─────────────────────────
-- Chamado automaticamente pelo frontend após 24h sem cancelamento
CREATE OR REPLACE FUNCTION public.promote_match_chat(p_thread_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Não autenticado'; END IF;

  -- Verificar que o usuário é membro
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Você não é membro deste chat.' USING ERRCODE = 'P0001';
  END IF;

  -- Verificar que é um match_dm temporário expirado (24h passaram)
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_threads
    WHERE id = p_thread_id
      AND type = 'match_dm'
      AND is_temporary = TRUE
      AND temp_expires_at <= NOW()
  ) THEN
    RAISE EXCEPTION 'O chat ainda não pode ser promovido (24h não passaram).' USING ERRCODE = 'P0001';
  END IF;

  -- Promover: virar DM normal
  UPDATE public.chat_threads
  SET
    is_temporary     = FALSE,
    type             = 'dm',
    temp_promoted_at = NOW(),
    updated_at       = NOW()
  WHERE id = p_thread_id;

  -- Mensagem de sistema de promoção
  INSERT INTO public.chat_messages (thread_id, author_id, type, content, created_at)
  VALUES (
    p_thread_id, v_user_id, 'system_join',
    '🎉 Este chat foi promovido! Vocês se conectaram e agora têm uma conversa permanente.',
    NOW()
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.promote_match_chat(UUID) TO authenticated;

-- ── 9. Trigger: promover automaticamente chats expirados ─────────────────────
-- (Executado via cron job ou chamada periódica do frontend)
CREATE OR REPLACE FUNCTION public.auto_promote_expired_match_chats()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count INTEGER := 0;
BEGIN
  -- Promover todos os chats temporários cujo prazo de 24h passou
  UPDATE public.chat_threads
  SET
    is_temporary     = FALSE,
    type             = 'dm',
    temp_promoted_at = NOW(),
    updated_at       = NOW()
  WHERE type = 'match_dm'
    AND is_temporary = TRUE
    AND temp_expires_at <= NOW();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.auto_promote_expired_match_chats() TO authenticated;

-- ── 10. Índices para performance ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_chat_threads_temp ON public.chat_threads(is_temporary, temp_expires_at)
  WHERE is_temporary = TRUE;

CREATE INDEX IF NOT EXISTS idx_chat_threads_match_dm ON public.chat_threads(type)
  WHERE type = 'match_dm';

-- ── 11. RPC set_user_interests — salva os interesses do usuário no perfil ─────
-- A coluna selected_interests em profiles é JSONB (criada na migration 001).
-- Esta RPC permite que o usuário autenticado atualize seus próprios interesses.
DROP FUNCTION IF EXISTS public.set_user_interests(TEXT[]);

CREATE OR REPLACE FUNCTION public.set_user_interests(p_interests JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET selected_interests = p_interests
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_user_interests(JSONB) TO authenticated;
