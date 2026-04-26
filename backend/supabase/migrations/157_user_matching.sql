-- ============================================================
-- Migration 157 — User Matching por Interesses
-- Encontrar usuários com interesses similares
-- ============================================================

-- Fila de matching: usuários que estão procurando conexões agora
CREATE TABLE IF NOT EXISTS matching_queue (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  interests     TEXT[] NOT NULL DEFAULT '{}',  -- snapshot dos interesses no momento
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT now(),
  expires_at    TIMESTAMPTZ DEFAULT (now() + INTERVAL '10 minutes'),
  UNIQUE (user_id)
);

-- Histórico de matches realizados
CREATE TABLE IF NOT EXISTS user_matches (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user_b        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  common_interests TEXT[] DEFAULT '{}',
  score         INT DEFAULT 0,             -- número de interesses em comum
  status        TEXT DEFAULT 'pending'     -- 'pending' | 'accepted' | 'declined' | 'expired'
                CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
  created_at    TIMESTAMPTZ DEFAULT now(),
  responded_at  TIMESTAMPTZ,
  UNIQUE (user_a, user_b)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_matching_queue_active ON matching_queue(is_active, expires_at);
CREATE INDEX IF NOT EXISTS idx_user_matches_user_a ON user_matches(user_a, status);
CREATE INDEX IF NOT EXISTS idx_user_matches_user_b ON user_matches(user_b, status);

-- RLS
ALTER TABLE matching_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_matches ENABLE ROW LEVEL SECURITY;

-- Usuário vê/gerencia sua própria fila
CREATE POLICY "matching_queue_own" ON matching_queue
  FOR ALL USING (user_id = auth.uid());

-- Usuário vê seus próprios matches
CREATE POLICY "user_matches_read" ON user_matches
  FOR SELECT USING (user_a = auth.uid() OR user_b = auth.uid());

CREATE POLICY "user_matches_update" ON user_matches
  FOR UPDATE USING (user_a = auth.uid() OR user_b = auth.uid());

-- ============================================================
-- RPC: entrar na fila de matching
-- ============================================================
CREATE OR REPLACE FUNCTION join_matching_queue()
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_interests TEXT[];
  v_entry_id UUID;
BEGIN
  -- Buscar interesses do usuário (selected_interests é JSONB array de strings)
  SELECT ARRAY(
    SELECT jsonb_array_elements_text(selected_interests)
    FROM profiles WHERE id = v_user_id
  ) INTO v_interests;

  -- Upsert na fila
  INSERT INTO matching_queue (user_id, interests, is_active, expires_at)
  VALUES (v_user_id, COALESCE(v_interests, '{}'), true, now() + INTERVAL '10 minutes')
  ON CONFLICT (user_id) DO UPDATE
    SET interests = EXCLUDED.interests,
        is_active = true,
        expires_at = now() + INTERVAL '10 minutes',
        created_at = now()
  RETURNING id INTO v_entry_id;

  RETURN v_entry_id;
END;
$$;

-- ============================================================
-- RPC: sair da fila de matching
-- ============================================================
CREATE OR REPLACE FUNCTION leave_matching_queue()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE matching_queue
  SET is_active = false
  WHERE user_id = auth.uid();
END;
$$;

-- ============================================================
-- RPC: encontrar matches por interesses em comum
-- Retorna até 10 usuários com mais interesses em comum
-- ============================================================
CREATE OR REPLACE FUNCTION find_interest_matches(p_limit INT DEFAULT 10)
RETURNS TABLE (
  user_id         UUID,
  nickname        TEXT,
  icon_url        TEXT,
  bio             TEXT,
  status_emoji    TEXT,
  status_text     TEXT,
  common_interests TEXT[],
  score           INT,
  is_following    BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_my_interests TEXT[];
BEGIN
  -- Buscar interesses do usuário atual
  SELECT ARRAY(
    SELECT jsonb_array_elements_text(selected_interests)
    FROM profiles WHERE id = v_user_id
  ) INTO v_my_interests;

  IF v_my_interests IS NULL OR array_length(v_my_interests, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    p.id AS user_id,
    p.nickname,
    p.icon_url,
    p.bio,
    p.status_emoji,
    p.status_text,
    -- Interesses em comum
    ARRAY(
      SELECT unnest(v_my_interests)
      INTERSECT
      SELECT jsonb_array_elements_text(p.selected_interests)
    ) AS common_interests,
    -- Score = número de interesses em comum
    (
      SELECT COUNT(*)::INT
      FROM (
        SELECT unnest(v_my_interests)
        INTERSECT
        SELECT jsonb_array_elements_text(p.selected_interests)
      ) t
    ) AS score,
    -- Já segue?
    EXISTS(
      SELECT 1 FROM follows
      WHERE follower_id = v_user_id AND following_id = p.id
    ) AS is_following
  FROM profiles p
  WHERE
    p.id != v_user_id
    AND p.is_banned = false
    AND (
      SELECT COUNT(*)
      FROM (
        SELECT unnest(v_my_interests)
        INTERSECT
        SELECT jsonb_array_elements_text(p.selected_interests)
      ) t
    ) > 0
  ORDER BY score DESC, p.created_at DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- RPC: responder a um match (aceitar/recusar)
-- ============================================================
CREATE OR REPLACE FUNCTION respond_to_match(
  p_match_id UUID,
  p_accept   BOOLEAN
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE user_matches
  SET
    status = CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END,
    responded_at = now()
  WHERE id = p_match_id
    AND (user_a = auth.uid() OR user_b = auth.uid())
    AND status = 'pending';
END;
$$;

-- Grants
GRANT EXECUTE ON FUNCTION join_matching_queue TO authenticated;
GRANT EXECUTE ON FUNCTION leave_matching_queue TO authenticated;
GRANT EXECUTE ON FUNCTION find_interest_matches TO authenticated;
GRANT EXECUTE ON FUNCTION respond_to_match TO authenticated;
