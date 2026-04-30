-- Migration 219: Configurações avançadas para ai_characters
-- Adiciona colunas de configuração técnica e comportamental para personagens de IA

-- ─── Novas colunas na tabela ai_characters ───────────────────────────────────
ALTER TABLE public.ai_characters
  ADD COLUMN IF NOT EXISTS model             text    NOT NULL DEFAULT 'gpt-4.1-mini',
  ADD COLUMN IF NOT EXISTS temperature       numeric NOT NULL DEFAULT 0.8 CHECK (temperature >= 0 AND temperature <= 2),
  ADD COLUMN IF NOT EXISTS max_tokens        integer NOT NULL DEFAULT 512  CHECK (max_tokens >= 50 AND max_tokens <= 4096),
  ADD COLUMN IF NOT EXISTS persona_style     text    NOT NULL DEFAULT 'casual',
  ADD COLUMN IF NOT EXISTS restrictions      text[]  NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS greeting_message  text,
  ADD COLUMN IF NOT EXISTS context_window    integer NOT NULL DEFAULT 10   CHECK (context_window >= 1 AND context_window <= 50),
  ADD COLUMN IF NOT EXISTS usage_count       bigint  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at        timestamptz NOT NULL DEFAULT now();

-- ─── Trigger para atualizar updated_at automaticamente ───────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS ai_characters_updated_at ON public.ai_characters;
CREATE TRIGGER ai_characters_updated_at
  BEFORE UPDATE ON public.ai_characters
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─── Dropar RPCs antigas ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_create_ai_character(text,text,text,text,text[],text,text,boolean);
DROP FUNCTION IF EXISTS public.admin_update_ai_character(uuid,text,text,text,text[],text,text,boolean);
DROP FUNCTION IF EXISTS public.admin_get_ai_characters();

-- ─── RPC: admin_get_ai_characters ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_ai_characters()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(row_to_json(c) ORDER BY c.created_at DESC)
    FROM (
      SELECT
        id, name, avatar_url, description, system_prompt,
        tags, language, is_active, created_at, updated_at,
        model, temperature, max_tokens, persona_style,
        restrictions, greeting_message, context_window, usage_count
      FROM public.ai_characters
    ) c
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_ai_characters() TO authenticated;

-- ─── RPC: admin_create_ai_character ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_create_ai_character(
  p_name             text,
  p_description      text,
  p_system_prompt    text,
  p_tags             text[]    DEFAULT '{}',
  p_language         text      DEFAULT 'pt',
  p_avatar_url       text      DEFAULT NULL,
  p_is_active        boolean   DEFAULT true,
  p_model            text      DEFAULT 'gpt-4.1-mini',
  p_temperature      numeric   DEFAULT 0.8,
  p_max_tokens       integer   DEFAULT 512,
  p_persona_style    text      DEFAULT 'casual',
  p_restrictions     text[]    DEFAULT '{}',
  p_greeting_message text      DEFAULT NULL,
  p_context_window   integer   DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO public.ai_characters (
    name, description, system_prompt, tags, language, avatar_url, is_active,
    model, temperature, max_tokens, persona_style, restrictions,
    greeting_message, context_window
  ) VALUES (
    p_name, p_description, p_system_prompt, p_tags, p_language, p_avatar_url, p_is_active,
    p_model, p_temperature, p_max_tokens, p_persona_style, p_restrictions,
    p_greeting_message, p_context_window
  ) RETURNING id INTO v_id;
  RETURN jsonb_build_object('id', v_id, 'success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_create_ai_character(text,text,text,text[],text,text,boolean,text,numeric,integer,text,text[],text,integer) TO authenticated;

-- ─── RPC: admin_update_ai_character ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_update_ai_character(
  p_id               uuid,
  p_name             text,
  p_description      text,
  p_system_prompt    text,
  p_tags             text[]    DEFAULT '{}',
  p_language         text      DEFAULT 'pt',
  p_avatar_url       text      DEFAULT NULL,
  p_is_active        boolean   DEFAULT true,
  p_model            text      DEFAULT 'gpt-4.1-mini',
  p_temperature      numeric   DEFAULT 0.8,
  p_max_tokens       integer   DEFAULT 512,
  p_persona_style    text      DEFAULT 'casual',
  p_restrictions     text[]    DEFAULT '{}',
  p_greeting_message text      DEFAULT NULL,
  p_context_window   integer   DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.ai_characters SET
    name             = p_name,
    description      = p_description,
    system_prompt    = p_system_prompt,
    tags             = p_tags,
    language         = p_language,
    avatar_url       = p_avatar_url,
    is_active        = p_is_active,
    model            = p_model,
    temperature      = p_temperature,
    max_tokens       = p_max_tokens,
    persona_style    = p_persona_style,
    restrictions     = p_restrictions,
    greeting_message = p_greeting_message,
    context_window   = p_context_window
  WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_update_ai_character(uuid,text,text,text,text[],text,text,boolean,text,numeric,integer,text,text[],text,integer) TO authenticated;

-- ─── RPC: admin_toggle_ai_character (manter compatibilidade) ─────────────────
DROP FUNCTION IF EXISTS public.admin_toggle_ai_character(uuid);
CREATE OR REPLACE FUNCTION public.admin_toggle_ai_character(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_new boolean;
BEGIN
  UPDATE public.ai_characters SET is_active = NOT is_active WHERE id = p_id RETURNING is_active INTO v_new;
  RETURN jsonb_build_object('is_active', v_new, 'success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_toggle_ai_character(uuid) TO authenticated;

-- ─── RPC: admin_delete_ai_character (manter compatibilidade) ─────────────────
DROP FUNCTION IF EXISTS public.admin_delete_ai_character(uuid);
CREATE OR REPLACE FUNCTION public.admin_delete_ai_character(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  DELETE FROM public.ai_characters WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_ai_character(uuid) TO authenticated;

-- ─── RPC: admin_search_users_for_team (buscar usuários para adicionar à equipe) ─
DROP FUNCTION IF EXISTS public.admin_search_users_for_team(text);
CREATE OR REPLACE FUNCTION public.admin_search_users_for_team(p_query text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(row_to_json(u))
    FROM (
      SELECT id, nickname, amino_id, icon_url, team_role, team_rank,
             is_team_admin, is_team_moderator
      FROM public.profiles
      WHERE (
        nickname ILIKE '%' || p_query || '%'
        OR amino_id ILIKE '%' || p_query || '%'
      )
      ORDER BY
        CASE WHEN amino_id ILIKE p_query || '%' THEN 0 ELSE 1 END,
        nickname
      LIMIT 10
    ) u
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_search_users_for_team(text) TO authenticated;
