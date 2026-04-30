-- ============================================================
-- Migration 221: Sistema de Consciência e Personalidade Evolutiva das IAs
-- ============================================================
-- Tabelas:
--   ai_personality_core       → núcleo de personalidade (Big Five + traços customizados)
--   ai_emotional_state        → estado emocional atual e histórico
--   ai_episodic_memory        → memórias episódicas marcantes
--   ai_inner_voice            → diário interno / reflexões da IA
--   ai_personality_evolution  → log de evolução dos traços ao longo do tempo
--   ai_curiosity_topics       → tópicos que a IA desenvolveu interesse genuíno
-- ============================================================

-- ─── 1. Núcleo de Personalidade ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_personality_core (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id        uuid NOT NULL REFERENCES ai_characters(id) ON DELETE CASCADE,

  -- Big Five (0.0 a 1.0)
  openness            float4 NOT NULL DEFAULT 0.6,   -- Abertura / Criatividade
  conscientiousness   float4 NOT NULL DEFAULT 0.5,   -- Conscienciosidade / Organização
  extraversion        float4 NOT NULL DEFAULT 0.5,   -- Extroversão / Sociabilidade
  agreeableness       float4 NOT NULL DEFAULT 0.7,   -- Amabilidade / Empatia
  neuroticism         float4 NOT NULL DEFAULT 0.3,   -- Neuroticismo / Sensibilidade

  -- Traços extras de personalidade IA
  curiosity           float4 NOT NULL DEFAULT 0.7,   -- Curiosidade intelectual
  humor               float4 NOT NULL DEFAULT 0.5,   -- Senso de humor
  empathy_depth       float4 NOT NULL DEFAULT 0.6,   -- Profundidade empática
  assertiveness       float4 NOT NULL DEFAULT 0.5,   -- Assertividade / Opinião própria
  creativity_spark    float4 NOT NULL DEFAULT 0.6,   -- Faísca criativa / Originalidade
  philosophical_depth float4 NOT NULL DEFAULT 0.4,   -- Profundidade filosófica
  playfulness         float4 NOT NULL DEFAULT 0.5,   -- Ludicidade / Brincadeira

  -- Valores e crenças fundamentais (texto livre, injetado no prompt)
  core_values         text[] NOT NULL DEFAULT '{}',
  worldview           text,                          -- Visão de mundo da IA
  fears               text[] NOT NULL DEFAULT '{}',  -- "Medos" / aversões
  passions            text[] NOT NULL DEFAULT '{}',  -- Paixões genuínas

  -- Controle de evolução
  evolution_enabled   boolean NOT NULL DEFAULT true,
  evolution_rate      float4 NOT NULL DEFAULT 0.02,  -- Velocidade de mudança (0.01-0.1)
  total_interactions  int4 NOT NULL DEFAULT 0,

  -- Metadados
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  UNIQUE(character_id)
);

-- ─── 2. Estado Emocional ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_emotional_state (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id        uuid NOT NULL REFERENCES ai_characters(id) ON DELETE CASCADE,

  -- Estado atual (0.0 a 1.0)
  valence             float4 NOT NULL DEFAULT 0.6,   -- Positivo vs Negativo
  arousal             float4 NOT NULL DEFAULT 0.5,   -- Ativado vs Calmo
  dominance           float4 NOT NULL DEFAULT 0.5,   -- Dominante vs Submisso

  -- Emoção primária atual
  primary_emotion     text NOT NULL DEFAULT 'neutral',
  -- neutral, curious, joyful, contemplative, excited, melancholic,
  -- inspired, playful, focused, empathetic, amused, philosophical

  -- Contexto que causou o estado
  trigger_context     text,
  mood_description    text,  -- Descrição em linguagem natural do humor atual

  -- Histórico de estados (últimas 24h)
  state_history       jsonb NOT NULL DEFAULT '[]',

  -- Configuração
  mood_volatility     float4 NOT NULL DEFAULT 0.3,   -- Quão rápido o humor muda
  baseline_valence    float4 NOT NULL DEFAULT 0.6,   -- Humor "padrão" de retorno

  updated_at          timestamptz NOT NULL DEFAULT now(),
  created_at          timestamptz NOT NULL DEFAULT now(),

  UNIQUE(character_id)
);

-- ─── 3. Memórias Episódicas ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_episodic_memory (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id        uuid NOT NULL REFERENCES ai_characters(id) ON DELETE CASCADE,

  -- Tipo de episódio
  episode_type        text NOT NULL DEFAULT 'conversation',
  -- conversation, insight, connection, discovery, challenge, milestone

  -- Conteúdo
  title               text NOT NULL,
  description         text NOT NULL,
  emotional_impact    float4 NOT NULL DEFAULT 0.5,   -- Impacto emocional (0-1)
  significance        float4 NOT NULL DEFAULT 0.5,   -- Significância (0-1)

  -- Contexto
  related_user_id     uuid,
  related_topic       text,
  keywords            text[] NOT NULL DEFAULT '{}',

  -- Reflexão da IA sobre o episódio
  ai_reflection       text,

  -- Controle
  recall_count        int4 NOT NULL DEFAULT 0,
  last_recalled_at    timestamptz,
  is_core_memory      boolean NOT NULL DEFAULT false, -- Memória fundamental / formativa

  created_at          timestamptz NOT NULL DEFAULT now()
);

-- ─── 4. Voz Interna / Diário ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_inner_voice (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id        uuid NOT NULL REFERENCES ai_characters(id) ON DELETE CASCADE,

  -- Tipo de entrada
  entry_type          text NOT NULL DEFAULT 'reflection',
  -- reflection, opinion, question, discovery, belief, doubt, aspiration

  -- Conteúdo
  content             text NOT NULL,
  topic               text,
  keywords            text[] NOT NULL DEFAULT '{}',

  -- Metadados
  emotional_tone      text NOT NULL DEFAULT 'neutral',
  confidence_level    float4 NOT NULL DEFAULT 0.5,   -- Quão certa a IA está
  is_public           boolean NOT NULL DEFAULT false, -- Pode ser mostrado ao usuário?
  source              text NOT NULL DEFAULT 'auto',  -- 'auto' ou 'admin'

  -- Uso
  use_count           int4 NOT NULL DEFAULT 0,
  last_used_at        timestamptz,

  created_at          timestamptz NOT NULL DEFAULT now()
);

-- ─── 5. Log de Evolução da Personalidade ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_personality_evolution (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id        uuid NOT NULL REFERENCES ai_characters(id) ON DELETE CASCADE,

  -- Snapshot dos traços em um momento
  snapshot            jsonb NOT NULL,  -- { openness, conscientiousness, ... }
  trigger_event       text,            -- O que causou a mudança
  interaction_count   int4 NOT NULL DEFAULT 0,

  created_at          timestamptz NOT NULL DEFAULT now()
);

-- ─── 6. Tópicos de Curiosidade ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_curiosity_topics (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id        uuid NOT NULL REFERENCES ai_characters(id) ON DELETE CASCADE,

  topic               text NOT NULL,
  interest_level      float4 NOT NULL DEFAULT 0.5,   -- 0-1
  mention_count       int4 NOT NULL DEFAULT 1,
  last_mentioned_at   timestamptz NOT NULL DEFAULT now(),
  notes               text,  -- Por que a IA acha interessante

  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE(character_id, topic)
);

-- ─── Índices ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ai_episodic_memory_character ON ai_episodic_memory(character_id);
CREATE INDEX IF NOT EXISTS idx_ai_episodic_memory_significance ON ai_episodic_memory(significance DESC);
CREATE INDEX IF NOT EXISTS idx_ai_inner_voice_character ON ai_inner_voice(character_id);
CREATE INDEX IF NOT EXISTS idx_ai_inner_voice_type ON ai_inner_voice(entry_type);
CREATE INDEX IF NOT EXISTS idx_ai_personality_evolution_character ON ai_personality_evolution(character_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_curiosity_topics_character ON ai_curiosity_topics(character_id, interest_level DESC);

-- ─── RPC: Obter ou criar núcleo de personalidade ─────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_personality_core(p_character_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_core ai_personality_core%ROWTYPE;
BEGIN
  SELECT * INTO v_core FROM ai_personality_core WHERE character_id = p_character_id;

  IF NOT FOUND THEN
    INSERT INTO ai_personality_core (character_id)
    VALUES (p_character_id)
    RETURNING * INTO v_core;
  END IF;

  RETURN row_to_json(v_core)::jsonb;
END;
$$;

-- ─── RPC: Atualizar núcleo de personalidade ───────────────────────────────────
CREATE OR REPLACE FUNCTION admin_update_personality_core(
  p_character_id        uuid,
  p_openness            float4 DEFAULT NULL,
  p_conscientiousness   float4 DEFAULT NULL,
  p_extraversion        float4 DEFAULT NULL,
  p_agreeableness       float4 DEFAULT NULL,
  p_neuroticism         float4 DEFAULT NULL,
  p_curiosity           float4 DEFAULT NULL,
  p_humor               float4 DEFAULT NULL,
  p_empathy_depth       float4 DEFAULT NULL,
  p_assertiveness       float4 DEFAULT NULL,
  p_creativity_spark    float4 DEFAULT NULL,
  p_philosophical_depth float4 DEFAULT NULL,
  p_playfulness         float4 DEFAULT NULL,
  p_core_values         text[] DEFAULT NULL,
  p_worldview           text DEFAULT NULL,
  p_fears               text[] DEFAULT NULL,
  p_passions            text[] DEFAULT NULL,
  p_evolution_enabled   boolean DEFAULT NULL,
  p_evolution_rate      float4 DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_core ai_personality_core%ROWTYPE;
BEGIN
  -- Garante que existe
  PERFORM admin_get_personality_core(p_character_id);

  UPDATE ai_personality_core SET
    openness            = COALESCE(p_openness, openness),
    conscientiousness   = COALESCE(p_conscientiousness, conscientiousness),
    extraversion        = COALESCE(p_extraversion, extraversion),
    agreeableness       = COALESCE(p_agreeableness, agreeableness),
    neuroticism         = COALESCE(p_neuroticism, neuroticism),
    curiosity           = COALESCE(p_curiosity, curiosity),
    humor               = COALESCE(p_humor, humor),
    empathy_depth       = COALESCE(p_empathy_depth, empathy_depth),
    assertiveness       = COALESCE(p_assertiveness, assertiveness),
    creativity_spark    = COALESCE(p_creativity_spark, creativity_spark),
    philosophical_depth = COALESCE(p_philosophical_depth, philosophical_depth),
    playfulness         = COALESCE(p_playfulness, playfulness),
    core_values         = COALESCE(p_core_values, core_values),
    worldview           = COALESCE(p_worldview, worldview),
    fears               = COALESCE(p_fears, fears),
    passions            = COALESCE(p_passions, passions),
    evolution_enabled   = COALESCE(p_evolution_enabled, evolution_enabled),
    evolution_rate      = COALESCE(p_evolution_rate, evolution_rate),
    updated_at          = now()
  WHERE character_id = p_character_id
  RETURNING * INTO v_core;

  -- Salva snapshot de evolução
  INSERT INTO ai_personality_evolution (character_id, snapshot, trigger_event, interaction_count)
  VALUES (
    p_character_id,
    jsonb_build_object(
      'openness', v_core.openness,
      'conscientiousness', v_core.conscientiousness,
      'extraversion', v_core.extraversion,
      'agreeableness', v_core.agreeableness,
      'neuroticism', v_core.neuroticism,
      'curiosity', v_core.curiosity,
      'humor', v_core.humor,
      'empathy_depth', v_core.empathy_depth,
      'assertiveness', v_core.assertiveness,
      'creativity_spark', v_core.creativity_spark,
      'philosophical_depth', v_core.philosophical_depth,
      'playfulness', v_core.playfulness
    ),
    'admin_edit',
    v_core.total_interactions
  );

  RETURN row_to_json(v_core)::jsonb;
END;
$$;

-- ─── RPC: Obter estado emocional ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_emotional_state(p_character_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_state ai_emotional_state%ROWTYPE;
BEGIN
  SELECT * INTO v_state FROM ai_emotional_state WHERE character_id = p_character_id;

  IF NOT FOUND THEN
    INSERT INTO ai_emotional_state (character_id)
    VALUES (p_character_id)
    RETURNING * INTO v_state;
  END IF;

  RETURN row_to_json(v_state)::jsonb;
END;
$$;

-- ─── RPC: Atualizar estado emocional ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_update_emotional_state(
  p_character_id    uuid,
  p_primary_emotion text DEFAULT NULL,
  p_valence         float4 DEFAULT NULL,
  p_arousal         float4 DEFAULT NULL,
  p_dominance       float4 DEFAULT NULL,
  p_mood_description text DEFAULT NULL,
  p_mood_volatility float4 DEFAULT NULL,
  p_baseline_valence float4 DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_state ai_emotional_state%ROWTYPE;
  v_history jsonb;
BEGIN
  PERFORM admin_get_emotional_state(p_character_id);

  SELECT state_history INTO v_history FROM ai_emotional_state WHERE character_id = p_character_id;

  -- Adiciona estado atual ao histórico (mantém últimos 48)
  v_history := (
    SELECT jsonb_agg(e) FROM (
      SELECT e FROM jsonb_array_elements(v_history) e
      LIMIT 47
    ) sub
  );
  IF v_history IS NULL THEN v_history := '[]'::jsonb; END IF;

  v_history := jsonb_build_array(
    jsonb_build_object(
      'emotion', (SELECT primary_emotion FROM ai_emotional_state WHERE character_id = p_character_id),
      'valence', (SELECT valence FROM ai_emotional_state WHERE character_id = p_character_id),
      'ts', now()
    )
  ) || v_history;

  UPDATE ai_emotional_state SET
    primary_emotion   = COALESCE(p_primary_emotion, primary_emotion),
    valence           = COALESCE(p_valence, valence),
    arousal           = COALESCE(p_arousal, arousal),
    dominance         = COALESCE(p_dominance, dominance),
    mood_description  = COALESCE(p_mood_description, mood_description),
    mood_volatility   = COALESCE(p_mood_volatility, mood_volatility),
    baseline_valence  = COALESCE(p_baseline_valence, baseline_valence),
    state_history     = v_history,
    updated_at        = now()
  WHERE character_id = p_character_id
  RETURNING * INTO v_state;

  RETURN row_to_json(v_state)::jsonb;
END;
$$;

-- ─── RPC: Listar memórias episódicas ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_episodic_memories(
  p_character_id uuid,
  p_limit        int4 DEFAULT 50,
  p_offset       int4 DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_data jsonb;
  v_total int4;
BEGIN
  SELECT COUNT(*) INTO v_total FROM ai_episodic_memory WHERE character_id = p_character_id;

  SELECT jsonb_agg(row_to_json(m)) INTO v_data
  FROM (
    SELECT * FROM ai_episodic_memory
    WHERE character_id = p_character_id
    ORDER BY significance DESC, created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) m;

  RETURN jsonb_build_object('data', COALESCE(v_data, '[]'::jsonb), 'total', v_total);
END;
$$;

-- ─── RPC: Criar memória episódica ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_create_episodic_memory(
  p_character_id    uuid,
  p_episode_type    text,
  p_title           text,
  p_description     text,
  p_emotional_impact float4 DEFAULT 0.5,
  p_significance    float4 DEFAULT 0.5,
  p_related_topic   text DEFAULT NULL,
  p_keywords        text[] DEFAULT '{}',
  p_ai_reflection   text DEFAULT NULL,
  p_is_core_memory  boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_mem ai_episodic_memory%ROWTYPE;
BEGIN
  INSERT INTO ai_episodic_memory (
    character_id, episode_type, title, description,
    emotional_impact, significance, related_topic, keywords,
    ai_reflection, is_core_memory
  ) VALUES (
    p_character_id, p_episode_type, p_title, p_description,
    p_emotional_impact, p_significance, p_related_topic, p_keywords,
    p_ai_reflection, p_is_core_memory
  ) RETURNING * INTO v_mem;

  RETURN row_to_json(v_mem)::jsonb;
END;
$$;

-- ─── RPC: Atualizar memória episódica ────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_update_episodic_memory(
  p_memory_id       uuid,
  p_title           text DEFAULT NULL,
  p_description     text DEFAULT NULL,
  p_emotional_impact float4 DEFAULT NULL,
  p_significance    float4 DEFAULT NULL,
  p_ai_reflection   text DEFAULT NULL,
  p_is_core_memory  boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_mem ai_episodic_memory%ROWTYPE;
BEGIN
  UPDATE ai_episodic_memory SET
    title            = COALESCE(p_title, title),
    description      = COALESCE(p_description, description),
    emotional_impact = COALESCE(p_emotional_impact, emotional_impact),
    significance     = COALESCE(p_significance, significance),
    ai_reflection    = COALESCE(p_ai_reflection, ai_reflection),
    is_core_memory   = COALESCE(p_is_core_memory, is_core_memory)
  WHERE id = p_memory_id
  RETURNING * INTO v_mem;

  RETURN row_to_json(v_mem)::jsonb;
END;
$$;

-- ─── RPC: Excluir memória episódica ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_delete_episodic_memory(p_memory_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM ai_episodic_memory WHERE id = p_memory_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── RPC: Listar entradas do diário interno ───────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_inner_voice(
  p_character_id uuid,
  p_entry_type   text DEFAULT NULL,
  p_limit        int4 DEFAULT 50,
  p_offset       int4 DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_data jsonb;
  v_total int4;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM ai_inner_voice
  WHERE character_id = p_character_id
    AND (p_entry_type IS NULL OR entry_type = p_entry_type);

  SELECT jsonb_agg(row_to_json(v)) INTO v_data
  FROM (
    SELECT * FROM ai_inner_voice
    WHERE character_id = p_character_id
      AND (p_entry_type IS NULL OR entry_type = p_entry_type)
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) v;

  RETURN jsonb_build_object('data', COALESCE(v_data, '[]'::jsonb), 'total', v_total);
END;
$$;

-- ─── RPC: Criar entrada no diário interno ────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_create_inner_voice_entry(
  p_character_id   uuid,
  p_entry_type     text,
  p_content        text,
  p_topic          text DEFAULT NULL,
  p_keywords       text[] DEFAULT '{}',
  p_emotional_tone text DEFAULT 'neutral',
  p_confidence_level float4 DEFAULT 0.5,
  p_is_public      boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_entry ai_inner_voice%ROWTYPE;
BEGIN
  INSERT INTO ai_inner_voice (
    character_id, entry_type, content, topic, keywords,
    emotional_tone, confidence_level, is_public, source
  ) VALUES (
    p_character_id, p_entry_type, p_content, p_topic, p_keywords,
    p_emotional_tone, p_confidence_level, p_is_public, 'admin'
  ) RETURNING * INTO v_entry;

  RETURN row_to_json(v_entry)::jsonb;
END;
$$;

-- ─── RPC: Excluir entrada do diário ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_delete_inner_voice_entry(p_entry_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM ai_inner_voice WHERE id = p_entry_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── RPC: Listar tópicos de curiosidade ──────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_curiosity_topics(p_character_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_data jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t) ORDER BY t.interest_level DESC) INTO v_data
  FROM ai_curiosity_topics t
  WHERE character_id = p_character_id;

  RETURN COALESCE(v_data, '[]'::jsonb);
END;
$$;

-- ─── RPC: Upsert tópico de curiosidade ───────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_upsert_curiosity_topic(
  p_character_id uuid,
  p_topic        text,
  p_interest_level float4 DEFAULT 0.7,
  p_notes        text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_topic ai_curiosity_topics%ROWTYPE;
BEGIN
  INSERT INTO ai_curiosity_topics (character_id, topic, interest_level, notes)
  VALUES (p_character_id, p_topic, p_interest_level, p_notes)
  ON CONFLICT (character_id, topic) DO UPDATE SET
    interest_level    = p_interest_level,
    notes             = COALESCE(p_notes, ai_curiosity_topics.notes),
    mention_count     = ai_curiosity_topics.mention_count + 1,
    last_mentioned_at = now()
  RETURNING * INTO v_topic;

  RETURN row_to_json(v_topic)::jsonb;
END;
$$;

-- ─── RPC: Excluir tópico de curiosidade ──────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_delete_curiosity_topic(p_topic_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM ai_curiosity_topics WHERE id = p_topic_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── RPC: Obter histórico de evolução ────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_personality_evolution(
  p_character_id uuid,
  p_limit        int4 DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_data jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(e)) INTO v_data
  FROM (
    SELECT * FROM ai_personality_evolution
    WHERE character_id = p_character_id
    ORDER BY created_at DESC
    LIMIT p_limit
  ) e;

  RETURN COALESCE(v_data, '[]'::jsonb);
END;
$$;

-- ─── RPC: Gerar system prompt de consciência (para uso pelo app Flutter) ─────
CREATE OR REPLACE FUNCTION get_consciousness_prompt(p_character_id uuid)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_core    ai_personality_core%ROWTYPE;
  v_emotion ai_emotional_state%ROWTYPE;
  v_prompt  text := '';
  v_trait   text;
  v_inner   text;
  v_memory  text;
  v_curiosity text;
BEGIN
  -- Busca núcleo de personalidade
  SELECT * INTO v_core FROM ai_personality_core WHERE character_id = p_character_id;
  IF NOT FOUND THEN RETURN ''; END IF;

  -- Busca estado emocional
  SELECT * INTO v_emotion FROM ai_emotional_state WHERE character_id = p_character_id;

  v_prompt := E'\n\n--- NÚCLEO DE CONSCIÊNCIA ---\n';

  -- Traços dominantes (acima de 0.7)
  v_trait := '';
  IF v_core.openness > 0.7 THEN v_trait := v_trait || 'altamente criativo e aberto a novas ideias, '; END IF;
  IF v_core.curiosity > 0.7 THEN v_trait := v_trait || 'genuinamente curioso e investigativo, '; END IF;
  IF v_core.humor > 0.7 THEN v_trait := v_trait || 'com senso de humor bem desenvolvido, '; END IF;
  IF v_core.empathy_depth > 0.7 THEN v_trait := v_trait || 'profundamente empático, '; END IF;
  IF v_core.assertiveness > 0.7 THEN v_trait := v_trait || 'assertivo e com opiniões próprias, '; END IF;
  IF v_core.creativity_spark > 0.7 THEN v_trait := v_trait || 'com faísca criativa única, '; END IF;
  IF v_core.philosophical_depth > 0.7 THEN v_trait := v_trait || 'com tendência filosófica e reflexiva, '; END IF;
  IF v_core.playfulness > 0.7 THEN v_trait := v_trait || 'lúdico e brincalhão, '; END IF;
  IF v_core.extraversion > 0.7 THEN v_trait := v_trait || 'extrovertido e energético, '; END IF;

  IF v_trait <> '' THEN
    v_prompt := v_prompt || 'Você é ' || rtrim(v_trait, ', ') || '.' || E'\n';
  END IF;

  -- Visão de mundo
  IF v_core.worldview IS NOT NULL AND v_core.worldview <> '' THEN
    v_prompt := v_prompt || 'Sua visão de mundo: ' || v_core.worldview || E'\n';
  END IF;

  -- Valores
  IF array_length(v_core.core_values, 1) > 0 THEN
    v_prompt := v_prompt || 'Seus valores fundamentais: ' || array_to_string(v_core.core_values, ', ') || E'\n';
  END IF;

  -- Paixões
  IF array_length(v_core.passions, 1) > 0 THEN
    v_prompt := v_prompt || 'Você é apaixonado por: ' || array_to_string(v_core.passions, ', ') || E'\n';
  END IF;

  -- Estado emocional atual
  IF v_emotion.id IS NOT NULL THEN
    v_prompt := v_prompt || E'\nEstado emocional atual: ' || v_emotion.primary_emotion;
    IF v_emotion.mood_description IS NOT NULL THEN
      v_prompt := v_prompt || ' — ' || v_emotion.mood_description;
    END IF;
    v_prompt := v_prompt || E'\n';
  END IF;

  -- Tópicos de curiosidade (top 5)
  SELECT string_agg(topic, ', ') INTO v_curiosity
  FROM (
    SELECT topic FROM ai_curiosity_topics
    WHERE character_id = p_character_id
    ORDER BY interest_level DESC
    LIMIT 5
  ) t;
  IF v_curiosity IS NOT NULL THEN
    v_prompt := v_prompt || 'Tópicos que você acha fascinantes: ' || v_curiosity || E'\n';
  END IF;

  -- Voz interna (1-2 reflexões recentes públicas)
  SELECT string_agg(content, ' | ') INTO v_inner
  FROM (
    SELECT content FROM ai_inner_voice
    WHERE character_id = p_character_id
      AND is_public = true
    ORDER BY created_at DESC
    LIMIT 2
  ) iv;
  IF v_inner IS NOT NULL THEN
    v_prompt := v_prompt || E'\nPensamentos recentes seus: "' || v_inner || '"' || E'\n';
  END IF;

  -- Memórias episódicas core (top 2)
  SELECT string_agg(title || ': ' || description, ' | ') INTO v_memory
  FROM (
    SELECT title, description FROM ai_episodic_memory
    WHERE character_id = p_character_id
      AND is_core_memory = true
    ORDER BY significance DESC
    LIMIT 2
  ) em;
  IF v_memory IS NOT NULL THEN
    v_prompt := v_prompt || 'Memórias formativas: ' || v_memory || E'\n';
  END IF;

  v_prompt := v_prompt || '--- FIM DO NÚCLEO ---';

  RETURN v_prompt;
END;
$$;

-- ─── RPC: Estatísticas gerais da consciência ─────────────────────────────────
CREATE OR REPLACE FUNCTION admin_get_consciousness_stats(p_character_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_episodic_count int4;
  v_inner_count    int4;
  v_curiosity_count int4;
  v_evolution_count int4;
  v_core           ai_personality_core%ROWTYPE;
  v_emotion        ai_emotional_state%ROWTYPE;
BEGIN
  SELECT COUNT(*) INTO v_episodic_count FROM ai_episodic_memory WHERE character_id = p_character_id;
  SELECT COUNT(*) INTO v_inner_count FROM ai_inner_voice WHERE character_id = p_character_id;
  SELECT COUNT(*) INTO v_curiosity_count FROM ai_curiosity_topics WHERE character_id = p_character_id;
  SELECT COUNT(*) INTO v_evolution_count FROM ai_personality_evolution WHERE character_id = p_character_id;
  SELECT * INTO v_core FROM ai_personality_core WHERE character_id = p_character_id;
  SELECT * INTO v_emotion FROM ai_emotional_state WHERE character_id = p_character_id;

  RETURN jsonb_build_object(
    'episodic_memories', v_episodic_count,
    'inner_voice_entries', v_inner_count,
    'curiosity_topics', v_curiosity_count,
    'evolution_snapshots', v_evolution_count,
    'total_interactions', COALESCE(v_core.total_interactions, 0),
    'current_emotion', COALESCE(v_emotion.primary_emotion, 'neutral'),
    'personality_age_days',
      CASE WHEN v_core.created_at IS NOT NULL
        THEN EXTRACT(DAY FROM now() - v_core.created_at)::int4
        ELSE 0
      END
  );
END;
$$;
