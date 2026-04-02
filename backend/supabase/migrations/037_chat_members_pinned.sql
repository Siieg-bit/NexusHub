-- Adicionar colunas de pin pessoal à tabela chat_members
-- (is_pinned_by_user e pinned_at são preferências pessoais, não globais)

ALTER TABLE public.chat_members
  ADD COLUMN IF NOT EXISTS is_pinned_by_user BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

-- Índice para ordenação de chats fixados
CREATE INDEX IF NOT EXISTS idx_chat_members_pinned
  ON public.chat_members(user_id, is_pinned_by_user, pinned_at DESC)
  WHERE is_pinned_by_user = TRUE;

COMMENT ON COLUMN public.chat_members.is_pinned_by_user IS 'Se o usuário fixou este chat no topo da sua lista pessoal';
COMMENT ON COLUMN public.chat_members.pinned_at IS 'Timestamp de quando o usuário fixou o chat (para ordenação)';
