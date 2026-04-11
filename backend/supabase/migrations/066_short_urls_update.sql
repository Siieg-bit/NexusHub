-- ============================================================
-- Migration 066: Atualiza sistema de URLs curtas
-- Mudanças:
--   /ch/{code}  → /chat/{code}
--   /i/{code}   → /invite/{code}
--   Código hash: 5 chars → 8 chars
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Atualiza generate_short_code para usar 8 chars por padrão
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.generate_short_code(length INT DEFAULT 8)
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
-- 2. Atualiza get_or_create_short_code para usar 8 chars
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

  -- Gera novo código único de 8 chars (até 10 tentativas)
  LOOP
    v_code := public.generate_short_code(8);
    v_attempt := v_attempt + 1;

    BEGIN
      INSERT INTO public.short_urls (code, type, target_id)
      VALUES (v_code, p_type, p_target_id);
      RETURN v_code;
    EXCEPTION WHEN unique_violation THEN
      IF v_attempt >= 10 THEN
        -- Aumenta para 10 chars se colisões demais
        v_code := public.generate_short_code(10);
        INSERT INTO public.short_urls (code, type, target_id)
        VALUES (v_code, p_type, p_target_id);
        RETURN v_code;
      END IF;
    END;
  END LOOP;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 3. Atualiza get_share_url com novos prefixos
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

    -- Post/Blog: /p/{8chars}
    WHEN 'post', 'blog' THEN
      v_code := public.get_or_create_short_code('post', p_target_id);
      RETURN v_base_url || '/p/' || v_code;

    -- Wiki: /w/{8chars}
    WHEN 'wiki' THEN
      v_code := public.get_or_create_short_code('wiki', p_target_id);
      RETURN v_base_url || '/w/' || v_code;

    -- Chat público: /chat/{8chars}  ← ATUALIZADO
    WHEN 'chat' THEN
      v_code := public.get_or_create_short_code('chat', p_target_id);
      RETURN v_base_url || '/chat/' || v_code;

    -- Sticker pack: /s/{8chars}
    WHEN 'sticker_pack' THEN
      v_code := public.get_or_create_short_code('sticker_pack', p_target_id);
      RETURN v_base_url || '/s/' || v_code;

    -- Convite: /invite/{code}  ← ATUALIZADO
    WHEN 'invite' THEN
      SELECT link INTO v_slug
      FROM public.communities
      WHERE id = p_target_id;

      IF v_slug IS NOT NULL AND v_slug != '' THEN
        v_code := regexp_replace(v_slug, '.*/invite/', '');
        -- Tenta legado /i/ também
        IF v_code = v_slug THEN
          v_code := regexp_replace(v_slug, '.*/i/', '');
        END IF;
        RETURN v_base_url || '/invite/' || v_code;
      ELSE
        v_code := public.get_or_create_short_code('invite', p_target_id);
        UPDATE public.communities
        SET link = v_base_url || '/invite/' || v_code
        WHERE id = p_target_id;
        RETURN v_base_url || '/invite/' || v_code;
      END IF;

    ELSE
      RETURN v_base_url || '/' || p_target_id::TEXT;
  END CASE;
END;
$$;

COMMENT ON FUNCTION public.get_share_url IS 'Gera URL curta de compartilhamento. Perfil: /u/amino_id, Comunidade: /c/endpoint, Post: /p/8chars, Wiki: /w/8chars, Chat: /chat/8chars, Sticker: /s/8chars, Invite: /invite/8chars';
