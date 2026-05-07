-- ============================================================
-- NexusHub — Migração 234: Shared Folder — Sistema de Aprovação
--
-- Problema: o Flutter usa colunas e RPCs que não existem no schema:
--   • shared_folders.requires_approval  (booleano)
--   • shared_files.approval_status      (text: 'approved'|'pending'|'rejected')
--   • RPC submit_shared_file(...)
--   • RPC get_pending_shared_files(...)
--   • RPC review_shared_file(...)
-- ============================================================

-- ── 1. Adicionar coluna requires_approval em shared_folders ──────────────
ALTER TABLE public.shared_folders
  ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN NOT NULL DEFAULT FALSE;

-- ── 2. Adicionar coluna approval_status em shared_files ──────────────────
--    Valores: 'approved' | 'pending' | 'rejected'
--    Arquivos existentes (criados antes desta migração) ficam 'approved'
--    para não sumir da UI.
ALTER TABLE public.shared_files
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved'
  CHECK (approval_status IN ('approved', 'pending', 'rejected'));

CREATE INDEX IF NOT EXISTS idx_shared_files_approval
  ON public.shared_files(folder_id, approval_status);

-- ── 3. RPC: submit_shared_file ───────────────────────────────────────────
--    Insere um arquivo na pasta compartilhada.
--    Se a pasta exige aprovação, o status inicial é 'pending'; caso
--    contrário, 'approved'.
--    Retorna o registro criado (incluindo approval_status).
CREATE OR REPLACE FUNCTION public.submit_shared_file(
  p_folder_id     UUID,
  p_file_url      TEXT,
  p_file_name     TEXT,
  p_file_type     TEXT,
  p_file_size     INTEGER,
  p_thumbnail_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_requires_appr  BOOLEAN;
  v_initial_status TEXT;
  v_community_id   UUID;
  v_is_member      BOOLEAN;
  v_new_file       JSONB;
BEGIN
  -- Verificar autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Buscar community_id e requires_approval da pasta
  SELECT sf.community_id, sf.requires_approval
  INTO v_community_id, v_requires_appr
  FROM public.shared_folders sf
  WHERE sf.id = p_folder_id;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'folder_not_found';
  END IF;

  -- Verificar se o usuário é membro da comunidade
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = v_community_id
      AND user_id = v_user_id
      AND status = 'active'
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;

  -- Determinar status inicial
  v_initial_status := CASE WHEN v_requires_appr THEN 'pending' ELSE 'approved' END;

  -- Inserir arquivo
  INSERT INTO public.shared_files (
    folder_id,
    uploader_id,
    file_url,
    file_name,
    file_type,
    file_size,
    thumbnail_url,
    approval_status
  )
  VALUES (
    p_folder_id,
    v_user_id,
    p_file_url,
    p_file_name,
    p_file_type,
    p_file_size,
    p_thumbnail_url,
    v_initial_status
  )
  RETURNING to_jsonb(shared_files.*) INTO v_new_file;

  RETURN v_new_file;
END;
$$;

-- ── 4. RPC: get_pending_shared_files ─────────────────────────────────────
--    Retorna arquivos pendentes de aprovação de uma comunidade.
--    Apenas líderes, co-líderes, curadores, moderadores, agents e admins
--    podem chamar esta função.
CREATE OR REPLACE FUNCTION public.get_pending_shared_files(
  p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_role     TEXT;
  v_result   JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Verificar role do usuário
  SELECT role INTO v_role
  FROM public.community_members
  WHERE community_id = p_community_id
    AND user_id = v_user_id;

  IF v_role NOT IN ('admin', 'agent', 'leader', 'co_leader', 'curator', 'moderator') THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      sf.*,
      jsonb_build_object(
        'nickname', p.nickname,
        'icon_url',  p.icon_url
      ) AS profiles
    FROM public.shared_files sf
    JOIN public.shared_folders folder ON folder.id = sf.folder_id
    JOIN public.profiles p ON p.id = sf.uploader_id
    WHERE folder.community_id = p_community_id
      AND sf.approval_status = 'pending'
    ORDER BY sf.created_at ASC
  ) t;

  RETURN v_result;
END;
$$;

-- ── 5. RPC: review_shared_file ───────────────────────────────────────────
--    Aprova ou rejeita um arquivo pendente.
--    Apenas staff da comunidade pode executar.
CREATE OR REPLACE FUNCTION public.review_shared_file(
  p_file_id UUID,
  p_action  TEXT,          -- 'approve' | 'reject'
  p_reason  TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_role         TEXT;
  v_community_id UUID;
  v_new_status   TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'invalid_action: must be approve or reject';
  END IF;

  -- Buscar community_id do arquivo
  SELECT folder.community_id
  INTO v_community_id
  FROM public.shared_files sf
  JOIN public.shared_folders folder ON folder.id = sf.folder_id
  WHERE sf.id = p_file_id;

  IF v_community_id IS NULL THEN
    RAISE EXCEPTION 'file_not_found';
  END IF;

  -- Verificar role
  SELECT role INTO v_role
  FROM public.community_members
  WHERE community_id = v_community_id
    AND user_id = v_user_id;

  IF v_role NOT IN ('admin', 'agent', 'leader', 'co_leader', 'curator', 'moderator') THEN
    RAISE EXCEPTION 'insufficient_permissions';
  END IF;

  v_new_status := CASE WHEN p_action = 'approve' THEN 'approved' ELSE 'rejected' END;

  UPDATE public.shared_files
  SET approval_status = v_new_status
  WHERE id = p_file_id;
END;
$$;

-- ── 6. Permissões ─────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.submit_shared_file TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_shared_files TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_shared_file TO authenticated;
