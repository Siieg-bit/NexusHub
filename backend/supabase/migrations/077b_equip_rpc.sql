-- ============================================================
-- 077b — RPC equip_store_item (atômico, SECURITY DEFINER)
-- ============================================================
-- Equipa ou desequipa um item da loja de forma atômica:
-- 1. Desequipa todos os outros itens do mesmo tipo do usuário
-- 2. Equipa (ou toggle) o item solicitado
-- Retorna jsonb com {success, equipped, message}
-- ============================================================

CREATE OR REPLACE FUNCTION public.equip_store_item(
  p_purchase_id UUID,
  p_item_type   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id     UUID;
  v_already     BOOLEAN;
  v_new_state   BOOLEAN;
BEGIN
  -- Garante que o purchase pertence ao usuário autenticado
  SELECT user_id, is_equipped
    INTO v_user_id, v_already
    FROM public.user_purchases
   WHERE id = p_purchase_id
     AND user_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'equipped', false,
      'message', 'Compra não encontrada ou não pertence ao usuário.'
    );
  END IF;

  -- Toggle: se já está equipado, desequipa; senão equipa
  v_new_state := NOT v_already;

  IF v_new_state THEN
    -- Desequipa todos os outros itens do mesmo tipo
    UPDATE public.user_purchases up
       SET is_equipped = false,
           equipped_in_community = NULL
      FROM public.store_items si
     WHERE up.item_id = si.id
       AND si.type    = p_item_type
       AND up.user_id = auth.uid()
       AND up.id     <> p_purchase_id;
  END IF;

  -- Equipa (ou desequipa) o item solicitado
  UPDATE public.user_purchases
     SET is_equipped          = v_new_state,
         equipped_in_community = NULL
   WHERE id = p_purchase_id;

  RETURN jsonb_build_object(
    'success', true,
    'equipped', v_new_state,
    'message', CASE WHEN v_new_state THEN 'Item equipado.' ELSE 'Item removido.' END
  );
END;
$$;

-- Garante que usuários autenticados podem chamar o RPC
GRANT EXECUTE ON FUNCTION public.equip_store_item(UUID, TEXT) TO authenticated;
