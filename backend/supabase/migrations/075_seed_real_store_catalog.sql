-- ============================================================
-- NexusHub — Migração 075: Catálogo real inicial da loja
-- Produtos funcionais e idempotentes para frames, bubbles,
-- fundos globais e packs de stickers integrados.
-- ============================================================

-- -----------------------------------------------------------------------------
-- 1. Sticker packs oficiais da loja
-- -----------------------------------------------------------------------------
INSERT INTO public.sticker_packs (
  id,
  name,
  description,
  icon_url,
  cover_url,
  author_name,
  price_coins,
  is_free,
  is_premium_only,
  is_active,
  sort_order,
  is_user_created,
  is_public,
  tags,
  sticker_count
)
VALUES
  (
    'a1111111-1111-1111-1111-111111111111',
    'Neon Reactions',
    'Pack oficial com reações vibrantes e rápidas para chats e comentários.',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2728.png',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f389.png',
    'NexusHub',
    240,
    FALSE,
    FALSE,
    TRUE,
    10,
    FALSE,
    TRUE,
    ARRAY['official', 'reaction', 'neon'],
    4
  ),
  (
    'b2222222-2222-2222-2222-222222222222',
    'Cute Chaos',
    'Pack oficial com energia divertida para comunidades, DMs e fandoms.',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f63a.png',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f49c.png',
    'NexusHub',
    260,
    FALSE,
    FALSE,
    TRUE,
    20,
    FALSE,
    TRUE,
    ARRAY['official', 'cute', 'fandom'],
    4
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon_url = EXCLUDED.icon_url,
  cover_url = EXCLUDED.cover_url,
  author_name = EXCLUDED.author_name,
  price_coins = EXCLUDED.price_coins,
  is_free = EXCLUDED.is_free,
  is_premium_only = EXCLUDED.is_premium_only,
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order,
  is_user_created = EXCLUDED.is_user_created,
  is_public = EXCLUDED.is_public,
  tags = EXCLUDED.tags,
  sticker_count = EXCLUDED.sticker_count;

-- -----------------------------------------------------------------------------
-- 2. Stickers oficiais dos packs acima
-- -----------------------------------------------------------------------------
INSERT INTO public.stickers (
  id,
  pack_id,
  name,
  image_url,
  is_animated,
  sort_order
)
VALUES
  ('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'a1111111-1111-1111-1111-111111111111', 'Party Pop', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f389.png', FALSE, 10),
  ('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'a1111111-1111-1111-1111-111111111111', 'Sparkle Burst', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2728.png', FALSE, 20),
  ('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaa3', 'a1111111-1111-1111-1111-111111111111', 'Fire Mood', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f525.png', FALSE, 30),
  ('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaa4', 'a1111111-1111-1111-1111-111111111111', 'Star Power', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2b50.png', FALSE, 40),
  ('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'b2222222-2222-2222-2222-222222222222', 'Purple Heart', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f49c.png', FALSE, 10),
  ('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'b2222222-2222-2222-2222-222222222222', 'Blue Heart', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f499.png', FALSE, 20),
  ('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbb3', 'b2222222-2222-2222-2222-222222222222', 'Robot Hype', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f916.png', FALSE, 30),
  ('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbb4', 'b2222222-2222-2222-2222-222222222222', 'Cat Energy', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f63a.png', FALSE, 40)
ON CONFLICT (id) DO UPDATE SET
  pack_id = EXCLUDED.pack_id,
  name = EXCLUDED.name,
  image_url = EXCLUDED.image_url,
  is_animated = EXCLUDED.is_animated,
  sort_order = EXCLUDED.sort_order;

-- -----------------------------------------------------------------------------
-- 3. Catálogo real da loja (store_items)
-- -----------------------------------------------------------------------------
INSERT INTO public.store_items (
  id,
  type,
  name,
  description,
  preview_url,
  asset_url,
  asset_config,
  price_coins,
  is_premium_only,
  is_limited_edition,
  available_until,
  max_purchases,
  current_purchases,
  is_active,
  sort_order
)
VALUES
  (
    'c3333333-3333-3333-3333-333333333331',
    'avatar_frame',
    'Spark Frame',
    'Frame global com brilho neon para destacar sua identidade no perfil.',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2728.png',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2728.png',
    jsonb_build_object(
      'frame_url', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2728.png',
      'image_url', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2728.png',
      'effect', 'sparkle',
      'rarity', 'rare'
    ),
    180,
    FALSE,
    FALSE,
    NULL,
    NULL,
    0,
    TRUE,
    10
  ),
  (
    'c3333333-3333-3333-3333-333333333332',
    'avatar_frame',
    'Flame Frame',
    'Frame global energético para perfis com presença forte e visual marcante.',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f525.png',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f525.png',
    jsonb_build_object(
      'frame_url', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f525.png',
      'image_url', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f525.png',
      'effect', 'fire',
      'rarity', 'epic'
    ),
    220,
    FALSE,
    TRUE,
    NULL,
    500,
    0,
    TRUE,
    20
  ),
  (
    'c3333333-3333-3333-3333-333333333333',
    'chat_bubble',
    'Glow Bubble',
    'Bolha de chat com brilho suave para conversas globais e comunidades.',
    'https://images.unsplash.com/photo-1519608487953-e999c86e7455?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1519608487953-e999c86e7455?auto=format&fit=crop&w=800&q=80',
    jsonb_build_object(
      'style', 'gradient',
      'bubble_style', 'gradient',
      'color', '#00B4D8',
      'bubble_color', '#00B4D8',
      'image_url', 'https://images.unsplash.com/photo-1519608487953-e999c86e7455?auto=format&fit=crop&w=800&q=80'
    ),
    140,
    FALSE,
    FALSE,
    NULL,
    NULL,
    0,
    TRUE,
    30
  ),
  (
    'c3333333-3333-3333-3333-333333333334',
    'chat_bubble',
    'Heart Bubble',
    'Bolha estilizada com foco em fandom, amizade e conversas leves.',
    'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=800&q=80',
    jsonb_build_object(
      'style', 'hearts',
      'bubble_style', 'hearts',
      'color', '#E040FB',
      'bubble_color', '#E040FB',
      'image_url', 'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=800&q=80'
    ),
    160,
    FALSE,
    FALSE,
    NULL,
    NULL,
    0,
    TRUE,
    40
  ),
  (
    'c3333333-3333-3333-3333-333333333335',
    'profile_background',
    'Aurora Night',
    'Fundo global com atmosfera neon para perfis com pegada sci-fi.',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    jsonb_build_object(
      'image_url', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
      'rarity', 'rare'
    ),
    260,
    FALSE,
    FALSE,
    NULL,
    NULL,
    0,
    TRUE,
    50
  ),
  (
    'c3333333-3333-3333-3333-333333333336',
    'profile_background',
    'Galaxy Pulse',
    'Fundo global com visual energético para perfis premium e fandom hubs.',
    'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?auto=format&fit=crop&w=1200&q=80',
    jsonb_build_object(
      'image_url', 'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?auto=format&fit=crop&w=1200&q=80',
      'rarity', 'epic'
    ),
    320,
    FALSE,
    TRUE,
    NULL,
    300,
    0,
    TRUE,
    60
  ),
  (
    'c3333333-3333-3333-3333-333333333337',
    'sticker_pack',
    'Neon Reactions Pack',
    'Pack oficial com stickers prontos para uso em chats, replies e momentos rápidos.',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f389.png',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f389.png',
    jsonb_build_object(
      'pack_id', 'a1111111-1111-1111-1111-111111111111',
      'cover_url', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f389.png',
      'sticker_count', 4,
      'tags', jsonb_build_array('official', 'reaction', 'neon')
    ),
    240,
    FALSE,
    FALSE,
    NULL,
    NULL,
    0,
    TRUE,
    70
  ),
  (
    'c3333333-3333-3333-3333-333333333338',
    'sticker_pack',
    'Cute Chaos Pack',
    'Pack oficial com stickers carismáticos para comunidades criativas e fandoms.',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f63a.png',
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f63a.png',
    jsonb_build_object(
      'pack_id', 'b2222222-2222-2222-2222-222222222222',
      'cover_url', 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f63a.png',
      'sticker_count', 4,
      'tags', jsonb_build_array('official', 'cute', 'fandom')
    ),
    260,
    FALSE,
    FALSE,
    NULL,
    NULL,
    0,
    TRUE,
    80
  )
ON CONFLICT (id) DO UPDATE SET
  type = EXCLUDED.type,
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  preview_url = EXCLUDED.preview_url,
  asset_url = EXCLUDED.asset_url,
  asset_config = EXCLUDED.asset_config,
  price_coins = EXCLUDED.price_coins,
  is_premium_only = EXCLUDED.is_premium_only,
  is_limited_edition = EXCLUDED.is_limited_edition,
  available_until = EXCLUDED.available_until,
  max_purchases = EXCLUDED.max_purchases,
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order;

-- -----------------------------------------------------------------------------
-- 4. Sincronizar contagem derivada dos packs seeded
-- -----------------------------------------------------------------------------
UPDATE public.sticker_packs sp
SET sticker_count = src.cnt
FROM (
  SELECT pack_id, COUNT(*)::INTEGER AS cnt
  FROM public.stickers
  WHERE pack_id IN (
    'a1111111-1111-1111-1111-111111111111'::UUID,
    'b2222222-2222-2222-2222-222222222222'::UUID
  )
  GROUP BY pack_id
) src
WHERE sp.id = src.pack_id;
