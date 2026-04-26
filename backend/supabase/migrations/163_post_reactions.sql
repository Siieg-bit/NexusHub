-- Migration 163: Post Reactions
-- Substitui o sistema de like simples por reactions com emojis.
-- Os tipos suportados são: like, love, haha, wow, sad, angry.

-- 1. Tabela de reactions
CREATE TABLE IF NOT EXISTS public.post_reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type       TEXT NOT NULL DEFAULT 'like'
               CHECK (type IN ('like', 'love', 'haha', 'wow', 'sad', 'angry')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(post_id, user_id) -- um usuário pode ter apenas uma reaction por post
);

CREATE INDEX IF NOT EXISTS idx_post_reactions_post_id ON public.post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_post_reactions_user_id ON public.post_reactions(user_id);

ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view reactions"
  ON public.post_reactions FOR SELECT USING (true);

CREATE POLICY "User can manage own reactions"
  ON public.post_reactions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Migrar likes existentes para reactions (tipo 'like')
INSERT INTO public.post_reactions (post_id, user_id, type)
SELECT pl.post_id, pl.user_id, 'like'
  FROM public.post_likes pl
 WHERE NOT EXISTS (
   SELECT 1 FROM public.post_reactions pr
    WHERE pr.post_id = pl.post_id AND pr.user_id = pl.user_id
 )
ON CONFLICT DO NOTHING;

-- 3. View materializada de contagem por tipo
CREATE OR REPLACE VIEW public.post_reaction_counts AS
SELECT
  post_id,
  COUNT(*) FILTER (WHERE type = 'like')  AS like_count,
  COUNT(*) FILTER (WHERE type = 'love')  AS love_count,
  COUNT(*) FILTER (WHERE type = 'haha')  AS haha_count,
  COUNT(*) FILTER (WHERE type = 'wow')   AS wow_count,
  COUNT(*) FILTER (WHERE type = 'sad')   AS sad_count,
  COUNT(*) FILTER (WHERE type = 'angry') AS angry_count,
  COUNT(*) AS total_count
FROM public.post_reactions
GROUP BY post_id;

-- 4. RPC para toggle reaction (upsert ou delete)
CREATE OR REPLACE FUNCTION public.toggle_post_reaction(
  p_post_id UUID,
  p_type    TEXT DEFAULT 'like'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_existing   TEXT;
  v_action     TEXT;
  v_new_type   TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  -- Verificar reaction existente
  SELECT type INTO v_existing
    FROM public.post_reactions
   WHERE post_id = p_post_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    -- Inserir nova reaction
    INSERT INTO public.post_reactions (post_id, user_id, type)
    VALUES (p_post_id, v_user_id, p_type);
    v_action   := 'added';
    v_new_type := p_type;

    -- Notificar autor do post (apenas para 'like' e 'love')
    IF p_type IN ('like', 'love') THEN
      INSERT INTO public.notifications (recipient_id, actor_id, type, post_id)
      SELECT p.user_id, v_user_id, 'like', p_post_id
        FROM public.posts p
       WHERE p.id = p_post_id
         AND p.user_id <> v_user_id
      ON CONFLICT DO NOTHING;
    END IF;

  ELSIF v_existing = p_type THEN
    -- Remover reaction (toggle off)
    DELETE FROM public.post_reactions
     WHERE post_id = p_post_id AND user_id = v_user_id;
    v_action   := 'removed';
    v_new_type := NULL;

  ELSE
    -- Trocar tipo de reaction
    UPDATE public.post_reactions
       SET type = p_type
     WHERE post_id = p_post_id AND user_id = v_user_id;
    v_action   := 'changed';
    v_new_type := p_type;
  END IF;

  -- Retornar contagens atualizadas
  RETURN (
    SELECT jsonb_build_object(
      'action',      v_action,
      'type',        v_new_type,
      'like_count',  COUNT(*) FILTER (WHERE type = 'like'),
      'love_count',  COUNT(*) FILTER (WHERE type = 'love'),
      'haha_count',  COUNT(*) FILTER (WHERE type = 'haha'),
      'wow_count',   COUNT(*) FILTER (WHERE type = 'wow'),
      'sad_count',   COUNT(*) FILTER (WHERE type = 'sad'),
      'angry_count', COUNT(*) FILTER (WHERE type = 'angry'),
      'total_count', COUNT(*)
    )
    FROM public.post_reactions
    WHERE post_id = p_post_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_post_reaction(UUID, TEXT) TO authenticated;
