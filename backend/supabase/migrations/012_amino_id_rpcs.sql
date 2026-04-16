-- ============================================================
-- NexusHub — Migração 012: RPCs com resolução de Amino ID
-- Adiciona wrappers que aceitam amino_id (texto) em vez de UUID,
-- resolvendo o UUID internamente antes de delegar às RPCs base.
-- ============================================================

-- ========================
-- 1. transfer_coins_by_amino_id
-- Aceita o amino_id do destinatário (campo nickname único em profiles)
-- ========================
CREATE OR REPLACE FUNCTION public.transfer_coins_by_amino_id(
  p_target_amino_id TEXT,
  p_amount INTEGER
)
RETURNS JSONB AS $$
DECLARE
  v_receiver_id UUID;
BEGIN
  -- Resolver amino_id → UUID
  SELECT id INTO v_receiver_id
  FROM public.profiles
  WHERE LOWER(nickname) = LOWER(TRIM(p_target_amino_id))
  LIMIT 1;

  IF v_receiver_id IS NULL THEN
    RETURN jsonb_build_object('error', 'user_not_found');
  END IF;

  -- Delegar à RPC base com UUID
  RETURN public.transfer_coins(v_receiver_id, p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- 2. send_tip_by_amino_id
-- Aceita o amino_id do destinatário para envio de Props
-- ========================
CREATE OR REPLACE FUNCTION public.send_tip_by_amino_id(
  p_target_amino_id TEXT,
  p_amount INTEGER,
  p_post_id UUID DEFAULT NULL,
  p_chat_message_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_receiver_id UUID;
BEGIN
  -- Resolver amino_id → UUID
  SELECT id INTO v_receiver_id
  FROM public.profiles
  WHERE LOWER(nickname) = LOWER(TRIM(p_target_amino_id))
  LIMIT 1;

  IF v_receiver_id IS NULL THEN
    RETURN jsonb_build_object('error', 'user_not_found');
  END IF;

  -- Delegar à RPC base com UUID
  RETURN public.send_tip(v_receiver_id, p_amount, p_post_id, p_chat_message_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================
-- Permissões
-- ========================
GRANT EXECUTE ON FUNCTION public.transfer_coins_by_amino_id(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_tip_by_amino_id(TEXT, INTEGER, UUID, UUID) TO authenticated;
