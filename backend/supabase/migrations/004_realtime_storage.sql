-- ============================================================================
-- AMINO CLONE - MIGRATION 004: REALTIME & STORAGE
-- Configuração de canais Realtime e buckets de Storage
-- ============================================================================

-- ============================================================================
-- REALTIME: Habilitar publicação em tabelas críticas
-- ============================================================================

-- Habilitar Realtime nas tabelas que precisam de atualizações em tempo real
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.comments;

-- ============================================================================
-- STORAGE: Criar buckets para armazenamento de mídia
-- ============================================================================

-- Bucket para avatares de usuários
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    TRUE,
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
);

-- Bucket para banners de perfil e comunidade
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'banners',
    'banners',
    TRUE,
    10485760, -- 10MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- Bucket para mídia de posts (imagens, vídeos)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'post-media',
    'post-media',
    TRUE,
    52428800, -- 50MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm']
);

-- Bucket para mídia de chat (imagens, áudio)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-media',
    'chat-media',
    TRUE,
    20971520, -- 20MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'audio/mpeg', 'audio/ogg', 'video/mp4']
);

-- Bucket para ícones de comunidades
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'community-icons',
    'community-icons',
    TRUE,
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- ============================================================================
-- STORAGE POLICIES: Avatares
-- ============================================================================

CREATE POLICY "Avatares são públicos para leitura"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "Usuários podem fazer upload de avatar"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY "Usuários podem atualizar seu avatar"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'avatars'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY "Usuários podem deletar seu avatar"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'avatars'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

-- ============================================================================
-- STORAGE POLICIES: Banners
-- ============================================================================

CREATE POLICY "Banners são públicos para leitura"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'banners');

CREATE POLICY "Usuários autenticados podem fazer upload de banners"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'banners'
        AND auth.role() = 'authenticated'
    );

CREATE POLICY "Usuários podem atualizar seus banners"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'banners'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

-- ============================================================================
-- STORAGE POLICIES: Post Media
-- ============================================================================

CREATE POLICY "Post media é pública para leitura"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'post-media');

CREATE POLICY "Usuários autenticados podem fazer upload de post media"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'post-media'
        AND auth.role() = 'authenticated'
    );

CREATE POLICY "Usuários podem deletar sua post media"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'post-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

-- ============================================================================
-- STORAGE POLICIES: Chat Media
-- ============================================================================

CREATE POLICY "Chat media é acessível para autenticados"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'chat-media'
        AND auth.role() = 'authenticated'
    );

CREATE POLICY "Usuários autenticados podem enviar chat media"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'chat-media'
        AND auth.role() = 'authenticated'
    );

-- ============================================================================
-- STORAGE POLICIES: Community Icons
-- ============================================================================

CREATE POLICY "Community icons são públicos para leitura"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'community-icons');

CREATE POLICY "Usuários autenticados podem fazer upload de community icons"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'community-icons'
        AND auth.role() = 'authenticated'
    );
