-- =============================================================================
-- Migration 038: Correções da Auditoria Completa Pós-Relatório Estratégico
-- =============================================================================
-- Bugs encontrados: colunas inexistentes referenciadas pelo Flutter,
-- RPCs com schema desatualizado, colunas faltantes em tabelas.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabela posts: adicionar colunas que o Flutter usa mas não existem
--    (gif_url, music_url, music_title são usadas em create_post_screen.dart)
-- ---------------------------------------------------------------------------
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS gif_url text;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS music_url text;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS music_title text;

-- ---------------------------------------------------------------------------
-- 2. Tabela wiki_entries: adicionar coluna 'infobox' (jsonb) usada pelo Flutter
--    O Flutter insere 'infobox' mas a tabela não tem essa coluna.
-- ---------------------------------------------------------------------------
ALTER TABLE public.wiki_entries ADD COLUMN IF NOT EXISTS infobox jsonb DEFAULT '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- 3. Tabela flags: o Flutter insere 'type' mas a coluna real é 'flag_type',
--    e insere 'target_message_id' mas a coluna real é 'target_chat_message_id'.
--    Solução: NÃO alterar o banco — corrigir no Flutter (mais seguro).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 4. Tabela notifications: o Flutter insere 'notification_type' e 'content'
--    mas as colunas reais são 'type' e 'body'. Além disso, insere 'target_id'
--    que não existe — deveria usar 'community_id'.
--    Solução: NÃO alterar o banco — corrigir no Flutter (mais seguro).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 5. Tabela community_members: o Flutter usa 'banned_until' e 'muted_until'
--    mas as colunas reais são 'ban_expires_at' e 'mute_expires_at'.
--    Solução: NÃO alterar o banco — corrigir no Flutter (mais seguro).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 6. Tabela community_general_links: o Flutter não envia 'created_by' (NOT NULL?).
--    Verificar se é nullable — se não for, o insert falhará.
--    Solução: tornar created_by nullable com default auth.uid()
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  -- Adicionar default para created_by se não tiver
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'community_general_links'
    AND column_name = 'created_by'
    AND column_default IS NULL
  ) THEN
    ALTER TABLE public.community_general_links
      ALTER COLUMN created_by SET DEFAULT auth.uid();
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 7. Tabela chat_threads: o Flutter insere 'created_by' que NÃO existe.
--    Precisamos decidir: criar a coluna ou corrigir no Flutter.
--    Decisão: NÃO criar coluna — o DM já tem host_id que serve o mesmo propósito.
--    Corrigir no Flutter: usar 'host_id' em vez de 'created_by'.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 8. Corrigir RPC create_post_with_reputation (overload antigo)
--    O overload antigo usa 'media_urls' e 'option_text'/'position' que não existem.
--    Recriar com schema correto.
-- ---------------------------------------------------------------------------

-- Dropar o overload antigo que usa p_author_id (o novo usa auth.uid())
DROP FUNCTION IF EXISTS public.create_post_with_reputation(uuid, uuid, text, text, text, text[], uuid, jsonb);

-- Recriar o overload antigo com schema correto
CREATE OR REPLACE FUNCTION public.create_post_with_reputation(
  p_community_id uuid,
  p_author_id uuid,
  p_title text,
  p_content text,
  p_type text DEFAULT 'blog'::text,
  p_media_list jsonb DEFAULT '[]'::jsonb,
  p_category_id uuid DEFAULT NULL::uuid,
  p_poll_options jsonb DEFAULT NULL::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_post_id UUID;
  v_is_member BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id AND user_id = p_author_id AND is_banned = false
  ) INTO v_is_member;
  IF NOT v_is_member THEN
    RAISE EXCEPTION 'User is not a member of this community';
  END IF;
  INSERT INTO public.posts (
    community_id, author_id, title, content, type, media_list, category_id, status
  ) VALUES (
    p_community_id, p_author_id, p_title, p_content, p_type::public.post_type,
    p_media_list, p_category_id, 'ok'
  ) RETURNING id INTO v_post_id;
  IF p_poll_options IS NOT NULL AND jsonb_array_length(p_poll_options) > 0 THEN
    INSERT INTO public.poll_options (post_id, text, sort_order)
    SELECT v_post_id, elem->>'text', (row_number() OVER ())::int
    FROM jsonb_array_elements(p_poll_options) AS elem;
  END IF;
  PERFORM public.add_reputation(p_author_id, p_community_id, 'create_post', 15, v_post_id);
  RETURN v_post_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 9. Tabela moderation_logs: o Flutter insere 'action' com valores como
--    'wiki_approve' e 'wiki_reject' que NÃO estão no enum moderation_action.
--    Adicionar esses valores ao enum.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'wiki_approve' AND enumtypid = 'moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE IF NOT EXISTS 'wiki_approve';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'wiki_reject' AND enumtypid = 'moderation_action'::regtype) THEN
    ALTER TYPE public.moderation_action ADD VALUE IF NOT EXISTS 'wiki_reject';
  END IF;
END $$;

-- =============================================================================
-- FIM DA MIGRATION 038
-- =============================================================================
