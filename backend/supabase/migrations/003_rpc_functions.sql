-- ============================================================================
-- AMINO CLONE - MIGRATION 003: FUNÇÕES RPC
-- Lógica de negócio no banco de dados
-- ============================================================================

-- ============================================================================
-- RPC: Check-in Diário (Gamificação)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.daily_check_in(p_community_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_today DATE := CURRENT_DATE;
    v_yesterday DATE := CURRENT_DATE - INTERVAL '1 day';
    v_consecutive INT;
    v_xp_earned INT;
    v_coins_earned INT;
    v_already_checked BOOLEAN;
    v_last_check DATE;
BEGIN
    -- Verificar se já fez check-in hoje
    SELECT EXISTS (
        SELECT 1 FROM public.check_in_history
        WHERE user_id = v_user_id
        AND checked_in_at = v_today
        AND (community_id IS NOT DISTINCT FROM p_community_id)
    ) INTO v_already_checked;

    IF v_already_checked THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Você já fez check-in hoje!',
            'already_checked', TRUE
        );
    END IF;

    -- Verificar streak (dias consecutivos)
    SELECT consecutive_check_in_days, last_check_in_at::DATE
    INTO v_consecutive, v_last_check
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_last_check = v_yesterday THEN
        v_consecutive := COALESCE(v_consecutive, 0) + 1;
    ELSE
        v_consecutive := 1;
    END IF;

    -- Calcular XP e coins baseado no streak
    v_xp_earned := LEAST(5 + (v_consecutive * 2), 50);
    v_coins_earned := CASE
        WHEN v_consecutive >= 7 THEN 10
        WHEN v_consecutive >= 3 THEN 5
        ELSE 2
    END;

    -- Registrar check-in
    INSERT INTO public.check_in_history (user_id, community_id, checked_in_at, xp_earned, coins_earned, streak_day)
    VALUES (v_user_id, p_community_id, v_today, v_xp_earned, v_coins_earned, v_consecutive);

    -- Atualizar perfil
    UPDATE public.profiles SET
        xp = xp + v_xp_earned,
        coins = coins + v_coins_earned,
        reputation = reputation + v_xp_earned,
        consecutive_check_in_days = v_consecutive,
        last_check_in_at = NOW()
    WHERE id = v_user_id;

    -- Registrar transação de XP
    INSERT INTO public.xp_transactions (user_id, community_id, action, xp_amount, coins_amount, description)
    VALUES (v_user_id, p_community_id, 'daily_check_in', v_xp_earned, v_coins_earned,
            'Check-in diário - Dia ' || v_consecutive || ' consecutivo');

    -- Verificar level up
    PERFORM check_level_up(v_user_id);

    RETURN jsonb_build_object(
        'success', TRUE,
        'consecutive_days', v_consecutive,
        'xp_earned', v_xp_earned,
        'coins_earned', v_coins_earned,
        'message', 'Check-in realizado! Dia ' || v_consecutive || ' consecutivo.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Verificar e aplicar Level Up
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_level_up(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_current_xp INT;
    v_current_level INT;
    v_new_level INT;
    v_xp_thresholds INT[] := ARRAY[0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5200,
                                     6500, 8000, 9700, 11600, 13700, 16000, 18500, 21200,
                                     24100, 27200, 30500];
BEGIN
    SELECT xp, global_level INTO v_current_xp, v_current_level
    FROM public.profiles WHERE id = p_user_id;

    v_new_level := 1;
    FOR i IN REVERSE array_length(v_xp_thresholds, 1)..1 LOOP
        IF v_current_xp >= v_xp_thresholds[i] THEN
            v_new_level := i;
            EXIT;
        END IF;
    END LOOP;

    IF v_new_level > v_current_level THEN
        UPDATE public.profiles SET global_level = v_new_level WHERE id = p_user_id;

        -- Notificação de level up
        INSERT INTO public.notifications (user_id, notification_type, title, body, data)
        VALUES (p_user_id, 'level_up', 'Level Up!',
                'Parabéns! Você alcançou o nível ' || v_new_level || '!',
                jsonb_build_object('new_level', v_new_level, 'old_level', v_current_level));
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Entrar em uma comunidade
-- ============================================================================

CREATE OR REPLACE FUNCTION public.join_community(p_community_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_join_type community_join_type;
    v_is_active BOOLEAN;
    v_already_member BOOLEAN;
BEGIN
    -- Verificar se a comunidade existe e está ativa
    SELECT join_type, is_active INTO v_join_type, v_is_active
    FROM public.communities WHERE id = p_community_id;

    IF NOT FOUND OR NOT v_is_active THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Comunidade não encontrada ou inativa.');
    END IF;

    -- Verificar se já é membro
    SELECT EXISTS (
        SELECT 1 FROM public.community_members
        WHERE user_id = v_user_id AND community_id = p_community_id
    ) INTO v_already_member;

    IF v_already_member THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Você já é membro desta comunidade.');
    END IF;

    -- Verificar tipo de entrada
    IF v_join_type != 'open' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Esta comunidade requer convite ou aprovação.');
    END IF;

    -- Inserir como membro
    INSERT INTO public.community_members (user_id, community_id, role)
    VALUES (v_user_id, p_community_id, 'member');

    -- XP por entrar em comunidade
    UPDATE public.profiles SET xp = xp + 5, reputation = reputation + 2
    WHERE id = v_user_id;

    INSERT INTO public.xp_transactions (user_id, community_id, action, xp_amount, description)
    VALUES (v_user_id, p_community_id, 'join_community', 5, 'Entrou em uma nova comunidade');

    RETURN jsonb_build_object('success', TRUE, 'message', 'Bem-vindo à comunidade!');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Sair de uma comunidade
-- ============================================================================

CREATE OR REPLACE FUNCTION public.leave_community(p_community_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_owner BOOLEAN;
BEGIN
    -- Verificar se é o dono
    SELECT EXISTS (
        SELECT 1 FROM public.communities
        WHERE id = p_community_id AND owner_id = v_user_id
    ) INTO v_is_owner;

    IF v_is_owner THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'O dono não pode sair da comunidade. Transfira a propriedade primeiro.');
    END IF;

    DELETE FROM public.community_members
    WHERE user_id = v_user_id AND community_id = p_community_id;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Você saiu da comunidade.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Toggle Like em Post
-- ============================================================================

CREATE OR REPLACE FUNCTION public.toggle_post_like(p_post_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_already_liked BOOLEAN;
    v_new_count INT;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.post_likes
        WHERE user_id = v_user_id AND post_id = p_post_id
    ) INTO v_already_liked;

    IF v_already_liked THEN
        DELETE FROM public.post_likes WHERE user_id = v_user_id AND post_id = p_post_id;
    ELSE
        INSERT INTO public.post_likes (user_id, post_id) VALUES (v_user_id, p_post_id);
    END IF;

    SELECT likes_count INTO v_new_count FROM public.posts WHERE id = p_post_id;

    RETURN jsonb_build_object(
        'liked', NOT v_already_liked,
        'likes_count', v_new_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Buscar feed da comunidade com paginação
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_community_feed(
    p_community_id UUID,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20,
    p_sort VARCHAR DEFAULT 'recent'
)
RETURNS JSONB AS $$
DECLARE
    v_offset INT := (p_page - 1) * p_page_size;
    v_result JSONB;
BEGIN
    SELECT jsonb_agg(post_data) INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', p.id,
            'title', p.title,
            'content', LEFT(p.content, 300),
            'media_urls', p.media_urls,
            'post_type', p.post_type,
            'feature_type', p.feature_type,
            'likes_count', p.likes_count,
            'comments_count', p.comments_count,
            'views_count', p.views_count,
            'created_at', p.created_at,
            'author', jsonb_build_object(
                'id', pr.id,
                'nickname', pr.nickname,
                'amino_id', pr.amino_id,
                'avatar_url', pr.avatar_url,
                'global_level', pr.global_level
            ),
            'is_liked', EXISTS (
                SELECT 1 FROM public.post_likes pl
                WHERE pl.post_id = p.id AND pl.user_id = auth.uid()
            )
        ) AS post_data
        FROM public.posts p
        JOIN public.profiles pr ON p.author_id = pr.id
        WHERE p.community_id = p_community_id
        AND p.status = 'published'
        ORDER BY
            CASE WHEN p_sort = 'popular' THEN p.likes_count END DESC NULLS LAST,
            CASE WHEN p_sort = 'recent' THEN p.created_at END DESC NULLS LAST,
            p.created_at DESC
        LIMIT p_page_size
        OFFSET v_offset
    ) sub;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================================
-- RPC: Buscar comunidades sugeridas/populares
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_suggested_communities(
    p_limit INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_agg(community_data) INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', c.id,
            'name', c.name,
            'tagline', c.tagline,
            'icon_url', c.icon_url,
            'banner_url', c.banner_url,
            'members_count', c.members_count,
            'online_members_count', c.online_members_count,
            'theme_color', c.theme_color,
            'is_member', EXISTS (
                SELECT 1 FROM public.community_members cm
                WHERE cm.community_id = c.id AND cm.user_id = auth.uid()
            )
        ) AS community_data
        FROM public.communities c
        WHERE c.is_active = TRUE
        AND c.is_searchable = TRUE
        ORDER BY c.members_count DESC
        LIMIT p_limit
    ) sub;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================================
-- RPC: Buscar perfil completo do usuário
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_profile(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', p.id,
        'amino_id', p.amino_id,
        'nickname', p.nickname,
        'avatar_url', p.avatar_url,
        'banner_url', p.banner_url,
        'bio', p.bio,
        'global_level', p.global_level,
        'reputation', p.reputation,
        'xp', p.xp,
        'coins', p.coins,
        'online_status', p.online_status,
        'is_verified', p.is_verified,
        'is_premium', p.is_premium,
        'consecutive_check_in_days', p.consecutive_check_in_days,
        'posts_count', p.posts_count,
        'comments_count', p.comments_count,
        'followers_count', p.followers_count,
        'following_count', p.following_count,
        'communities_count', p.communities_count,
        'created_at', p.created_at,
        'is_following', EXISTS (
            SELECT 1 FROM public.user_follows uf
            WHERE uf.follower_id = auth.uid() AND uf.following_id = p_user_id
        ),
        'is_followed_by', EXISTS (
            SELECT 1 FROM public.user_follows uf
            WHERE uf.follower_id = p_user_id AND uf.following_id = auth.uid()
        )
    ) INTO v_result
    FROM public.profiles p
    WHERE p.id = p_user_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================================
-- RPC: Ação de moderação
-- ============================================================================

CREATE OR REPLACE FUNCTION public.moderate_user(
    p_community_id UUID,
    p_target_user_id UUID,
    p_action moderation_action,
    p_reason TEXT DEFAULT NULL,
    p_duration_hours INT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_moderator_id UUID := auth.uid();
BEGIN
    -- Verificar se é moderador
    IF NOT is_community_moderator(p_community_id) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Sem permissão para moderar.');
    END IF;

    -- Aplicar ação
    CASE p_action
        WHEN 'mute' THEN
            UPDATE public.community_members
            SET is_muted = TRUE,
                muted_until = CASE
                    WHEN p_duration_hours IS NOT NULL
                    THEN NOW() + (p_duration_hours || ' hours')::INTERVAL
                    ELSE NULL
                END
            WHERE user_id = p_target_user_id AND community_id = p_community_id;

        WHEN 'ban' THEN
            UPDATE public.community_members
            SET is_banned = TRUE,
                banned_until = CASE
                    WHEN p_duration_hours IS NOT NULL
                    THEN NOW() + (p_duration_hours || ' hours')::INTERVAL
                    ELSE NULL
                END
            WHERE user_id = p_target_user_id AND community_id = p_community_id;

        WHEN 'warn' THEN
            INSERT INTO public.notifications (user_id, actor_id, notification_type, title, body, data)
            VALUES (p_target_user_id, v_moderator_id, 'moderation', 'Aviso de Moderação',
                    COALESCE(p_reason, 'Você recebeu um aviso dos moderadores.'),
                    jsonb_build_object('community_id', p_community_id, 'action', 'warn'));

        WHEN 'delete_content' THEN
            NULL; -- Implementado via chamada separada
    END CASE;

    -- Registrar log de moderação
    INSERT INTO public.moderation_logs (community_id, moderator_id, target_user_id, action, reason)
    VALUES (p_community_id, v_moderator_id, p_target_user_id, p_action, p_reason);

    RETURN jsonb_build_object('success', TRUE, 'message', 'Ação de moderação aplicada.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Buscar leaderboard da comunidade
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
    p_community_id UUID,
    p_limit INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_agg(member_data) INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'rank', ROW_NUMBER() OVER (ORDER BY cm.reputation DESC),
            'user_id', p.id,
            'nickname', p.nickname,
            'amino_id', p.amino_id,
            'avatar_url', p.avatar_url,
            'global_level', p.global_level,
            'community_reputation', cm.reputation,
            'role', cm.role
        ) AS member_data
        FROM public.community_members cm
        JOIN public.profiles p ON cm.user_id = p.id
        WHERE cm.community_id = p_community_id
        AND cm.is_banned = FALSE
        ORDER BY cm.reputation DESC
        LIMIT p_limit
    ) sub;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================================
-- RPC: Pesquisa global
-- ============================================================================

CREATE OR REPLACE FUNCTION public.global_search(
    p_query TEXT,
    p_type VARCHAR DEFAULT 'all',
    p_limit INT DEFAULT 20
)
RETURNS JSONB AS $$
DECLARE
    v_communities JSONB;
    v_users JSONB;
    v_posts JSONB;
BEGIN
    IF p_type IN ('all', 'communities') THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', c.id, 'name', c.name, 'tagline', c.tagline,
            'icon_url', c.icon_url, 'members_count', c.members_count,
            'type', 'community'
        )) INTO v_communities
        FROM public.communities c
        WHERE c.is_active = TRUE AND c.is_searchable = TRUE
        AND (c.name ILIKE '%' || p_query || '%' OR c.tagline ILIKE '%' || p_query || '%')
        LIMIT p_limit;
    END IF;

    IF p_type IN ('all', 'users') THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', p.id, 'nickname', p.nickname, 'amino_id', p.amino_id,
            'avatar_url', p.avatar_url, 'global_level', p.global_level,
            'type', 'user'
        )) INTO v_users
        FROM public.profiles p
        WHERE p.nickname ILIKE '%' || p_query || '%' OR p.amino_id ILIKE '%' || p_query || '%'
        LIMIT p_limit;
    END IF;

    IF p_type IN ('all', 'posts') THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', po.id, 'title', po.title, 'content', LEFT(po.content, 200),
            'community_id', po.community_id, 'likes_count', po.likes_count,
            'type', 'post'
        )) INTO v_posts
        FROM public.posts po
        WHERE po.status = 'published'
        AND (po.title ILIKE '%' || p_query || '%' OR po.content ILIKE '%' || p_query || '%')
        LIMIT p_limit;
    END IF;

    RETURN jsonb_build_object(
        'communities', COALESCE(v_communities, '[]'::JSONB),
        'users', COALESCE(v_users, '[]'::JSONB),
        'posts', COALESCE(v_posts, '[]'::JSONB)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
