# NexusHub — Relatório de Implementação (Sessão 034)

**Data:** 01/04/2026  
**Status:** ✅ Concluído — `flutter analyze`: 0 issues · `flutter test`: 234 passed

---

## Resumo das Mudanças

### 1. Limpeza do Banco de Dados

| Item | Resultado |
|------|-----------|
| Chats de seed deletados | 4 de 4 (Meggie3524, K-Pop Fan Chat, Anime General Chat, Anime Theatre) |
| Comunidades restantes | 2 (Anime Amino, K-Pop Amino) |
| Método utilizado | Secret key do Supabase (bypass RLS) |

**Observação técnica:** As chaves legadas (anon/service_role) foram desativadas pelo Supabase em 30/03/2026. O projeto agora usa `sb_publishable_*` e `sb_secret_*`.

---

### 2. Migração 034 — Backend

**Arquivo:** `backend/supabase/migrations/034_chat_admin_delete_and_create_public.sql`  
**Aplicada via:** Supabase Management API (Personal Access Token)

| Objeto | Tipo | Descrição |
|--------|------|-----------|
| `chat_threads_delete_host_or_admin` | RLS Policy (DELETE) | Permite deletar chat se `host_id = auth.uid()` **ou** `is_team_member()` |
| `create_public_chat` | RPC (SECURITY DEFINER) | Cria chat público em uma comunidade; valida membership do usuário |

**Políticas finais em `chat_threads`:**
- `[SELECT]` chat_threads_select — `true` (todos veem)
- `[INSERT]` chat_threads_insert — `host_id = auth.uid()`
- `[UPDATE]` chat_threads_update — `host_id = auth.uid()`
- `[DELETE]` chat_threads_delete_host_or_admin — `host_id = auth.uid() OR is_team_member()`

---

### 3. Widget `CommunityLiveChats` — Correção de Query

**Arquivo:** `frontend/lib/features/communities/widgets/community_live_chats.dart`

**Mudanças:**
- Query agora filtra `.eq('type', 'public')` — DMs e grupos privados não aparecem mais
- Adicionado cabeçalho "Chats Públicos" com botão **Criar** (verde, pill-shaped)
- Quando não há chats públicos, exibe placeholder clicável "Toque para criar o primeiro"
- Seção sempre visível (antes sumia quando `_chats.isEmpty`)
- Limite aumentado de 6 para 10 chats

---

### 4. Nova Tela `CreatePublicChatScreen`

**Arquivo:** `frontend/lib/features/chat/screens/create_public_chat_screen.dart`  
**Rota:** `/create-public-chat` (registrada em `app_router.dart`)

**Fluxo:**
1. Usuário toca "Criar" na seção de chats da comunidade
2. Tela abre com nome da comunidade pré-preenchido (read-only)
3. Usuário preenche nome (obrigatório, 3–50 chars) e descrição (opcional)
4. Toca "Criar Chat Público" → chama RPC `create_public_chat`
5. Sucesso → navega diretamente para o chat criado (`/chat/:id`)
6. Erro → SnackBar com mensagem traduzida

**Validações:**
- Campo nome: obrigatório, mínimo 3 caracteres
- RPC valida: autenticação, título não vazio, membership ativo na comunidade

---

## Checklist Manual de Validação

### Pré-condições
- [ ] Estar logado como membro de "Anime Amino" ou "K-Pop Amino"
- [ ] Banco limpo (0 chats de seed)

### Limpeza do Banco
- [ ] Abrir Supabase Dashboard → Table Editor → `chat_threads`: deve mostrar 0 linhas
- [ ] `communities`: deve mostrar apenas "Anime Amino" e "K-Pop Amino"

### Seção de Chats Públicos na Comunidade
- [ ] Acessar "Anime Amino" → tela da comunidade
- [ ] Verificar que a seção "Chats Públicos" aparece (mesmo sem chats)
- [ ] Verificar que o placeholder "Nenhum chat público ainda" é exibido
- [ ] Verificar que o botão "Criar" (verde) está visível no cabeçalho da seção

### Criar Chat Público
- [ ] Tocar no botão "Criar" ou no placeholder
- [ ] Tela "Novo Chat Público" abre com nome da comunidade exibido
- [ ] Tentar criar sem nome → mensagem de validação aparece
- [ ] Tentar criar com nome < 3 chars → mensagem de validação aparece
- [ ] Preencher nome válido (ex: "Discussão Geral") e tocar "Criar Chat Público"
- [ ] Navega automaticamente para o chat criado
- [ ] Voltar à comunidade → chat aparece na seção "Chats Públicos"

### Isolamento de Tipos
- [ ] Criar um grupo privado via `/create-group-chat`
- [ ] Verificar que o grupo NÃO aparece na seção "Chats Públicos" da comunidade
- [ ] DMs também não aparecem na seção

### Permissões de Delete (team admin)
- [ ] Logado como Sieg (team admin): pode deletar qualquer chat via REST API
- [ ] Usuário comum: só pode deletar chats onde é `host_id`

---

## Arquivos Modificados/Criados

| Arquivo | Ação |
|---------|------|
| `backend/supabase/migrations/034_chat_admin_delete_and_create_public.sql` | Criado |
| `frontend/lib/features/communities/widgets/community_live_chats.dart` | Modificado |
| `frontend/lib/features/chat/screens/create_public_chat_screen.dart` | Criado |
| `frontend/lib/router/app_router.dart` | Modificado (import + rota) |
