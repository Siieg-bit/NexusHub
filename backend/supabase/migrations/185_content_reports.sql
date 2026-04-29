-- =============================================================================
-- Migration 185: Sistema de reports de conteúdo
--
-- Cria a tabela `content_reports` e o RPC `report_content` para que usuários
-- possam reportar comunidades, posts, perfis e mensagens.
-- =============================================================================

-- ── Tabela ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.content_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content_type  TEXT NOT NULL CHECK (content_type IN ('community', 'post', 'profile', 'message', 'comment')),
  content_id    TEXT NOT NULL,
  reason        TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed', 'actioned')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at   TIMESTAMPTZ,
  reviewed_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes         TEXT
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_content_reports_reporter   ON public.content_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_content    ON public.content_reports(content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_status     ON public.content_reports(status);
CREATE INDEX IF NOT EXISTS idx_content_reports_created_at ON public.content_reports(created_at DESC);

-- Constraint: um usuário só pode reportar o mesmo conteúdo uma vez
CREATE UNIQUE INDEX IF NOT EXISTS idx_content_reports_unique
  ON public.content_reports(reporter_id, content_type, content_id);

-- ── RLS ───────────────────────────────────────────────────────────────────────
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

-- Usuário só vê seus próprios reports
CREATE POLICY "reports_select_own"
  ON public.content_reports FOR SELECT
  USING (reporter_id = auth.uid());

-- Sem INSERT/UPDATE/DELETE direto — tudo via RPC
CREATE POLICY "reports_no_direct_write"
  ON public.content_reports FOR INSERT
  WITH CHECK (false);

-- ── RPC report_content ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.report_content(
  p_content_type TEXT,
  p_content_id   TEXT,
  p_reason       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reporter UUID := auth.uid();
  v_report_id UUID;
BEGIN
  -- Validações
  IF v_reporter IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_content_type NOT IN ('community', 'post', 'profile', 'message', 'comment') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_content_type');
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason_required');
  END IF;

  -- Não pode reportar a si mesmo (para perfis)
  IF p_content_type = 'profile' AND p_content_id = v_reporter::TEXT THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_report_self');
  END IF;

  -- Upsert: se já reportou, atualiza o motivo
  INSERT INTO public.content_reports (
    reporter_id, content_type, content_id, reason
  ) VALUES (
    v_reporter, p_content_type, p_content_id, trim(p_reason)
  )
  ON CONFLICT (reporter_id, content_type, content_id)
  DO UPDATE SET
    reason     = EXCLUDED.reason,
    status     = 'pending',
    created_at = now()
  RETURNING id INTO v_report_id;

  RETURN jsonb_build_object('success', true, 'report_id', v_report_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.report_content(TEXT, TEXT, TEXT) TO authenticated;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
