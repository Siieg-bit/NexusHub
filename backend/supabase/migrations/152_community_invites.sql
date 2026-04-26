-- =============================================================================
-- Migration 152: Community Invites
-- =============================================================================

-- Tabela de convites
CREATE TABLE IF NOT EXISTS public.community_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    code TEXT UNIQUE NOT NULL,
    uses INTEGER DEFAULT 0,
    max_uses INTEGER, -- NULL para ilimitado
    expires_at TIMESTAMPTZ, -- NULL para nunca expirar
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.community_invites ENABLE ROW LEVEL SECURITY;

-- Políticas
CREATE POLICY "Qualquer um pode ver convites" ON public.community_invites
    FOR SELECT USING (true);

CREATE POLICY "Membros podem criar convites" ON public.community_invites
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.community_members
            WHERE community_id = community_invites.community_id
            AND profile_id = auth.uid()
        )
    );

-- RPC para gerar ou obter convite existente
CREATE OR REPLACE FUNCTION public.get_or_create_community_invite(
    p_community_id UUID
) RETURNS TEXT AS $$
DECLARE
    v_code TEXT;
BEGIN
    -- Tenta pegar um convite ilimitado já existente do usuário para esta comunidade
    SELECT code INTO v_code
    FROM public.community_invites
    WHERE community_id = p_community_id
    AND creator_id = auth.uid()
    AND max_uses IS NULL
    AND (expires_at IS NULL OR expires_at > now())
    LIMIT 1;

    IF v_code IS NOT NULL THEN
        RETURN v_code;
    END IF;

    -- Se não existe, cria um novo
    v_code := substring(md5(random()::text || clock_timestamp()::text) from 1 for 8);
    
    INSERT INTO public.community_invites (community_id, creator_id, code)
    VALUES (p_community_id, auth.uid(), v_code);

    RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_or_create_community_invite(UUID) TO authenticated;
