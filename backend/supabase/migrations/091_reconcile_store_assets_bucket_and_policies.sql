-- ============================================================
-- NexusHub — Migração 091: Reconciliação do bucket store-assets
-- Versiona no repositório o bucket e as políticas que já existiam
-- no Supabase remoto, mas ainda não estavam representadas nas
-- migrations locais.
-- ============================================================

-- 1. Garantir o bucket store-assets
INSERT INTO storage.buckets (id, name, public)
VALUES ('store-assets', 'store-assets', true)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public;

-- 2. Garantir leitura pública dos assets da loja
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'store_assets_public_read'
  ) THEN
    CREATE POLICY "store_assets_public_read"
      ON storage.objects
      FOR SELECT
      TO public
      USING (bucket_id = 'store-assets');
  END IF;
END $$;

-- 3. Garantir escrita apenas para membros da equipe NexusHub
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'store_assets_team_insert'
  ) THEN
    CREATE POLICY "store_assets_team_insert"
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'store-assets'
        AND public.is_team_member()
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'store_assets_team_update'
  ) THEN
    CREATE POLICY "store_assets_team_update"
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'store-assets'
        AND public.is_team_member()
      )
      WITH CHECK (
        bucket_id = 'store-assets'
        AND public.is_team_member()
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'store_assets_team_delete'
  ) THEN
    CREATE POLICY "store_assets_team_delete"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'store-assets'
        AND public.is_team_member()
      );
  END IF;
END $$;
