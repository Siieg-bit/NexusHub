-- ============================================================================
-- Migração 078: Nine-Slice Bubble Assets
-- 
-- Atualiza o asset_config dos chat_bubbles na loja para incluir:
-- - bubble_url: URL real da imagem PNG no Supabase Storage
-- - image_width / image_height: dimensões reais do PNG (128×128)
-- - slice_left/top/right/bottom: pontos de corte nine-slice (38px cada lado)
-- - content_padding_h/v: padding interno do conteúdo
-- - bubble_style: 'nine_slice' (identifica que deve usar NineSliceBubble)
--
-- O bucket 'store-assets' foi criado como público no Supabase Storage.
-- A imagem heart_bubble_frame.png foi uploadada em:
-- store-assets/bubbles/heart_bubble_frame.png
-- ============================================================================

-- Heart Bubble: frame decorativo com corações nos cantos
UPDATE public.store_items
SET asset_config = '{
  "color": "#E040FB",
  "image_url": "https://ylvzqqvcanzzswjkqeya.supabase.co/storage/v1/object/public/store-assets/bubbles/heart_bubble_frame.png",
  "slice_top": 38,
  "bubble_url": "https://ylvzqqvcanzzswjkqeya.supabase.co/storage/v1/object/public/store-assets/bubbles/heart_bubble_frame.png",
  "slice_left": 38,
  "image_width": 128,
  "slice_right": 38,
  "bubble_color": "#E040FB",
  "bubble_style": "nine_slice",
  "image_height": 128,
  "slice_bottom": 38,
  "content_padding_h": 20,
  "content_padding_v": 14
}'::jsonb
WHERE id = 'c3333333-3333-3333-3333-333333333334';

-- Glow Bubble: mesmo frame com tint azul ciano
UPDATE public.store_items
SET asset_config = '{
  "color": "#00B4D8",
  "image_url": "https://ylvzqqvcanzzswjkqeya.supabase.co/storage/v1/object/public/store-assets/bubbles/heart_bubble_frame.png",
  "slice_top": 38,
  "bubble_url": "https://ylvzqqvcanzzswjkqeya.supabase.co/storage/v1/object/public/store-assets/bubbles/heart_bubble_frame.png",
  "slice_left": 38,
  "tint_color": "#00BCD4",
  "image_width": 128,
  "slice_right": 38,
  "bubble_color": "#00B4D8",
  "bubble_style": "nine_slice",
  "image_height": 128,
  "slice_bottom": 38,
  "content_padding_h": 20,
  "content_padding_v": 14
}'::jsonb
WHERE id = 'c3333333-3333-3333-3333-333333333333';
