-- ============================================================
-- Migration 180: Bucket screening-videos para vídeos locais
--
-- Permite que o host da sala de projeção faça upload de vídeos
-- locais do dispositivo. O vídeo é armazenado temporariamente
-- durante a sessão e pode ser removido após o encerramento.
--
-- Estrutura de caminho: {sessionId}/{userId}/{timestamp}.{ext}
-- Limite: 500 MB por arquivo
-- Tipos: mp4, mov, avi, mkv, webm, m4v
-- ============================================================

-- 1. CRIAR BUCKET
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'screening-videos',
  'screening-videos',
  true,
  524288000, -- 500 MB
  ARRAY[
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska',
    'video/webm',
    'video/x-m4v',
    'video/mpeg',
    'video/ogg'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- 2. POLÍTICA DE LEITURA (qualquer um pode ler — bucket público)
CREATE POLICY "screening_videos_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'screening-videos');

-- 3. POLÍTICA DE UPLOAD (apenas usuários autenticados podem fazer upload)
CREATE POLICY "screening_videos_auth_upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'screening-videos'
    -- O caminho deve começar com um sessionId válido (UUID)
    AND (storage.foldername(name))[1] IS NOT NULL
  );

-- 4. POLÍTICA DE DELEÇÃO (apenas o próprio usuário pode deletar seus arquivos)
-- Caminho: {sessionId}/{userId}/{timestamp}.{ext}
-- O userId é o segundo segmento do caminho
CREATE POLICY "screening_videos_owner_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'screening-videos'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );
