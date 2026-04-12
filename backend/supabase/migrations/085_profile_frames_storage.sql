-- ============================================================
-- NexusHub — Migração 085: Storage para Molduras de Perfil
-- Garante que o bucket store-assets aceita uploads na pasta
-- frames/ com as mesmas políticas já existentes para bubbles/
-- ============================================================

-- O bucket store-assets já existe (criado na migration 015).
-- Esta migration apenas garante que as políticas de storage
-- cubram o path frames/ da mesma forma que cobrem bubbles/.

-- ── Política: leitura pública de frames ──────────────────────
-- Permite que qualquer usuário (inclusive anônimo) leia
-- os assets de molduras publicados na loja.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'store_assets_frames_public_read'
  ) THEN
    CREATE POLICY store_assets_frames_public_read
      ON storage.objects FOR SELECT
      USING (bucket_id = 'store-assets' AND (storage.foldername(name))[1] = 'frames');
  END IF;
END $$;

-- ── Política: upload de frames apenas para membros da equipe ─
-- Apenas usuários com is_team_admin = true ou
-- is_team_moderator = true podem fazer upload de molduras.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'store_assets_frames_team_upload'
  ) THEN
    CREATE POLICY store_assets_frames_team_upload
      ON storage.objects FOR INSERT
      WITH CHECK (
        bucket_id = 'store-assets'
        AND (storage.foldername(name))[1] = 'frames'
        AND EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid()
            AND (is_team_admin = true OR is_team_moderator = true)
        )
      );
  END IF;
END $$;

-- ── Política: deleção de frames apenas para membros da equipe ─
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'store_assets_frames_team_delete'
  ) THEN
    CREATE POLICY store_assets_frames_team_delete
      ON storage.objects FOR DELETE
      USING (
        bucket_id = 'store-assets'
        AND (storage.foldername(name))[1] = 'frames'
        AND EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid()
            AND (is_team_admin = true OR is_team_moderator = true)
        )
      );
  END IF;
END $$;

-- ── Índice auxiliar para consultas de molduras na loja ────────
-- Melhora performance de queries .eq('type', 'avatar_frame')
-- (o índice idx_store_items_type já cobre isso, mas documentamos aqui)
-- CREATE INDEX IF NOT EXISTS idx_store_items_avatar_frame
--   ON public.store_items(created_at DESC)
--   WHERE type = 'avatar_frame';

COMMENT ON TABLE public.store_items IS
  'Itens da loja NexusHub. Tipos suportados: avatar_frame, chat_bubble, sticker_pack, profile_background, chat_background. '
  'Para avatar_frame, asset_config deve conter: frame_url, image_url, rarity, frame_style, image_width, image_height. '
  'Para chat_bubble, asset_config deve conter: bubble_url, image_url, bubble_style, nine-slice params (slice_top/left/right/bottom), image_width, image_height, content_padding_h/v, rarity.';
