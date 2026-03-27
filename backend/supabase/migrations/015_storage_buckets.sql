-- ============================================================
-- Migration 015: Supabase Storage Buckets + Políticas RLS
-- ============================================================
-- Cria os 5 buckets necessários para o NexusHub:
--   1. avatars         — fotos de perfil dos usuários
--   2. community_icons — ícones e capas das comunidades
--   3. post_media      — imagens/vídeos anexados a posts
--   4. chat_media      — imagens/vídeos/áudio enviados no chat
--   5. wiki_media      — imagens das wiki entries
-- ============================================================

-- 1. CRIAR BUCKETS (públicos para leitura, autenticados para escrita)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars', 'avatars', true, 5242880, -- 5MB
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('community_icons', 'community_icons', true, 10485760, -- 10MB
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('post_media', 'post_media', true, 52428800, -- 50MB
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm']),
  ('chat_media', 'chat_media', true, 26214400, -- 25MB
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'audio/mpeg', 'audio/ogg', 'audio/webm', 'application/pdf']),
  ('wiki_media', 'wiki_media', true, 10485760, -- 10MB
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 2. POLÍTICAS DE LEITURA (qualquer um pode ler — buckets públicos)
-- ============================================================

-- AVATARS: leitura pública
CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

-- COMMUNITY_ICONS: leitura pública
CREATE POLICY "community_icons_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'community_icons');

-- POST_MEDIA: leitura pública
CREATE POLICY "post_media_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'post_media');

-- CHAT_MEDIA: leitura pública
CREATE POLICY "chat_media_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'chat_media');

-- WIKI_MEDIA: leitura pública
CREATE POLICY "wiki_media_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'wiki_media');

-- ============================================================
-- 3. POLÍTICAS DE ESCRITA (apenas usuários autenticados)
-- ============================================================

-- AVATARS: usuário só pode fazer upload na sua própria pasta
CREATE POLICY "avatars_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- AVATARS: usuário só pode atualizar seus próprios arquivos
CREATE POLICY "avatars_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- AVATARS: usuário só pode deletar seus próprios arquivos
CREATE POLICY "avatars_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- COMMUNITY_ICONS: qualquer membro autenticado pode fazer upload
-- (a validação de role Agent/Admin é feita no Flutter)
CREATE POLICY "community_icons_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'community_icons'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "community_icons_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'community_icons'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "community_icons_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'community_icons'
    AND auth.role() = 'authenticated'
  );

-- POST_MEDIA: qualquer autenticado pode fazer upload
CREATE POLICY "post_media_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'post_media'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "post_media_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'post_media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "post_media_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'post_media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- CHAT_MEDIA: qualquer autenticado pode fazer upload
CREATE POLICY "chat_media_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'chat_media'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "chat_media_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'chat_media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "chat_media_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'chat_media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- WIKI_MEDIA: qualquer autenticado pode fazer upload
CREATE POLICY "wiki_media_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'wiki_media'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "wiki_media_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'wiki_media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "wiki_media_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'wiki_media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
