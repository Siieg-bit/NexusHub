-- Migration 190: Ecossistema RPG do Chat
-- Sistema de gamificação para salas de chat (chat_threads).
-- O host do chat ativa/desativa o modo RPG e configura todo o ecossistema.
-- Membros criam personagens, ganham XP, acumulam moeda e compram itens.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ATIVAR MODO RPG NO CHAT (extensão de chat_threads)
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.chat_threads
  ADD COLUMN IF NOT EXISTS rpg_mode_enabled   BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS rpg_currency_name  TEXT NOT NULL DEFAULT 'Ouro',
  ADD COLUMN IF NOT EXISTS rpg_currency_icon  TEXT,
  ADD COLUMN IF NOT EXISTS rpg_xp_multiplier  NUMERIC(4,2) NOT NULL DEFAULT 1.0;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. CLASSES RPG DO CHAT (criadas pelo host)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.chat_rpg_classes (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id         UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  description       TEXT,
  color             TEXT NOT NULL DEFAULT '#7C4DFF',
  icon_url          TEXT,
  base_attributes   JSONB NOT NULL DEFAULT '{}',
  starting_currency INT NOT NULL DEFAULT 0,
  sort_order        INT NOT NULL DEFAULT 0,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_rpg_classes_thread
  ON public.chat_rpg_classes (thread_id, is_active, sort_order);

ALTER TABLE public.chat_rpg_classes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_rpg_classes_select" ON public.chat_rpg_classes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "chat_rpg_classes_host_manage" ON public.chat_rpg_classes
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_threads
      WHERE id = chat_rpg_classes.thread_id
        AND (host_id = auth.uid() OR co_hosts @> to_jsonb(auth.uid()::text))
    )
  );

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ATRIBUTOS CONFIGURÁVEIS PELO HOST
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.chat_rpg_attributes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id   UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  attr_type   TEXT NOT NULL DEFAULT 'stat'
                CHECK (attr_type IN ('stat', 'resource')),
  icon_url    TEXT,
  color       TEXT NOT NULL DEFAULT '#FF9800',
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_rpg_attrs_thread
  ON public.chat_rpg_attributes (thread_id, sort_order);

ALTER TABLE public.chat_rpg_attributes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_rpg_attrs_select" ON public.chat_rpg_attributes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "chat_rpg_attrs_host_manage" ON public.chat_rpg_attributes
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_threads
      WHERE id = chat_rpg_attributes.thread_id
        AND (host_id = auth.uid() OR co_hosts @> to_jsonb(auth.uid()::text))
    )
  );

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. ITENS RPG DO CHAT (criados pelo host)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.chat_rpg_items (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id           UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  name                TEXT NOT NULL,
  description         TEXT,
  item_type           TEXT NOT NULL DEFAULT 'consumable'
                        CHECK (item_type IN ('weapon', 'armor', 'consumable', 'quest_item', 'accessory')),
  rarity              TEXT NOT NULL DEFAULT 'common'
                        CHECK (rarity IN ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  price               INT NOT NULL DEFAULT 0,
  attribute_modifiers JSONB NOT NULL DEFAULT '{}',
  image_url           TEXT,
  is_available        BOOLEAN NOT NULL DEFAULT true,
  max_stack           INT NOT NULL DEFAULT 99,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_rpg_items_thread
  ON public.chat_rpg_items (thread_id, is_available, rarity);

ALTER TABLE public.chat_rpg_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_rpg_items_select" ON public.chat_rpg_items
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "chat_rpg_items_host_manage" ON public.chat_rpg_items
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_threads
      WHERE id = chat_rpg_items.thread_id
        AND (host_id = auth.uid() OR co_hosts @> to_jsonb(auth.uid()::text))
    )
  );

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. FICHAS DE PERSONAGEM (uma por membro por chat)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.chat_rpg_characters (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id        UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id         UUID REFERENCES public.chat_rpg_classes(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  avatar_url       TEXT,
  bio              TEXT,
  level            INT NOT NULL DEFAULT 1,
  xp               INT NOT NULL DEFAULT 0,
  currency_balance INT NOT NULL DEFAULT 0,
  attributes       JSONB NOT NULL DEFAULT '{}',
  char_status      TEXT NOT NULL DEFAULT 'alive'
                     CHECK (char_status IN ('alive', 'dead', 'inactive')),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (thread_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_rpg_chars_thread
  ON public.chat_rpg_characters (thread_id, level DESC);
CREATE INDEX IF NOT EXISTS idx_chat_rpg_chars_user
  ON public.chat_rpg_characters (user_id);

ALTER TABLE public.chat_rpg_characters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_rpg_chars_select" ON public.chat_rpg_characters
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "chat_rpg_chars_own_write" ON public.chat_rpg_characters
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. INVENTÁRIO
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.chat_rpg_inventory (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id UUID NOT NULL REFERENCES public.chat_rpg_characters(id) ON DELETE CASCADE,
  item_id      UUID NOT NULL REFERENCES public.chat_rpg_items(id) ON DELETE CASCADE,
  quantity     INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  is_equipped  BOOLEAN NOT NULL DEFAULT false,
  acquired_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (character_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_rpg_inv_char
  ON public.chat_rpg_inventory (character_id);

ALTER TABLE public.chat_rpg_inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_rpg_inv_select" ON public.chat_rpg_inventory
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "chat_rpg_inv_own" ON public.chat_rpg_inventory
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_rpg_characters
      WHERE id = chat_rpg_inventory.character_id
        AND user_id = auth.uid()
    )
  );

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. LOG DE EVENTOS RPG
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.chat_rpg_event_log (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id      UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  character_id   UUID REFERENCES public.chat_rpg_characters(id) ON DELETE SET NULL,
  actor_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type     TEXT NOT NULL,
  description    TEXT,
  xp_delta       INT NOT NULL DEFAULT 0,
  currency_delta INT NOT NULL DEFAULT 0,
  metadata       JSONB NOT NULL DEFAULT '{}',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_rpg_log_thread
  ON public.chat_rpg_event_log (thread_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_rpg_log_char
  ON public.chat_rpg_event_log (character_id, created_at DESC);

ALTER TABLE public.chat_rpg_event_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_rpg_log_select" ON public.chat_rpg_event_log
  FOR SELECT TO authenticated USING (true);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. RPCs
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 8.1. Ativar/Desativar Modo RPG (apenas host do chat) ─────────────────────
CREATE OR REPLACE FUNCTION public.toggle_chat_rpg_mode(
  p_thread_id UUID,
  p_enabled   BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_host_id TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT host_id INTO v_host_id FROM public.chat_threads WHERE id = p_thread_id;

  IF v_host_id IS NULL OR v_host_id::UUID != v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'only_host_can_toggle');
  END IF;

  UPDATE public.chat_threads
  SET rpg_mode_enabled = p_enabled
  WHERE id = p_thread_id;

  RETURN jsonb_build_object('success', true, 'rpg_enabled', p_enabled);
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_chat_rpg_mode TO authenticated;

-- ── 8.2. Configurar RPG do chat (host/co-host) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.configure_chat_rpg(
  p_thread_id      UUID,
  p_currency_name  TEXT DEFAULT NULL,
  p_currency_icon  TEXT DEFAULT NULL,
  p_xp_multiplier  NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_threads
    WHERE id = p_thread_id
      AND (host_id = v_user_id::text OR co_hosts @> to_jsonb(v_user_id::text))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_host');
  END IF;

  UPDATE public.chat_threads SET
    rpg_currency_name = COALESCE(p_currency_name, rpg_currency_name),
    rpg_currency_icon = COALESCE(p_currency_icon, rpg_currency_icon),
    rpg_xp_multiplier = COALESCE(p_xp_multiplier, rpg_xp_multiplier)
  WHERE id = p_thread_id;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.configure_chat_rpg TO authenticated;

-- ── 8.3. Gerenciar classes RPG (host/co-host) ────────────────────────────────
CREATE OR REPLACE FUNCTION public.manage_chat_rpg_class(
  p_thread_id       UUID,
  p_class_id        UUID DEFAULT NULL,
  p_name            TEXT DEFAULT NULL,
  p_description     TEXT DEFAULT NULL,
  p_color           TEXT DEFAULT '#7C4DFF',
  p_icon_url        TEXT DEFAULT NULL,
  p_base_attributes JSONB DEFAULT '{}',
  p_starting_currency INT DEFAULT 0,
  p_sort_order      INT DEFAULT 0,
  p_delete          BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_new_id  UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_threads
    WHERE id = p_thread_id
      AND (host_id = v_user_id::text OR co_hosts @> to_jsonb(v_user_id::text))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_host');
  END IF;

  IF p_delete AND p_class_id IS NOT NULL THEN
    UPDATE public.chat_rpg_classes SET is_active = false
    WHERE id = p_class_id AND thread_id = p_thread_id;
    RETURN jsonb_build_object('success', true, 'action', 'deleted');
  END IF;

  IF p_class_id IS NULL THEN
    INSERT INTO public.chat_rpg_classes
      (thread_id, name, description, color, icon_url, base_attributes,
       starting_currency, sort_order)
    VALUES
      (p_thread_id, p_name, p_description, p_color, p_icon_url,
       p_base_attributes, p_starting_currency, p_sort_order)
    RETURNING id INTO v_new_id;
    RETURN jsonb_build_object('success', true, 'action', 'created', 'id', v_new_id);
  ELSE
    UPDATE public.chat_rpg_classes SET
      name              = COALESCE(p_name,             name),
      description       = COALESCE(p_description,      description),
      color             = COALESCE(p_color,             color),
      icon_url          = COALESCE(p_icon_url,          icon_url),
      base_attributes   = COALESCE(p_base_attributes,   base_attributes),
      starting_currency = COALESCE(p_starting_currency, starting_currency),
      sort_order        = COALESCE(p_sort_order,        sort_order)
    WHERE id = p_class_id AND thread_id = p_thread_id;
    RETURN jsonb_build_object('success', true, 'action', 'updated');
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.manage_chat_rpg_class TO authenticated;

-- ── 8.4. Gerenciar itens RPG (host/co-host) ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.manage_chat_rpg_item(
  p_thread_id           UUID,
  p_item_id             UUID DEFAULT NULL,
  p_name                TEXT DEFAULT NULL,
  p_description         TEXT DEFAULT NULL,
  p_item_type           TEXT DEFAULT 'consumable',
  p_rarity              TEXT DEFAULT 'common',
  p_price               INT DEFAULT 0,
  p_attribute_modifiers JSONB DEFAULT '{}',
  p_image_url           TEXT DEFAULT NULL,
  p_is_available        BOOLEAN DEFAULT true,
  p_max_stack           INT DEFAULT 99,
  p_delete              BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_new_id  UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_threads
    WHERE id = p_thread_id
      AND (host_id = v_user_id::text OR co_hosts @> to_jsonb(v_user_id::text))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_host');
  END IF;

  IF p_delete AND p_item_id IS NOT NULL THEN
    DELETE FROM public.chat_rpg_items
    WHERE id = p_item_id AND thread_id = p_thread_id;
    RETURN jsonb_build_object('success', true, 'action', 'deleted');
  END IF;

  IF p_item_id IS NULL THEN
    INSERT INTO public.chat_rpg_items
      (thread_id, name, description, item_type, rarity, price,
       attribute_modifiers, image_url, is_available, max_stack)
    VALUES
      (p_thread_id, p_name, p_description, p_item_type, p_rarity, p_price,
       p_attribute_modifiers, p_image_url, p_is_available, p_max_stack)
    RETURNING id INTO v_new_id;
    RETURN jsonb_build_object('success', true, 'action', 'created', 'id', v_new_id);
  ELSE
    UPDATE public.chat_rpg_items SET
      name                = COALESCE(p_name,                name),
      description         = COALESCE(p_description,         description),
      item_type           = COALESCE(p_item_type,           item_type),
      rarity              = COALESCE(p_rarity,              rarity),
      price               = COALESCE(p_price,               price),
      attribute_modifiers = COALESCE(p_attribute_modifiers, attribute_modifiers),
      image_url           = COALESCE(p_image_url,           image_url),
      is_available        = COALESCE(p_is_available,        is_available),
      max_stack           = COALESCE(p_max_stack,           max_stack)
    WHERE id = p_item_id AND thread_id = p_thread_id;
    RETURN jsonb_build_object('success', true, 'action', 'updated');
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.manage_chat_rpg_item TO authenticated;

-- ── 8.5. Criar/Atualizar Ficha de Personagem (membro) ────────────────────────
CREATE OR REPLACE FUNCTION public.create_or_update_chat_rpg_character(
  p_thread_id  UUID,
  p_name       TEXT,
  p_class_id   UUID DEFAULT NULL,
  p_avatar_url TEXT DEFAULT NULL,
  p_bio        TEXT DEFAULT NULL,
  p_attributes JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_char_id    UUID;
  v_exists     BOOLEAN;
  v_rpg_active BOOLEAN;
  v_start_curr INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT rpg_mode_enabled INTO v_rpg_active
  FROM public.chat_threads WHERE id = p_thread_id;

  IF NOT v_rpg_active THEN
    RETURN jsonb_build_object('success', false, 'error', 'rpg_not_enabled');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE thread_id = p_thread_id AND user_id = v_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_member');
  END IF;

  IF p_class_id IS NOT NULL THEN
    SELECT starting_currency INTO v_start_curr
    FROM public.chat_rpg_classes
    WHERE id = p_class_id AND thread_id = p_thread_id AND is_active = true;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.chat_rpg_characters
    WHERE thread_id = p_thread_id AND user_id = v_user_id
  ) INTO v_exists;

  IF NOT v_exists THEN
    INSERT INTO public.chat_rpg_characters
      (thread_id, user_id, class_id, name, avatar_url, bio,
       attributes, currency_balance)
    VALUES
      (p_thread_id, v_user_id, p_class_id, p_name, p_avatar_url, p_bio,
       p_attributes, v_start_curr)
    RETURNING id INTO v_char_id;

    INSERT INTO public.chat_rpg_event_log
      (thread_id, character_id, actor_id, event_type, description)
    VALUES
      (p_thread_id, v_char_id, v_user_id, 'character_created',
       'Personagem "' || p_name || '" criado.');

    RETURN jsonb_build_object('success', true, 'action', 'created', 'character_id', v_char_id);
  ELSE
    UPDATE public.chat_rpg_characters SET
      name       = COALESCE(p_name,       name),
      class_id   = COALESCE(p_class_id,   class_id),
      avatar_url = COALESCE(p_avatar_url, avatar_url),
      bio        = COALESCE(p_bio,        bio),
      attributes = COALESCE(p_attributes, attributes),
      updated_at = now()
    WHERE thread_id = p_thread_id AND user_id = v_user_id
    RETURNING id INTO v_char_id;

    RETURN jsonb_build_object('success', true, 'action', 'updated', 'character_id', v_char_id);
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_or_update_chat_rpg_character TO authenticated;

-- ── 8.6. Conceder XP e Moeda (host/co-host only) ─────────────────────────────
CREATE OR REPLACE FUNCTION public.award_chat_rpg_resources(
  p_thread_id      UUID,
  p_target_user_id UUID,
  p_xp_delta       INT DEFAULT 0,
  p_currency_delta INT DEFAULT 0,
  p_reason         TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_actor_id   UUID := auth.uid();
  v_char_id    UUID;
  v_new_xp     INT;
  v_new_level  INT;
  v_new_curr   INT;
  v_multiplier NUMERIC;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_threads
    WHERE id = p_thread_id
      AND (host_id = v_actor_id::text OR co_hosts @> to_jsonb(v_actor_id::text))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_host');
  END IF;

  SELECT rpg_xp_multiplier INTO v_multiplier
  FROM public.chat_threads WHERE id = p_thread_id;

  p_xp_delta := ROUND(p_xp_delta * v_multiplier)::INT;

  UPDATE public.chat_rpg_characters SET
    xp               = GREATEST(0, xp + p_xp_delta),
    currency_balance = GREATEST(0, currency_balance + p_currency_delta),
    updated_at       = now()
  WHERE thread_id = p_thread_id AND user_id = p_target_user_id
  RETURNING id, xp, currency_balance INTO v_char_id, v_new_xp, v_new_curr;

  IF v_char_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'character_not_found');
  END IF;

  -- Nível: floor(sqrt(xp / 100)) + 1
  v_new_level := FLOOR(SQRT(v_new_xp::NUMERIC / 100.0))::INT + 1;

  UPDATE public.chat_rpg_characters SET level = v_new_level
  WHERE id = v_char_id AND level != v_new_level;

  INSERT INTO public.chat_rpg_event_log
    (thread_id, character_id, actor_id, event_type, description,
     xp_delta, currency_delta)
  VALUES
    (p_thread_id, v_char_id, v_actor_id, 'resource_award',
     COALESCE(p_reason, 'Recursos concedidos pelo host.'),
     p_xp_delta, p_currency_delta);

  RETURN jsonb_build_object(
    'success', true,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'new_currency', v_new_curr
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.award_chat_rpg_resources TO authenticated;

-- ── 8.7. Comprar item na loja (membro) ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.buy_chat_rpg_item(
  p_thread_id UUID,
  p_item_id   UUID,
  p_quantity  INT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_char_id    UUID;
  v_balance    INT;
  v_item_price INT;
  v_item_name  TEXT;
  v_max_stack  INT;
  v_total_cost INT;
  v_inv_qty    INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT id, currency_balance INTO v_char_id, v_balance
  FROM public.chat_rpg_characters
  WHERE thread_id = p_thread_id AND user_id = v_user_id;

  IF v_char_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_character');
  END IF;

  SELECT name, price, max_stack INTO v_item_name, v_item_price, v_max_stack
  FROM public.chat_rpg_items
  WHERE id = p_item_id AND thread_id = p_thread_id AND is_available = true;

  IF v_item_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'item_not_found');
  END IF;

  v_total_cost := v_item_price * p_quantity;

  IF v_balance < v_total_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_funds',
      'balance', v_balance, 'cost', v_total_cost);
  END IF;

  SELECT quantity INTO v_inv_qty FROM public.chat_rpg_inventory
  WHERE character_id = v_char_id AND item_id = p_item_id;

  IF COALESCE(v_inv_qty, 0) + p_quantity > v_max_stack THEN
    RETURN jsonb_build_object('success', false, 'error', 'stack_full');
  END IF;

  UPDATE public.chat_rpg_characters SET
    currency_balance = currency_balance - v_total_cost,
    updated_at = now()
  WHERE id = v_char_id;

  INSERT INTO public.chat_rpg_inventory (character_id, item_id, quantity)
  VALUES (v_char_id, p_item_id, p_quantity)
  ON CONFLICT (character_id, item_id)
  DO UPDATE SET quantity = chat_rpg_inventory.quantity + EXCLUDED.quantity;

  INSERT INTO public.chat_rpg_event_log
    (thread_id, character_id, actor_id, event_type, description, currency_delta)
  VALUES
    (p_thread_id, v_char_id, v_user_id, 'item_purchased',
     'Comprou ' || p_quantity || 'x "' || v_item_name || '".',
     -v_total_cost);

  RETURN jsonb_build_object('success', true, 'spent', v_total_cost);
END;
$$;
GRANT EXECUTE ON FUNCTION public.buy_chat_rpg_item TO authenticated;

-- ── 8.8. Obter ficha completa do personagem ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_chat_rpg_character(
  p_thread_id UUID,
  p_user_id   UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := COALESCE(p_user_id, auth.uid());
  v_char    JSONB;
  v_class   JSONB;
  v_inv     JSONB;
  v_thread  JSONB;
BEGIN
  SELECT to_jsonb(c) INTO v_char FROM public.chat_rpg_characters c
  WHERE c.thread_id = p_thread_id AND c.user_id = v_user_id;

  IF v_char IS NULL THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT to_jsonb(cl) INTO v_class FROM public.chat_rpg_classes cl
  WHERE cl.id = (v_char->>'class_id')::UUID;

  SELECT jsonb_agg(
    jsonb_build_object(
      'inventory_id', inv.id,
      'quantity', inv.quantity,
      'is_equipped', inv.is_equipped,
      'item', to_jsonb(it)
    )
  ) INTO v_inv
  FROM public.chat_rpg_inventory inv
  JOIN public.chat_rpg_items it ON it.id = inv.item_id
  WHERE inv.character_id = (v_char->>'id')::UUID;

  SELECT jsonb_build_object(
    'rpg_currency_name', rpg_currency_name,
    'rpg_currency_icon', rpg_currency_icon,
    'rpg_xp_multiplier', rpg_xp_multiplier
  ) INTO v_thread
  FROM public.chat_threads WHERE id = p_thread_id;

  RETURN jsonb_build_object(
    'found', true,
    'character', v_char,
    'class', v_class,
    'inventory', COALESCE(v_inv, '[]'::JSONB),
    'thread_config', v_thread
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_chat_rpg_character TO authenticated;

-- ── 8.9. Ranking RPG do chat ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_chat_rpg_ranking(
  p_thread_id UUID,
  p_limit     INT DEFAULT 20
)
RETURNS TABLE (
  rank           BIGINT,
  user_id        UUID,
  character_name TEXT,
  level          INT,
  xp             INT,
  class_name     TEXT,
  class_color    TEXT,
  avatar_url     TEXT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY c.level DESC, c.xp DESC) AS rank,
    c.user_id,
    c.name  AS character_name,
    c.level,
    c.xp,
    cl.name AS class_name,
    cl.color AS class_color,
    c.avatar_url
  FROM public.chat_rpg_characters c
  LEFT JOIN public.chat_rpg_classes cl ON cl.id = c.class_id
  WHERE c.thread_id = p_thread_id
    AND c.char_status = 'alive'
  ORDER BY c.level DESC, c.xp DESC
  LIMIT p_limit;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_chat_rpg_ranking TO authenticated;

-- ── 8.10. Equipar/desequipar item ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_equip_chat_rpg_item(
  p_thread_id UUID,
  p_item_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_char_id  UUID;
  v_equipped BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT id INTO v_char_id FROM public.chat_rpg_characters
  WHERE thread_id = p_thread_id AND user_id = v_user_id;

  IF v_char_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_character');
  END IF;

  SELECT is_equipped INTO v_equipped FROM public.chat_rpg_inventory
  WHERE character_id = v_char_id AND item_id = p_item_id;

  IF v_equipped IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'item_not_in_inventory');
  END IF;

  UPDATE public.chat_rpg_inventory SET is_equipped = NOT v_equipped
  WHERE character_id = v_char_id AND item_id = p_item_id;

  RETURN jsonb_build_object('success', true, 'equipped', NOT v_equipped);
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_equip_chat_rpg_item TO authenticated;
