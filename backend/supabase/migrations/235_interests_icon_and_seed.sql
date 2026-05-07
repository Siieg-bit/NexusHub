-- =============================================================================
-- Migration 235 — Interesses: adicionar icon_name e popular tabela completa
--
-- Objetivo: Permitir que os ícones das categorias de interesse sejam
-- gerenciados remotamente pelo admin, sem necessidade de atualizar o APK.
--
-- Mudanças:
--   1. Adiciona coluna `icon_name` (TEXT) na tabela `interests`
--   2. Popula a tabela com as 24 categorias que estavam hardcoded no Flutter
--      (interest_wizard_screen.dart), usando ON CONFLICT para ser idempotente
-- =============================================================================

-- 1. Adicionar coluna icon_name
ALTER TABLE public.interests
  ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'star_rounded';

-- 2. Popular com as 24 categorias hardcoded no Flutter
-- Usamos ON CONFLICT (name) DO UPDATE para ser idempotente (pode rodar N vezes)
-- A coluna `name` não tem UNIQUE constraint na migration 001, então adicionamos
-- um índice único antes do upsert.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'interests' AND indexname = 'interests_name_unique'
  ) THEN
    CREATE UNIQUE INDEX interests_name_unique ON public.interests(name);
  END IF;
END $$;

INSERT INTO public.interests (name, display_name, category, background_color, icon_name, sort_order)
VALUES
  ('Anime & Manga',     'Anime & Manga',     'Entertainment', '#E91E63', 'movie_filter_rounded',               1),
  ('K-Pop',             'K-Pop',             'Entertainment', '#9C27B0', 'music_note_rounded',                 2),
  ('Games',             'Games',             'Entertainment', '#4CAF50', 'sports_esports_rounded',             3),
  ('Art & Design',      'Art & Design',      'Creative',      '#FF9800', 'palette_rounded',                    4),
  ('Fashion',           'Fashion',           'Lifestyle',     '#E040FB', 'checkroom_rounded',                  5),
  ('Books & Writing',   'Books & Writing',   'Creative',      '#795548', 'menu_book_rounded',                  6),
  ('Movies & Series',   'Movies & Series',   'Entertainment', '#F44336', 'theaters_rounded',                   7),
  ('Music',             'Music',             'Entertainment', '#2196F3', 'headphones_rounded',                 8),
  ('Photography',       'Photography',       'Creative',      '#607D8B', 'camera_alt_rounded',                 9),
  ('Science',           'Science',           'Education',     '#00BCD4', 'science_rounded',                   10),
  ('Sports',            'Sports',            'Lifestyle',     '#FF5722', 'fitness_center_rounded',            11),
  ('Technology',        'Technology',        'Education',     '#3F51B5', 'computer_rounded',                  12),
  ('Cosplay',           'Cosplay',           'Creative',      '#FF4081', 'face_retouching_natural_rounded',   13),
  ('Spirituality',      'Spirituality',      'Lifestyle',     '#8BC34A', 'self_improvement_rounded',          14),
  ('Cooking',           'Cooking',           'Lifestyle',     '#FFEB3B', 'restaurant_rounded',                15),
  ('Pets & Animals',    'Pets & Animals',    'Lifestyle',     '#009688', 'pets_rounded',                      16),
  ('Travel',            'Travel',            'Lifestyle',     '#03A9F4', 'flight_rounded',                    17),
  ('Horror',            'Horror',            'Entertainment', '#424242', 'dark_mode_rounded',                 18),
  ('Memes & Humor',     'Memes & Humor',     'Entertainment', '#FFC107', 'sentiment_very_satisfied_rounded',  19),
  ('Languages',         'Languages',         'Education',     '#673AB7', 'translate_rounded',                 20),
  ('DIY',               'Do It Yourself',    'Creative',      '#CDDC39', 'handyman_rounded',                  21),
  ('Comics',            'Comics',            'Entertainment', '#FF6F00', 'auto_stories_rounded',              22),
  ('Dance',             'Dance',             'Entertainment', '#D500F9', 'nightlife_rounded',                 23),
  ('Nature',            'Nature',            'Lifestyle',     '#4CAF50', 'park_rounded',                      24)
ON CONFLICT (name) DO UPDATE SET
  display_name     = EXCLUDED.display_name,
  category         = EXCLUDED.category,
  background_color = EXCLUDED.background_color,
  icon_name        = EXCLUDED.icon_name,
  sort_order       = EXCLUDED.sort_order;
