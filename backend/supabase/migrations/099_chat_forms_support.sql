-- NexusHub — Migração 099: Suporte a Formulários no Chat
-- ========================================================
-- Objetivo: Adicionar tipo de mensagem 'form' e tabelas para armazenar/responder formulários

-- ========================
-- 1. ADICIONAR TIPO FORM AO ENUM
-- ========================

-- Adicionar novo tipo ao enum chat_message_type
ALTER TYPE public.chat_message_type ADD VALUE 'form' BEFORE 'share_url';

-- ========================
-- 2. CRIAR TABELA CHAT_FORMS
-- ========================

CREATE TABLE IF NOT EXISTS public.chat_forms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  chat_thread_id UUID NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Dados do formulário
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  fields JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array de {id, label, type, required, options}
  
  -- Configurações
  allow_multiple_responses BOOLEAN DEFAULT FALSE,
  show_responses_to_creator BOOLEAN DEFAULT TRUE,
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_forms_message ON public.chat_forms(message_id);
CREATE INDEX idx_chat_forms_thread ON public.chat_forms(chat_thread_id);
CREATE INDEX idx_chat_forms_creator ON public.chat_forms(creator_id);

-- ========================
-- 3. CRIAR TABELA CHAT_FORM_RESPONSES
-- ========================

CREATE TABLE IF NOT EXISTS public.chat_form_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id UUID NOT NULL REFERENCES public.chat_forms(id) ON DELETE CASCADE,
  responder_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Dados da resposta
  responses JSONB NOT NULL DEFAULT '{}', -- {field_id: value, ...}
  
  -- Metadata
  responded_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Índice único para evitar duplicatas se allow_multiple_responses = false
  UNIQUE(form_id, responder_id)
);

CREATE INDEX idx_chat_form_responses_form ON public.chat_form_responses(form_id);
CREATE INDEX idx_chat_form_responses_responder ON public.chat_form_responses(responder_id);

-- ========================
-- 4. HABILITAR RLS
-- ========================

ALTER TABLE public.chat_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_form_responses ENABLE ROW LEVEL SECURITY;

-- RLS para chat_forms: membros do chat podem ver
CREATE POLICY "chat_forms_select_members" ON public.chat_forms
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_thread_members
      WHERE chat_thread_id = chat_forms.chat_thread_id
        AND user_id = auth.uid()
    )
  );

-- RLS para chat_forms: apenas criador pode inserir
CREATE POLICY "chat_forms_insert_creator" ON public.chat_forms
  FOR INSERT
  WITH CHECK (creator_id = auth.uid());

-- RLS para chat_forms: apenas criador pode atualizar
CREATE POLICY "chat_forms_update_creator" ON public.chat_forms
  FOR UPDATE
  USING (creator_id = auth.uid())
  WITH CHECK (creator_id = auth.uid());

-- RLS para chat_form_responses: usuário pode ver suas próprias respostas
CREATE POLICY "chat_form_responses_select_own" ON public.chat_form_responses
  FOR SELECT
  USING (responder_id = auth.uid());

-- RLS para chat_form_responses: criador do form pode ver respostas
CREATE POLICY "chat_form_responses_select_creator" ON public.chat_form_responses
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_forms cf
      WHERE cf.id = form_id AND cf.creator_id = auth.uid()
    )
  );

-- RLS para chat_form_responses: usuário autenticado pode inserir respostas
CREATE POLICY "chat_form_responses_insert_authenticated" ON public.chat_form_responses
  FOR INSERT
  WITH CHECK (
    responder_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.chat_thread_members
      WHERE chat_thread_id = (
        SELECT chat_thread_id FROM public.chat_forms WHERE id = form_id
      )
      AND user_id = auth.uid()
    )
  );

-- ========================
-- 5. RPC CREATE_CHAT_FORM
-- ========================

CREATE OR REPLACE FUNCTION public.create_chat_form(
  p_chat_thread_id UUID,
  p_title TEXT,
  p_description TEXT DEFAULT '',
  p_fields JSONB DEFAULT '[]'::jsonb,
  p_allow_multiple_responses BOOLEAN DEFAULT FALSE,
  p_show_responses_to_creator BOOLEAN DEFAULT TRUE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_form_id UUID;
  v_message_id UUID;
  v_result jsonb;
BEGIN
  -- Validar autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Validar que usuário é membro do chat
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_thread_members
    WHERE chat_thread_id = p_chat_thread_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Você não é membro deste chat';
  END IF;

  -- Validar que chat existe
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_threads WHERE id = p_chat_thread_id
  ) THEN
    RAISE EXCEPTION 'Chat não encontrado';
  END IF;

  -- Validar fields
  IF jsonb_typeof(p_fields) <> 'array' THEN
    RAISE EXCEPTION 'Fields deve ser um array JSON';
  END IF;

  -- Criar formulário
  INSERT INTO public.chat_forms (
    chat_thread_id,
    creator_id,
    title,
    description,
    fields,
    allow_multiple_responses,
    show_responses_to_creator
  ) VALUES (
    p_chat_thread_id,
    v_user_id,
    p_title,
    p_description,
    p_fields,
    p_allow_multiple_responses,
    p_show_responses_to_creator
  ) RETURNING id INTO v_form_id;

  -- Criar mensagem de sistema para o formulário
  INSERT INTO public.chat_messages (
    chat_thread_id,
    sender_id,
    type,
    content,
    extra_data
  ) VALUES (
    p_chat_thread_id,
    v_user_id,
    'form'::public.chat_message_type,
    p_title,
    jsonb_build_object('form_id', v_form_id)
  ) RETURNING id INTO v_message_id;

  -- Atualizar form com message_id
  UPDATE public.chat_forms SET message_id = v_message_id WHERE id = v_form_id;

  v_result := jsonb_build_object(
    'success', true,
    'form_id', v_form_id,
    'message_id', v_message_id
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_chat_form(UUID, TEXT, TEXT, JSONB, BOOLEAN, BOOLEAN) TO authenticated;

-- ========================
-- 6. RPC RESPOND_TO_CHAT_FORM
-- ========================

CREATE OR REPLACE FUNCTION public.respond_to_chat_form(
  p_form_id UUID,
  p_responses JSONB
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_response_id UUID;
  v_allow_multiple BOOLEAN;
  v_result jsonb;
BEGIN
  -- Validar autenticação
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Validar que form existe
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_forms WHERE id = p_form_id
  ) THEN
    RAISE EXCEPTION 'Formulário não encontrado';
  END IF;

  -- Obter configurações do form
  SELECT allow_multiple_responses INTO v_allow_multiple
  FROM public.chat_forms WHERE id = p_form_id;

  -- Verificar se usuário já respondeu (se não permitir múltiplas)
  IF NOT v_allow_multiple AND EXISTS (
    SELECT 1 FROM public.chat_form_responses
    WHERE form_id = p_form_id AND responder_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Você já respondeu este formulário';
  END IF;

  -- Validar que responses é um objeto JSON
  IF jsonb_typeof(p_responses) <> 'object' THEN
    RAISE EXCEPTION 'Responses deve ser um objeto JSON';
  END IF;

  -- Inserir resposta
  INSERT INTO public.chat_form_responses (
    form_id,
    responder_id,
    responses
  ) VALUES (
    p_form_id,
    v_user_id,
    p_responses
  ) RETURNING id INTO v_response_id;

  v_result := jsonb_build_object(
    'success', true,
    'response_id', v_response_id
  );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.respond_to_chat_form(UUID, JSONB) TO authenticated;

-- ========================
-- 7. RPC GET_CHAT_FORM_RESPONSES
-- ========================

CREATE OR REPLACE FUNCTION public.get_chat_form_responses(
  p_form_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_creator BOOLEAN;
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  -- Verificar se usuário é criador do form
  SELECT creator_id = v_user_id INTO v_is_creator
  FROM public.chat_forms WHERE id = p_form_id;

  IF v_is_creator IS NULL THEN
    RAISE EXCEPTION 'Formulário não encontrado';
  END IF;

  -- Se não é criador, retornar apenas sua resposta
  IF NOT v_is_creator THEN
    v_result := jsonb_build_object(
      'responses', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'response_id', id,
            'responses', responses,
            'responded_at', responded_at
          )
        )
        FROM public.chat_form_responses
        WHERE form_id = p_form_id AND responder_id = v_user_id
      ),
      'total_responses', (
        SELECT COUNT(*) FROM public.chat_form_responses WHERE form_id = p_form_id
      )
    );
  ELSE
    -- Se é criador, retornar todas as respostas
    v_result := jsonb_build_object(
      'responses', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'response_id', cfr.id,
            'responder_id', cfr.responder_id,
            'responder_name', p.display_name,
            'responses', cfr.responses,
            'responded_at', cfr.responded_at
          )
        )
        FROM public.chat_form_responses cfr
        JOIN public.profiles p ON cfr.responder_id = p.id
        WHERE cfr.form_id = p_form_id
      ),
      'total_responses', (
        SELECT COUNT(*) FROM public.chat_form_responses WHERE form_id = p_form_id
      )
    );
  END IF;

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_chat_form_responses(UUID) TO authenticated;

-- ========================
-- 8. COMENTÁRIOS
-- ========================

COMMENT ON TABLE public.chat_forms IS 'Armazena formulários criados em chats';
COMMENT ON TABLE public.chat_form_responses IS 'Armazena respostas de usuários para formulários';
COMMENT ON FUNCTION public.create_chat_form(UUID, TEXT, TEXT, JSONB, BOOLEAN, BOOLEAN) IS 'Cria novo formulário em um chat';
COMMENT ON FUNCTION public.respond_to_chat_form(UUID, JSONB) IS 'Registra resposta de usuário para um formulário';
COMMENT ON FUNCTION public.get_chat_form_responses(UUID) IS 'Obtém respostas de um formulário (criador vê todas, outros veem apenas sua)';
