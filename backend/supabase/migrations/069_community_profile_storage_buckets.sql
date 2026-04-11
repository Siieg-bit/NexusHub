-- ============================================================
-- Migration 069: Buckets de Storage para Perfil de Comunidade
--
-- Problema: Banner, background e galeria do perfil de comunidade
-- eram enviados para o bucket 'avatars' com paths customizados.
-- Isso é semanticamente incorreto e pode conflitar com políticas
-- futuras do bucket de avatares.
--
-- Solução: Criar buckets dedicados para cada tipo de mídia do
-- perfil de comunidade:
--   - community-profile-banners  (banner local do usuário)
--   - community-profile-backgrounds (plano de fundo local)
--   - community-profile-gallery  (galeria de fotos local)
--
-- O avatar local continua no bucket 'avatars' (correto).
-- ============================================================

-- ============================================================
-- 1. CRIAR BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('community-profile-banners', 'community-profile-banners', true, 5242880, -- 5MB
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('community-profile-backgrounds', 'community-profile-backgrounds', true, 10485760, -- 10MB
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('community-profile-gallery', 'community-profile-gallery', true, 5242880, -- 5MB
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 2. POLÍTICAS DE LEITURA (qualquer um pode ler — buckets públicos)
-- ============================================================
CREATE POLICY "community_profile_banners_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'community-profile-banners');

CREATE POLICY "community_profile_backgrounds_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'community-profile-backgrounds');

CREATE POLICY "community_profile_gallery_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'community-profile-gallery');

-- ============================================================
-- 3. POLÍTICAS DE ESCRITA (usuário só escreve na própria pasta)
-- O path segue o padrão: userId/communityId/timestamp.jpg
-- O primeiro segmento é sempre o userId do usuário autenticado.
-- ============================================================

-- COMMUNITY-PROFILE-BANNERS
CREATE POLICY "community_profile_banners_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'community-profile-banners'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "community_profile_banners_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'community-profile-banners'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "community_profile_banners_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'community-profile-banners'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- COMMUNITY-PROFILE-BACKGROUNDS
CREATE POLICY "community_profile_backgrounds_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'community-profile-backgrounds'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "community_profile_backgrounds_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'community-profile-backgrounds'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "community_profile_backgrounds_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'community-profile-backgrounds'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- COMMUNITY-PROFILE-GALLERY
CREATE POLICY "community_profile_gallery_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'community-profile-gallery'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "community_profile_gallery_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'community-profile-gallery'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "community_profile_gallery_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'community-profile-gallery'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
