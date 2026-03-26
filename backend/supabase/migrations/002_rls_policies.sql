-- ============================================================================
-- AMINO CLONE - MIGRATION 002: ROW LEVEL SECURITY (RLS)
-- Políticas de segurança para todas as tabelas
-- ============================================================================

-- Habilitar RLS em TODAS as tabelas
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wiki_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_in_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- FUNÇÕES AUXILIARES DE SEGURANÇA
-- ============================================================================

-- Verificar se o usuário é membro de uma comunidade
CREATE OR REPLACE FUNCTION is_community_member(p_community_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.community_members
        WHERE user_id = auth.uid()
        AND community_id = p_community_id
        AND is_banned = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Verificar se o usuário é moderador (curator, leader ou agent) de uma comunidade
CREATE OR REPLACE FUNCTION is_community_moderator(p_community_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.community_members
        WHERE user_id = auth.uid()
        AND community_id = p_community_id
        AND role IN ('curator', 'leader', 'agent')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Verificar se o usuário é leader ou agent de uma comunidade
CREATE OR REPLACE FUNCTION is_community_leader(p_community_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.community_members
        WHERE user_id = auth.uid()
        AND community_id = p_community_id
        AND role IN ('leader', 'agent')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================================
-- POLÍTICAS: profiles
-- ============================================================================

CREATE POLICY "Perfis são visíveis publicamente"
    ON public.profiles FOR SELECT
    USING (TRUE);

CREATE POLICY "Usuários podem editar seu próprio perfil"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ============================================================================
-- POLÍTICAS: user_follows
-- ============================================================================

CREATE POLICY "Follows são visíveis publicamente"
    ON public.user_follows FOR SELECT
    USING (TRUE);

CREATE POLICY "Usuários autenticados podem seguir"
    ON public.user_follows FOR INSERT
    WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Usuários podem deixar de seguir"
    ON public.user_follows FOR DELETE
    USING (auth.uid() = follower_id);

-- ============================================================================
-- POLÍTICAS: communities
-- ============================================================================

CREATE POLICY "Comunidades ativas e pesquisáveis são visíveis"
    ON public.communities FOR SELECT
    USING (is_active = TRUE);

CREATE POLICY "Usuários autenticados podem criar comunidades"
    ON public.communities FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Donos e leaders podem editar comunidades"
    ON public.communities FOR UPDATE
    USING (
        auth.uid() = owner_id
        OR is_community_leader(id)
    );

-- ============================================================================
-- POLÍTICAS: community_members
-- ============================================================================

CREATE POLICY "Membros da comunidade são visíveis"
    ON public.community_members FOR SELECT
    USING (TRUE);

CREATE POLICY "Usuários autenticados podem entrar em comunidades abertas"
    ON public.community_members FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.communities
            WHERE id = community_id
            AND join_type = 'open'
            AND is_active = TRUE
        )
    );

CREATE POLICY "Usuários podem sair de comunidades"
    ON public.community_members FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY "Moderadores podem atualizar membros"
    ON public.community_members FOR UPDATE
    USING (is_community_moderator(community_id));

-- ============================================================================
-- POLÍTICAS: posts
-- ============================================================================

CREATE POLICY "Posts publicados são visíveis para membros"
    ON public.posts FOR SELECT
    USING (
        status = 'published'
        AND is_community_member(community_id)
    );

CREATE POLICY "Membros podem criar posts"
    ON public.posts FOR INSERT
    WITH CHECK (
        auth.uid() = author_id
        AND is_community_member(community_id)
    );

CREATE POLICY "Autores podem editar seus posts"
    ON public.posts FOR UPDATE
    USING (
        auth.uid() = author_id
        OR is_community_moderator(community_id)
    );

CREATE POLICY "Autores e moderadores podem deletar posts"
    ON public.posts FOR DELETE
    USING (
        auth.uid() = author_id
        OR is_community_moderator(community_id)
    );

-- ============================================================================
-- POLÍTICAS: post_likes
-- ============================================================================

CREATE POLICY "Likes são visíveis"
    ON public.post_likes FOR SELECT
    USING (TRUE);

CREATE POLICY "Membros podem dar like"
    ON public.post_likes FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_id
            AND is_community_member(p.community_id)
        )
    );

CREATE POLICY "Usuários podem remover like"
    ON public.post_likes FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- POLÍTICAS: comments
-- ============================================================================

CREATE POLICY "Comentários são visíveis para membros"
    ON public.comments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_id
            AND is_community_member(p.community_id)
        )
    );

CREATE POLICY "Membros podem comentar"
    ON public.comments FOR INSERT
    WITH CHECK (
        auth.uid() = author_id
        AND EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_id
            AND is_community_member(p.community_id)
        )
    );

CREATE POLICY "Autores e moderadores podem editar comentários"
    ON public.comments FOR UPDATE
    USING (
        auth.uid() = author_id
        OR EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_id
            AND is_community_moderator(p.community_id)
        )
    );

CREATE POLICY "Autores e moderadores podem deletar comentários"
    ON public.comments FOR DELETE
    USING (
        auth.uid() = author_id
        OR EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_id
            AND is_community_moderator(p.community_id)
        )
    );

-- ============================================================================
-- POLÍTICAS: comment_likes
-- ============================================================================

CREATE POLICY "Comment likes são visíveis"
    ON public.comment_likes FOR SELECT
    USING (TRUE);

CREATE POLICY "Usuários podem dar like em comentários"
    ON public.comment_likes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem remover like de comentários"
    ON public.comment_likes FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- POLÍTICAS: chat_rooms
-- ============================================================================

CREATE POLICY "Chat rooms visíveis para membros"
    ON public.chat_rooms FOR SELECT
    USING (
        (chat_type = 'community' AND is_community_member(community_id))
        OR EXISTS (
            SELECT 1 FROM public.chat_room_members
            WHERE chat_room_id = id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Membros podem criar chat rooms"
    ON public.chat_rooms FOR INSERT
    WITH CHECK (
        auth.uid() = creator_id
        AND (
            community_id IS NULL
            OR is_community_member(community_id)
        )
    );

CREATE POLICY "Criadores e moderadores podem editar chat rooms"
    ON public.chat_rooms FOR UPDATE
    USING (
        auth.uid() = creator_id
        OR (community_id IS NOT NULL AND is_community_moderator(community_id))
    );

-- ============================================================================
-- POLÍTICAS: chat_room_members
-- ============================================================================

CREATE POLICY "Membros do chat são visíveis"
    ON public.chat_room_members FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.chat_room_members crm
            WHERE crm.chat_room_id = chat_room_id AND crm.user_id = auth.uid()
        )
    );

CREATE POLICY "Usuários podem entrar em chat rooms"
    ON public.chat_room_members FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem sair de chat rooms"
    ON public.chat_room_members FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- POLÍTICAS: messages
-- ============================================================================

CREATE POLICY "Mensagens visíveis para membros do chat"
    ON public.messages FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.chat_room_members
            WHERE chat_room_id = messages.chat_room_id
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Membros do chat podem enviar mensagens"
    ON public.messages FOR INSERT
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM public.chat_room_members
            WHERE chat_room_id = messages.chat_room_id
            AND user_id = auth.uid()
            AND is_muted = FALSE
        )
    );

CREATE POLICY "Remetentes podem deletar suas mensagens"
    ON public.messages FOR UPDATE
    USING (auth.uid() = sender_id);

-- ============================================================================
-- POLÍTICAS: wiki_entries
-- ============================================================================

CREATE POLICY "Wiki visível para membros"
    ON public.wiki_entries FOR SELECT
    USING (is_community_member(community_id));

CREATE POLICY "Membros podem criar wiki entries"
    ON public.wiki_entries FOR INSERT
    WITH CHECK (
        auth.uid() = author_id
        AND is_community_member(community_id)
    );

CREATE POLICY "Autores e moderadores podem editar wiki"
    ON public.wiki_entries FOR UPDATE
    USING (
        auth.uid() = author_id
        OR is_community_moderator(community_id)
    );

-- ============================================================================
-- POLÍTICAS: check_in_history
-- ============================================================================

CREATE POLICY "Usuários veem seu próprio histórico de check-in"
    ON public.check_in_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem fazer check-in"
    ON public.check_in_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- POLÍTICAS: xp_transactions
-- ============================================================================

CREATE POLICY "Usuários veem suas próprias transações de XP"
    ON public.xp_transactions FOR SELECT
    USING (auth.uid() = user_id);

-- ============================================================================
-- POLÍTICAS: notifications
-- ============================================================================

CREATE POLICY "Usuários veem suas próprias notificações"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Sistema pode criar notificações"
    ON public.notifications FOR INSERT
    WITH CHECK (TRUE);

CREATE POLICY "Usuários podem marcar notificações como lidas"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id);

-- ============================================================================
-- POLÍTICAS: reports
-- ============================================================================

CREATE POLICY "Reporters veem seus próprios reports"
    ON public.reports FOR SELECT
    USING (
        auth.uid() = reporter_id
        OR is_community_moderator(community_id)
    );

CREATE POLICY "Membros podem criar reports"
    ON public.reports FOR INSERT
    WITH CHECK (
        auth.uid() = reporter_id
        AND is_community_member(community_id)
    );

CREATE POLICY "Moderadores podem atualizar reports"
    ON public.reports FOR UPDATE
    USING (is_community_moderator(community_id));

-- ============================================================================
-- POLÍTICAS: moderation_logs
-- ============================================================================

CREATE POLICY "Moderadores veem logs de moderação"
    ON public.moderation_logs FOR SELECT
    USING (is_community_moderator(community_id));

CREATE POLICY "Moderadores podem criar logs"
    ON public.moderation_logs FOR INSERT
    WITH CHECK (is_community_moderator(community_id));

-- ============================================================================
-- POLÍTICAS: bookmarks
-- ============================================================================

CREATE POLICY "Usuários veem seus próprios bookmarks"
    ON public.bookmarks FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem criar bookmarks"
    ON public.bookmarks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem remover bookmarks"
    ON public.bookmarks FOR DELETE
    USING (auth.uid() = user_id);
