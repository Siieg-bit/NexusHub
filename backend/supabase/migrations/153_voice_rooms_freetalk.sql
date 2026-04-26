-- ============================================================================
-- Migration 153: Voice Rooms (FreeTalk)
--
-- Implementa o sistema de salas de voz estilo "palco" inspirado no OluOlu.
-- Arquitetura:
--   • voice_rooms: metadados da sala (título, host, status, comunidade)
--   • voice_room_members: membros ativos com role, mute e hand_raised
--   • RPCs: create_voice_room, join_voice_room, leave_voice_room,
--           raise_hand_voice_room, accept_speaker_request,
--           mute_voice_room_member, kick_voice_room_member,
--           step_down_from_stage, end_voice_room, get_voice_room_members
-- ============================================================================

-- ─── Tabela principal de salas ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.voice_rooms (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id  UUID REFERENCES public.communities(id) ON DELETE CASCADE,
  host_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title         TEXT NOT NULL DEFAULT 'Free Talk',
  status        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended')),
  agora_channel TEXT,  -- canal Agora.io para esta sala (gerado automaticamente)
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at      TIMESTAMPTZ
);

-- ─── Membros da sala ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.voice_room_members (
  room_id     UUID NOT NULL REFERENCES public.voice_rooms(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'listener' CHECK (role IN ('host', 'speaker', 'listener')),
  is_muted    BOOLEAN NOT NULL DEFAULT true,
  hand_raised BOOLEAN NOT NULL DEFAULT false,
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

-- ─── Índices ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_voice_rooms_community
  ON public.voice_rooms(community_id) WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_voice_rooms_host
  ON public.voice_rooms(host_id) WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_voice_room_members_room
  ON public.voice_room_members(room_id);

-- ─── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.voice_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voice_room_members ENABLE ROW LEVEL SECURITY;

-- voice_rooms: qualquer autenticado pode ver salas ativas
CREATE POLICY "voice_rooms_select" ON public.voice_rooms
  FOR SELECT TO authenticated USING (true);

-- voice_rooms: apenas o host pode atualizar
CREATE POLICY "voice_rooms_update_host" ON public.voice_rooms
  FOR UPDATE TO authenticated USING (host_id = auth.uid());

-- voice_room_members: qualquer autenticado pode ver membros
CREATE POLICY "voice_room_members_select" ON public.voice_room_members
  FOR SELECT TO authenticated USING (true);

-- voice_room_members: usuário pode inserir a si mesmo
CREATE POLICY "voice_room_members_insert_self" ON public.voice_room_members
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

-- voice_room_members: usuário pode atualizar a si mesmo
CREATE POLICY "voice_room_members_update_self" ON public.voice_room_members
  FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- voice_room_members: usuário pode deletar a si mesmo (sair)
CREATE POLICY "voice_room_members_delete_self" ON public.voice_room_members
  FOR DELETE TO authenticated USING (user_id = auth.uid());

-- ─── RPC: create_voice_room ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_voice_room(
  p_community_id UUID DEFAULT NULL,
  p_title        TEXT DEFAULT 'Free Talk'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_room_id UUID;
  v_channel TEXT;
BEGIN
  -- Gerar canal Agora único
  v_channel := 'freetalk_' || replace(gen_random_uuid()::text, '-', '');

  -- Criar a sala
  INSERT INTO public.voice_rooms (community_id, host_id, title, agora_channel)
  VALUES (p_community_id, auth.uid(), p_title, v_channel)
  RETURNING id INTO v_room_id;

  -- Adicionar o host como membro com role 'host' e microfone ativo
  INSERT INTO public.voice_room_members (room_id, user_id, role, is_muted)
  VALUES (v_room_id, auth.uid(), 'host', false);

  RETURN jsonb_build_object(
    'room_id', v_room_id,
    'title', p_title,
    'host_id', auth.uid(),
    'agora_channel', v_channel
  );
END;
$$;

-- ─── RPC: join_voice_room ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.join_voice_room(
  p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_room public.voice_rooms;
BEGIN
  -- Verificar se a sala existe e está ativa
  SELECT * INTO v_room FROM public.voice_rooms
  WHERE id = p_room_id AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sala não encontrada ou já encerrada';
  END IF;

  -- Inserir ou atualizar membro (upsert)
  INSERT INTO public.voice_room_members (room_id, user_id, role, is_muted)
  VALUES (p_room_id, auth.uid(), 'listener', true)
  ON CONFLICT (room_id, user_id) DO UPDATE
    SET joined_at = now();

  RETURN jsonb_build_object(
    'room_id', p_room_id,
    'title', v_room.title,
    'host_id', v_room.host_id,
    'agora_channel', v_room.agora_channel,
    'role', 'listener'
  );
END;
$$;

-- ─── RPC: leave_voice_room ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.leave_voice_room(
  p_room_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.voice_room_members
  WHERE room_id = p_room_id AND user_id = auth.uid();
END;
$$;

-- ─── RPC: raise_hand_voice_room ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.raise_hand_voice_room(
  p_room_id UUID,
  p_raised  BOOLEAN DEFAULT true
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.voice_room_members
  SET hand_raised = p_raised
  WHERE room_id = p_room_id
    AND user_id = auth.uid()
    AND role = 'listener';
END;
$$;

-- ─── RPC: accept_speaker_request ─────────────────────────────────────────────
-- Apenas o host pode aceitar pedidos de fala
CREATE OR REPLACE FUNCTION public.accept_speaker_request(
  p_room_id     UUID,
  p_target_user UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_host_id UUID;
BEGIN
  -- Verificar se o chamador é o host
  SELECT host_id INTO v_host_id FROM public.voice_rooms
  WHERE id = p_room_id AND status = 'active';

  IF v_host_id != auth.uid() THEN
    RAISE EXCEPTION 'Apenas o host pode aceitar pedidos de fala';
  END IF;

  -- Promover listener a speaker e ativar microfone
  UPDATE public.voice_room_members
  SET role = 'speaker', is_muted = false, hand_raised = false
  WHERE room_id = p_room_id AND user_id = p_target_user AND role = 'listener';
END;
$$;

-- ─── RPC: mute_voice_room_member ─────────────────────────────────────────────
-- Host pode mutar qualquer membro; membro pode mutar/desmutar a si mesmo
CREATE OR REPLACE FUNCTION public.mute_voice_room_member(
  p_room_id     UUID,
  p_target_user UUID,
  p_muted       BOOLEAN DEFAULT true
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_host_id UUID;
BEGIN
  SELECT host_id INTO v_host_id FROM public.voice_rooms
  WHERE id = p_room_id AND status = 'active';

  -- Apenas host ou o próprio usuário podem mutar
  IF v_host_id != auth.uid() AND p_target_user != auth.uid() THEN
    RAISE EXCEPTION 'Sem permissão para mutar este membro';
  END IF;

  UPDATE public.voice_room_members
  SET is_muted = p_muted
  WHERE room_id = p_room_id AND user_id = p_target_user;
END;
$$;

-- ─── RPC: kick_voice_room_member ─────────────────────────────────────────────
-- Apenas o host pode expulsar membros
CREATE OR REPLACE FUNCTION public.kick_voice_room_member(
  p_room_id     UUID,
  p_target_user UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_host_id UUID;
BEGIN
  SELECT host_id INTO v_host_id FROM public.voice_rooms
  WHERE id = p_room_id AND status = 'active';

  IF v_host_id != auth.uid() THEN
    RAISE EXCEPTION 'Apenas o host pode expulsar membros';
  END IF;

  DELETE FROM public.voice_room_members
  WHERE room_id = p_room_id AND user_id = p_target_user;
END;
$$;

-- ─── RPC: step_down_from_stage ───────────────────────────────────────────────
-- Speaker pode voltar a ser listener voluntariamente
CREATE OR REPLACE FUNCTION public.step_down_from_stage(
  p_room_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.voice_room_members
  SET role = 'listener', is_muted = true, hand_raised = false
  WHERE room_id = p_room_id AND user_id = auth.uid() AND role = 'speaker';
END;
$$;

-- ─── RPC: end_voice_room ─────────────────────────────────────────────────────
-- Apenas o host pode encerrar a sala
CREATE OR REPLACE FUNCTION public.end_voice_room(
  p_room_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_host_id UUID;
BEGIN
  SELECT host_id INTO v_host_id FROM public.voice_rooms
  WHERE id = p_room_id AND status = 'active';

  IF v_host_id != auth.uid() THEN
    RAISE EXCEPTION 'Apenas o host pode encerrar a sala';
  END IF;

  -- Encerrar a sala
  UPDATE public.voice_rooms
  SET status = 'ended', ended_at = now()
  WHERE id = p_room_id;

  -- Remover todos os membros
  DELETE FROM public.voice_room_members WHERE room_id = p_room_id;
END;
$$;

-- ─── RPC: get_voice_room_members ─────────────────────────────────────────────
-- Retorna membros com perfil embutido
CREATE OR REPLACE FUNCTION public.get_voice_room_members(
  p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'user_id', m.user_id,
      'role', m.role,
      'is_muted', m.is_muted,
      'hand_raised', m.hand_raised,
      'joined_at', m.joined_at,
      'profile', jsonb_build_object(
        'nickname', p.nickname,
        'icon_url', p.icon_url
      )
    )
    ORDER BY
      CASE m.role WHEN 'host' THEN 0 WHEN 'speaker' THEN 1 ELSE 2 END,
      m.joined_at ASC
  )
  INTO v_result
  FROM public.voice_room_members m
  JOIN public.profiles p ON p.id = m.user_id
  WHERE m.room_id = p_room_id;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── Realtime: habilitar para voice_room_members ──────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_room_members;

-- ─── Comentários ─────────────────────────────────────────────────────────────
COMMENT ON TABLE public.voice_rooms IS
  'Salas de voz estilo palco (FreeTalk) — inspirado no OluOlu';
COMMENT ON TABLE public.voice_room_members IS
  'Membros ativos de uma sala de voz com role, mute e hand_raised';
