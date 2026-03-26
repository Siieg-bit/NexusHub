-- ============================================================
-- NexusHub — Migração 002: Conteúdo (Posts, Wiki, Polls, Quizzes)
-- ============================================================

-- ========================
-- 1. CATEGORIAS DE BLOG/POST
-- ========================

CREATE TABLE public.post_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  icon_url TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 2. POSTS (blogs, polls, quizzes, images, etc)
-- ========================

CREATE TABLE public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Tipo de post (Blog.smali: 0-8)
  type public.post_type DEFAULT 'normal',
  
  -- Conteúdo principal
  title TEXT NOT NULL DEFAULT '',
  content TEXT DEFAULT '',                         -- Corpo do post (Markdown/HTML)
  media_list JSONB DEFAULT '[]'::jsonb,            -- Array de {url, type, width, height}
  cover_image_url TEXT,
  background_url TEXT,                             -- Background customizado do post
  
  -- Categoria
  category_id UUID REFERENCES public.post_categories(id),
  tags JSONB DEFAULT '[]'::jsonb,                  -- Array de strings
  
  -- Para crosspost/repost
  original_post_id UUID REFERENCES public.posts(id),
  original_community_id UUID REFERENCES public.communities(id),
  
  -- Para posts com link externo
  external_url TEXT,
  link_summary JSONB,                              -- {title, description, image, domain}
  
  -- Estatísticas
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  views_count INTEGER DEFAULT 0,
  tips_total INTEGER DEFAULT 0,                    -- Total de coins recebidos como props
  
  -- Moderação
  status public.content_status DEFAULT 'ok',
  is_featured BOOLEAN DEFAULT FALSE,               -- Destacado por Leaders
  is_pinned BOOLEAN DEFAULT FALSE,                 -- Fixado no topo
  featured_by UUID REFERENCES public.profiles(id),
  featured_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_posts_community ON public.posts(community_id);
CREATE INDEX idx_posts_author ON public.posts(author_id);
CREATE INDEX idx_posts_type ON public.posts(type);
CREATE INDEX idx_posts_status ON public.posts(status);
CREATE INDEX idx_posts_featured ON public.posts(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_posts_created ON public.posts(created_at DESC);

-- ========================
-- 3. OPÇÕES DE ENQUETE (poll_options)
-- ========================

CREATE TABLE public.poll_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  image_url TEXT,
  votes_count INTEGER DEFAULT 0,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 4. VOTOS DE ENQUETE (poll_votes)
-- ========================

CREATE TABLE public.poll_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(option_id, user_id)
);

-- ========================
-- 5. QUIZ (quiz_questions e quiz_answers)
-- ========================

CREATE TABLE public.quiz_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  image_url TEXT,
  explanation TEXT DEFAULT '',                      -- Explicação da resposta correta
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.quiz_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID NOT NULL REFERENCES public.quiz_questions(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  is_correct BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0
);

CREATE TABLE public.quiz_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score INTEGER DEFAULT 0,
  total_questions INTEGER DEFAULT 0,
  completed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================
-- 6. WIKI ENTRIES (items/catálogo)
-- ========================

CREATE TABLE public.wiki_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  icon_url TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.wiki_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.wiki_categories(id),
  
  -- Conteúdo
  title TEXT NOT NULL,
  content TEXT DEFAULT '',                         -- Corpo (Markdown/HTML)
  cover_image_url TEXT,
  media_list JSONB DEFAULT '[]'::jsonb,
  
  -- Campos especiais do Amino Wiki
  my_rating REAL,                                  -- Avaliação pessoal (0-5)
  custom_fields JSONB DEFAULT '[]'::jsonb,         -- Array de {label, value} (ex: "What I Like")
  tags JSONB DEFAULT '[]'::jsonb,
  
  -- Fluxo de aprovação
  status public.content_status DEFAULT 'pending',  -- Wiki precisa de aprovação
  submission_note TEXT DEFAULT '',                  -- "Note to Curator"
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewed_at TIMESTAMPTZ,
  
  -- Estatísticas
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  views_count INTEGER DEFAULT 0,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_wiki_community ON public.wiki_entries(community_id);
CREATE INDEX idx_wiki_status ON public.wiki_entries(status);

-- ========================
-- 7. COMENTÁRIOS (comments)
-- ========================
-- Polimórfico: pode ser em post, wiki ou perfil (The Wall)

CREATE TABLE public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Alvo polimórfico
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  wiki_id UUID REFERENCES public.wiki_entries(id) ON DELETE CASCADE,
  profile_wall_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,  -- The Wall
  
  -- Conteúdo
  content TEXT NOT NULL,
  media_url TEXT,                                   -- Imagem/GIF anexado
  
  -- Reply (resposta a outro comentário)
  parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  
  -- Estatísticas
  likes_count INTEGER DEFAULT 0,
  
  -- Moderação
  status public.content_status DEFAULT 'ok',
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Garantir que pelo menos um alvo é definido
  CONSTRAINT comment_has_target CHECK (
    (post_id IS NOT NULL)::int +
    (wiki_id IS NOT NULL)::int +
    (profile_wall_id IS NOT NULL)::int = 1
  )
);

CREATE INDEX idx_comments_post ON public.comments(post_id) WHERE post_id IS NOT NULL;
CREATE INDEX idx_comments_wiki ON public.comments(wiki_id) WHERE wiki_id IS NOT NULL;
CREATE INDEX idx_comments_wall ON public.comments(profile_wall_id) WHERE profile_wall_id IS NOT NULL;

-- ========================
-- 8. LIKES (curtidas)
-- ========================

CREATE TABLE public.likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Alvo polimórfico
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  wiki_id UUID REFERENCES public.wiki_entries(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Garantir que pelo menos um alvo é definido
  CONSTRAINT like_has_target CHECK (
    (post_id IS NOT NULL)::int +
    (wiki_id IS NOT NULL)::int +
    (comment_id IS NOT NULL)::int = 1
  ),
  
  -- Garantir unicidade por tipo
  UNIQUE(user_id, post_id),
  UNIQUE(user_id, wiki_id),
  UNIQUE(user_id, comment_id)
);

-- ========================
-- 9. BOOKMARKS (salvos)
-- ========================

CREATE TABLE public.bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  wiki_id UUID REFERENCES public.wiki_entries(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT bookmark_has_target CHECK (
    (post_id IS NOT NULL)::int +
    (wiki_id IS NOT NULL)::int = 1
  )
);

-- ========================
-- 10. DRAFTS (rascunhos)
-- ========================

CREATE TABLE public.drafts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  type public.post_type DEFAULT 'normal',
  title TEXT DEFAULT '',
  content TEXT DEFAULT '',
  media_list JSONB DEFAULT '[]'::jsonb,
  extra_data JSONB DEFAULT '{}'::jsonb,            -- Poll options, quiz data, etc
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
