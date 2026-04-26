-- Migration 166: Profile Visitors (Visitantes Recentes do Perfil)
-- Registra visitas ao perfil e permite que o usuário veja quem visitou seu perfil.

CREATE TABLE IF NOT EXISTS public.profile_visits (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  visited_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  visited_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_anonymous BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (visitor_id, visited_id)
);

-- Índice para buscar visitantes recentes de um perfil
CREATE INDEX IF NOT EXISTS idx_profile_visits_visited
  ON public.profile_visits (visited_id, visited_at DESC);

-- Índice para buscar perfis visitados por um usuário
CREATE INDEX IF NOT EXISTS idx_profile_visits_visitor
  ON public.profile_visits (visitor_id, visited_at DESC);

-- RLS
ALTER TABLE public.profile_visits ENABLE ROW LEVEL SECURITY;

-- Usuário pode ver quem visitou seu próprio perfil (exceto anônimos)
CREATE POLICY "profile_visits_read_own" ON public.profile_visits
  FOR SELECT TO authenticated
  USING (visited_id = auth.uid() AND is_anonymous = false);

-- Usuário pode inserir/atualizar suas próprias visitas
CREATE POLICY "profile_visits_insert" ON public.profile_visits
  FOR INSERT TO authenticated
  WITH CHECK (visitor_id = auth.uid());

CREATE POLICY "profile_visits_update" ON public.profile_visits
  FOR UPDATE TO authenticated
  USING (visitor_id = auth.uid())
  WITH CHECK (visitor_id = auth.uid());

-- RPC: registrar visita ao perfil
CREATE OR REPLACE FUNCTION public.record_profile_visit(
  p_visited_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_visitor_id UUID := auth.uid();
  v_is_anon    BOOLEAN;
BEGIN
  IF v_visitor_id IS NULL THEN RETURN; END IF;
  -- Não registrar auto-visita
  IF v_visitor_id = p_visited_id THEN RETURN; END IF;
  -- Verificar se o visitante optou por ser anônimo
  SELECT COALESCE(
    (settings->>'anonymous_profile_visits')::boolean, false
  )
  INTO v_is_anon
  FROM public.profiles
  WHERE id = v_visitor_id;
  -- Upsert: atualizar timestamp se já visitou
  INSERT INTO public.profile_visits (visitor_id, visited_id, visited_at, is_anonymous)
  VALUES (v_visitor_id, p_visited_id, now(), v_is_anon)
  ON CONFLICT (visitor_id, visited_id)
  DO UPDATE SET visited_at = now(), is_anonymous = EXCLUDED.is_anonymous;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_profile_visit(UUID) TO authenticated;

-- RPC: buscar visitantes recentes do perfil (últimos 7 dias, máx 20)
CREATE OR REPLACE FUNCTION public.get_recent_profile_visitors(
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  visitor_id   UUID,
  nickname     TEXT,
  icon_url     TEXT,
  amino_id     TEXT,
  is_verified  BOOLEAN,
  visited_at   TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    pv.visitor_id,
    pr.nickname,
    pr.icon_url,
    pr.amino_id,
    pr.is_nickname_verified AS is_verified,
    pv.visited_at
  FROM public.profile_visits pv
  JOIN public.profiles pr ON pr.id = pv.visitor_id
  WHERE pv.visited_id = auth.uid()
    AND pv.is_anonymous = false
    AND pv.visited_at >= now() - INTERVAL '7 days'
  ORDER BY pv.visited_at DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_recent_profile_visitors(INT) TO authenticated;
