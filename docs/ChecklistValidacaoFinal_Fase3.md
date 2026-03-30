# Checklist de Validação Final — Fase 3 Estabilizada

## 1. Mapeamento de Fluxos Afetados

A tabela abaixo relaciona cada fluxo prioritário com as sprints que o afetaram e os arquivos modificados.

| Fluxo | Sprints | Arquivos Alterados |
| :--- | :--- | :--- |
| **Chat** | 3A, 3C, 3E | `chat_room_screen.dart`, `message_bubble.dart`, `chat_input_bar.dart`, `chat_reply_preview.dart`, `chat_media_sheet.dart`, `chat_message_actions.dart`, `chat_provider.dart`, `realtime_service.dart` |
| **Comunidade** | 3B, 3C | `community_detail_screen.dart`, `community_list_screen.dart`, `community_check_in_bar.dart`, `community_live_chats.dart`, `community_guidelines_tab.dart`, `community_feed_tab.dart`, `community_chat_tab.dart`, `community_drawer.dart`, `community_detail_providers.dart`, `community_shared_providers.dart` |
| **Perfil** | 3B | `profile_screen.dart`, `profile_linked_communities.dart`, `profile_pinned_wikis.dart`, `profile_stories_tab.dart`, `profile_wall_tab.dart`, `profile_providers.dart` |
| **Notificações / Paginação** | 3D, 3E | `notification_provider.dart`, `notifications_screen.dart`, `paginated_list_view.dart`, `realtime_service.dart` |
| **Busca de Comunidade** | 3D | `community_search_screen.dart` |
| **Realtime / Reconexão** | 3E | `realtime_service.dart`, `chat_room_screen.dart`, `chat_provider.dart`, `notification_provider.dart`, `screening_room_screen.dart` |

## 2. Checklist de Validação Manual por Fluxo

### 2.1 Chat

| Item | Cenário | Resultado Esperado | Status |
| :--- | :--- | :--- | :--- |
| CH-01 | Abrir sala de chat com mensagens existentes | Mensagens carregam normalmente, scroll funciona | Pendente |
| CH-02 | Enviar mensagem de texto | Mensagem aparece na lista em tempo real | Pendente |
| CH-03 | Responder a uma mensagem (reply) | Preview de reply aparece no input, mensagem enviada com referência | Pendente |
| CH-04 | Abrir sheet de mídia (câmera, galeria, etc.) | Bottom sheet abre com todas as opções | Pendente |
| CH-05 | Long press em mensagem → ações | Bottom sheet de ações aparece (copiar, responder, fixar, etc.) | Pendente |
| CH-06 | Mensagem fixada (pinned) | Banner de pinned aparece no topo | Pendente |
| CH-07 | Emoji picker toggle | Picker abre/fecha sem conflito com teclado | Pendente |
| CH-08 | **[NOVO VISUAL]** Queda de conexão WebSocket | Banner "Reconectando..." aparece no topo da sala | Pendente |
| CH-09 | Reconexão bem-sucedida após queda | Banner desaparece, mensagens novas chegam | Pendente |
| CH-10 | Scroll para cima (mensagens antigas) | Paginação carrega mensagens anteriores | Pendente |

### 2.2 Comunidade

| Item | Cenário | Resultado Esperado | Status |
| :--- | :--- | :--- | :--- |
| CO-01 | Abrir detalhe de comunidade | Tela carrega com tabs (Home, Feed, Chat, Guidelines) | Pendente |
| CO-02 | Check-in diário | Barra de check-in funciona, reputação atualiza | Pendente |
| CO-03 | Tab Feed | Posts carregam com paginação, PostCard renderiza | Pendente |
| CO-04 | Tab Chat | Lista de threads carrega | Pendente |
| CO-05 | Tab Guidelines | Conteúdo de regras renderiza | Pendente |
| CO-06 | Live Chatrooms section | Salas ao vivo aparecem quando existem | Pendente |
| CO-07 | Community Drawer | Drawer abre com informações da comunidade | Pendente |
| CO-08 | Lista de comunidades | Cards renderizam sem crash | Pendente |
| CO-09 | Preview sheet de comunidade | Sheet abre ao tocar em card | Pendente |

### 2.3 Perfil

| Item | Cenário | Resultado Esperado | Status |
| :--- | :--- | :--- | :--- |
| PR-01 | Abrir perfil próprio | Tela carrega com header, tabs, comunidades vinculadas | Pendente |
| PR-02 | Tab Wall | Posts do usuário carregam | Pendente |
| PR-03 | Tab Stories | Stories do usuário aparecem | Pendente |
| PR-04 | Comunidades vinculadas | Seção mostra comunidades do usuário | Pendente |
| PR-05 | Pinned Wikis | Wikis fixadas aparecem em carrossel horizontal | Pendente |
| PR-06 | Abrir perfil de outro usuário | Mesma tela funciona para perfis alheios | Pendente |

### 2.4 Notificações / Paginação

| Item | Cenário | Resultado Esperado | Status |
| :--- | :--- | :--- | :--- |
| NO-01 | Abrir tela de notificações | Lista carrega com notificações recentes | Pendente |
| NO-02 | Scroll para baixo (paginação) | Mais notificações carregam com debounce | Pendente |
| NO-03 | Pull-to-refresh | Lista recarrega do início | Pendente |
| NO-04 | Marcar todas como lidas | Badge de contagem zera | Pendente |
| NO-05 | Tap em notificação | Navega para o contexto correto (post, perfil, etc.) | Pendente |
| NO-06 | **[NOVO VISUAL]** Erro em página intermediária | Banner de retry inline aparece (não spinner infinito) | Pendente |
| NO-07 | Retry após erro intermediário | Tap em "Tentar novamente" recarrega a página | Pendente |
| NO-08 | Cache offline-first | Notificações aparecem imediatamente do cache, depois atualizam | Pendente |

### 2.5 Busca de Comunidade

| Item | Cenário | Resultado Esperado | Status |
| :--- | :--- | :--- | :--- |
| BU-01 | Digitar no campo de busca | Sugestões aparecem após 300ms (debounce) | Pendente |
| BU-02 | Continuar digitando | Busca completa dispara após 600ms | Pendente |
| BU-03 | Selecionar sugestão | Campo preenche e busca executa | Pendente |
| BU-04 | Tabs de resultado (Posts, Membros, Wiki) | Cada tab mostra resultados filtrados | Pendente |
| BU-05 | Limpar campo | Resultados limpam, sugestões recentes aparecem | Pendente |

### 2.6 Realtime / Reconexão

| Item | Cenário | Resultado Esperado | Status |
| :--- | :--- | :--- | :--- |
| RT-01 | Conexão estável | `connectionStatus` = `connected`, sem banner | Pendente |
| RT-02 | Perda de conexão | Status muda para `connecting`, backoff inicia | Pendente |
| RT-03 | Reconexão automática | Canal recriado, callbacks re-registrados | Pendente |
| RT-04 | Backoff exponencial | Delays: 1s, 2s, 4s, 8s, 16s, max 30s | Pendente |
| RT-05 | Unsubscribe cancela retry | Timer cancelado, canal removido do registry | Pendente |
| RT-06 | UnsubscribeAll limpa tudo | Todos os canais removidos, status = disconnected | Pendente |

## 3. Mudanças Visuais Confirmadas

| Mudança | Localização | Cenário de Ativação | Impacto no Fluxo Normal |
| :--- | :--- | :--- | :--- |
| Banner "Reconectando..." | `ChatRoomScreen` | Queda de conexão WebSocket | **Nenhum** — só aparece em falha de rede |
| Retry banner inline | `PaginatedListView` | Erro em página intermediária de paginação | **Nenhum** — substitui spinner infinito silencioso |
| Retry banner inline | `NotificationsScreen` | Erro ao carregar mais notificações | **Nenhum** — substitui spinner infinito silencioso |
| RepaintBoundary | Chat, Feed global, Feed comunidade | Sempre presente (invisível) | **Nenhum** — widget de renderização puro |

## 4. Mudança Funcional Confirmada

| Mudança | Localização | Comportamento Anterior | Comportamento Atual |
| :--- | :--- | :--- | :--- |
| Fix debounce duplo | `CommunitySearchScreen` | Sugestões e busca usavam mesmo timer, sugestões nunca disparavam | Timers separados: sugestões (300ms) e busca (600ms) funcionam independentemente |
