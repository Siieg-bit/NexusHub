# Sprint 3D — Mini-Relatório: Paginação, Cache e Error Feedback

## Antes

A infraestrutura de paginação do NexusHub apresentava três lacunas estruturais que comprometiam a experiência do usuário e a resiliência da aplicação.

O **PaginatedListView** e **PaginatedGridView** (509 LOC) usavam um único campo `_error` para erros de primeira carga e de páginas intermediárias. Quando a lista já continha itens e uma página subsequente falhava, o erro era atribuído a `_error` mas a UI nunca o exibia — o usuário via um spinner infinito sem possibilidade de retry. O scroll listener disparava `_loadNextPage()` a cada pixel de scroll sem debounce, potencialmente gerando múltiplas chamadas simultâneas antes que o guard `_isLoading` fosse ativado. O threshold de prefetch era fixo em 200px, sem possibilidade de customização.

O **NotificationProvider** engolia silenciosamente erros de `loadMore()` com `catch (e) { _page--; }`, sem surfacear o erro no state. A tela de notificações sempre exibia um spinner no final da lista quando `hasMore == true`, mesmo após falha. O **CacheService**, embora totalmente implementado com boxes Hive para 8 domínios (posts, communities, messages, profiles, feed, notifications, wiki, metadata), não era integrado com nenhum provider — código morto desde sua criação.

O **CommunitySearchScreen** continha um bug de debounce: a variável `_debounce` era atribuída duas vezes consecutivas (300ms para sugestões, 600ms para busca), fazendo com que o segundo Timer sobrescrevesse o primeiro. O resultado era que `_fetchSuggestions()` nunca era chamado.

## Depois

### PaginatedListView / PaginatedGridView (658 LOC)

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Erro em página intermediária | Silencioso (spinner infinito) | Banner inline de retry com visual claro |
| Campos de erro | `_error` (ambíguo) | `_firstLoadError` + `_loadMoreError` (separados) |
| Scroll debounce | Nenhum | Timer de 100ms |
| Prefetch threshold | Fixo 200px | Configurável via `prefetchThreshold` (default 300px) |
| Trailing widget | Sempre spinner | Condicional: spinner, retry banner, ou nada |

### NotificationProvider (283 LOC)

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Erro em loadMore | `catch (e) { _page--; }` | Surfaceado em `NotificationState.loadMoreError` |
| Retry | Impossível | `retryLoadMore()` limpa erro e retenta |
| Cache | Nenhum | Cache-first via CacheService (Hive) |
| Offline | Tela vazia | Exibe dados do cache se disponível |

### NotificationsScreen (577 LOC)

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Scroll debounce | Nenhum | Timer de 100ms |
| Prefetch threshold | 200px | 300px |
| Trailing widget | Sempre spinner | Retry banner quando `loadMoreError != null` |

### CommunitySearchScreen (bug fix)

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Debounce | `_debounce` sobrescrito (sugestões nunca disparavam) | `_suggestDebounce` (300ms) + `_searchDebounce` (600ms) independentes |

## Ganhos

O ganho principal é **resiliência visível**: quando uma página intermediária falha, o usuário vê claramente o que aconteceu e pode tentar novamente com um toque. Antes, o único recurso era pull-to-refresh (que recarregava tudo do zero) ou sair e voltar à tela.

A integração do CacheService com o NotificationProvider dá **exibição instantânea** na abertura da tela de notificações quando há cache disponível, eliminando o tempo de espera da rede em aberturas subsequentes. Se o dispositivo estiver offline, os dados do cache são usados como fallback em vez de exibir uma tela vazia.

O debounce de scroll elimina chamadas duplicadas de `loadMore()` em scroll rápido, reduzindo carga desnecessária no Supabase. O prefetch threshold configurável permite que cada tela ajuste o momento do carregamento antecipado conforme o tamanho dos seus itens.

A correção do debounce no CommunitySearchScreen restaura o autocomplete de sugestões, que estava silenciosamente quebrado.

## Riscos

| Risco | Severidade | Mitigação |
|-------|-----------|-----------|
| Timer de debounce pode atrasar loadMore em scroll muito lento | Baixa | 100ms é imperceptível; threshold de 300px compensa |
| CacheService pode retornar dados stale | Baixa | Cache é apenas fallback; dados frescos sempre sobrescrevem |
| `clearLoadMoreError` pattern no copyWith | Baixa | Flag explícita, mais segura que nullable-with-sentinel |

## Arquivos Alterados

| Arquivo | Mudança |
|---------|---------|
| `lib/core/widgets/paginated_list_view.dart` | Reescrito: error inline, debounce, prefetch configurável |
| `lib/core/providers/notification_provider.dart` | loadMoreError, retryLoadMore, cache integration |
| `lib/features/notifications/screens/notifications_screen.dart` | Debounce, retry banner inline |
| `lib/features/communities/screens/community_search_screen.dart` | Fix double-debounce bug |

## Commit

`6c24752` — `refactor(sprint-3d): pagination hardening, error feedback, debounce, cache`
