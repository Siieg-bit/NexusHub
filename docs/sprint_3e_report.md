# Sprint 3E — Mini-Relatório: Realtime Hardening

## Antes

Todas as 4 assinaturas Realtime do NexusHub (chat, mensagens do provider, notificações, screening room) usavam `.subscribe()` diretamente no canal Supabase, sem callback de status e sem reconexão automática. Quando o WebSocket caía (troca de rede, sleep/wake, reinício do servidor Supabase), os canais morriam silenciosamente. O usuário não recebia nenhum feedback visual — as mensagens simplesmente paravam de chegar, sem explicação. O único recurso era fechar e reabrir a tela.

O Supabase Realtime client faz auto-reconnect no nível do socket, mas canais individuais podem precisar de re-subscribe após reconexão. A única exceção era o `PresenceService`, que já usava o callback `(status, error)` do `.subscribe()`.

## Depois

### RealtimeService (novo, 196 LOC)

Serviço centralizado que encapsula a criação e gerenciamento de canais Realtime com reconexão automática.

| Funcionalidade | Detalhe |
|----------------|---------|
| `subscribeWithRetry()` | Cria canal, configura listeners, inscreve com monitoramento de status |
| Backoff exponencial | 1s, 2s, 4s, 8s, 16s, max 30s entre tentativas |
| Recriação de canal | Canal é destruído e recriado em cada retry (evita estado inválido) |
| `connectionStatus` | `ValueNotifier<RealtimeConnectionStatus>` para UI |
| `unsubscribe()` | Remove canal gerenciado e cancela timers de retry |
| `unsubscribeAll()` | Cleanup global |

### Consumidores migrados

| Arquivo | Canal | Tipo |
|---------|-------|------|
| `chat_room_screen.dart` | `chat:{threadId}` | PostgresChanges INSERT |
| `chat_provider.dart` | `messages:{threadId}` | PostgresChanges INSERT |
| `notification_provider.dart` | `notifications:{userId}` | PostgresChanges INSERT |
| `screening_room_screen.dart` | `screening_{sessionId}` | Broadcast (chat, video_control, participant_update) |

### ChatRoomScreen — Banner de conexão

Quando o realtime desconecta, um banner amarelo "Reconectando..." aparece no topo da área de mensagens (acima do banner de mensagem fixada). Quando reconecta, o banner desaparece automaticamente.

### O que **não** foi feito (e por quê)

| Item | Razão |
|------|-------|
| Typing indicator | Feature nova, não hardening. Strings de l10n existem, mas a implementação requer broadcast bidirecional e debounce — escopo de sprint separado |
| Merge das subscriptions duplicadas de chat | `chat_room_screen.dart` e `chat_provider.dart` subscrevem o mesmo filtro para a mesma thread. Unificar requer migrar a tela para usar o provider exclusivamente — risco alto de regressão |
| Offline message queue | Requer mudanças no schema (tabela de pending messages) e lógica de sync — fora do escopo |
| PresenceService / CallService | Já possuem lifecycle próprio e tratamento de status |

## Ganhos

O ganho principal é **resiliência silenciosa**: quando a conexão cai, o RealtimeService tenta reconectar automaticamente com backoff exponencial, recriando o canal a cada tentativa. O usuário vê o banner "Reconectando..." apenas no chat (onde o impacto é mais visível), e quando a conexão volta, tudo funciona normalmente sem intervenção.

Antes, uma queda de conexão significava perda permanente de realtime até o usuário navegar para fora e voltar. Agora, o serviço tenta indefinidamente com intervalos crescentes, e o canal é recriado do zero a cada tentativa (evitando o problema de canais em estado inválido que o Supabase client não resolve sozinho).

A centralização no RealtimeService também simplifica a manutenção: qualquer novo consumidor de realtime pode usar `subscribeWithRetry()` e ganhar reconexão automática gratuitamente, sem reimplementar a lógica.

## Riscos

| Risco | Severidade | Mitigação |
|-------|-----------|-----------|
| Recriação de canal pode perder mensagens durante o intervalo de retry | Média | Mensagens são persistidas no banco; pull-to-refresh ou reentrada na tela recupera |
| Backoff máximo de 30s pode ser longo em redes instáveis | Baixa | 30s é conservador; pode ser reduzido se necessário |
| `connectionStatus` global reflete qualquer canal desconectado | Baixa | Comportamento correto — se qualquer canal está fora, o status global deve refletir |
| `_channel` reference pode ficar stale após recriação | Baixa | `subscribeWithRetry` atualiza `managed.channel`; referências externas (screening room `sendBroadcastMessage`) usam a referência retornada que é atualizada |

## Arquivos Alterados

| Arquivo | Mudança |
|---------|---------|
| `lib/core/services/realtime_service.dart` | **Novo** — serviço centralizado de reconexão |
| `lib/features/chat/screens/chat_room_screen.dart` | Migrado para RealtimeService, banner de conexão |
| `lib/core/providers/chat_provider.dart` | Migrado para RealtimeService |
| `lib/core/providers/notification_provider.dart` | Migrado para RealtimeService |
| `lib/features/live/screens/screening_room_screen.dart` | Migrado para RealtimeService |

## Commit

`526f279` — `refactor(sprint-3e): realtime hardening — centralized reconnection with backoff`
