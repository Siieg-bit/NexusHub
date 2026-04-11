-- ============================================================
-- Migration 065: Sistema de URLs Curtas (Short URLs)
-- nexushub.app/u/{amino_id}   → perfil
-- nexushub.app/c/{endpoint}   → comunidade
-- nexushub.app/p/{code}       → post/blog
-- nexushub.app/w/{code}       → wiki
-- nexushub.app/ch/{code}      → chat público
-- nexushub.app/s/{code}       → sticker pack
-- nexushub.app/i/{code}       → convite de comunidade
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Tabela de short codes (para tipos que não têm slug natural)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.short_urls (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT NOT NULL UNIQUE,          -- Código curto Base62 (5 chars)
  type        TEXT NOT NULL,                 -- 'post', 'wiki', 'chat', 'sticker_pack', 'invite'
  target_id   UUID NOT NULL,                 -- UUID do recurso alvo
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  hits        INTEGER DEFAULT 0             -- Contador de acessos
);

CREATE INDEX IF NOT EXISTS idx_short_urls_code ON public.short_urls(code);
CREATE INDEX IF NOT EXISTS idx_short_urls_target ON public.short_urls(target_id);

-- RLS
ALTER TABLE public.short_urls ENABLE ROW LEVEL SECURITY;

-- Qualquer um pode ler (para resolver links)
CREATE POLICY "short_urls_read" ON public.short_urls
  FOR SELECT USING (true);

-- Apenas usuários autenticados podem criar
CREATE POLICY "short_urls_insert" ON public.short_urls
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ─────────────────────────────────────────────────────────────
-- 2. Função Base62 para gerar códigos curtos
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.generate_short_code(length INT DEFAULT 5)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  chars TEXT := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := '';
  i INT;
  rand_bytes BYTEA;
BEGIN
  rand_bytes := gen_random_bytes(length);
  FOR i IN 0..(length - 1) LOOP
    result := result || substr(chars, (get_byte(rand_bytes, i) % 62) + 1, 1);
  END LOOP;
  RETURN result;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 3. Função para obter ou criar short code para um recurso
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_or_create_short_code(
  p_type      TEXT,
  p_target_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code TEXT;
  v_attempt INT := 0;
BEGIN
  -- Verifica se já existe
  SELECT code INTO v_code
  FROM public.short_urls
  WHERE type = p_type AND target_id = p_target_id
  LIMIT 1;

  IF v_code IS NOT NULL THEN
    RETURN v_code;
  END IF;

  -- Gera novo código único (até 10 tentativas)
  LOOP
    v_code := public.generate_short_code(5);
    v_attempt := v_attempt + 1;

    BEGIN
      INSERT INTO public.short_urls (code, type, target_id)
      VALUES (v_code, p_type, p_target_id);
      RETURN v_code;
    EXCEPTION WHEN unique_violation THEN
      IF v_attempt >= 10 THEN
        -- Aumenta para 6 chars se colisões demais
        v_code := public.generate_short_code(6);
        INSERT INTO public.short_urls (code, type, target_id)
        VALUES (v_code, p_type, p_target_id);
        RETURN v_code;
      END IF;
    END;
  END LOOP;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 4. Função para resolver um short code → retorna tipo e UUID
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.resolve_short_url(p_code TEXT)
RETURNS TABLE(
  type        TEXT,
  target_id   UUID,
  -- Campos extras para navegação direta
  community_id UUID,
  extra_data   JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row public.short_urls%ROWTYPE;
BEGIN
  SELECT * INTO v_row
  FROM public.short_urls
  WHERE code = p_code
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Incrementa hits de forma assíncrona (sem bloquear)
  UPDATE public.short_urls SET hits = hits + 1 WHERE code = p_code;

  -- Retorna dados básicos
  type      := v_row.type;
  target_id := v_row.target_id;
  extra_data := '{}'::jsonb;
  community_id := NULL;

  -- Para posts/blogs, busca o community_id para navegação correta
  IF v_row.type IN ('post', 'blog') THEN
    SELECT p.community_id INTO community_id
    FROM public.posts p
    WHERE p.id = v_row.target_id;
  END IF;

  -- Para wiki, busca o community_id
  IF v_row.type = 'wiki' THEN
    SELECT w.community_id INTO community_id
    FROM public.wiki_entries w
    WHERE w.id = v_row.target_id;
  END IF;

  -- Para chat público, busca o community_id
  IF v_row.type = 'chat' THEN
    SELECT t.community_id INTO community_id
    FROM public.chat_threads t
    WHERE t.id = v_row.target_id;
  END IF;

  RETURN NEXT;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 5. Função para gerar URL completa de compartilhamento
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_share_url(
  p_type      TEXT,
  p_target_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code     TEXT;
  v_slug     TEXT;
  v_base_url TEXT := 'https://nexushub.app';
BEGIN
  CASE p_type
    -- Perfil: usa amino_id se disponível, senão UUID
    WHEN 'user' THEN
      SELECT amino_id INTO v_slug
      FROM public.profiles
      WHERE id = p_target_id;

      IF v_slug IS NOT NULL AND v_slug != '' THEN
        RETURN v_base_url || '/u/' || v_slug;
      ELSE
        RETURN v_base_url || '/u/' || p_target_id::TEXT;
      END IF;

    -- Comunidade: usa endpoint (slug)
    WHEN 'community' THEN
      SELECT endpoint INTO v_slug
      FROM public.communities
      WHERE id = p_target_id;

      IF v_slug IS NOT NULL AND v_slug != '' THEN
        RETURN v_base_url || '/c/' || v_slug;
      ELSE
        RETURN v_base_url || '/c/' || p_target_id::TEXT;
      END IF;

    -- Post/Blog: short code de 5 chars
    WHEN 'post', 'blog' THEN
      v_code := public.get_or_create_short_code('post', p_target_id);
      RETURN v_base_url || '/p/' || v_code;

    -- Wiki: short code
    WHEN 'wiki' THEN
      v_code := public.get_or_create_short_code('wiki', p_target_id);
      RETURN v_base_url || '/w/' || v_code;

    -- Chat público: short code
    WHEN 'chat' THEN
      v_code := public.get_or_create_short_code('chat', p_target_id);
      RETURN v_base_url || '/ch/' || v_code;

    -- Sticker pack: short code
    WHEN 'sticker_pack' THEN
      v_code := public.get_or_create_short_code('sticker_pack', p_target_id);
      RETURN v_base_url || '/s/' || v_code;

    -- Convite de comunidade: usa o link existente ou gera código
    WHEN 'invite' THEN
      SELECT link INTO v_slug
      FROM public.communities
      WHERE id = p_target_id;

      IF v_slug IS NOT NULL AND v_slug != '' THEN
        -- Extrai apenas o código do link existente
        v_code := regexp_replace(v_slug, '.*/i/', '');
        RETURN v_base_url || '/i/' || v_code;
      ELSE
        v_code := public.get_or_create_short_code('invite', p_target_id);
        -- Salva o link na comunidade
        UPDATE public.communities
        SET link = v_base_url || '/i/' || v_code
        WHERE id = p_target_id;
        RETURN v_base_url || '/i/' || v_code;
      END IF;

    ELSE
      RETURN v_base_url || '/' || p_target_id::TEXT;
  END CASE;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 6. Trigger: gera short code automaticamente ao criar post/wiki/chat
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_auto_short_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_type TEXT;
BEGIN
  -- Determina o tipo baseado na tabela
  v_type := TG_ARGV[0];

  -- Gera o short code de forma assíncrona
  PERFORM public.get_or_create_short_code(v_type, NEW.id);

  RETURN NEW;
END;
$$;

-- Trigger em posts
DROP TRIGGER IF EXISTS trg_post_short_code ON public.posts;
CREATE TRIGGER trg_post_short_code
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_auto_short_code('post');

-- Trigger em wiki_entries (se existir)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wiki_entries') THEN
    DROP TRIGGER IF EXISTS trg_wiki_short_code ON public.wiki_entries;
    EXECUTE '
      CREATE TRIGGER trg_wiki_short_code
        AFTER INSERT ON public.wiki_entries
        FOR EACH ROW
        EXECUTE FUNCTION public.trg_auto_short_code(''wiki'')
    ';
  END IF;
END;
$$;

-- Trigger em chat_threads (apenas chats públicos)
CREATE OR REPLACE FUNCTION public.trg_chat_short_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Apenas para chats públicos (type = 'public')
  IF NEW.type = 'public' THEN
    PERFORM public.get_or_create_short_code('chat', NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_chat_thread_short_code ON public.chat_threads;
CREATE TRIGGER trg_chat_thread_short_code
  AFTER INSERT ON public.chat_threads
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_chat_short_code();

-- ─────────────────────────────────────────────────────────────
-- 7. Gera short codes para posts/wikis/chats existentes (backfill)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_row RECORD;
BEGIN
  -- Posts existentes
  FOR v_row IN SELECT id FROM public.posts LOOP
    PERFORM public.get_or_create_short_code('post', v_row.id);
  END LOOP;

  -- Chats públicos existentes
  FOR v_row IN SELECT id FROM public.chat_threads WHERE type = 'public' LOOP
    PERFORM public.get_or_create_short_code('chat', v_row.id);
  END LOOP;

  -- Wiki entries existentes (se tabela existir)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wiki_entries') THEN
    FOR v_row IN SELECT id FROM public.wiki_entries LOOP
      PERFORM public.get_or_create_short_code('wiki', v_row.id);
    END LOOP;
  END IF;
END;
$$;

COMMENT ON TABLE public.short_urls IS 'Tabela de URLs curtas para compartilhamento. Padrão: nexushub.app/{prefix}/{code}';
COMMENT ON FUNCTION public.get_share_url IS 'Gera URL curta de compartilhamento. Perfil: /u/amino_id, Comunidade: /c/endpoint, Post: /p/5chars, Wiki: /w/5chars, Chat: /ch/5chars, Sticker: /s/5chars, Invite: /i/5chars';
