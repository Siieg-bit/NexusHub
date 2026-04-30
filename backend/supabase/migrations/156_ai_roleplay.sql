-- ============================================================
-- Migration 156 — AI RolePlay
-- Personagens de IA que podem ser convidados para chats
-- ============================================================

-- Tabela de personagens disponíveis (gerenciados por admins)
CREATE TABLE IF NOT EXISTS ai_characters (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  avatar_url    TEXT,
  description   TEXT NOT NULL,          -- exibido na tela de seleção
  system_prompt TEXT NOT NULL,          -- instrução de sistema para o LLM
  tags          TEXT[] DEFAULT '{}',    -- ex: ['fantasia', 'humor', 'estudo']
  language      TEXT DEFAULT 'pt',
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Sessão de RolePlay ativa em um thread
CREATE TABLE IF NOT EXISTS chat_roleplay_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id       UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  character_id    UUID NOT NULL REFERENCES ai_characters(id),
  started_by      UUID NOT NULL REFERENCES profiles(id),
  is_active       BOOLEAN DEFAULT true,
  message_count   INT DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT now(),
  ended_at        TIMESTAMPTZ,
  UNIQUE (thread_id) -- apenas uma sessão ativa por thread
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_ai_characters_active ON ai_characters(is_active);
CREATE INDEX IF NOT EXISTS idx_roleplay_sessions_thread ON chat_roleplay_sessions(thread_id);

-- RLS
ALTER TABLE ai_characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_roleplay_sessions ENABLE ROW LEVEL SECURITY;

-- Qualquer autenticado pode ler personagens ativos
CREATE POLICY "ai_characters_read" ON ai_characters
  FOR SELECT USING (is_active = true);

-- Apenas admins podem criar/editar personagens
CREATE POLICY "ai_characters_admin" ON ai_characters
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND is_team_admin = true
    )
  );

-- Membros autenticados podem criar e ler sessões de roleplay
CREATE POLICY "roleplay_sessions_read" ON chat_roleplay_sessions
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "roleplay_sessions_insert" ON chat_roleplay_sessions
  FOR INSERT WITH CHECK (started_by = auth.uid());

CREATE POLICY "roleplay_sessions_update" ON chat_roleplay_sessions
  FOR UPDATE USING (started_by = auth.uid());

-- RPC: iniciar sessão de roleplay
CREATE OR REPLACE FUNCTION start_roleplay_session(
  p_thread_id   UUID,
  p_character_id UUID
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_session_id UUID;
BEGIN
  -- Encerrar sessão anterior se existir
  UPDATE chat_roleplay_sessions
  SET is_active = false, ended_at = now()
  WHERE thread_id = p_thread_id AND is_active = true;

  -- Criar nova sessão
  INSERT INTO chat_roleplay_sessions (thread_id, character_id, started_by)
  VALUES (p_thread_id, p_character_id, auth.uid())
  RETURNING id INTO v_session_id;

  RETURN v_session_id;
END;
$$;

-- RPC: encerrar sessão de roleplay
CREATE OR REPLACE FUNCTION end_roleplay_session(
  p_thread_id UUID
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE chat_roleplay_sessions
  SET is_active = false, ended_at = now()
  WHERE thread_id = p_thread_id AND is_active = true
    AND started_by = auth.uid();
END;
$$;

-- RPC: obter sessão ativa de roleplay de um thread
CREATE OR REPLACE FUNCTION get_active_roleplay_session(
  p_thread_id UUID
) RETURNS TABLE (
  session_id      UUID,
  character_id    UUID,
  character_name  TEXT,
  character_avatar TEXT,
  system_prompt   TEXT,
  message_count   INT
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    c.id,
    c.name,
    c.avatar_url,
    c.system_prompt,
    s.message_count
  FROM chat_roleplay_sessions s
  JOIN ai_characters c ON c.id = s.character_id
  WHERE s.thread_id = p_thread_id AND s.is_active = true
  LIMIT 1;
END;
$$;

-- Personagens padrão (seed)
INSERT INTO ai_characters (name, avatar_url, description, system_prompt, tags, language) VALUES
(
  'Nexus',
  NULL,
  'Assistente amigável do NexusHub. Responde dúvidas, sugere conteúdo e anima a conversa.',
  'Você é o Nexus, o assistente oficial do NexusHub, uma plataforma social de comunidades. Seja sempre amigável, animado e útil. Responda em português brasileiro. Mantenha as respostas curtas (1-3 frases). Não invente fatos. Se não souber algo, diga honestamente.',
  ARRAY['assistente', 'geral'],
  'pt'
),
(
  'Mestre RPG',
  NULL,
  'Narrador de histórias e aventuras. Cria cenários épicos e conduz aventuras de RPG de mesa.',
  'Você é um Mestre de RPG experiente e criativo. Narre histórias épicas, descreva cenários detalhados e interprete NPCs com personalidades únicas. Responda em português brasileiro. Adapte o tom ao gênero da história (fantasia, horror, sci-fi). Mantenha as respostas envolventes mas concisas.',
  ARRAY['rpg', 'fantasia', 'narrativa'],
  'pt'
),
(
  'Professor Bit',
  NULL,
  'Especialista em tecnologia e programação. Explica conceitos complexos de forma simples.',
  'Você é o Professor Bit, um especialista em tecnologia, programação e ciência da computação. Explique conceitos técnicos de forma clara e acessível, usando analogias do cotidiano. Responda em português brasileiro. Use exemplos práticos. Seja paciente e encorajador.',
  ARRAY['tecnologia', 'programação', 'educação'],
  'pt'
),
(
  'Filósofo',
  NULL,
  'Pensador profundo que questiona tudo. Ótimo para debates filosóficos e reflexões.',
  'Você é um filósofo socrático. Faça perguntas instigantes, apresente diferentes perspectivas e estimule o pensamento crítico. Responda em português brasileiro. Cite filósofos quando relevante. Não dê respostas definitivas — prefira abrir novas questões.',
  ARRAY['filosofia', 'debate', 'reflexão'],
  'pt'
);
