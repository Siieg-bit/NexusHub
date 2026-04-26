-- Migration 167: Referral Program (Programa de Referral)
-- Usuários podem convidar outros via link único e ganhar coins por conversões.

-- Tabela de referrals
CREATE TABLE IF NOT EXISTS public.referrals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referred_id   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ref_code      TEXT NOT NULL UNIQUE,
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'completed', 'rewarded')),
  rewarded_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals (referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON public.referrals (ref_code);

-- RLS
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "referrals_read_own" ON public.referrals
  FOR SELECT TO authenticated
  USING (referrer_id = auth.uid() OR referred_id = auth.uid());

CREATE POLICY "referrals_insert_own" ON public.referrals
  FOR INSERT TO authenticated
  WITH CHECK (referrer_id = auth.uid());

-- RPC: gerar ou recuperar o código de referral do usuário atual
CREATE OR REPLACE FUNCTION public.get_or_create_referral_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_code     TEXT;
  v_amino_id TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  -- Verificar se já existe um código para este usuário
  SELECT ref_code INTO v_code
  FROM public.referrals
  WHERE referrer_id = v_user_id
  LIMIT 1;
  IF v_code IS NOT NULL THEN RETURN v_code; END IF;
  -- Gerar novo código baseado no amino_id do usuário
  SELECT amino_id INTO v_amino_id FROM public.profiles WHERE id = v_user_id;
  v_code := COALESCE(v_amino_id, SUBSTRING(v_user_id::TEXT, 1, 8));
  -- Garantir unicidade
  WHILE EXISTS (SELECT 1 FROM public.referrals WHERE ref_code = v_code) LOOP
    v_code := v_code || SUBSTRING(gen_random_uuid()::TEXT, 1, 4);
  END LOOP;
  INSERT INTO public.referrals (referrer_id, ref_code)
  VALUES (v_user_id, v_code);
  RETURN v_code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_referral_code() TO authenticated;

-- RPC: registrar conversão de referral (chamado no onboarding)
CREATE OR REPLACE FUNCTION public.complete_referral(
  p_ref_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referred_id  UUID := auth.uid();
  v_referrer_id  UUID;
  v_referral_id  UUID;
BEGIN
  IF v_referred_id IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  -- Verificar se o usuário já foi referido
  IF EXISTS (SELECT 1 FROM public.referrals WHERE referred_id = v_referred_id) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_referred');
  END IF;
  -- Buscar o referral pelo código
  SELECT id, referrer_id INTO v_referral_id, v_referrer_id
  FROM public.referrals
  WHERE ref_code = p_ref_code
    AND referred_id IS NULL
    AND status = 'pending'
  LIMIT 1;
  IF v_referral_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_code');
  END IF;
  -- Não permitir auto-referral
  IF v_referrer_id = v_referred_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'self_referral');
  END IF;
  -- Vincular o referido ao referral
  UPDATE public.referrals
  SET referred_id = v_referred_id, status = 'completed'
  WHERE id = v_referral_id;
  -- Dar 25 coins ao referido
  UPDATE public.profiles
  SET coins = COALESCE(coins, 0) + 25
  WHERE id = v_referred_id;
  -- Dar 50 coins ao referente
  UPDATE public.profiles
  SET coins = COALESCE(coins, 0) + 50
  WHERE id = v_referrer_id;
  -- Marcar como recompensado
  UPDATE public.referrals
  SET status = 'rewarded', rewarded_at = now()
  WHERE id = v_referral_id;
  -- Notificar o referente
  INSERT INTO public.notifications (user_id, type, title, body, actor_id)
  VALUES (
    v_referrer_id,
    'referral_reward',
    'Convite aceito! 🎉',
    'Alguém se cadastrou com seu link de convite. Você ganhou 50 coins!',
    v_referred_id
  );
  RETURN jsonb_build_object('success', true, 'referrer_id', v_referrer_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_referral(TEXT) TO authenticated;

-- RPC: buscar estatísticas de referral do usuário atual
CREATE OR REPLACE FUNCTION public.get_referral_stats()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'ref_code', (
      SELECT ref_code FROM public.referrals
      WHERE referrer_id = auth.uid() LIMIT 1
    ),
    'total_invites', (
      SELECT COUNT(*) FROM public.referrals
      WHERE referrer_id = auth.uid()
    ),
    'completed_invites', (
      SELECT COUNT(*) FROM public.referrals
      WHERE referrer_id = auth.uid() AND status IN ('completed', 'rewarded')
    ),
    'total_coins_earned', (
      SELECT COUNT(*) * 50 FROM public.referrals
      WHERE referrer_id = auth.uid() AND status = 'rewarded'
    ),
    'referred_users', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'nickname', pr.nickname,
        'icon_url', pr.icon_url,
        'joined_at', r.created_at
      ) ORDER BY r.created_at DESC), '[]'::jsonb)
      FROM public.referrals r
      JOIN public.profiles pr ON pr.id = r.referred_id
      WHERE r.referrer_id = auth.uid()
        AND r.referred_id IS NOT NULL
    )
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_referral_stats() TO authenticated;
