-- ============================================================================
-- AMINO CLONE - SEED DATA
-- Dados de teste para desenvolvimento
-- NOTA: Execute APÓS as migrations e APÓS criar usuários no Supabase Auth
-- ============================================================================

-- Inserir comunidades de exemplo (substitua owner_id por UUIDs reais do Auth)
-- Estes são exemplos; em produção, os UUIDs virão do Supabase Auth

-- Exemplo de comunidades temáticas (inspiradas no Amino original)
INSERT INTO public.communities (id, name, tagline, description, owner_id, primary_language, theme_color, members_count)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'Anime Brasil',
     'A maior comunidade de anime do Brasil!',
     'Bem-vindo à comunidade Anime Brasil! Aqui discutimos tudo sobre anime, mangá, light novels e cultura otaku.',
     '00000000-0000-0000-0000-000000000099', -- Substituir pelo UUID real
     'pt-BR', '#E74C3C', 0),

    ('00000000-0000-0000-0000-000000000002', 'K-Pop Universe',
     'Seu universo K-Pop começa aqui',
     'Comunidade dedicada a fãs de K-Pop. Compartilhe notícias, fancams, edits e muito mais!',
     '00000000-0000-0000-0000-000000000099',
     'pt-BR', '#9B59B6', 0),

    ('00000000-0000-0000-0000-000000000003', 'Gaming Zone',
     'Gamers unite!',
     'A comunidade para gamers de todos os tipos. PC, Console, Mobile - todos são bem-vindos!',
     '00000000-0000-0000-0000-000000000099',
     'pt-BR', '#2ECC71', 0),

    ('00000000-0000-0000-0000-000000000004', 'Arte & Criatividade',
     'Expresse sua criatividade',
     'Compartilhe suas artes, desenhos, pinturas digitais e receba feedback da comunidade.',
     '00000000-0000-0000-0000-000000000099',
     'pt-BR', '#F39C12', 0),

    ('00000000-0000-0000-0000-000000000005', 'Ciência & Tecnologia',
     'Explorando o futuro juntos',
     'Discussões sobre ciência, tecnologia, programação, IA e o futuro da humanidade.',
     '00000000-0000-0000-0000-000000000099',
     'pt-BR', '#3498DB', 0);

-- ============================================================================
-- NOTA PARA O DESENVOLVEDOR:
-- ============================================================================
-- 1. Primeiro crie usuários no Supabase Auth (via dashboard ou API)
-- 2. Os perfis serão criados automaticamente pelo trigger handle_new_user()
-- 3. Atualize os owner_id das comunidades acima com UUIDs reais
-- 4. Use o app para criar posts, comentários e mensagens de teste
-- 5. Para testar gamificação, chame: SELECT daily_check_in();
-- ============================================================================
