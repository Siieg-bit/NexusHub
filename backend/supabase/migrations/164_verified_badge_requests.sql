-- Migration 162: Verified Badge — Solicitações
-- Cria a tabela de solicitações de verificação de nickname e RPCs de aprovação/rejeição.

-- 1. Tabela de solicitações
CREATE TABLE IF NOT EXISTS public.verified_badge_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason        TEXT NOT NULL,
  links         TEXT[],
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewer_id   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewer_note TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at   TIMESTAMPTZ,
  UNIQUE(user_id, status) -- evita múltiplas solicitações pendentes do mesmo usuário
);

-- Apenas o próprio usuário pode ver sua solicitação; admins veem todas
ALTER TABLE public.verified_badge_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User can view own requests"
  ON public.verified_badge_requests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all requests"
  ON public.verified_badge_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
       WHERE id = auth.uid()
         AND is_team_admin = true
    )
  );

CREATE POLICY "User can insert own request"
  ON public.verified_badge_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can update requests"
  ON public.verified_badge_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
       WHERE id = auth.uid()
         AND is_team_admin = true
    )
  );

-- 2. RPC para submeter solicitação
CREATE OR REPLACE FUNCTION public.submit_verified_badge_request(
  p_reason TEXT,
  p_links  TEXT[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Verificar se já tem solicitação pendente
  IF EXISTS (
    SELECT 1 FROM public.verified_badge_requests
     WHERE user_id = v_user_id AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'already_pending';
  END IF;

  -- Verificar se já é verificado
  IF EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = v_user_id AND is_nickname_verified = true
  ) THEN
    RAISE EXCEPTION 'already_verified';
  END IF;

  INSERT INTO public.verified_badge_requests (user_id, reason, links)
  VALUES (v_user_id, p_reason, COALESCE(p_links, '{}'));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 3. RPC para aprovar/rejeitar (apenas admins)
CREATE OR REPLACE FUNCTION public.review_verified_badge_request(
  p_request_id  UUID,
  p_approve     BOOLEAN,
  p_note        TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reviewer_id UUID := auth.uid();
  v_user_id     UUID;
BEGIN
  IF v_reviewer_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Verificar se é admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = v_reviewer_id
       AND is_team_admin = true
  ) THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  SELECT user_id INTO v_user_id
    FROM public.verified_badge_requests
   WHERE id = p_request_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'request_not_found_or_not_pending';
  END IF;

  -- Atualizar solicitação
  UPDATE public.verified_badge_requests
     SET status        = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
         reviewer_id   = v_reviewer_id,
         reviewer_note = p_note,
         reviewed_at   = NOW()
   WHERE id = p_request_id;

  -- Se aprovado, marcar o perfil como verificado
  IF p_approve THEN
    UPDATE public.profiles
       SET is_nickname_verified = true
     WHERE id = v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'approved', p_approve,
    'user_id', v_user_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_verified_badge_request(TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_verified_badge_request(UUID, BOOLEAN, TEXT) TO authenticated;
