-- Migration 165: System Announcements (Anúncios Globais do Sistema)
-- Permite que a equipe da plataforma crie anúncios globais exibidos no feed.

CREATE TABLE IF NOT EXISTS public.system_announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  image_url   TEXT,
  cta_text    TEXT,
  cta_url     TEXT,
  status      TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'expired')),
  publish_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expire_at   TIMESTAMPTZ,
  created_by  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice para buscar anúncios ativos
CREATE INDEX IF NOT EXISTS idx_system_announcements_active
  ON public.system_announcements (status, publish_at, expire_at);

-- RLS
ALTER TABLE public.system_announcements ENABLE ROW LEVEL SECURITY;

-- Qualquer usuário autenticado pode ler anúncios ativos
CREATE POLICY "system_announcements_read" ON public.system_announcements
  FOR SELECT TO authenticated
  USING (
    status = 'active'
    AND publish_at <= now()
    AND (expire_at IS NULL OR expire_at > now())
  );

-- Apenas platform_admin pode criar/editar
CREATE POLICY "system_announcements_admin_write" ON public.system_announcements
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_team_admin = TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_team_admin = TRUE
    )
  );

-- RPC: buscar anúncios ativos
CREATE OR REPLACE FUNCTION public.get_active_system_announcements()
RETURNS TABLE (
  id          UUID,
  title       TEXT,
  body        TEXT,
  image_url   TEXT,
  cta_text    TEXT,
  cta_url     TEXT,
  publish_at  TIMESTAMPTZ,
  expire_at   TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, title, body, image_url, cta_text, cta_url, publish_at, expire_at
  FROM public.system_announcements
  WHERE status = 'active'
    AND publish_at <= now()
    AND (expire_at IS NULL OR expire_at > now())
  ORDER BY publish_at DESC
  LIMIT 5;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_system_announcements() TO authenticated;
