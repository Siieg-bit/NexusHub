# Auditoria de Gambiarras — NexusHub Frontend
> Gerado em: 2026-04-24 | Varredura completa de todo o codebase Flutter

---

## CATEGORIA A — CRÍTICO: Operações de negócio sem RPC (insert/update/delete direto)

### A1. Moderação de posts — `moderation_actions_screen.dart`
**Problema:** ban, unban, mute, hide_post, delete_post, feature_post, unfeature_post, pin_post, unpin_post, kick_member são feitos com updates/deletes diretos nas tabelas `community_members` e `posts`, sem validação de hierarquia no backend.
**Risco:** Qualquer usuário que consiga chamar a função Dart pode moderar sem validação server-side.
**Solução:** Usar os RPCs existentes `moderate_user`, `ban_community_member` e criar `moderate_post` e `send_moderation_notification`.

### A2. Moderação de posts — `post_moderation_menu.dart`
**Problema:** `feature_post` e `unfeature_post` fazem update direto em `posts.is_featured`, `posts.featured_at`, `posts.featured_by`. O log de moderação é chamado separadamente, criando janela de inconsistência.
**Solução:** RPC `feature_post` / `unfeature_post` que atomicamente atualiza e loga.

### A3. Moderação de membros — `member_role_manager.dart`
**Problema:** Silenciar membro faz update direto em `community_members.is_silenced` + `log_moderation_action` separados. Ocultar membro faz update direto em `community_members.is_hidden` sem log.
**Solução:** RPCs `silence_community_member` e `toggle_member_visibility`.

### A4. Resolução de flags — `flag_center_screen.dart`
**Problema:** `_resolveFlag` faz update direto em `flags.status` sem validar permissão no backend. Já existe o RPC `resolve_flag` no backend (migration 073) que faz isso corretamente.
**Solução:** Usar o RPC `resolve_flag` existente.

### A5. Notificações inseridas manualmente — `moderation_actions_screen.dart`, `member_role_manager.dart`, `post_moderation_menu.dart`
**Problema:** Notificações de moderação são inseridas diretamente em `notifications` pelo frontend. Isso bypassa triggers, pode criar duplicatas e não tem validação.
**Solução:** RPC `send_moderation_notification` centralizado.

### A6. Entrada em comunidade — `community_detail_screen.dart`, `community_info_screen.dart`
**Problema:** Join de comunidade faz insert direto em `community_members`. Não verifica se a comunidade está ativa, se o usuário está banido, não dispara trigger de boas-vindas.
**Solução:** RPC `join_community` com todas as validações.

### A7. Saída de comunidade — `community_provider.dart`
**Problema:** Leave faz delete direto em `community_members`. Não verifica se o usuário é o único líder (agent), não limpa dados relacionados.
**Solução:** RPC `leave_community` com validações.

### A8. Votação em enquete — `quick_poll_voter.dart`
**Problema:** Vota inserindo em `poll_votes` E incrementando `poll_options.votes_count` manualmente (+1). Já existe o RPC `vote_on_poll` que faz isso atomicamente.
**Solução:** Usar o RPC `vote_on_poll` existente.

### A9. Tentativa de quiz — `poll_quiz_widget.dart`
**Problema:** Salva tentativa de quiz com upsert direto em `quiz_attempts`. Já existe o RPC `answer_quiz` no backend.
**Solução:** Usar o RPC `answer_quiz` existente.

### A10. Edição de story — `create_story_screen.dart`
**Problema:** Editar story faz update direto em `stories`. Não valida se o usuário é o autor, não valida campos.
**Solução:** RPC `update_story`.

### A11. Revisão de wiki — `wiki_curator_review_screen.dart`
**Problema:** Aprovação/rejeição de wiki faz update direto em `wiki_entries.status` + notificação separada. Não é atômico.
**Solução:** RPC `review_wiki_entry` que atualiza e notifica atomicamente.

### A12. Wiki "What I Like" — `wiki_screen.dart`
**Problema:** Insert direto em `wiki_what_i_like` sem validar duplicata, sem reputação.
**Solução:** RPC `add_wiki_what_i_like`.

### A13. Avaliação de wiki — `wiki_screen.dart`
**Problema:** Upsert direto em `wiki_ratings` sem atualizar `average_rating` e `total_ratings` na `wiki_entries` atomicamente.
**Solução:** RPC `rate_wiki_entry`.

### A14. Interesses do usuário — `interest_wizard_screen.dart`
**Problema:** Delete + insert direto em `interests`. Não é atômico — se o insert falhar após o delete, o usuário fica sem interesses.
**Solução:** RPC `set_user_interests` com transação.

### A15. Bloquear/desbloquear usuário — `block_provider.dart`, `blocked_users_screen.dart`
**Problema:** Upsert/delete direto em `blocks`. Já existem os RPCs `block_user` e `unblock_user` (migration 049).
**Solução:** Usar os RPCs existentes.

### A16. Toggle co-host de chat — `chat_room_screen.dart`
**Problema:** Update direto em `chat_threads.co_hosts` (array JSON). Sem validação de permissão no backend.
**Solução:** RPC `toggle_chat_co_host`.

### A17. Configurações de notificação — `notification_settings_screen.dart`
**Problema:** Upsert direto em `notification_settings`. Sem validação de campos.
**Solução:** RPC `update_notification_settings`.

### A18. Configurações de privacidade — `privacy_settings_screen.dart`, `privacy_service.dart`
**Problema:** Upsert direto em `user_settings`. Sem validação.
**Solução:** RPC `update_user_settings`.

### A19. Criar sticker — `quick_sticker_creator.dart`
**Problema:** Insert direto em `sticker_packs` e `stickers`. Já existe o RPC `create_sticker_pack` (migration 053).
**Solução:** Usar o RPC existente + criar `add_sticker_to_pack`.

### A20. Publicar wiki no feed — `create_wiki_screen.dart`
**Problema:** Após criar wiki via RPC, insere post no feed com insert direto em `posts`. Não é atômico com a criação da wiki.
**Solução:** Incluir criação do post no RPC `submit_wiki_entry` existente.

### A21. Deletar post — `post_provider.dart`, `post_detail_screen.dart`
**Problema:** Delete/update de status direto em `posts`. Sem log de moderação, sem validação de permissão no backend.
**Solução:** RPC `delete_post`.

### A22. Deletar comentário — `post_detail_screen.dart`, `wiki_screen.dart`
**Problema:** Delete direto em `comments`. Sem log, sem validação de permissão.
**Solução:** RPC `delete_comment`.

### A23. Ocultar post do feed — `post_detail_screen.dart`
**Problema:** Upsert direto em `hidden_posts`.
**Solução:** RPC `hide_post_from_feed`.

### A24. Links gerais da comunidade — `community_general_links_screen.dart`
**Problema:** Insert/update direto em `community_general_links`. Sem validação de permissão de líder.
**Solução:** RPCs `add_community_link` e `update_community_link`.

### A25. Presença/online status — `presence_service.dart`
**Problema:** Update direto em `profiles.online_status` e `profiles.is_ghost_mode`. Aceitável para presença (alta frequência), mas pode ser encapsulado em RPC para consistência.
**Avaliação:** Baixa prioridade — presença é um caso especial de alta frequência onde o overhead de RPC é real.

---

## CATEGORIA B — ALTO: Lógica de negócio duplicada no frontend

### B1. Incremento manual de contador — `quick_poll_voter.dart`
`poll_options.votes_count` é incrementado manualmente no frontend com `current + 1`. Race condition garantida em votações simultâneas.

### B2. Permissões checadas no Dart (102 ocorrências)
Roles como `'leader'`, `'curator'`, `'moderator'` são comparados diretamente no Dart em múltiplos arquivos. Se o enum de roles mudar no banco, o frontend quebra silenciosamente.

### B3. Operações não atômicas — `moderation_actions_screen.dart`
Ban/mute/feature/pin + log de moderação + notificação são chamadas sequenciais separadas. Se qualquer uma falhar no meio, o estado fica inconsistente.

---

## CATEGORIA C — MÉDIO: Anti-padrões de código

### C1. Catch vazio em operações críticas
18 arquivos com `catch (_) {}` em operações que não são best-effort (moderação, criação de conteúdo, etc).

### C2. Strings hardcoded em widgets (não usando `s.xxx`)
Múltiplos arquivos com strings em português diretamente em `Text('...')` em vez de usar o sistema de localização.

---

## PRIORIDADE DE CORREÇÃO

| Prioridade | Itens | Justificativa |
|---|---|---|
| **P0 — Imediato** | A4, A8, A9, A15 | RPCs já existem, só precisa trocar a chamada |
| **P1 — Alta** | A1, A2, A3, A5, A6, A7 | Risco de segurança — moderação e join/leave sem validação server-side |
| **P2 — Alta** | A10, A11, A12, A13, A14, A16 | Operações não atômicas com risco de inconsistência |
| **P3 — Média** | A17, A18, A19, A20, A21, A22, A23, A24 | Sem validação de permissão, mas risco menor |
| **P4 — Baixa** | B1, B2, B3, C1, C2 | Qualidade de código, não risco imediato |
