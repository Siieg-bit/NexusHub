-- ============================================================
-- NexusHub — Migração 009: Storage Buckets e Realtime
-- ============================================================

-- ========================
-- STORAGE BUCKETS
-- ========================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES
  ('avatars', 'avatars', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('banners', 'banners', TRUE, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('community-icons', 'community-icons', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('community-banners', 'community-banners', TRUE, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('post-media', 'post-media', TRUE, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm']),
  ('wiki-media', 'wiki-media', TRUE, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('chat-media', 'chat-media', TRUE, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'audio/mpeg', 'audio/ogg', 'audio/webm']),
  ('stickers', 'stickers', TRUE, 2097152, ARRAY['image/png', 'image/webp', 'image/gif']),
  ('avatar-frames', 'avatar-frames', TRUE, 5242880, ARRAY['image/png', 'image/webp', 'image/gif']),
  ('chat-bubbles', 'chat-bubbles', TRUE, 2097152, ARRAY['image/png', 'image/webp', 'image/svg+xml']),
  ('shared-files', 'shared-files', TRUE, 104857600, NULL),
  ('voice-notes', 'voice-notes', FALSE, 10485760, ARRAY['audio/mpeg', 'audio/ogg', 'audio/webm', 'audio/mp4'])
ON CONFLICT (id) DO NOTHING;

-- ========================
-- STORAGE POLICIES
-- ========================

-- Avatars: qualquer autenticado pode fazer upload do próprio
CREATE POLICY "avatars_select_public" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "avatars_insert_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "avatars_update_own" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "avatars_delete_own" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Banners: mesma lógica
CREATE POLICY "banners_select_public" ON storage.objects
  FOR SELECT USING (bucket_id = 'banners');

CREATE POLICY "banners_insert_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'banners'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "banners_update_own" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'banners'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Community icons/banners: apenas agent/leader pode alterar
CREATE POLICY "community_icons_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'community-icons');

CREATE POLICY "community_icons_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'community-icons'
    AND auth.uid() IS NOT NULL
  );

CREATE POLICY "community_banners_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'community-banners');

CREATE POLICY "community_banners_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'community-banners'
    AND auth.uid() IS NOT NULL
  );

-- Post media: autenticados podem fazer upload
CREATE POLICY "post_media_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'post-media');

CREATE POLICY "post_media_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'post-media'
    AND auth.uid() IS NOT NULL
  );

-- Wiki media
CREATE POLICY "wiki_media_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'wiki-media');

CREATE POLICY "wiki_media_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'wiki-media'
    AND auth.uid() IS NOT NULL
  );

-- Chat media
CREATE POLICY "chat_media_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'chat-media');

CREATE POLICY "chat_media_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'chat-media'
    AND auth.uid() IS NOT NULL
  );

-- Stickers, frames, bubbles: público para leitura
CREATE POLICY "stickers_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'stickers');

CREATE POLICY "frames_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatar-frames');

CREATE POLICY "bubbles_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'chat-bubbles');

-- Shared files
CREATE POLICY "shared_files_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'shared-files');

CREATE POLICY "shared_files_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'shared-files'
    AND auth.uid() IS NOT NULL
  );

-- Voice notes: privado
CREATE POLICY "voice_notes_select" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'voice-notes'
    AND auth.uid() IS NOT NULL
  );

CREATE POLICY "voice_notes_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'voice-notes'
    AND auth.uid() IS NOT NULL
  );

-- ========================
-- REALTIME: Habilitar para tabelas que precisam de tempo real
-- ========================

ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_members;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.community_members;
