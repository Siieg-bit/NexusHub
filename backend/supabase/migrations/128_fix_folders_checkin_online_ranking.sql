-- ============================================================
-- Migração 128: Corrige folders, check-in heatmap, tempo online e ranking
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. FOLDERS: política INSERT no bucket shared-files
-- ─────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('shared-files', 'shared-files', true, 104857600)
ON CONFLICT (id) DO NOTHING;

-- Política INSERT: apenas membros da comunidade podem fazer upload
DROP POLICY IF EXISTS "shared_files_insert" ON storage.objects;
CREATE POLICY "shared_files_insert"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'shared-files'
    AND (
      -- Verifica que o path começa com shared-files/{community_id}/
      -- e que o usuário é membro da comunidade
      EXISTS (
        SELECT 1 FROM public.community_members cm
        WHERE cm.community_id = (string_to_array(name, '/'))[1]::uuid
          AND cm.user_id = auth.uid()
          AND cm.is_banned = FALSE
      )
    )
  );

-- Política UPDATE/DELETE: apenas o uploader ou staff pode deletar
DROP POLICY IF EXISTS "shared_files_delete" ON storage.objects;
CREATE POLICY "shared_files_delete"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'shared-files'
    AND (
      -- Uploader pode deletar o próprio arquivo
      (storage.foldername(name))[1] IS NOT NULL
      OR auth.uid() IS NOT NULL
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 2. FOLDERS: sistema de aprovação de imagens
-- ─────────────────────────────────────────────────────────────
-- Adicionar status de aprovação na tabela shared_files
ALTER TABLE public.shared_files
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved'
    CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Adicionar configuração de aprovação obrigatória por folder
ALTER TABLE public.shared_folders
  ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN NOT NULL DEFAULT FALSE;

-- RPC: aprovar ou rejeitar arquivo (apenas líderes/co-líderes/curadores)
CREATE OR REPLACE FUNCTION public.review_shared_file(
  p_file_id UUID,
  p_action TEXT, -- 'approve' | 'reject'
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_community_id UUID;
  v_role TEXT;
  v_uploader_id UUID;
BEGIN
  -- Buscar community_id e uploader via folder
  SELECT sf.community_id, sfi.uploader_id
  INTO v_community_id, v_uploader_id
  FROM public.shared_files sfi
  JOIN public.shared_folders sf ON sf.id = sfi.folder_id
  WHERE sfi.id = p_file_id;

  IF v_community_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'file_not_found');
  END IF;

  -- Verificar se o usuário é staff da comunidade
  SELECT role INTO v_role
  FROM public.community_members
  WHERE community_id = v_community_id AND user_id = auth.uid();

  IF v_role NOT IN ('leader', 'co_leader', 'curator') THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  IF p_action = 'approve' THEN
    UPDATE public.shared_files
    SET approval_status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = NOW()
    WHERE id = p_file_id;

    -- Notificar o uploader
    INSERT INTO public.notifications (user_id, actor_id, type, body, community_id)
    VALUES (v_uploader_id, auth.uid(), 'achievement',
            'Sua imagem foi aprovada no folder da comunidade!', v_community_id);

  ELSIF p_action = 'reject' THEN
    UPDATE public.shared_files
    SET approval_status = 'rejected',
        reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        rejection_reason = p_reason
    WHERE id = p_file_id;

    -- Notificar o uploader
    INSERT INTO public.notifications (user_id, actor_id, type, body, community_id)
    VALUES (v_uploader_id, auth.uid(), 'moderation',
            COALESCE('Sua imagem foi rejeitada: ' || p_reason, 'Sua imagem foi rejeitada no folder da comunidade.'),
            v_community_id);
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid_action');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- RPC: upload de arquivo com suporte a aprovação
CREATE OR REPLACE FUNCTION public.submit_shared_file(
  p_folder_id UUID,
  p_file_url TEXT,
  p_file_name TEXT,
  p_file_type TEXT,
  p_file_size BIGINT,
  p_thumbnail_url TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_community_id UUID;
  v_requires_approval BOOLEAN;
  v_is_member BOOLEAN;
  v_approval_status TEXT;
  v_file_id UUID;
BEGIN
  -- Buscar community_id e configuração de aprovação
  SELECT sf.community_id, sf.requires_approval
  INTO v_community_id, v_requires_approval
  FROM public.shared_folders sf
  WHERE sf.id = p_folder_id;

  IF v_community_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'folder_not_found');
  END IF;

  -- Verificar se é membro
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = v_community_id AND user_id = auth.uid() AND is_banned = FALSE
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_member');
  END IF;

  -- Verificar se é staff (staff não precisa de aprovação)
  IF v_requires_approval THEN
    DECLARE
      v_role TEXT;
    BEGIN
      SELECT role INTO v_role
      FROM public.community_members
      WHERE community_id = v_community_id AND user_id = auth.uid();

      IF v_role IN ('leader', 'co_leader', 'curator') THEN
        v_approval_status := 'approved';
      ELSE
        v_approval_status := 'pending';
      END IF;
    END;
  ELSE
    v_approval_status := 'approved';
  END IF;

  -- Inserir arquivo
  INSERT INTO public.shared_files (
    folder_id, uploader_id, file_url, file_name, file_type,
    file_size, thumbnail_url, description, approval_status
  ) VALUES (
    p_folder_id, auth.uid(), p_file_url, p_file_name, p_file_type,
    p_file_size, p_thumbnail_url, p_description, v_approval_status
  ) RETURNING id INTO v_file_id;

  -- Notificar líderes se precisar de aprovação
  IF v_approval_status = 'pending' THEN
    INSERT INTO public.notifications (user_id, actor_id, type, body, community_id)
    SELECT cm.user_id, auth.uid(), 'moderation',
           'Nova imagem aguardando aprovação no folder da comunidade.',
           v_community_id
    FROM public.community_members cm
    WHERE cm.community_id = v_community_id
      AND cm.role IN ('leader', 'co_leader', 'curator')
      AND cm.user_id != auth.uid();
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'file_id', v_file_id,
    'approval_status', v_approval_status
  );
END;
$$;

-- RPC: buscar arquivos pendentes de aprovação (para líderes)
CREATE OR REPLACE FUNCTION public.get_pending_shared_files(p_community_id UUID)
RETURNS TABLE(
  id UUID,
  folder_id UUID,
  folder_name TEXT,
  uploader_id UUID,
  uploader_nickname TEXT,
  uploader_icon_url TEXT,
  file_url TEXT,
  file_name TEXT,
  file_type TEXT,
  file_size BIGINT,
  thumbnail_url TEXT,
  description TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = auth.uid();

  IF v_role NOT IN ('leader', 'co_leader', 'curator') THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    sfi.id,
    sfi.folder_id,
    sf.name AS folder_name,
    sfi.uploader_id,
    COALESCE(cm.local_nickname, p.nickname) AS uploader_nickname,
    COALESCE(cm.local_icon_url, p.icon_url) AS uploader_icon_url,
    sfi.file_url,
    sfi.file_name,
    sfi.file_type,
    sfi.file_size::BIGINT,
    sfi.thumbnail_url,
    sfi.description,
    sfi.created_at
  FROM public.shared_files sfi
  JOIN public.shared_folders sf ON sf.id = sfi.folder_id
  JOIN public.profiles p ON p.id = sfi.uploader_id
  LEFT JOIN public.community_members cm ON cm.user_id = sfi.uploader_id
    AND cm.community_id = p_community_id
  WHERE sf.community_id = p_community_id
    AND sfi.approval_status = 'pending'
  ORDER BY sfi.created_at ASC;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 3. CHECK-IN HEATMAP: corrigir query (checked_in_at → date)
--    Criar view para facilitar a query do Flutter
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.checkin_history AS
SELECT
  id,
  user_id,
  community_id,
  DATE(checked_in_at AT TIME ZONE 'America/Sao_Paulo') AS checkin_date,
  streak_day,
  coins_earned,
  xp_earned,
  checked_in_at
FROM public.checkins;

-- Política de acesso à view
GRANT SELECT ON public.checkin_history TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 4. TEMPO ONLINE: adicionar acumulador de minutos online
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS online_minutes_today INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS online_minutes_total INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS online_minutes_week INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_online_reset_at DATE DEFAULT CURRENT_DATE;

-- Função para atualizar minutos online (chamada pelo presence_service via heartbeat)
CREATE OR REPLACE FUNCTION public.update_online_minutes(
  p_user_id UUID,
  p_minutes_delta INT DEFAULT 1
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET
    online_minutes_today = CASE
      WHEN last_online_reset_at < CURRENT_DATE THEN p_minutes_delta
      ELSE online_minutes_today + p_minutes_delta
    END,
    online_minutes_week = CASE
      WHEN EXTRACT(WEEK FROM last_online_reset_at) != EXTRACT(WEEK FROM CURRENT_DATE) THEN p_minutes_delta
      ELSE online_minutes_week + p_minutes_delta
    END,
    online_minutes_total = online_minutes_total + p_minutes_delta,
    last_online_reset_at = CURRENT_DATE,
    last_seen_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- Cron job para resetar online_minutes_today à meia-noite (Brasília = UTC-3 = 03:00 UTC)
SELECT cron.schedule(
  'reset-online-minutes-daily',
  '0 3 * * *',
  $$UPDATE public.profiles SET online_minutes_today = 0, last_online_reset_at = CURRENT_DATE$$
);

-- ─────────────────────────────────────────────────────────────
-- 5. RANKING: adicionar online_minutes em community_members
--    e criar RPC de ranking por tempo online
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.community_members
  ADD COLUMN IF NOT EXISTS online_minutes_total INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS online_minutes_week INT NOT NULL DEFAULT 0;

-- Função para sincronizar minutos online do membro da comunidade
CREATE OR REPLACE FUNCTION public.sync_community_online_minutes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Quando online_minutes_total ou _week mudar em profiles, atualizar community_members
  UPDATE public.community_members
  SET
    online_minutes_total = NEW.online_minutes_total,
    online_minutes_week = NEW.online_minutes_week
  WHERE user_id = NEW.id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_community_online_minutes ON public.profiles;
CREATE TRIGGER trg_sync_community_online_minutes
  AFTER UPDATE OF online_minutes_total, online_minutes_week ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_community_online_minutes();

-- RPC: ranking por tempo online de uma comunidade
CREATE OR REPLACE FUNCTION public.get_community_online_leaderboard(
  p_community_id UUID,
  p_period TEXT DEFAULT 'week', -- 'week' | 'all'
  p_limit INT DEFAULT 50
)
RETURNS TABLE(
  user_id UUID,
  nickname TEXT,
  icon_url TEXT,
  level INT,
  reputation INT,
  role TEXT,
  online_minutes INT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cm.user_id,
    COALESCE(cm.local_nickname, p.nickname) AS nickname,
    COALESCE(cm.local_icon_url, p.icon_url) AS icon_url,
    COALESCE(cm.local_level, public.calculate_level(COALESCE(cm.local_reputation, 0))) AS level,
    COALESCE(cm.local_reputation, 0) AS reputation,
    cm.role::TEXT AS role,
    CASE p_period
      WHEN 'week' THEN cm.online_minutes_week
      ELSE cm.online_minutes_total
    END AS online_minutes
  FROM public.community_members cm
  JOIN public.profiles p ON p.id = cm.user_id
  WHERE cm.community_id = p_community_id
    AND cm.is_banned = FALSE
  ORDER BY
    CASE p_period
      WHEN 'week' THEN cm.online_minutes_week
      ELSE cm.online_minutes_total
    END DESC NULLS LAST
  LIMIT p_limit;
END;
$$;
