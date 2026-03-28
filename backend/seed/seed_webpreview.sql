-- ============================================================================
-- NexusHub — SEED DATA (baseado no Web-Preview)
-- Popula o banco com dados idênticos ao protótipo para visualização completa
-- ============================================================================
-- INSTRUÇÕES:
-- 1. Primeiro crie os usuários no Supabase Auth (via Dashboard > Authentication)
--    Crie 9 usuários com emails: u1@nexushub.dev até u9@nexushub.dev (senha: Test123!)
-- 2. O trigger handle_new_user() criará os profiles automaticamente
-- 3. Atualize os UUIDs abaixo com os UUIDs reais gerados pelo Auth
-- 4. Execute este script no SQL Editor do Supabase Dashboard
-- ============================================================================

-- ============================================================================
-- PASSO 0: DEFINIR UUIDs (SUBSTITUA PELOS REAIS DO AUTH)
-- ============================================================================
-- Após criar os usuários no Auth, pegue os UUIDs e substitua aqui:

DO $$
DECLARE
  -- Usuários (substitua pelos UUIDs reais do Supabase Auth)
  v_u1 UUID := '11111111-1111-1111-1111-111111111111'; -- NexusUser (usuário principal)
  v_u2 UUID := '22222222-2222-2222-2222-222222222222'; -- OtakuMaster
  v_u3 UUID := '33333333-3333-3333-3333-333333333333'; -- ProGamer99
  v_u4 UUID := '44444444-4444-4444-4444-444444444444'; -- ArtistaSoul
  v_u5 UUID := '55555555-5555-5555-5555-555555555555'; -- MelodyKing
  v_u6 UUID := '66666666-6666-6666-6666-666666666666'; -- SakuraFan
  v_u7 UUID := '77777777-7777-7777-7777-777777777777'; -- RetroGamer
  v_u8 UUID := '88888888-8888-8888-8888-888888888888'; -- DarkWriter
  v_u9 UUID := '99999999-9999-9999-9999-999999999999'; -- CosplayQueen

  -- Comunidades (UUIDs fixos para referência)
  v_c1  UUID := 'aaaaaaaa-0001-0001-0001-aaaaaaaaaaaa'; -- Anime Amino
  v_c2  UUID := 'aaaaaaaa-0002-0002-0002-aaaaaaaaaaaa'; -- K-Pop Amino
  v_c3  UUID := 'aaaaaaaa-0003-0003-0003-aaaaaaaaaaaa'; -- Gaming Amino
  v_c4  UUID := 'aaaaaaaa-0004-0004-0004-aaaaaaaaaaaa'; -- Art Amino
  v_c5  UUID := 'aaaaaaaa-0005-0005-0005-aaaaaaaaaaaa'; -- Horror Amino
  v_c6  UUID := 'aaaaaaaa-0006-0006-0006-aaaaaaaaaaaa'; -- Pokemon Amino
  v_c7  UUID := 'aaaaaaaa-0007-0007-0007-aaaaaaaaaaaa'; -- Cosplay Amino
  v_c8  UUID := 'aaaaaaaa-0008-0008-0008-aaaaaaaaaaaa'; -- Books Amino
  v_c9  UUID := 'aaaaaaaa-0009-0009-0009-aaaaaaaaaaaa'; -- Naruto Amino
  v_c10 UUID := 'aaaaaaaa-0010-0010-0010-aaaaaaaaaaaa'; -- Dragon Ball Amino
  v_c11 UUID := 'aaaaaaaa-0011-0011-0011-aaaaaaaaaaaa'; -- One Piece Amino
  v_c12 UUID := 'aaaaaaaa-0012-0012-0012-aaaaaaaaaaaa'; -- Minecraft Amino
  v_c13 UUID := 'aaaaaaaa-0013-0013-0013-aaaaaaaaaaaa'; -- J-Rock Amino
  v_c14 UUID := 'aaaaaaaa-0014-0014-0014-aaaaaaaaaaaa'; -- Digital Art Amino
  v_c15 UUID := 'aaaaaaaa-0015-0015-0015-aaaaaaaaaaaa'; -- Marvel Amino

  -- Posts
  v_p1 UUID := 'bbbbbbbb-0001-0001-0001-bbbbbbbbbbbb';
  v_p2 UUID := 'bbbbbbbb-0002-0002-0002-bbbbbbbbbbbb';
  v_p3 UUID := 'bbbbbbbb-0003-0003-0003-bbbbbbbbbbbb';
  v_p4 UUID := 'bbbbbbbb-0004-0004-0004-bbbbbbbbbbbb';
  v_p5 UUID := 'bbbbbbbb-0005-0005-0005-bbbbbbbbbbbb';
  v_p6 UUID := 'bbbbbbbb-0006-0006-0006-bbbbbbbbbbbb';
  v_p7 UUID := 'bbbbbbbb-0007-0007-0007-bbbbbbbbbbbb';

  -- Chat Threads
  v_ch1 UUID := 'cccccccc-0001-0001-0001-cccccccccccc';
  v_ch2 UUID := 'cccccccc-0002-0002-0002-cccccccccccc';
  v_ch3 UUID := 'cccccccc-0003-0003-0003-cccccccccccc';
  v_ch4 UUID := 'cccccccc-0004-0004-0004-cccccccccccc';
  v_ch5 UUID := 'cccccccc-0005-0005-0005-cccccccccccc';
  v_ch6 UUID := 'cccccccc-0006-0006-0006-cccccccccccc';
  v_ch7 UUID := 'cccccccc-0007-0007-0007-cccccccccccc';
  v_ch8 UUID := 'cccccccc-0008-0008-0008-cccccccccccc';
  v_ch9 UUID := 'cccccccc-0009-0009-0009-cccccccccccc';

  -- Wiki
  v_w1 UUID := 'dddddddd-0001-0001-0001-dddddddddddd';
  v_w2 UUID := 'dddddddd-0002-0002-0002-dddddddddddd';
  v_w3 UUID := 'dddddddd-0003-0003-0003-dddddddddddd';
  v_w4 UUID := 'dddddddd-0004-0004-0004-dddddddddddd';

  -- Wiki Categories
  v_wc1 UUID := 'eeeeeeee-0001-0001-0001-eeeeeeeeeeee';
  v_wc2 UUID := 'eeeeeeee-0002-0002-0002-eeeeeeeeeeee';
  v_wc3 UUID := 'eeeeeeee-0003-0003-0003-eeeeeeeeeeee';

  -- Poll Options
  v_po1 UUID := 'ffffffff-0001-0001-0001-ffffffffffff';
  v_po2 UUID := 'ffffffff-0002-0002-0002-ffffffffffff';
  v_po3 UUID := 'ffffffff-0003-0003-0003-ffffffffffff';
  v_po4 UUID := 'ffffffff-0004-0004-0004-ffffffffffff';

  -- Comments
  v_cm1 UUID := '11111111-0001-0001-0001-cccccccccccc';
  v_cm2 UUID := '11111111-0002-0002-0002-cccccccccccc';
  v_cm3 UUID := '11111111-0003-0003-0003-cccccccccccc';
  v_cm4 UUID := '11111111-0004-0004-0004-cccccccccccc';

BEGIN

-- ============================================================================
-- PASSO 1: ATUALIZAR PROFILES (já criados pelo trigger handle_new_user)
-- ============================================================================

UPDATE public.profiles SET
  nickname = 'NexusUser',
  amino_id = 'nexususer',
  icon_url = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop',
  banner_url = 'https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=600&h=400&fit=crop',
  bio = 'Welcome to my profile! I love anime, gaming and art. Always looking for new friends and communities to join!',
  level = 16, reputation = 48914, coins = 68,
  consecutive_checkin_days = 318,
  followers_count = 30190, following_count = 24,
  online_status = 1, has_completed_onboarding = TRUE
WHERE id = v_u1;

UPDATE public.profiles SET
  nickname = 'OtakuMaster',
  amino_id = 'otakumaster',
  icon_url = 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100&h=100&fit=crop',
  bio = 'Anime reviewer and community leader since 2018!',
  level = 32, reputation = 125600, coins = 450,
  consecutive_checkin_days = 200,
  followers_count = 45000, following_count = 120,
  online_status = 1, has_completed_onboarding = TRUE
WHERE id = v_u2;

UPDATE public.profiles SET
  nickname = 'ProGamer99',
  amino_id = 'progamer99',
  icon_url = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
  bio = 'Competitive Valorant player. Also love RPGs and retro games.',
  level = 28, reputation = 89400, coins = 320,
  consecutive_checkin_days = 120,
  followers_count = 15600, following_count = 18,
  online_status = 1, has_completed_onboarding = TRUE
WHERE id = v_u3;

UPDATE public.profiles SET
  nickname = 'ArtistaSoul',
  amino_id = 'artistasoul',
  icon_url = 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop',
  bio = 'Digital artist and illustrator. Commissions open!',
  level = 19, reputation = 34200, coins = 150,
  consecutive_checkin_days = 60,
  followers_count = 8900, following_count = 45,
  online_status = 1, has_completed_onboarding = TRUE
WHERE id = v_u4;

UPDATE public.profiles SET
  nickname = 'MelodyKing',
  amino_id = 'melodyking',
  icon_url = 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop',
  bio = 'K-Pop fan and music enthusiast. BTS ARMY!',
  level = 15, reputation = 21300, coins = 200,
  consecutive_checkin_days = 45,
  followers_count = 5600, following_count = 90,
  online_status = 2, has_completed_onboarding = TRUE
WHERE id = v_u5;

UPDATE public.profiles SET
  nickname = 'SakuraFan',
  amino_id = 'sakurafan',
  icon_url = 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop',
  bio = 'Anime fan art creator. Studio Ghibli is life!',
  level = 21, reputation = 67800, coins = 280,
  consecutive_checkin_days = 90,
  followers_count = 12000, following_count = 35,
  online_status = 1, has_completed_onboarding = TRUE
WHERE id = v_u6;

UPDATE public.profiles SET
  nickname = 'RetroGamer',
  amino_id = 'retrogamer',
  icon_url = 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop',
  bio = 'SNES collector. 500+ retro games in my collection.',
  level = 24, reputation = 45600, coins = 180,
  consecutive_checkin_days = 30,
  followers_count = 7800, following_count = 25,
  online_status = 2, has_completed_onboarding = TRUE
WHERE id = v_u7;

UPDATE public.profiles SET
  nickname = 'DarkWriter',
  amino_id = 'darkwriter',
  icon_url = 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop',
  bio = 'Horror writer and movie collector. 500+ movies watched.',
  level = 18, reputation = 28900, coins = 100,
  consecutive_checkin_days = 30,
  followers_count = 3400, following_count = 15,
  online_status = 1, has_completed_onboarding = TRUE
WHERE id = v_u8;

UPDATE public.profiles SET
  nickname = 'CosplayQueen',
  amino_id = 'cosplayqueen',
  icon_url = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop',
  bio = 'Professional cosplayer. 100+ cosplays and counting!',
  level = 26, reputation = 56700, coins = 350,
  consecutive_checkin_days = 15,
  followers_count = 22000, following_count = 50,
  online_status = 2, has_completed_onboarding = TRUE
WHERE id = v_u9;

-- ============================================================================
-- PASSO 2: INSERIR COMUNIDADES
-- ============================================================================

INSERT INTO public.communities (id, name, tagline, description, icon_url, banner_url, endpoint, agent_id, primary_language, category, members_count, community_heat, listed_status) VALUES
  (v_c1,  'Anime Amino',       'The biggest anime community!', 'The biggest anime community! Share your love for anime and manga.', 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&h=300&fit=crop', 'anime',       v_u2, 'en', 'anime',    3253749, 95.0, 'listed'),
  (v_c2,  'K-Pop Amino',       'For all K-Pop fans!',          'For all K-Pop fans! BTS, BLACKPINK, Stray Kids and more.',         'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&h=300&fit=crop', 'k-pop',       v_u5, 'en', 'music',    2185430, 88.0, 'listed'),
  (v_c3,  'Gaming Amino',      'The ultimate gaming community', 'The ultimate gaming community. PC, Console, Mobile.',              'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&h=300&fit=crop', 'gaming',      v_u3, 'en', 'gaming',   2134500, 92.0, 'listed'),
  (v_c4,  'Art Amino',         'Share your art!',              'Share your art, get feedback, and improve your skills!',            'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=600&h=300&fit=crop', 'art',         v_u4, 'en', 'art',      1498200, 78.0, 'listed'),
  (v_c5,  'Horror Amino',      'For horror fans!',             'For horror fans! Movies, books, games, creepypasta.',              'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&h=300&fit=crop', 'horror',      v_u8, 'en', 'movies',    867800, 65.0, 'listed'),
  (v_c6,  'Pokemon Amino',     'Gotta catch em all!',          'Gotta catch em all! The Pokemon community.',                       'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?w=600&h=300&fit=crop', 'pokemon',     v_u7, 'en', 'gaming',   1512300, 82.0, 'listed'),
  (v_c7,  'Cosplay Amino',     'Show off your cosplays!',      'Show off your cosplays and get tips!',                             'https://images.unsplash.com/photo-1608889825103-eb5ed706fc64?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1608889825103-eb5ed706fc64?w=600&h=300&fit=crop', 'cosplay',     v_u9, 'en', 'cosplay',   754200, 55.0, 'listed'),
  (v_c8,  'Books Amino',       'For book lovers!',             'For book lovers! Reviews, recommendations and discussions.',        'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=600&h=300&fit=crop', 'books',       v_u8, 'en', 'books',     543100, 45.0, 'listed'),
  (v_c9,  'Naruto Amino',      'For all Naruto fans!',         'For all Naruto and Boruto fans!',                                  'https://images.unsplash.com/photo-1601850494422-3cf14624b0b3?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1601850494422-3cf14624b0b3?w=600&h=300&fit=crop', 'naruto',      v_u2, 'en', 'anime',    1456000, 80.0, 'listed'),
  (v_c10, 'Dragon Ball Amino', 'Kamehameha!',                  'Kamehameha! The Dragon Ball community.',                           'https://images.unsplash.com/photo-1614583225154-5fcdda07019e?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1614583225154-5fcdda07019e?w=600&h=300&fit=crop', 'dragonball',  v_u2, 'en', 'anime',     987000, 70.0, 'listed'),
  (v_c11, 'One Piece Amino',   'Set sail!',                    'Set sail with the Straw Hat crew!',                                'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&h=300&fit=crop', 'onepiece',    v_u6, 'en', 'anime',    1890000, 85.0, 'listed'),
  (v_c12, 'Minecraft Amino',   'Build anything!',              'Build, explore, survive. The Minecraft community.',                 'https://images.unsplash.com/photo-1553481187-be93c21490a9?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1553481187-be93c21490a9?w=600&h=300&fit=crop', 'minecraft',   v_u7, 'en', 'gaming',    890000, 72.0, 'listed'),
  (v_c13, 'J-Rock Amino',      'Japanese Rock!',               'Japanese Rock and Visual Kei community.',                          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&h=300&fit=crop', 'jrock',       v_u5, 'en', 'music',     234000, 35.0, 'listed'),
  (v_c14, 'Digital Art Amino',  'All digital art!',             'Procreate, Photoshop, Clip Studio - all digital art!',             'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=600&h=300&fit=crop', 'digitalart',  v_u4, 'en', 'art',       567000, 50.0, 'listed'),
  (v_c15, 'Marvel Amino',      'Everything Marvel!',            'Marvel Comics, MCU, and everything Marvel!',                       'https://images.unsplash.com/photo-1612036782180-6f0b6cd846fe?w=200&h=200&fit=crop', 'https://images.unsplash.com/photo-1612036782180-6f0b6cd846fe?w=600&h=300&fit=crop', 'marvel',      v_u8, 'en', 'movies',   1234000, 75.0, 'listed');

-- ============================================================================
-- PASSO 3: INSERIR MEMBROS DAS COMUNIDADES (com roles e perfis locais)
-- ============================================================================

-- NexusUser (u1) é membro de: c1 (Anime), c2 (K-Pop), c3 (Gaming), c5 (Horror), c9 (Naruto)
INSERT INTO public.community_members (community_id, user_id, role, local_nickname, local_icon_url, local_bio, local_level, local_reputation, consecutive_checkin_days) VALUES
  -- u1 em Anime Amino (Leader)
  (v_c1, v_u1, 'leader', 'AnimeNexus', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop', 'Anime enthusiast since 2010! My top 3: Attack on Titan, One Piece, Demon Slayer.', 16, 48914, 318),
  -- u1 em K-Pop Amino (Curator)
  (v_c2, v_u1, 'curator', 'MelodyLover', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop', 'BTS ARMY forever! Also love Stray Kids and ATEEZ.', 12, 12340, 45),
  -- u1 em Gaming Amino (Curator)
  (v_c3, v_u1, 'curator', 'ProGamerX', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop', 'Competitive Valorant player. Also love RPGs and retro games.', 22, 34500, 120),
  -- u1 em Horror Amino (Member)
  (v_c5, v_u1, 'member', 'DarkSoul', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop', 'Horror movie collector. 500+ movies watched.', 8, 5670, 30),
  -- u1 em Naruto Amino (Member)
  (v_c9, v_u1, 'member', 'HokageNexus', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&h=200&fit=crop', 'Believe it! Naruto changed my life.', 14, 23400, 200);

-- OtakuMaster (u2) - Leader em Anime, membro em várias
INSERT INTO public.community_members (community_id, user_id, role, local_level, local_reputation) VALUES
  (v_c1, v_u2, 'leader', 32, 125600),
  (v_c9, v_u2, 'leader', 28, 89000),
  (v_c10, v_u2, 'curator', 20, 45000),
  (v_c11, v_u2, 'member', 15, 21000);

-- ProGamer99 (u3) - Curator em Gaming
INSERT INTO public.community_members (community_id, user_id, role, local_level, local_reputation) VALUES
  (v_c3, v_u3, 'curator', 28, 89400),
  (v_c1, v_u3, 'member', 12, 15000),
  (v_c12, v_u3, 'member', 18, 30000);

-- ArtistaSoul (u4) - Membro em Anime e Art
INSERT INTO public.community_members (community_id, user_id, role, local_level, local_reputation) VALUES
  (v_c1, v_u4, 'member', 19, 34200),
  (v_c4, v_u4, 'leader', 25, 67000),
  (v_c14, v_u4, 'curator', 20, 40000);

-- MelodyKing (u5) - Membro em K-Pop
INSERT INTO public.community_members (community_id, user_id, role, local_level, local_reputation) VALUES
  (v_c2, v_u5, 'member', 15, 21300),
  (v_c13, v_u5, 'leader', 18, 28000);

-- SakuraFan (u6) - Curator em Anime
INSERT INTO public.community_members (community_id, user_id, role, local_level, local_reputation) VALUES
  (v_c1, v_u6, 'curator', 21, 67800),
  (v_c11, v_u6, 'leader', 24, 55000),
  (v_c4, v_u6, 'member', 10, 12000);

-- RetroGamer (u7)
INSERT INTO public.community_members (community_id, user_id, role, local_level, local_reputation) VALUES
  (v_c3, v_u7, 'member', 24, 45600),
  (v_c6, v_u7, 'leader', 22, 50000),
  (v_c12, v_u7, 'leader', 20, 38000);

-- DarkWriter (u8)
INSERT INTO public.community_members (community_id, user_id, role, local_level, local_reputation) VALUES
  (v_c5, v_u8, 'leader', 18, 28900),
  (v_c1, v_u8, 'member', 10, 8000),
  (v_c8, v_u8, 'leader', 16, 22000),
  (v_c15, v_u8, 'curator', 14, 18000);

-- CosplayQueen (u9)
INSERT INTO public.community_members (community_id, user_id, role, local_level, local_reputation) VALUES
  (v_c7, v_u9, 'leader', 26, 56700),
  (v_c1, v_u9, 'member', 8, 5000);

-- ============================================================================
-- PASSO 4: INSERIR POSTS (7 posts do web-preview)
-- ============================================================================

INSERT INTO public.posts (id, community_id, author_id, type, title, content, cover_image_url, likes_count, comments_count, is_liked, is_pinned, is_featured, tags, created_at) VALUES
  (v_p1, v_c1, v_u2, 'normal',
   'Top 10 Animes da Temporada - Primavera 2026',
   'Pessoal, a temporada de primavera esta incrivel! Aqui vai minha lista dos melhores animes que estao passando agora. Comentem se concordam!',
   'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&h=400&fit=crop',
   234, 45, FALSE, TRUE, TRUE,
   '["anime", "temporada", "ranking"]'::jsonb,
   '2026-03-25T14:30:00Z'),

  (v_p2, v_c3, v_u3, 'normal',
   'Guia Completo: Como subir de rank em Valorant',
   'Depois de muito estudo e pratica, compilei as melhores dicas para subir de rank.',
   'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&h=400&fit=crop',
   189, 67, FALSE, FALSE, TRUE,
   '["valorant", "guia", "ranked"]'::jsonb,
   '2026-03-25T10:15:00Z'),

  (v_p3, v_c1, v_u4, 'normal',
   'Minha nova ilustracao digital - Feedback?',
   'Passei 3 semanas trabalhando nessa ilustracao. O que voces acham?',
   'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=600&h=400&fit=crop',
   456, 89, FALSE, FALSE, TRUE,
   '["arte", "digital", "ilustracao"]'::jsonb,
   '2026-03-24T18:00:00Z'),

  (v_p4, v_c2, v_u5, 'poll',
   'Enquete: Melhor album de 2026 ate agora?',
   'Qual album lancado em 2026 e o seu favorito? Vote na enquete!',
   NULL,
   312, 234, FALSE, FALSE, FALSE,
   '["musica", "enquete", "2026"]'::jsonb,
   '2026-03-24T12:00:00Z'),

  (v_p5, v_c1, v_u6, 'normal',
   'Fan Art: Personagem original estilo Ghibli',
   'Criei esse personagem inspirado no estilo do Studio Ghibli.',
   'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&h=400&fit=crop',
   567, 123, FALSE, FALSE, TRUE,
   '["fanart", "ghibli", "original"]'::jsonb,
   '2026-03-23T20:00:00Z'),

  (v_p6, v_c3, v_u7, 'quiz',
   'Quiz: Voce conhece os classicos do SNES?',
   'Teste seus conhecimentos sobre os jogos classicos do Super Nintendo!',
   NULL,
   178, 56, FALSE, FALSE, FALSE,
   '["quiz", "retro", "snes"]'::jsonb,
   '2026-03-23T15:00:00Z'),

  (v_p7, v_c5, v_u8, 'normal',
   'Creepypasta Original: O Corredor Sem Fim',
   'Era uma noite chuvosa quando decidi explorar o antigo hospital abandonado...',
   'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&h=400&fit=crop',
   89, 34, FALSE, FALSE, TRUE,
   '["creepypasta", "original", "horror"]'::jsonb,
   '2026-03-22T22:00:00Z');

-- ============================================================================
-- PASSO 5: INSERIR POLL OPTIONS (para post p4 - enquete K-Pop)
-- ============================================================================

INSERT INTO public.poll_options (id, post_id, text, votes_count, sort_order) VALUES
  (v_po1, v_p4, 'BLACKPINK - Born Pink II', 145, 1),
  (v_po2, v_p4, 'BTS - Beyond',             98,  2),
  (v_po3, v_p4, 'Stray Kids - MAXIDENT 2',  45,  3),
  (v_po4, v_p4, 'Other',                    24,  4);

-- ============================================================================
-- PASSO 6: INSERIR COMENTÁRIOS (no post p1 - Top 10 Animes)
-- ============================================================================

INSERT INTO public.comments (id, author_id, post_id, content, likes_count, created_at) VALUES
  (v_cm1, v_u3, v_p1, 'Great list! I would add Solo Leveling Season 2 though.', 23, '2026-03-25T15:00:00Z'),
  (v_cm2, v_u4, v_p1, 'The animation quality this season is insane!', 15, '2026-03-25T15:30:00Z'),
  (v_cm3, v_u6, v_p1, 'Where is the romance genre? There are some great ones too!', 8, '2026-03-25T16:00:00Z'),
  (v_cm4, v_u7, v_p1, 'Solid picks! I would swap #7 and #5 personally.', 5, '2026-03-25T17:00:00Z');

-- ============================================================================
-- PASSO 7: INSERIR LIKES (para simular os isLiked do web-preview)
-- ============================================================================

INSERT INTO public.likes (user_id, post_id) VALUES
  (v_u1, v_p1),  -- NexusUser liked p1
  (v_u1, v_p3),  -- NexusUser liked p3
  (v_u1, v_p5);  -- NexusUser liked p5

INSERT INTO public.likes (user_id, comment_id) VALUES
  (v_u1, v_cm2); -- NexusUser liked comment cm2

-- ============================================================================
-- PASSO 8: INSERIR CHAT THREADS (9 salas de chat do web-preview)
-- ============================================================================

INSERT INTO public.chat_threads (id, community_id, type, title, icon_url, host_id, members_count, last_message_preview, last_message_author, last_message_at) VALUES
  (v_ch1, v_c1, 'public', 'Anime General Chat', NULL, v_u2, 1245, 'Anyone watching the new season?', 'OtakuMaster', NOW() - INTERVAL '2 minutes'),
  (v_ch2, v_c3, 'public', 'Gaming Lounge', NULL, v_u3, 890, 'GG everyone! That was intense', 'ProGamer99', NOW() - INTERVAL '5 minutes'),
  (v_ch3, v_c2, 'public', 'K-Pop Fan Chat', NULL, v_u5, 2100, 'Did you see the new MV?!', 'MelodyKing', NOW() - INTERVAL '15 minutes'),
  (v_ch4, v_c4, 'public', 'Art Critique Room', NULL, v_u4, 340, 'Love the color palette!', 'ArtistaSoul', NOW() - INTERVAL '1 hour'),
  (v_ch5, v_c5, 'public', 'Horror Stories', NULL, v_u8, 210, 'That ending was terrifying...', 'DarkWriter', NOW() - INTERVAL '30 minutes'),
  (v_ch6, v_c1, 'dm', 'Meggie3524', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop', v_u9, 2, 'I want to know how to appeal...', 'Meggie3524', NOW() - INTERVAL '2 minutes'),
  (v_ch7, v_c3, 'dm', 'De Boeurs', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop', v_u3, 2, 'Want to play ranked later?', 'De Boeurs', NOW() - INTERVAL '1 hour'),
  (v_ch8, v_c1, 'public', 'Anime Theatre', NULL, v_u6, 525, 'Streaming starts at 8pm!', 'SakuraFan', NOW() - INTERVAL '10 minutes'),
  (v_ch9, v_c9, 'public', 'Naruto Discussions', NULL, v_u2, 780, 'Boruto manga is getting better', 'HokageFan', NOW() - INTERVAL '20 minutes');

-- ============================================================================
-- PASSO 9: INSERIR MEMBROS DOS CHATS
-- ============================================================================

-- Anime General Chat (ch1) - vários membros
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch1, v_u1, 3), (v_ch1, v_u2, 0), (v_ch1, v_u3, 0),
  (v_ch1, v_u4, 0), (v_ch1, v_u6, 0), (v_ch1, v_u8, 0);

-- Gaming Lounge (ch2)
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch2, v_u1, 0), (v_ch2, v_u3, 0), (v_ch2, v_u7, 0);

-- K-Pop Fan Chat (ch3)
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch3, v_u1, 12), (v_ch3, v_u5, 0);

-- Art Critique Room (ch4)
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch4, v_u4, 0), (v_ch4, v_u6, 0);

-- Horror Stories (ch5)
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch5, v_u1, 0), (v_ch5, v_u8, 0);

-- DM Meggie3524 (ch6)
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch6, v_u1, 1), (v_ch6, v_u9, 0);

-- DM De Boeurs (ch7)
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch7, v_u1, 0), (v_ch7, v_u3, 0);

-- Anime Theatre (ch8)
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch8, v_u1, 0), (v_ch8, v_u6, 0), (v_ch8, v_u2, 0);

-- Naruto Discussions (ch9)
INSERT INTO public.chat_members (thread_id, user_id, unread_count) VALUES
  (v_ch9, v_u1, 5), (v_ch9, v_u2, 0);

-- ============================================================================
-- PASSO 10: INSERIR MENSAGENS DE CHAT (Anime General Chat)
-- ============================================================================

INSERT INTO public.chat_messages (thread_id, author_id, type, content, created_at) VALUES
  (v_ch1, v_u2, 'system_join', 'Welcome to Anime General Chat! Be respectful and have fun.', NOW() - INTERVAL '3 hours'),
  (v_ch1, v_u2, 'text', 'Hey everyone! Who is watching the new anime season?', NOW() - INTERVAL '70 minutes'),
  (v_ch1, v_u6, 'text', 'Me! The new isekai is amazing!', NOW() - INTERVAL '69 minutes'),
  (v_ch1, v_u3, 'text', 'I prefer the action ones. MAPPA really outdid themselves!', NOW() - INTERVAL '68 minutes'),
  (v_ch1, v_u4, 'text', 'The art style is incredible. I have been studying their techniques.', NOW() - INTERVAL '67 minutes'),
  (v_ch1, v_u1, 'text', 'Totally agree! What is everyone top 3 this season?', NOW() - INTERVAL '65 minutes'),
  (v_ch1, v_u5, 'text', 'Do not forget the OSTs! The music this season is fire!', NOW() - INTERVAL '64 minutes');

-- ============================================================================
-- PASSO 11: INSERIR WIKI CATEGORIES E ENTRIES
-- ============================================================================

INSERT INTO public.wiki_categories (id, community_id, name, sort_order) VALUES
  (v_wc1, v_c1, 'General', 1),
  (v_wc2, v_c1, 'Rankings', 2),
  (v_wc3, v_c1, 'Database', 3);

INSERT INTO public.wiki_entries (id, community_id, author_id, category_id, title, content, cover_image_url, views_count, status) VALUES
  (v_w1, v_c1, v_u2, v_wc1, 'Getting Started Guide', 'Welcome to Anime Amino! This guide will help you get started...', 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=300&h=200&fit=crop', 12450, 'ok'),
  (v_w2, v_c1, v_u2, v_wc1, 'Community Rules & Guidelines', 'Please read and follow these rules to keep our community safe...', NULL, 8920, 'ok'),
  (v_w3, v_c1, v_u6, v_wc2, 'Anime Tier List 2026', 'Our community-voted tier list for the best anime of 2026...', 'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=300&h=200&fit=crop', 5670, 'ok'),
  (v_w4, v_c1, v_u2, v_wc3, 'Character Encyclopedia', 'A comprehensive database of anime characters...', 'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=300&h=200&fit=crop', 15230, 'ok');

-- ============================================================================
-- PASSO 12: INSERIR FOLLOWS (relações de seguir)
-- ============================================================================

INSERT INTO public.follows (follower_id, following_id) VALUES
  (v_u1, v_u2), (v_u1, v_u3), (v_u1, v_u4), (v_u1, v_u6),
  (v_u2, v_u1), (v_u2, v_u6), (v_u2, v_u3),
  (v_u3, v_u1), (v_u3, v_u7),
  (v_u4, v_u1), (v_u4, v_u6),
  (v_u5, v_u1), (v_u5, v_u2),
  (v_u6, v_u1), (v_u6, v_u2), (v_u6, v_u4),
  (v_u7, v_u3), (v_u7, v_u1),
  (v_u8, v_u1),
  (v_u9, v_u1), (v_u9, v_u6);

-- ============================================================================
-- PASSO 13: INSERIR INTERESSES (para onboarding)
-- ============================================================================

INSERT INTO public.interests (name, display_name, category, background_color) VALUES
  ('anime', 'Anime & Manga', 'Entertainment', '#E91E63'),
  ('gaming', 'Gaming', 'Entertainment', '#4CAF50'),
  ('art', 'Art & Design', 'Creative', '#FF9800'),
  ('music', 'Music', 'Entertainment', '#9C27B0'),
  ('movies', 'Movies & TV', 'Entertainment', '#F44336'),
  ('books', 'Books & Writing', 'Creative', '#795548'),
  ('cosplay', 'Cosplay', 'Creative', '#E040FB'),
  ('science', 'Science & Tech', 'Education', '#00BCD4'),
  ('sports', 'Sports & Fitness', 'Lifestyle', '#8BC34A'),
  ('food', 'Food & Cooking', 'Lifestyle', '#FF5722'),
  ('pets', 'Pets & Animals', 'Lifestyle', '#607D8B'),
  ('fashion', 'Fashion & Beauty', 'Lifestyle', '#EC407A');

RAISE NOTICE '✅ Seed completo! Dados do web-preview inseridos com sucesso.';
RAISE NOTICE '📊 Resumo: 9 usuários, 15 comunidades, 7 posts, 9 chats, 4 wiki entries, 12 interesses';

END $$;
