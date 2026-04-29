-- =============================================================================
-- Migration 182: Membros Favoritos (favorite_members)
-- =============================================================================
-- Cria a tabela `favorite_members` que armazena os atalhos de membros
-- favoritos por usuário e por comunidade.
--
-- Diferença em relação a "follows":
--   - follows = seguir alguém globalmente (feed, notificações)
--   - favorite_members = atalho pessoal na barra "Meus Membros Favoritos"
--     dentro de uma comunidade específica. Totalmente independente de follows.
--
-- Regras:
--   - Um usuário pode favoritar qualquer membro ativo de uma comunidade.
--   - Não pode favoritar a si mesmo.
--   - Limite de 20 favoritos por comunidade.
--   - A ordem é definida por `position` (inteiro, menor = primeiro).
-- =============================================================================

-- ─── 1. Tabela ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.favorite_members (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id       UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id   UUID        NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  target_user_id UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  position       INTEGER     NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_favorite_member UNIQUE (owner_id, community_id, target_user_id),
  CONSTRAINT no_self_favorite    CHECK  (owner_id <> target_user_id)
);

CREATE INDEX IF NOT EXISTS idx_fav_members_owner_community
  ON public.favorite_members (owner_id, community_id, position);

-- ─── 2. RLS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.favorite_members ENABLE ROW LEVEL SECURITY;

-- Cada usuário só vê seus próprios favoritos
CREATE POLICY "favorite_members_select_own"
  ON public.favorite_members FOR SELECT
  USING (owner_id = auth.uid());

-- Sem INSERT/UPDATE/DELETE direto — tudo via RPC SECURITY DEFINER
CREATE POLICY "favorite_members_no_direct_write"
  ON public.favorite_members FOR ALL
  USING (false);

-- ─── 3. RPC: add_favorite_member ──────────────────────────────────────────────
-- Adiciona um membro à lista de favoritos do usuário autenticado.
-- Valida: autenticação, não favoritar a si mesmo, membership ativo,
-- limite de 20 favoritos e duplicata (retorna success=true se já existe).
CREATE OR REPLACE FUNCTION public.add_favorite_member(
  p_community_id   UUID,
  p_target_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID := auth.uid();
  v_count    INT;
  v_pos      INT;
BEGIN
  IF v_owner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF v_owner_id = p_target_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_favorite_self');
  END IF;

  -- Verificar que o alvo é membro ativo da comunidade
  -- (community_members não tem coluna status; usa is_banned)
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
      AND user_id      = p_target_user_id
      AND is_banned    = false
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'target_not_a_member');
  END IF;

  -- Verificar se já existe (idempotente)
  IF EXISTS (
    SELECT 1 FROM public.favorite_members
    WHERE owner_id       = v_owner_id
      AND community_id   = p_community_id
      AND target_user_id = p_target_user_id
  ) THEN
    RETURN jsonb_build_object('success', true, 'already_exists', true);
  END IF;

  -- Verificar limite de 20 favoritos
  SELECT COUNT(*) INTO v_count
  FROM public.favorite_members
  WHERE owner_id     = v_owner_id
    AND community_id = p_community_id;

  IF v_count >= 20 THEN
    RETURN jsonb_build_object('success', false, 'error', 'limit_reached');
  END IF;

  -- Posição = próximo após o último
  SELECT COALESCE(MAX(position), -1) + 1 INTO v_pos
  FROM public.favorite_members
  WHERE owner_id     = v_owner_id
    AND community_id = p_community_id;

  INSERT INTO public.favorite_members
    (owner_id, community_id, target_user_id, position)
  VALUES
    (v_owner_id, p_community_id, p_target_user_id, v_pos);

  RETURN jsonb_build_object('success', true, 'already_exists', false);
END;
$$;
GRANT EXECUTE ON FUNCTION public.add_favorite_member(UUID, UUID) TO authenticated;

-- ─── 4. RPC: remove_favorite_member ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.remove_favorite_member(
  p_community_id   UUID,
  p_target_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID := auth.uid();
BEGIN
  IF v_owner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  DELETE FROM public.favorite_members
  WHERE owner_id       = v_owner_id
    AND community_id   = p_community_id
    AND target_user_id = p_target_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.remove_favorite_member(UUID, UUID) TO authenticated;

-- ─── 5. RPC: get_favorite_members ────────────────────────────────────────────
-- Retorna a lista de membros favoritos do usuário autenticado em uma comunidade,
-- enriquecida com dados de perfil local (nickname e icon_url da comunidade).
CREATE OR REPLACE FUNCTION public.get_favorite_members(
  p_community_id UUID
)
RETURNS TABLE (
  target_user_id UUID,
  sort_position  INTEGER,
  nickname       TEXT,
  icon_url       TEXT,
  global_nickname TEXT,
  global_icon_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID := auth.uid();
BEGIN
  IF v_owner_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    fm.target_user_id,
    fm.position AS sort_position,
    -- Preferir nickname local da comunidade; fallback para global
    COALESCE(
      NULLIF(TRIM(cm.local_nickname), ''),
      p.nickname
    ) AS nickname,
    -- Preferir avatar local da comunidade; fallback para global
    COALESCE(
      NULLIF(TRIM(cm.local_icon_url), ''),
      p.icon_url
    ) AS icon_url,
    p.nickname  AS global_nickname,
    p.icon_url  AS global_icon_url
  FROM public.favorite_members fm
  JOIN public.profiles p
    ON p.id = fm.target_user_id
  LEFT JOIN public.community_members cm
    ON cm.community_id = p_community_id
   AND cm.user_id      = fm.target_user_id
  WHERE fm.owner_id     = v_owner_id
    AND fm.community_id = p_community_id
  ORDER BY fm.position ASC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_favorite_members(UUID) TO authenticated;
