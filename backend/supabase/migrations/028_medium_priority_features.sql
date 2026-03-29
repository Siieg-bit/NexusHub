-- ============================================================================
-- NexusHub — Migração 028: Funcionalidades de Prioridade MÉDIA
-- Adiciona: ghost mode, disable chats/comments, post visibility,
--           comments_blocked, post editing, chat backgrounds per-user,
--           sticker favorites, notification_settings granular, only_friends
-- ============================================================================

-- ============================================================================
-- 1. PROFILES — novos campos de privacidade
-- ============================================================================
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_ghost_mode BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS disable_incoming_chats BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS disable_profile_comments BOOLEAN DEFAULT FALSE;

-- ============================================================================
-- 2. POSTS — visibilidade e controle de comentários
-- ============================================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'post_visibility') THEN
    CREATE TYPE public.post_visibility AS ENUM ('public', 'followers', 'private');
  END IF;
END $$;

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS visibility public.post_visibility DEFAULT 'public',
  ADD COLUMN IF NOT EXISTS comments_blocked BOOLEAN DEFAULT FALSE;

-- ============================================================================
-- 3. CHAT BACKGROUNDS — background por usuário por chat
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.chat_backgrounds (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  thread_id   UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  background_url TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, thread_id)
);

ALTER TABLE public.chat_backgrounds ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chat_backgrounds' AND policyname='chat_backgrounds_select_own') THEN
    CREATE POLICY "chat_backgrounds_select_own" ON public.chat_backgrounds
      FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chat_backgrounds' AND policyname='chat_backgrounds_upsert_own') THEN
    CREATE POLICY "chat_backgrounds_upsert_own" ON public.chat_backgrounds
      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_chat_backgrounds_user_thread ON public.chat_backgrounds(user_id, thread_id);

-- ============================================================================
-- 4. USER STICKER FAVORITES — stickers salvos/favoritos por usuário
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_sticker_favorites (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sticker_id  TEXT NOT NULL,
  sticker_url TEXT NOT NULL,
  pack_id     TEXT,
  category    TEXT DEFAULT 'saved',  -- 'saved', 'favorite', 'recent'
  used_count  INTEGER DEFAULT 0,
  last_used_at TIMESTAMPTZ DEFAULT NOW(),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, sticker_id, category)
);

ALTER TABLE public.user_sticker_favorites ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_sticker_favorites' AND policyname='user_sticker_favorites_own') THEN
    CREATE POLICY "user_sticker_favorites_own" ON public.user_sticker_favorites
      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_sticker_favorites_user ON public.user_sticker_favorites(user_id, category);
CREATE INDEX IF NOT EXISTS idx_user_sticker_favorites_recent ON public.user_sticker_favorites(user_id, last_used_at DESC);

-- ============================================================================
-- 5. NOTIFICATION SETTINGS — tabela granular com filtros
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notification_settings (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- Master toggle
  push_enabled            BOOLEAN DEFAULT TRUE,
  -- Filtro "apenas amigos"
  only_friends            BOOLEAN DEFAULT FALSE,
  -- Por tipo
  push_likes              BOOLEAN DEFAULT TRUE,
  push_comments           BOOLEAN DEFAULT TRUE,
  push_follows            BOOLEAN DEFAULT TRUE,
  push_mentions           BOOLEAN DEFAULT TRUE,
  push_chat_messages      BOOLEAN DEFAULT TRUE,
  push_community_invites  BOOLEAN DEFAULT TRUE,
  push_achievements       BOOLEAN DEFAULT TRUE,
  push_level_up           BOOLEAN DEFAULT TRUE,
  push_moderation         BOOLEAN DEFAULT TRUE,
  push_economy            BOOLEAN DEFAULT TRUE,
  push_stories            BOOLEAN DEFAULT TRUE,
  -- Timestamps
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='notification_settings' AND policyname='notification_settings_own') THEN
    CREATE POLICY "notification_settings_own" ON public.notification_settings
      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_notification_settings_user ON public.notification_settings(user_id);

-- ============================================================================
-- 6. RPC: set_chat_background — definir background per-user per-chat
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_chat_background(
  p_thread_id UUID,
  p_background_url TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.chat_backgrounds (user_id, thread_id, background_url, updated_at)
  VALUES (auth.uid(), p_thread_id, p_background_url, NOW())
  ON CONFLICT (user_id, thread_id)
  DO UPDATE SET background_url = EXCLUDED.background_url, updated_at = NOW();
END;
$$;

-- ============================================================================
-- 7. RPC: toggle_sticker_favorite — salvar/favoritar/remover sticker
-- ============================================================================
CREATE OR REPLACE FUNCTION public.toggle_sticker_favorite(
  p_sticker_id  TEXT,
  p_sticker_url TEXT,
  p_pack_id     TEXT DEFAULT NULL,
  p_category    TEXT DEFAULT 'saved'  -- 'saved' ou 'favorite'
)
RETURNS BOOLEAN  -- TRUE = adicionado, FALSE = removido
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.user_sticker_favorites
    WHERE user_id = auth.uid() AND sticker_id = p_sticker_id AND category = p_category
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.user_sticker_favorites
    WHERE user_id = auth.uid() AND sticker_id = p_sticker_id AND category = p_category;
    RETURN FALSE;
  ELSE
    INSERT INTO public.user_sticker_favorites (user_id, sticker_id, sticker_url, pack_id, category)
    VALUES (auth.uid(), p_sticker_id, p_sticker_url, p_pack_id, p_category)
    ON CONFLICT (user_id, sticker_id, category) DO NOTHING;
    RETURN TRUE;
  END IF;
END;
$$;

-- ============================================================================
-- 8. RPC: track_sticker_used — registrar uso recente de sticker
-- ============================================================================
CREATE OR REPLACE FUNCTION public.track_sticker_used(
  p_sticker_id  TEXT,
  p_sticker_url TEXT,
  p_pack_id     TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_sticker_favorites (user_id, sticker_id, sticker_url, pack_id, category, used_count, last_used_at)
  VALUES (auth.uid(), p_sticker_id, p_sticker_url, p_pack_id, 'recent', 1, NOW())
  ON CONFLICT (user_id, sticker_id, category)
  DO UPDATE SET used_count = user_sticker_favorites.used_count + 1, last_used_at = NOW();

  -- Manter apenas os 20 mais recentes
  DELETE FROM public.user_sticker_favorites
  WHERE user_id = auth.uid()
    AND category = 'recent'
    AND id NOT IN (
      SELECT id FROM public.user_sticker_favorites
      WHERE user_id = auth.uid() AND category = 'recent'
      ORDER BY last_used_at DESC
      LIMIT 20
    );
END;
$$;

-- ============================================================================
-- 9. RPC: edit_post — editar post publicado (só o autor)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.edit_post(
  p_post_id UUID,
  p_title   TEXT DEFAULT NULL,
  p_content TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.posts
  SET
    title   = COALESCE(p_title, title),
    content = COALESCE(p_content, content),
    updated_at = NOW()
  WHERE id = p_post_id AND author_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Post não encontrado ou sem permissão';
  END IF;
END;
$$;

-- ============================================================================
-- 10. RPC: upsert_notification_settings — salvar preferências de notificação
-- ============================================================================
CREATE OR REPLACE FUNCTION public.upsert_notification_settings(
  p_push_enabled           BOOLEAN DEFAULT TRUE,
  p_only_friends           BOOLEAN DEFAULT FALSE,
  p_push_likes             BOOLEAN DEFAULT TRUE,
  p_push_comments          BOOLEAN DEFAULT TRUE,
  p_push_follows           BOOLEAN DEFAULT TRUE,
  p_push_mentions          BOOLEAN DEFAULT TRUE,
  p_push_chat_messages     BOOLEAN DEFAULT TRUE,
  p_push_community_invites BOOLEAN DEFAULT TRUE,
  p_push_achievements      BOOLEAN DEFAULT TRUE,
  p_push_level_up          BOOLEAN DEFAULT TRUE,
  p_push_moderation        BOOLEAN DEFAULT TRUE,
  p_push_economy           BOOLEAN DEFAULT TRUE,
  p_push_stories           BOOLEAN DEFAULT TRUE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_settings (
    user_id, push_enabled, only_friends,
    push_likes, push_comments, push_follows, push_mentions,
    push_chat_messages, push_community_invites, push_achievements,
    push_level_up, push_moderation, push_economy, push_stories, updated_at
  ) VALUES (
    auth.uid(), p_push_enabled, p_only_friends,
    p_push_likes, p_push_comments, p_push_follows, p_push_mentions,
    p_push_chat_messages, p_push_community_invites, p_push_achievements,
    p_push_level_up, p_push_moderation, p_push_economy, p_push_stories, NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    push_enabled           = EXCLUDED.push_enabled,
    only_friends           = EXCLUDED.only_friends,
    push_likes             = EXCLUDED.push_likes,
    push_comments          = EXCLUDED.push_comments,
    push_follows           = EXCLUDED.push_follows,
    push_mentions          = EXCLUDED.push_mentions,
    push_chat_messages     = EXCLUDED.push_chat_messages,
    push_community_invites = EXCLUDED.push_community_invites,
    push_achievements      = EXCLUDED.push_achievements,
    push_level_up          = EXCLUDED.push_level_up,
    push_moderation        = EXCLUDED.push_moderation,
    push_economy           = EXCLUDED.push_economy,
    push_stories           = EXCLUDED.push_stories,
    updated_at             = NOW();
END;
$$;

-- ============================================================================
-- 11. Atualizar push-notification para respeitar only_friends e push_enabled
-- ============================================================================
-- A lógica de filtro only_friends será aplicada na Edge Function push-notification.
-- Aqui apenas garantimos que o índice existe.
CREATE INDEX IF NOT EXISTS idx_notification_settings_only_friends
  ON public.notification_settings(user_id, only_friends, push_enabled);
