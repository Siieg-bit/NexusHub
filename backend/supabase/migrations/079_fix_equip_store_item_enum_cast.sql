-- Migração 079: Corrige cast do enum store_item_type no RPC equip_store_item
--
-- Problema: o parâmetro p_item_type é text, mas a coluna store_items.type
-- é do tipo enum store_item_type. O Postgres não consegue comparar
-- enum = text sem cast explícito, lançando:
--   "operator does not exist: store_item_type = text"
--
-- Solução: adicionar cast explícito p_item_type::store_item_type na
-- cláusula WHERE do UPDATE que desequipa outros itens do mesmo tipo.

CREATE OR REPLACE FUNCTION public.equip_store_item(
  p_purchase_id uuid,
  p_item_type   text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID;
  v_already   BOOLEAN;
  v_new_state BOOLEAN;
BEGIN
  -- Garante que o purchase pertence ao usuário autenticado
  SELECT user_id, is_equipped
    INTO v_user_id, v_already
    FROM public.user_purchases
   WHERE id      = p_purchase_id
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
    -- Desequipa todos os outros itens do mesmo tipo.
    -- CAST explícito necessário: p_item_type::store_item_type
    UPDATE public.user_purchases up
       SET is_equipped           = false,
           equipped_in_community = NULL
      FROM public.store_items si
     WHERE up.item_id = si.id
       AND si.type    = p_item_type::store_item_type
       AND up.user_id = auth.uid()
       AND up.id     <> p_purchase_id;
  END IF;

  -- Equipa (ou desequipa) o item solicitado
  UPDATE public.user_purchases
     SET is_equipped           = v_new_state,
         equipped_in_community = NULL
   WHERE id = p_purchase_id;

  RETURN jsonb_build_object(
    'success', true,
    'equipped', v_new_state,
    'message', CASE WHEN v_new_state THEN 'Item equipado.' ELSE 'Item removido.' END
  );
END;
$$;
