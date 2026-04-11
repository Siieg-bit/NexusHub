-- ============================================================
-- Migration 070: Sistema Completo de Comunidades
--
-- Implementa:
-- 1. Campos de banners múltiplos e personalizáveis por contexto
-- 2. Descrição e regras configuráveis
-- 3. Cor predominante aplicada em mais contextos
-- 4. Sistema de tags/títulos customizados para membros
-- 5. Promote/Demote com RPC completa
-- 6. Fixar posts na comunidade com limite
-- 7. Sistema de ban/advertência com histórico melhorado
-- ============================================================

-- ============================================================
-- 1. BANNERS MÚLTIPLOS NA TABELA communities
-- Cada contexto de exibição tem seu próprio banner
-- ============================================================
ALTER TABLE public.communities
  -- Banner principal (header da tela de detalhe)
  ADD COLUMN IF NOT EXISTS banner_header_url    TEXT,
  -- Banner do drawer lateral
  ADD COLUMN IF NOT EXISTS banner_drawer_url    TEXT,
  -- Banner da lista de comunidades (card)
  ADD COLUMN IF NOT EXISTS banner_card_url      TEXT,
  -- Banner da tela de info/sobre
  ADD COLUMN IF NOT EXISTS banner_info_url      TEXT,
  -- Cor de fundo alternativa (gradiente)
  ADD COLUMN IF NOT EXISTS theme_gradient_end   TEXT,
  -- Modo de exibição da cor predominante
  ADD COLUMN IF NOT EXISTS theme_apply_mode     TEXT DEFAULT 'accent',
  -- Regras da comunidade (separado das guidelines)
  ADD COLUMN IF NOT EXISTS rules                TEXT DEFAULT '',
  -- Descrição expandida (além do tagline)
  ADD COLUMN IF NOT EXISTS about_text           TEXT DEFAULT '',
  -- Tags de categoria da comunidade
  ADD COLUMN IF NOT EXISTS community_tags       TEXT[] DEFAULT '{}',
  -- Número máximo de posts fixados
  ADD COLUMN IF NOT EXISTS max_pinned_posts     INTEGER DEFAULT 5;

COMMENT ON COLUMN public.communities.banner_header_url IS
  'Banner exibido no header da tela de detalhe da comunidade';
COMMENT ON COLUMN public.communities.banner_drawer_url IS
  'Banner exibido no drawer lateral da comunidade';
COMMENT ON COLUMN public.communities.banner_card_url IS
  'Banner exibido no card da lista de comunidades';
COMMENT ON COLUMN public.communities.banner_info_url IS
  'Banner exibido na tela de informações/sobre da comunidade';
COMMENT ON COLUMN public.communities.theme_gradient_end IS
  'Cor final do gradiente do tema (opcional)';
COMMENT ON COLUMN public.communities.theme_apply_mode IS
  'Como a cor predominante é aplicada: accent, full, gradient';
COMMENT ON COLUMN public.communities.rules IS
  'Regras da comunidade em formato Markdown';
COMMENT ON COLUMN public.communities.about_text IS
  'Texto de descrição expandida da comunidade';
COMMENT ON COLUMN public.communities.community_tags IS
  'Array de tags/categorias da comunidade';
COMMENT ON COLUMN public.communities.max_pinned_posts IS
  'Número máximo de posts que podem ser fixados simultaneamente';

-- ============================================================
-- 2. TABELA DE TÍTULOS/TAGS DE MEMBROS
-- Títulos customizados que líderes podem dar a membros
-- ============================================================
CREATE TABLE IF NOT EXISTS public.member_titles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  issued_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Título
  title TEXT NOT NULL,
  color TEXT DEFAULT '#FFFFFF',
  icon TEXT,                        -- Emoji ou nome do ícone
  
  -- Visibilidade
  is_visible BOOLEAN DEFAULT TRUE,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(community_id, user_id, title)
);

CREATE INDEX IF NOT EXISTS idx_member_titles_community ON public.member_titles(community_id);
CREATE INDEX IF NOT EXISTS idx_member_titles_user ON public.member_titles(user_id);

COMMENT ON TABLE public.member_titles IS
  'Títulos/tags customizados dados por líderes a membros da comunidade';

-- ============================================================
-- 3. TABELA DE HISTÓRICO DE PROMOÇÕES/DEMISSÕES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.role_changes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  changed_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  old_role public.user_role NOT NULL,
  new_role public.user_role NOT NULL,
  reason TEXT DEFAULT '',
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_role_changes_community ON public.role_changes(community_id);
CREATE INDEX IF NOT EXISTS idx_role_changes_user ON public.role_changes(user_id);

-- ============================================================
-- 4. MELHORIAS NA TABELA community_members
-- ============================================================
ALTER TABLE public.community_members
  ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_silenced BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS silenced_until TIMESTAMPTZ;

-- ============================================================
-- 5. RPC: Atualizar configurações completas da comunidade
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_community_settings(
  p_community_id          UUID,
  p_name                  TEXT     DEFAULT NULL,
  p_tagline               TEXT     DEFAULT NULL,
  p_description           TEXT     DEFAULT NULL,
  p_about_text            TEXT     DEFAULT NULL,
  p_rules                 TEXT     DEFAULT NULL,
  p_icon_url              TEXT     DEFAULT NULL,
  p_banner_url            TEXT     DEFAULT NULL,
  p_banner_header_url     TEXT     DEFAULT NULL,
  p_banner_drawer_url     TEXT     DEFAULT NULL,
  p_banner_card_url       TEXT     DEFAULT NULL,
  p_banner_info_url       TEXT     DEFAULT NULL,
  p_theme_color           TEXT     DEFAULT NULL,
  p_theme_gradient_end    TEXT     DEFAULT NULL,
  p_theme_apply_mode      TEXT     DEFAULT NULL,
  p_join_type             TEXT     DEFAULT NULL,
  p_listed_status         TEXT     DEFAULT NULL,
  p_is_searchable         BOOLEAN  DEFAULT NULL,
  p_primary_language      TEXT     DEFAULT NULL,
  p_category              TEXT     DEFAULT NULL,
  p_community_tags        TEXT[]   DEFAULT NULL,
  p_configuration         JSONB    DEFAULT NULL,
  p_home_layout           JSONB    DEFAULT NULL,
  p_welcome_message       TEXT     DEFAULT NULL,
  p_max_pinned_posts      INTEGER  DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Verificar se o usuário é agent ou leader da comunidade
  SELECT role INTO v_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_role NOT IN ('agent', 'leader') THEN
    -- Verificar se é admin global
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_team_admin = TRUE
    ) THEN
      RETURN jsonb_build_object('error', 'insufficient_permissions');
    END IF;
  END IF;

  UPDATE public.communities SET
    name                = COALESCE(p_name, name),
    tagline             = COALESCE(p_tagline, tagline),
    description         = COALESCE(p_description, description),
    about_text          = COALESCE(p_about_text, about_text),
    rules               = COALESCE(p_rules, rules),
    icon_url            = COALESCE(p_icon_url, icon_url),
    banner_url          = COALESCE(p_banner_url, banner_url),
    banner_header_url   = COALESCE(p_banner_header_url, banner_header_url),
    banner_drawer_url   = COALESCE(p_banner_drawer_url, banner_drawer_url),
    banner_card_url     = COALESCE(p_banner_card_url, banner_card_url),
    banner_info_url     = COALESCE(p_banner_info_url, banner_info_url),
    theme_color         = COALESCE(p_theme_color, theme_color),
    theme_gradient_end  = COALESCE(p_theme_gradient_end, theme_gradient_end),
    theme_apply_mode    = COALESCE(p_theme_apply_mode, theme_apply_mode),
    join_type           = COALESCE(p_join_type::public.community_join_type, join_type),
    listed_status       = COALESCE(p_listed_status::public.community_listed_status, listed_status),
    is_searchable       = COALESCE(p_is_searchable, is_searchable),
    primary_language    = COALESCE(p_primary_language, primary_language),
    category            = COALESCE(p_category, category),
    community_tags      = COALESCE(p_community_tags, community_tags),
    configuration       = COALESCE(p_configuration, configuration),
    home_layout         = COALESCE(p_home_layout, home_layout),
    welcome_message     = COALESCE(p_welcome_message, welcome_message),
    max_pinned_posts    = COALESCE(p_max_pinned_posts, max_pinned_posts),
    updated_at          = NOW()
  WHERE id = p_community_id;

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_community_settings TO authenticated;

-- ============================================================
-- 6. RPC: Promover/Demitir membro
-- ============================================================
CREATE OR REPLACE FUNCTION public.change_member_role(
  p_community_id  UUID,
  p_target_user_id UUID,
  p_new_role      TEXT,
  p_reason        TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_my_role      TEXT;
  v_target_role  TEXT;
  v_old_role     public.user_role;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Buscar role do moderador
  SELECT role INTO v_my_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  -- Buscar role atual do alvo
  SELECT role INTO v_target_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = p_target_user_id;

  IF v_target_role IS NULL THEN
    RETURN jsonb_build_object('error', 'user_not_member');
  END IF;

  -- Regras de hierarquia:
  -- Agent pode promover/demitir qualquer um
  -- Leader pode promover para curator, demitir curators
  -- Curator não pode mudar roles
  IF v_my_role = 'agent' THEN
    -- Agent pode fazer tudo exceto remover outro agent
    IF v_target_role = 'agent' THEN
      RETURN jsonb_build_object('error', 'cannot_change_agent_role');
    END IF;
  ELSIF v_my_role = 'leader' THEN
    -- Leader pode promover para curator ou demitir curators
    IF v_target_role IN ('agent', 'leader') THEN
      RETURN jsonb_build_object('error', 'insufficient_permissions');
    END IF;
    IF p_new_role NOT IN ('curator', 'member') THEN
      RETURN jsonb_build_object('error', 'leaders_can_only_manage_curators');
    END IF;
  ELSE
    -- Verificar se é admin global
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_team_admin = TRUE
    ) THEN
      RETURN jsonb_build_object('error', 'insufficient_permissions');
    END IF;
  END IF;

  v_old_role := v_target_role::public.user_role;

  -- Atualizar role
  UPDATE public.community_members
  SET role = p_new_role::public.user_role
  WHERE community_id = p_community_id AND user_id = p_target_user_id;

  -- Registrar histórico
  INSERT INTO public.role_changes (community_id, user_id, changed_by, old_role, new_role, reason)
  VALUES (p_community_id, p_target_user_id, v_user_id, v_old_role, p_new_role::public.user_role, p_reason);

  -- Registrar no log de moderação
  INSERT INTO public.moderation_logs (community_id, moderator_id, action, target_user_id, reason)
  VALUES (
    p_community_id,
    v_user_id,
    CASE WHEN p_new_role > v_target_role THEN 'promote' ELSE 'demote' END::public.moderation_action,
    p_target_user_id,
    p_reason
  );

  -- Notificar o usuário
  INSERT INTO public.notifications (user_id, actor_id, type, title, body, community_id)
  VALUES (
    p_target_user_id,
    v_user_id,
    'moderation',
    CASE
      WHEN p_new_role IN ('leader', 'curator') THEN 'Você foi promovido!'
      ELSE 'Alteração de cargo'
    END,
    CASE
      WHEN p_new_role = 'leader' THEN 'Você agora é Líder desta comunidade.'
      WHEN p_new_role = 'curator' THEN 'Você agora é Curador desta comunidade.'
      WHEN p_new_role = 'moderator' THEN 'Você agora é Moderador desta comunidade.'
      ELSE 'Seu cargo na comunidade foi alterado.'
    END,
    p_community_id
  );

  RETURN jsonb_build_object('success', TRUE, 'old_role', v_old_role, 'new_role', p_new_role);
END;
$$;

GRANT EXECUTE ON FUNCTION public.change_member_role TO authenticated;

-- ============================================================
-- 7. RPC: Dar/remover título customizado a membro
-- ============================================================
CREATE OR REPLACE FUNCTION public.manage_member_title(
  p_community_id  UUID,
  p_target_user_id UUID,
  p_action        TEXT,   -- 'add' ou 'remove'
  p_title         TEXT,
  p_color         TEXT DEFAULT '#FFFFFF',
  p_icon          TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_my_role  TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Verificar permissão (leader ou agent)
  SELECT role INTO v_my_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_my_role NOT IN ('agent', 'leader', 'curator') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_team_admin = TRUE
    ) THEN
      RETURN jsonb_build_object('error', 'insufficient_permissions');
    END IF;
  END IF;

  IF p_action = 'add' THEN
    INSERT INTO public.member_titles (community_id, user_id, issued_by, title, color, icon)
    VALUES (p_community_id, p_target_user_id, v_user_id, p_title, p_color, p_icon)
    ON CONFLICT (community_id, user_id, title) DO UPDATE
    SET color = p_color, icon = p_icon, is_visible = TRUE;

    -- Atualizar custom_titles no community_members (cache)
    UPDATE public.community_members
    SET custom_titles = (
      SELECT jsonb_agg(jsonb_build_object('title', mt.title, 'color', mt.color, 'icon', mt.icon))
      FROM public.member_titles mt
      WHERE mt.community_id = p_community_id
        AND mt.user_id = p_target_user_id
        AND mt.is_visible = TRUE
    )
    WHERE community_id = p_community_id AND user_id = p_target_user_id;

  ELSIF p_action = 'remove' THEN
    DELETE FROM public.member_titles
    WHERE community_id = p_community_id
      AND user_id = p_target_user_id
      AND title = p_title;

    -- Atualizar cache
    UPDATE public.community_members
    SET custom_titles = (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('title', mt.title, 'color', mt.color, 'icon', mt.icon)), '[]'::jsonb)
      FROM public.member_titles mt
      WHERE mt.community_id = p_community_id
        AND mt.user_id = p_target_user_id
        AND mt.is_visible = TRUE
    )
    WHERE community_id = p_community_id AND user_id = p_target_user_id;
  END IF;

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_member_title TO authenticated;

-- ============================================================
-- 8. RPC: Fixar/desafixar post na comunidade
-- ============================================================
CREATE OR REPLACE FUNCTION public.pin_community_post(
  p_community_id  UUID,
  p_post_id       UUID,
  p_pin           BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id     UUID := auth.uid();
  v_my_role     TEXT;
  v_pinned_count INTEGER;
  v_max_pins    INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- Verificar permissão
  SELECT role INTO v_my_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_my_role NOT IN ('agent', 'leader', 'curator', 'moderator') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_team_admin = TRUE
    ) THEN
      RETURN jsonb_build_object('error', 'insufficient_permissions');
    END IF;
  END IF;

  IF p_pin THEN
    -- Verificar limite de posts fixados
    SELECT COUNT(*) INTO v_pinned_count
    FROM public.posts
    WHERE community_id = p_community_id AND is_pinned = TRUE AND status = 'ok';

    SELECT COALESCE(max_pinned_posts, 5) INTO v_max_pins
    FROM public.communities
    WHERE id = p_community_id;

    IF v_pinned_count >= v_max_pins THEN
      RETURN jsonb_build_object('error', 'max_pinned_reached', 'max', v_max_pins);
    END IF;

    UPDATE public.posts
    SET is_pinned = TRUE,
        pinned_at = NOW(),
        pinned_by = v_user_id
    WHERE id = p_post_id AND community_id = p_community_id;
  ELSE
    UPDATE public.posts
    SET is_pinned = FALSE,
        pinned_at = NULL,
        pinned_by = NULL
    WHERE id = p_post_id AND community_id = p_community_id;
  END IF;

  -- Registrar no log
  INSERT INTO public.moderation_logs (community_id, moderator_id, action, target_post_id, reason)
  VALUES (
    p_community_id,
    v_user_id,
    CASE WHEN p_pin THEN 'feature_post' ELSE 'unfeature_post' END::public.moderation_action,
    p_post_id,
    CASE WHEN p_pin THEN 'Post fixado na comunidade' ELSE 'Post desafixado da comunidade' END
  );

  RETURN jsonb_build_object('success', TRUE, 'pinned', p_pin);
END;
$$;

GRANT EXECUTE ON FUNCTION public.pin_community_post TO authenticated;

-- ============================================================
-- 9. RPC: Buscar posts fixados da comunidade
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_pinned_posts(p_community_id UUID)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT row_to_json(p)::jsonb
  FROM (
    SELECT
      posts.*,
      profiles.nickname AS author_nickname,
      profiles.icon_url AS author_icon_url
    FROM public.posts
    JOIN public.profiles ON profiles.id = posts.author_id
    WHERE posts.community_id = p_community_id
      AND posts.is_pinned = TRUE
      AND posts.status = 'ok'
    ORDER BY posts.pinned_at DESC
  ) p;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pinned_posts TO authenticated, anon;

-- ============================================================
-- 10. RPC: Buscar membros com roles de staff da comunidade
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_community_staff(p_community_id UUID)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT row_to_json(s)::jsonb
  FROM (
    SELECT
      cm.id AS member_id,
      cm.user_id,
      cm.role,
      cm.joined_at,
      cm.custom_titles,
      cm.local_level,
      cm.local_reputation,
      p.nickname,
      p.icon_url,
      p.amino_id,
      p.online_status
    FROM public.community_members cm
    JOIN public.profiles p ON p.id = cm.user_id
    WHERE cm.community_id = p_community_id
      AND cm.role IN ('agent', 'leader', 'curator', 'moderator')
    ORDER BY
      CASE cm.role
        WHEN 'agent' THEN 1
        WHEN 'leader' THEN 2
        WHEN 'curator' THEN 3
        WHEN 'moderator' THEN 4
        ELSE 5
      END,
      cm.joined_at ASC
  ) s;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_staff TO authenticated, anon;

-- ============================================================
-- 11. RPC: Buscar histórico de moderação de um usuário
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_moderation_history(
  p_community_id  UUID,
  p_target_user_id UUID
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_my_role TEXT;
BEGIN
  -- Verificar permissão
  SELECT role INTO v_my_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_my_role NOT IN ('agent', 'leader', 'curator', 'moderator') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_team_admin = TRUE
    ) THEN
      RETURN;
    END IF;
  END IF;

  RETURN QUERY
  SELECT row_to_json(h)::jsonb
  FROM (
    SELECT
      ml.*,
      p.nickname AS moderator_nickname,
      p.icon_url AS moderator_icon_url
    FROM public.moderation_logs ml
    JOIN public.profiles p ON p.id = ml.moderator_id
    WHERE ml.community_id = p_community_id
      AND ml.target_user_id = p_target_user_id
    ORDER BY ml.created_at DESC
    LIMIT 50
  ) h;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_moderation_history TO authenticated;

-- ============================================================
-- 12. RPC: Buscar usuários banidos da comunidade
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_banned_users(p_community_id UUID)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_my_role TEXT;
BEGIN
  -- Verificar permissão
  SELECT role INTO v_my_role
  FROM public.community_members
  WHERE community_id = p_community_id AND user_id = v_user_id;

  IF v_my_role NOT IN ('agent', 'leader', 'curator', 'moderator') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_team_admin = TRUE
    ) THEN
      RETURN;
    END IF;
  END IF;

  RETURN QUERY
  SELECT row_to_json(b)::jsonb
  FROM (
    SELECT
      bans.*,
      p.nickname AS user_nickname,
      p.icon_url AS user_icon_url,
      pb.nickname AS banned_by_nickname
    FROM public.bans
    JOIN public.profiles p ON p.id = bans.user_id
    JOIN public.profiles pb ON pb.id = bans.banned_by
    WHERE bans.community_id = p_community_id
      AND bans.is_active = TRUE
    ORDER BY bans.created_at DESC
  ) b;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_banned_users TO authenticated;

-- ============================================================
-- 13. Adicionar coluna pinned_by na tabela posts (se não existir)
-- ============================================================
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS pinned_by UUID REFERENCES public.profiles(id);

-- ============================================================
-- 14. Políticas RLS para as novas tabelas
-- ============================================================

-- member_titles: leitura pública, escrita por staff
ALTER TABLE public.member_titles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_titles_select" ON public.member_titles
  FOR SELECT USING (TRUE);

CREATE POLICY "member_titles_insert" ON public.member_titles
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = member_titles.community_id
        AND user_id = auth.uid()
        AND role IN ('agent', 'leader', 'curator')
    )
  );

CREATE POLICY "member_titles_delete" ON public.member_titles
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = member_titles.community_id
        AND user_id = auth.uid()
        AND role IN ('agent', 'leader', 'curator')
    )
  );

-- role_changes: leitura por staff, sem escrita direta (via RPC)
ALTER TABLE public.role_changes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "role_changes_select" ON public.role_changes
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.community_members
      WHERE community_id = role_changes.community_id
        AND user_id = auth.uid()
        AND role IN ('agent', 'leader', 'curator', 'moderator')
    )
  );

-- ============================================================
-- 15. Bucket de storage para banners da comunidade
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('community-banners', 'community-banners', true, 10485760,
   ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY IF NOT EXISTS "community_banners_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'community-banners');

CREATE POLICY IF NOT EXISTS "community_banners_auth_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'community-banners'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY IF NOT EXISTS "community_banners_auth_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'community-banners'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY IF NOT EXISTS "community_banners_auth_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'community-banners'
    AND auth.role() = 'authenticated'
  );
