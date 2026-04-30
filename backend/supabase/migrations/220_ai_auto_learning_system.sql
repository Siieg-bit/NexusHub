-- ============================================================
-- Migration 220: Sistema de Auto-Aprendizado para IAs
-- Tabelas: ai_learning_memories, ai_behavior_patterns, ai_feedback_queue
-- RPCs: admin_get_learning_memories, admin_approve_memory,
--        admin_reject_memory, admin_edit_memory, admin_delete_memory,
--        admin_get_behavior_patterns, admin_toggle_pattern,
--        admin_get_learning_stats, admin_clear_memories,
--        submit_ai_feedback (para usuários), get_ai_context_memories (para o app)
-- ============================================================

-- ─── 1. Tabela: ai_feedback_queue ─────────────────────────────────────────────
-- Fila de feedbacks brutos enviados pelos usuários durante conversas.
-- Processados periodicamente para gerar memórias aprovadas.
CREATE TABLE IF NOT EXISTS public.ai_feedback_queue (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id    uuid NOT NULL REFERENCES public.ai_characters(id) ON DELETE CASCADE,
  session_id      uuid REFERENCES public.chat_roleplay_sessions(id) ON DELETE SET NULL,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_message    text NOT NULL,
  ai_response     text NOT NULL,
  rating          smallint NOT NULL CHECK (rating IN (-1, 1)), -- -1 = ruim, 1 = bom
  topic_tags      text[] DEFAULT '{}',
  context_snippet text,   -- últimas N mensagens antes deste par
  processed       boolean DEFAULT false,
  created_at      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ai_feedback_queue_character_id_idx ON public.ai_feedback_queue(character_id);
CREATE INDEX IF NOT EXISTS ai_feedback_queue_processed_idx    ON public.ai_feedback_queue(processed);
CREATE INDEX IF NOT EXISTS ai_feedback_queue_rating_idx       ON public.ai_feedback_queue(rating);

-- RLS: usuários só veem seus próprios feedbacks; admins veem tudo via RPC
ALTER TABLE public.ai_feedback_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_feedback" ON public.ai_feedback_queue
  FOR ALL USING (user_id = auth.uid());

-- ─── 2. Tabela: ai_learning_memories ──────────────────────────────────────────
-- Memórias aprovadas que são injetadas no contexto da IA antes de responder.
-- Cada memória é um par (pergunta_tipo → resposta_exemplar) com metadados de qualidade.
CREATE TABLE IF NOT EXISTS public.ai_learning_memories (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id    uuid NOT NULL REFERENCES public.ai_characters(id) ON DELETE CASCADE,
  memory_type     text NOT NULL DEFAULT 'example'
                  CHECK (memory_type IN ('example', 'fact', 'preference', 'rule', 'tone')),
  trigger_pattern text NOT NULL,  -- padrão de mensagem que ativa esta memória
  ideal_response  text NOT NULL,  -- resposta exemplar aprovada
  topic_tags      text[] DEFAULT '{}',
  approval_score  numeric DEFAULT 1.0, -- 0.0 a 5.0, baseado em quantos 👍 acumulou
  use_count       integer DEFAULT 0,   -- quantas vezes foi injetada no contexto
  hit_count       integer DEFAULT 0,   -- quantas vezes foi usada e gerou 👍 depois
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected', 'archived')),
  source_feedback_id uuid REFERENCES public.ai_feedback_queue(id) ON DELETE SET NULL,
  admin_notes     text,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now(),
  approved_at     timestamptz,
  approved_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ai_learning_memories_character_id_idx ON public.ai_learning_memories(character_id);
CREATE INDEX IF NOT EXISTS ai_learning_memories_status_idx        ON public.ai_learning_memories(status);
CREATE INDEX IF NOT EXISTS ai_learning_memories_type_idx          ON public.ai_learning_memories(memory_type);

ALTER TABLE public.ai_learning_memories ENABLE ROW LEVEL SECURITY;
-- Apenas RPCs SECURITY DEFINER acessam esta tabela

-- ─── 3. Tabela: ai_behavior_patterns ──────────────────────────────────────────
-- Padrões comportamentais extraídos automaticamente da análise de feedbacks.
-- Ex: "respostas com emojis têm 78% de aprovação", "respostas > 200 chars têm 45% de aprovação"
CREATE TABLE IF NOT EXISTS public.ai_behavior_patterns (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id    uuid NOT NULL REFERENCES public.ai_characters(id) ON DELETE CASCADE,
  pattern_key     text NOT NULL,   -- identificador único do padrão
  pattern_label   text NOT NULL,   -- descrição legível
  pattern_rule    text NOT NULL,   -- regra a ser injetada no system prompt
  category        text NOT NULL DEFAULT 'style'
                  CHECK (category IN ('style', 'length', 'format', 'topic', 'tone', 'custom')),
  approval_rate   numeric DEFAULT 0.0,  -- % de aprovação (0.0 a 1.0)
  sample_count    integer DEFAULT 0,    -- quantas amostras geraram este padrão
  is_active       boolean DEFAULT true,
  is_auto         boolean DEFAULT true, -- true = gerado automaticamente, false = criado pelo admin
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now(),
  UNIQUE(character_id, pattern_key)
);

CREATE INDEX IF NOT EXISTS ai_behavior_patterns_character_id_idx ON public.ai_behavior_patterns(character_id);
CREATE INDEX IF NOT EXISTS ai_behavior_patterns_active_idx        ON public.ai_behavior_patterns(is_active);

ALTER TABLE public.ai_behavior_patterns ENABLE ROW LEVEL SECURITY;

-- ─── 4. Coluna de estatísticas em ai_characters ───────────────────────────────
ALTER TABLE public.ai_characters
  ADD COLUMN IF NOT EXISTS learning_enabled  boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS auto_approve      boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS min_approval_score numeric DEFAULT 3.0,
  ADD COLUMN IF NOT EXISTS total_feedbacks   integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS positive_feedbacks integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS negative_feedbacks integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS memory_count      integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_learned_at   timestamptz;

-- ─── 5. RPC: submit_ai_feedback ───────────────────────────────────────────────
-- Chamada pelo app Flutter quando usuário avalia uma resposta da IA.
DROP FUNCTION IF EXISTS public.submit_ai_feedback(uuid, uuid, text, text, smallint, text[], text);
CREATE OR REPLACE FUNCTION public.submit_ai_feedback(
  p_character_id    uuid,
  p_session_id      uuid,
  p_user_message    text,
  p_ai_response     text,
  p_rating          smallint,  -- 1 = bom, -1 = ruim
  p_topic_tags      text[]    DEFAULT '{}',
  p_context_snippet text      DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_feedback_id uuid;
  v_char record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Verificar se o personagem existe e tem aprendizado habilitado
  SELECT id, learning_enabled, auto_approve, min_approval_score
  INTO v_char
  FROM ai_characters WHERE id = p_character_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'character_not_found');
  END IF;

  IF NOT v_char.learning_enabled THEN
    RETURN jsonb_build_object('success', false, 'error', 'learning_disabled');
  END IF;

  -- Inserir feedback na fila
  INSERT INTO ai_feedback_queue (
    character_id, session_id, user_id,
    user_message, ai_response, rating,
    topic_tags, context_snippet
  ) VALUES (
    p_character_id, p_session_id, v_user_id,
    p_user_message, p_ai_response, p_rating,
    COALESCE(p_topic_tags, '{}'), p_context_snippet
  ) RETURNING id INTO v_feedback_id;

  -- Atualizar contadores do personagem
  UPDATE ai_characters SET
    total_feedbacks    = total_feedbacks + 1,
    positive_feedbacks = positive_feedbacks + CASE WHEN p_rating = 1 THEN 1 ELSE 0 END,
    negative_feedbacks = negative_feedbacks + CASE WHEN p_rating = -1 THEN 1 ELSE 0 END,
    last_learned_at    = now()
  WHERE id = p_character_id;

  -- Auto-aprovar se configurado e rating positivo
  IF v_char.auto_approve AND p_rating = 1 THEN
    INSERT INTO ai_learning_memories (
      character_id, memory_type, trigger_pattern, ideal_response,
      topic_tags, approval_score, status, source_feedback_id, approved_at
    ) VALUES (
      p_character_id, 'example', p_user_message, p_ai_response,
      COALESCE(p_topic_tags, '{}'), 1.0, 'approved', v_feedback_id, now()
    );

    UPDATE ai_feedback_queue SET processed = true WHERE id = v_feedback_id;

    UPDATE ai_characters SET
      memory_count = memory_count + 1
    WHERE id = p_character_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'feedback_id', v_feedback_id,
    'auto_approved', (v_char.auto_approve AND p_rating = 1)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_ai_feedback TO authenticated;

-- ─── 6. RPC: get_ai_context_memories ──────────────────────────────────────────
-- Chamada pelo app antes de enviar mensagem à IA.
-- Retorna as memórias mais relevantes para injetar no contexto.
DROP FUNCTION IF EXISTS public.get_ai_context_memories(uuid, text, integer);
CREATE OR REPLACE FUNCTION public.get_ai_context_memories(
  p_character_id uuid,
  p_user_message text,
  p_limit        integer DEFAULT 5
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_memories jsonb;
  v_patterns jsonb;
BEGIN
  -- Buscar memórias aprovadas mais relevantes (por topic_tags e approval_score)
  SELECT jsonb_agg(jsonb_build_object(
    'trigger', trigger_pattern,
    'response', ideal_response,
    'score', approval_score,
    'type', memory_type
  ) ORDER BY approval_score DESC, use_count DESC)
  INTO v_memories
  FROM (
    SELECT trigger_pattern, ideal_response, approval_score, memory_type, use_count
    FROM ai_learning_memories
    WHERE character_id = p_character_id
      AND status = 'approved'
    ORDER BY approval_score DESC, hit_count DESC
    LIMIT p_limit
  ) sub;

  -- Buscar padrões comportamentais ativos
  SELECT jsonb_agg(jsonb_build_object(
    'rule', pattern_rule,
    'category', category,
    'approval_rate', approval_rate
  ) ORDER BY approval_rate DESC)
  INTO v_patterns
  FROM ai_behavior_patterns
  WHERE character_id = p_character_id
    AND is_active = true
  ORDER BY approval_rate DESC
  LIMIT 10;

  -- Incrementar use_count das memórias retornadas
  UPDATE ai_learning_memories SET
    use_count = use_count + 1
  WHERE character_id = p_character_id
    AND status = 'approved';

  RETURN jsonb_build_object(
    'memories', COALESCE(v_memories, '[]'::jsonb),
    'patterns', COALESCE(v_patterns, '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_ai_context_memories TO authenticated;

-- ─── 7. RPC: admin_get_learning_stats ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_learning_stats(uuid);
CREATE OR REPLACE FUNCTION public.admin_get_learning_stats(
  p_character_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_feedbacks',    COALESCE(SUM(total_feedbacks), 0),
    'positive_feedbacks', COALESCE(SUM(positive_feedbacks), 0),
    'negative_feedbacks', COALESCE(SUM(negative_feedbacks), 0),
    'memory_count',       COALESCE(SUM(memory_count), 0),
    'approval_rate',      CASE WHEN COALESCE(SUM(total_feedbacks), 0) > 0
                          THEN ROUND(COALESCE(SUM(positive_feedbacks), 0)::numeric / SUM(total_feedbacks) * 100, 1)
                          ELSE 0 END,
    'characters_learning', COUNT(*) FILTER (WHERE learning_enabled = true),
    'pending_queue',      (SELECT COUNT(*) FROM ai_feedback_queue
                           WHERE processed = false
                           AND (p_character_id IS NULL OR character_id = p_character_id)),
    'pending_memories',   (SELECT COUNT(*) FROM ai_learning_memories
                           WHERE status = 'pending'
                           AND (p_character_id IS NULL OR character_id = p_character_id))
  )
  INTO v_stats
  FROM ai_characters
  WHERE p_character_id IS NULL OR id = p_character_id;

  RETURN v_stats;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_learning_stats TO authenticated;

-- ─── 8. RPC: admin_get_learning_memories ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_learning_memories(uuid, text, integer, integer);
CREATE OR REPLACE FUNCTION public.admin_get_learning_memories(
  p_character_id uuid     DEFAULT NULL,
  p_status       text     DEFAULT 'pending',
  p_limit        integer  DEFAULT 50,
  p_offset       integer  DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_total  bigint;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM ai_learning_memories m
  WHERE (p_character_id IS NULL OR m.character_id = p_character_id)
    AND (p_status = 'all' OR m.status = p_status);

  SELECT jsonb_agg(row_to_json(sub)) INTO v_result
  FROM (
    SELECT
      m.id, m.character_id, m.memory_type, m.trigger_pattern,
      m.ideal_response, m.topic_tags, m.approval_score,
      m.use_count, m.hit_count, m.status, m.admin_notes,
      m.created_at, m.approved_at,
      c.name AS character_name, c.avatar_url AS character_avatar,
      f.user_message AS original_user_message,
      f.rating AS original_rating
    FROM ai_learning_memories m
    JOIN ai_characters c ON c.id = m.character_id
    LEFT JOIN ai_feedback_queue f ON f.id = m.source_feedback_id
    WHERE (p_character_id IS NULL OR m.character_id = p_character_id)
      AND (p_status = 'all' OR m.status = p_status)
    ORDER BY m.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) sub;

  RETURN jsonb_build_object(
    'data', COALESCE(v_result, '[]'::jsonb),
    'total', v_total
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_learning_memories TO authenticated;

-- ─── 9. RPC: admin_approve_memory ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_approve_memory(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_approve_memory(
  p_memory_id  uuid,
  p_admin_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  UPDATE ai_learning_memories SET
    status      = 'approved',
    admin_notes = COALESCE(p_admin_note, admin_notes),
    approved_at = now(),
    approved_by = v_admin_id,
    updated_at  = now()
  WHERE id = p_memory_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'memory_not_found');
  END IF;

  -- Incrementar memory_count do personagem
  UPDATE ai_characters SET
    memory_count = memory_count + 1
  WHERE id = (SELECT character_id FROM ai_learning_memories WHERE id = p_memory_id);

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_approve_memory TO authenticated;

-- ─── 10. RPC: admin_reject_memory ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_reject_memory(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_reject_memory(
  p_memory_id  uuid,
  p_admin_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE ai_learning_memories SET
    status      = 'rejected',
    admin_notes = COALESCE(p_admin_note, admin_notes),
    updated_at  = now()
  WHERE id = p_memory_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'memory_not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_reject_memory TO authenticated;

-- ─── 11. RPC: admin_edit_memory ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_edit_memory(uuid, text, text, text[], text, text);
CREATE OR REPLACE FUNCTION public.admin_edit_memory(
  p_memory_id       uuid,
  p_trigger_pattern text    DEFAULT NULL,
  p_ideal_response  text    DEFAULT NULL,
  p_topic_tags      text[]  DEFAULT NULL,
  p_memory_type     text    DEFAULT NULL,
  p_admin_notes     text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE ai_learning_memories SET
    trigger_pattern = COALESCE(p_trigger_pattern, trigger_pattern),
    ideal_response  = COALESCE(p_ideal_response, ideal_response),
    topic_tags      = COALESCE(p_topic_tags, topic_tags),
    memory_type     = COALESCE(p_memory_type, memory_type),
    admin_notes     = COALESCE(p_admin_notes, admin_notes),
    updated_at      = now()
  WHERE id = p_memory_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'memory_not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_edit_memory TO authenticated;

-- ─── 12. RPC: admin_delete_memory ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_delete_memory(uuid);
CREATE OR REPLACE FUNCTION public.admin_delete_memory(p_memory_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_char_id uuid;
  v_status  text;
BEGIN
  SELECT character_id, status INTO v_char_id, v_status
  FROM ai_learning_memories WHERE id = p_memory_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'memory_not_found');
  END IF;

  DELETE FROM ai_learning_memories WHERE id = p_memory_id;

  -- Decrementar memory_count se era aprovada
  IF v_status = 'approved' THEN
    UPDATE ai_characters SET
      memory_count = GREATEST(0, memory_count - 1)
    WHERE id = v_char_id;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_memory TO authenticated;

-- ─── 13. RPC: admin_create_memory ─────────────────────────────────────────────
-- Permite ao admin criar memórias manualmente (sem precisar de feedback de usuário)
DROP FUNCTION IF EXISTS public.admin_create_memory(uuid, text, text, text, text[], numeric);
CREATE OR REPLACE FUNCTION public.admin_create_memory(
  p_character_id    uuid,
  p_memory_type     text,
  p_trigger_pattern text,
  p_ideal_response  text,
  p_topic_tags      text[]  DEFAULT '{}',
  p_approval_score  numeric DEFAULT 5.0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_memory_id uuid;
BEGIN
  INSERT INTO ai_learning_memories (
    character_id, memory_type, trigger_pattern, ideal_response,
    topic_tags, approval_score, status, approved_at, approved_by
  ) VALUES (
    p_character_id, p_memory_type, p_trigger_pattern, p_ideal_response,
    COALESCE(p_topic_tags, '{}'), p_approval_score, 'approved', now(), v_admin_id
  ) RETURNING id INTO v_memory_id;

  UPDATE ai_characters SET
    memory_count = memory_count + 1
  WHERE id = p_character_id;

  RETURN jsonb_build_object('success', true, 'memory_id', v_memory_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_create_memory TO authenticated;

-- ─── 14. RPC: admin_get_behavior_patterns ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_behavior_patterns(uuid);
CREATE OR REPLACE FUNCTION public.admin_get_behavior_patterns(
  p_character_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(sub) ORDER BY sub.approval_rate DESC) INTO v_result
  FROM (
    SELECT
      p.id, p.character_id, p.pattern_key, p.pattern_label,
      p.pattern_rule, p.category, p.approval_rate,
      p.sample_count, p.is_active, p.is_auto,
      p.created_at, p.updated_at,
      c.name AS character_name, c.avatar_url AS character_avatar
    FROM ai_behavior_patterns p
    JOIN ai_characters c ON c.id = p.character_id
    WHERE (p_character_id IS NULL OR p.character_id = p_character_id)
    ORDER BY p.approval_rate DESC
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_behavior_patterns TO authenticated;

-- ─── 15. RPC: admin_toggle_pattern ────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_toggle_pattern(uuid, boolean);
CREATE OR REPLACE FUNCTION public.admin_toggle_pattern(
  p_pattern_id uuid,
  p_active     boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE ai_behavior_patterns SET
    is_active  = p_active,
    updated_at = now()
  WHERE id = p_pattern_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'pattern_not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_toggle_pattern TO authenticated;

-- ─── 16. RPC: admin_create_behavior_pattern ───────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_create_behavior_pattern(uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.admin_create_behavior_pattern(
  p_character_id uuid,
  p_pattern_key  text,
  p_pattern_label text,
  p_pattern_rule  text,
  p_category      text DEFAULT 'custom'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_pattern_id uuid;
BEGIN
  INSERT INTO ai_behavior_patterns (
    character_id, pattern_key, pattern_label, pattern_rule,
    category, is_auto, approval_rate, sample_count
  ) VALUES (
    p_character_id, p_pattern_key, p_pattern_label, p_pattern_rule,
    p_category, false, 1.0, 0
  ) RETURNING id INTO v_pattern_id;

  RETURN jsonb_build_object('success', true, 'pattern_id', v_pattern_id);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', false, 'error', 'pattern_key_exists');
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_create_behavior_pattern TO authenticated;

-- ─── 17. RPC: admin_delete_behavior_pattern ───────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_delete_behavior_pattern(uuid);
CREATE OR REPLACE FUNCTION public.admin_delete_behavior_pattern(p_pattern_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  DELETE FROM ai_behavior_patterns WHERE id = p_pattern_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'pattern_not_found');
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_behavior_pattern TO authenticated;

-- ─── 18. RPC: admin_update_learning_config ────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_learning_config(uuid, boolean, boolean, numeric);
CREATE OR REPLACE FUNCTION public.admin_update_learning_config(
  p_character_id     uuid,
  p_learning_enabled boolean DEFAULT NULL,
  p_auto_approve     boolean DEFAULT NULL,
  p_min_score        numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE ai_characters SET
    learning_enabled  = COALESCE(p_learning_enabled, learning_enabled),
    auto_approve      = COALESCE(p_auto_approve, auto_approve),
    min_approval_score = COALESCE(p_min_score, min_approval_score),
    updated_at        = now()
  WHERE id = p_character_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'character_not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_update_learning_config TO authenticated;

-- ─── 19. RPC: admin_get_feedback_queue ────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_feedback_queue(uuid, boolean, integer, integer);
CREATE OR REPLACE FUNCTION public.admin_get_feedback_queue(
  p_character_id uuid    DEFAULT NULL,
  p_processed    boolean DEFAULT false,
  p_limit        integer DEFAULT 50,
  p_offset       integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_total  bigint;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM ai_feedback_queue q
  WHERE (p_character_id IS NULL OR q.character_id = p_character_id)
    AND q.processed = p_processed;

  SELECT jsonb_agg(row_to_json(sub)) INTO v_result
  FROM (
    SELECT
      q.id, q.character_id, q.user_id, q.user_message,
      q.ai_response, q.rating, q.topic_tags, q.processed,
      q.created_at,
      c.name AS character_name, c.avatar_url AS character_avatar,
      p.nickname AS user_nickname, p.icon_url AS user_avatar
    FROM ai_feedback_queue q
    JOIN ai_characters c ON c.id = q.character_id
    LEFT JOIN profiles p ON p.id = q.user_id
    WHERE (p_character_id IS NULL OR q.character_id = p_character_id)
      AND q.processed = p_processed
    ORDER BY q.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) sub;

  RETURN jsonb_build_object(
    'data', COALESCE(v_result, '[]'::jsonb),
    'total', v_total
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_feedback_queue TO authenticated;

-- ─── 20. RPC: admin_promote_feedback_to_memory ────────────────────────────────
-- Promove um feedback da fila para uma memória aprovada
DROP FUNCTION IF EXISTS public.admin_promote_feedback_to_memory(uuid, text, text, text[]);
CREATE OR REPLACE FUNCTION public.admin_promote_feedback_to_memory(
  p_feedback_id     uuid,
  p_memory_type     text    DEFAULT 'example',
  p_trigger_pattern text    DEFAULT NULL,  -- se NULL, usa user_message original
  p_topic_tags      text[]  DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_admin_id  uuid := auth.uid();
  v_feedback  record;
  v_memory_id uuid;
BEGIN
  SELECT * INTO v_feedback
  FROM ai_feedback_queue WHERE id = p_feedback_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'feedback_not_found');
  END IF;

  INSERT INTO ai_learning_memories (
    character_id, memory_type, trigger_pattern, ideal_response,
    topic_tags, approval_score, status, source_feedback_id,
    approved_at, approved_by
  ) VALUES (
    v_feedback.character_id,
    p_memory_type,
    COALESCE(p_trigger_pattern, v_feedback.user_message),
    v_feedback.ai_response,
    COALESCE(p_topic_tags, v_feedback.topic_tags, '{}'),
    CASE WHEN v_feedback.rating = 1 THEN 4.0 ELSE 1.0 END,
    'approved',
    p_feedback_id,
    now(),
    v_admin_id
  ) RETURNING id INTO v_memory_id;

  UPDATE ai_feedback_queue SET processed = true WHERE id = p_feedback_id;

  UPDATE ai_characters SET
    memory_count = memory_count + 1
  WHERE id = v_feedback.character_id;

  RETURN jsonb_build_object('success', true, 'memory_id', v_memory_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_promote_feedback_to_memory TO authenticated;

-- ─── 21. RPC: admin_clear_memories ────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_clear_memories(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_clear_memories(
  p_character_id uuid,
  p_status       text DEFAULT 'all'  -- 'all', 'pending', 'rejected'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM ai_learning_memories
  WHERE character_id = p_character_id
    AND (p_status = 'all' OR status = p_status)
  ;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  -- Recalcular memory_count
  UPDATE ai_characters SET
    memory_count = (
      SELECT COUNT(*) FROM ai_learning_memories
      WHERE character_id = p_character_id AND status = 'approved'
    )
  WHERE id = p_character_id;

  RETURN jsonb_build_object('success', true, 'deleted', v_deleted);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_clear_memories TO authenticated;

-- ─── 22. Inserir padrões comportamentais padrão para personagens existentes ────
-- (apenas se não existirem ainda)
INSERT INTO public.ai_behavior_patterns (character_id, pattern_key, pattern_label, pattern_rule, category, is_auto, approval_rate, sample_count)
SELECT
  c.id,
  'be_concise',
  'Respostas concisas',
  'Prefira respostas diretas e objetivas. Evite repetições desnecessárias.',
  'length',
  false,
  0.8,
  0
FROM ai_characters c
WHERE NOT EXISTS (
  SELECT 1 FROM ai_behavior_patterns p
  WHERE p.character_id = c.id AND p.pattern_key = 'be_concise'
);
