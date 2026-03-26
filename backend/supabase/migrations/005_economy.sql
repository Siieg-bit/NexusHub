-- ============================================================
-- NexusHub — Migração 005: Economia, Loja e Gamificação
-- Baseado em Wallet.smali, TippingInfo.smali, LotteryLog.smali
-- ============================================================

-- ========================
-- 1. TRANSAÇÕES DE MOEDAS (coin_transactions)
-- ========================

CREATE TABLE public.coin_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Valores
  amount INTEGER NOT NULL,                         -- Positivo = ganho, Negativo = gasto
  balance_after INTEGER NOT NULL,                  -- Saldo após transação
  
  -- Origem/Destino
  source TEXT NOT NULL,                            -- 'checkin', 'lucky_draw', 'iap', 'ad_reward', 'tip_received', 'purchase', 'tip_sent', 'streak_repair'
  reference_id UUID,                               -- ID do item/post/compra relacionado
  description TEXT DEFAULT '',
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_coin_tx_user ON public.coin_transactions(user_id);
CREATE INDEX idx_coin_tx_created ON public.coin_transactions(created_at DESC);

-- ========================
-- 2. ITENS DA LOJA (store_items)
-- ========================

CREATE TABLE public.store_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Tipo e identificação
  type public.store_item_type NOT NULL,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  preview_url TEXT,                                -- Imagem de preview
  
  -- Assets
  asset_url TEXT,                                  -- URL do recurso real (frame, bubble, etc)
  asset_config JSONB DEFAULT '{}'::jsonb,          -- Configurações específicas do tipo
  
  -- Preço
  price_coins INTEGER DEFAULT 0,
  price_real_cents INTEGER,                        -- Preço em centavos (para IAP direto)
  
  -- Restrições
  is_premium_only BOOLEAN DEFAULT FALSE,
  is_limited_edition BOOLEAN DEFAULT FALSE,
  available_until TIMESTAMPTZ,
  max_purchases INTEGER,                           -- NULL = ilimitado
  current_purchases INTEGER DEFAULT 0,
  
  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_store_items_type ON public.store_items(type);
CREATE INDEX idx_store_items_active ON public.store_items(is_active) WHERE is_active = TRUE;

-- ========================
-- 3. COMPRAS DO USUÁRIO (user_purchases)
-- ========================

CREATE TABLE public.user_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.store_items(id) ON DELETE CASCADE,
  
  -- Detalhes da compra
  price_paid INTEGER NOT NULL,                     -- Coins pagos
  
  -- Status de uso
  is_equipped BOOLEAN DEFAULT FALSE,               -- Se está ativo/equipado
  equipped_in_community UUID REFERENCES public.communities(id),  -- NULL = global
  
  -- Metadata
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ                           -- NULL = permanente
);

CREATE INDEX idx_purchases_user ON public.user_purchases(user_id);
CREATE INDEX idx_purchases_equipped ON public.user_purchases(is_equipped) WHERE is_equipped = TRUE;

-- ========================
-- 4. AVATAR FRAMES (molduras de perfil)
-- ========================

CREATE TABLE public.avatar_frames (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  
  -- Assets
  frame_url TEXT NOT NULL,                         -- URL da imagem da moldura
  frame_config JSONB DEFAULT '{}'::jsonb,          -- {size, offset, animation}
  is_animated BOOLEAN DEFAULT FALSE,
  
  -- Preço
  price_coins INTEGER DEFAULT 0,
  is_premium_only BOOLEAN DEFAULT FALSE,
  
  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 5. STICKER PACKS (pacotes de stickers)
-- ========================

CREATE TABLE public.sticker_packs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  icon_url TEXT,
  author_name TEXT DEFAULT 'NexusHub',
  
  -- Preço
  price_coins INTEGER DEFAULT 0,
  is_free BOOLEAN DEFAULT FALSE,
  is_premium_only BOOLEAN DEFAULT FALSE,
  
  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.stickers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_id UUID NOT NULL REFERENCES public.sticker_packs(id) ON DELETE CASCADE,
  name TEXT DEFAULT '',
  image_url TEXT NOT NULL,
  is_animated BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 6. PROPS / GORJETAS (tips)
-- ========================

CREATE TABLE public.tips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Valor
  amount INTEGER NOT NULL CHECK (amount > 0),
  
  -- Contexto
  post_id UUID REFERENCES public.posts(id),
  chat_message_id UUID REFERENCES public.chat_messages(id),
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tips_sender ON public.tips(sender_id);
CREATE INDEX idx_tips_receiver ON public.tips(receiver_id);

-- ========================
-- 7. CHECK-IN E LUCKY DRAW (checkins / lottery)
-- ========================

CREATE TABLE public.checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,  -- NULL = global
  
  -- Recompensa base
  coins_earned INTEGER DEFAULT 0,
  xp_earned INTEGER DEFAULT 0,
  
  -- Streak
  streak_day INTEGER DEFAULT 1,                    -- Dia atual da ofensiva
  
  -- Metadata
  checked_in_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_checkins_user ON public.checkins(user_id);
CREATE INDEX idx_checkins_date ON public.checkins(checked_in_at DESC);

CREATE TABLE public.lottery_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  checkin_id UUID REFERENCES public.checkins(id),
  
  -- Resultado (LotteryLog.smali)
  award_type public.lottery_award_type NOT NULL,   -- none, coin, product
  coins_won INTEGER DEFAULT 0,
  product_id UUID REFERENCES public.store_items(id),
  
  -- Metadata
  played_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 8. STREAK REPAIR (reparo de ofensiva)
-- ========================

CREATE TABLE public.streak_repairs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Detalhes
  broken_days INTEGER NOT NULL,                    -- Quantos dias perdeu
  cost_coins INTEGER NOT NULL,                     -- Custo do reparo
  
  -- Metadata
  repaired_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 9. IAP RECEIPTS (comprovantes de compra real)
-- ========================

CREATE TABLE public.iap_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Plataforma
  platform TEXT NOT NULL,                          -- 'ios', 'android'
  store_product_id TEXT NOT NULL,                   -- ID do produto na loja
  transaction_id TEXT UNIQUE NOT NULL,              -- ID da transação na loja
  
  -- Validação
  receipt_data TEXT,                                -- Receipt criptografado
  is_validated BOOLEAN DEFAULT FALSE,
  validated_at TIMESTAMPTZ,
  
  -- Detalhes
  amount_cents INTEGER,                            -- Valor em centavos
  currency TEXT DEFAULT 'BRL',
  coins_credited INTEGER DEFAULT 0,                -- Moedas creditadas
  is_subscription BOOLEAN DEFAULT FALSE,           -- Se é Amino+/NexusHub+
  subscription_expires_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_iap_user ON public.iap_receipts(user_id);
CREATE INDEX idx_iap_transaction ON public.iap_receipts(transaction_id);

-- ========================
-- 10. AD REWARD LOGS (recompensas por anúncios)
-- ========================

CREATE TABLE public.ad_reward_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Detalhes
  ad_network TEXT NOT NULL,                        -- 'applovin', 'vungle', etc
  ad_unit_id TEXT,
  coins_earned INTEGER NOT NULL,
  
  -- Anti-fraude
  device_id TEXT,
  ip_address INET,
  
  -- Metadata
  watched_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ad_rewards_user ON public.ad_reward_logs(user_id);
