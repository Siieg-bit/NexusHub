# Auditoria Forense — Fase 3: Performance e Arquitetura

## Fase A — Linha do Tempo de Estabilidade

A tabela abaixo resume cada commit da Fase 3 em ordem cronológica, com o objetivo declarado, os arquivos alterados, o risco arquitetural e a classificação de estabilidade.

| Commit | Sprint | Objetivo Declarado | Arquivos Alterados | Risco | Classificação |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `60e155c` | 3A | Decomposição de `chat_room_screen.dart` | 6 arquivos (5 novos widgets + 1 reescrito) | Baixo | **MANTER** |
| `0387763` | 3B | Decomposição de `community_detail_screen` + `profile_screen` | 14 arquivos (10 novos + 2 reescritos + 2 docs) | Médio | **MANTER COM AJUSTES** |
| `76fca10` | 3B | Docs Sprint 3B | 1 arquivo (docs) | Nenhum | MANTER |
| `1465d48` | 3C | Otimização de providers e rebuilds | 8 arquivos | Baixo | **MANTER COM AJUSTES** |
| `8b3f386` | 3C | Docs Sprint 3C | 1 arquivo (docs) | Nenhum | MANTER |
| `6c24752` | 3D | Paginação, cache, debounce, retry | 4 arquivos | Médio-Alto | **MANTER COM AJUSTES** |
| `b08c249` | 3D | Docs Sprint 3D | 1 arquivo (docs) | Nenhum | MANTER |
| `526f279` | 3E | Realtime hardening — RealtimeService | 5 arquivos (1 novo + 4 alterados) | Alto | **MANTER COM AJUSTES** |
| `9d50c1a` | 3E | Docs Sprint 3E | 1 arquivo (docs) | Nenhum | MANTER |
| `11a15cc` | — | Relatório final Fase 3 | 1 arquivo (docs) | Nenhum | MANTER |

**Primeiro commit que deteriorou a estabilidade:** `0387763` (Sprint 3B) — introduziu o erro de compilação `ResponsiveHelper` em `profile_pinned_wikis.dart`. O segundo erro (`ResponsiveUtil`) foi introduzido em `6c24752` (Sprint 3D).

## Fase B — Verificação Real

### flutter pub get
Sucesso. Todas as dependências resolvidas sem conflitos.

### flutter analyze (HEAD = 11a15cc)
**Total: 26 issues — 2 errors, 6 warnings, 18 infos**

Os 18 infos são todos `deprecated_member_use` pré-existentes (anteriores à Fase 3) e não representam regressão.

**Erros de compilação (2):**

| Erro | Arquivo | Sprint | Causa Raiz |
| :--- | :--- | :--- | :--- |
| `Undefined class 'ResponsiveHelper'` | `profile_pinned_wikis.dart:170` | 3B (`0387763`) | Tipo inventado na extração; deveria ser `Responsive` |
| `Undefined class 'ResponsiveUtil'` | `paginated_list_view.dart:269` | 3D (`6c24752`) | Tipo inventado na reescrita; deveria ser `Responsive` |

**Warnings introduzidos pela Fase 3 (6):**

| Warning | Arquivo | Sprint | Causa Raiz |
| :--- | :--- | :--- | :--- |
| `unused_field '_channel'` | `chat_provider.dart:101` | 3E | `_channel` é atribuído mas nunca lido (RealtimeService gerencia agora) |
| `unused_field '_channel'` | `notification_provider.dart:58` | 3E | Idem |
| `unused_field '_channel'` | `chat_room_screen.dart:62` | 3E | Idem |
| `unused_element_parameter 'retryCount'` | `realtime_service.dart:193` | 3E | Parâmetro no construtor de `_ManagedChannel` nunca passado (usa default) |
| `unused_element_parameter 'retryTimer'` | `realtime_service.dart:194` | 3E | Idem |
| `unused_import 'community_shared_providers.dart'` | `community_detail_screen.dart:14` | 3C | Import adicionado mas não utilizado neste arquivo |

### flutter test
**103 testes — todos passando.** Nenhuma regressão nos testes existentes. Porém, os testes não cobrem os arquivos com erros de compilação, o que explica por que os testes passam apesar dos 2 erros.

## Fase C — Auditoria Técnica por Sprint

### Sprint 3A — Decomposição do ChatRoomScreen

A Sprint 3A realizou uma extração limpa de 5 widgets de UI a partir do monolítico `chat_room_screen.dart` (2620 para 1683 LOC). A análise do diff confirma que se trata de refatoração pura, sem alteração de lógica ou comportamento. Os widgets extraídos (`MessageBubble`, `ChatReplyPreview`, `ChatInputBar`, `ChatMediaSheet`, `ChatMessageActionsSheet`) são cópias fiéis do código inline original, convertidas de classes privadas para públicas com os mesmos parâmetros. Nenhum novo estado visual foi introduzido. A divisão melhorou significativamente a testabilidade e manutenção.

**Veredicto: MANTER. Sem mudança visual. Sem mudança funcional. Refator limpo.**

### Sprint 3B — Decomposição de CommunityDetail + Profile

A Sprint 3B extraiu 6 widgets de `community_detail_screen.dart` e 5 widgets de `profile_screen.dart`, além de 2 arquivos de providers. A extração corrigiu o anti-pattern de `ref` como parâmetro de construtor, convertendo para `ConsumerWidget`. Contudo, a extração introduziu **1 erro de compilação**: o método `_coverPlaceholder` em `profile_pinned_wikis.dart` declara o parâmetro como `ResponsiveHelper r`, mas a classe correta é `Responsive`. O código original em `profile_screen.dart` não tinha esse método separado — era código inline que usava `r` (do tipo `Responsive`) diretamente.

**Veredicto: MANTER COM AJUSTES. 1 erro de compilação a corrigir (ResponsiveHelper → Responsive). Sem mudança visual intencional. Sem mudança funcional.**

### Sprint 3C — Otimização de Providers e Rebuilds

A Sprint 3C extraiu providers compartilhados (`checkInStatusProvider`, `userCommunitiesProvider`) para `community_shared_providers.dart`, eliminando acoplamento circular. Converteu `_AminoCommunityCard` e `_CommunityPreviewSheet` de `StatefulWidget` com `widget.ref.watch` para `ConsumerStatefulWidget`. Aplicou `select()` para `currentUserProfileProvider.iconUrl` e adicionou `RepaintBoundary` em 3 listas longas.

Os `RepaintBoundary` são invisíveis ao usuário (widget de renderização puro). O `select()` é aplicação correta que reduz rebuilds reais. O import não utilizado de `community_shared_providers.dart` em `community_detail_screen.dart` é um resíduo inofensivo mas deve ser removido.

**Veredicto: MANTER COM AJUSTES. 1 warning (unused import) a corrigir. Sem mudança visual. Sem mudança funcional.**

### Sprint 3D — Paginação, Cache, Debounce, Retry

A Sprint 3D fez 4 alterações principais:

1. **PaginatedListView/GridView**: adicionou retry banner inline para erros intermediários, debounce de scroll e prefetch configurável. O retry banner é um **novo estado visual** que não existia antes — porém só aparece em cenário de erro de rede em página intermediária, que antes era silencioso (spinner infinito). É uma melhoria de UX defensiva, não uma mudança no fluxo normal.

2. **NotificationProvider**: integrou `CacheService` para offline-first e adicionou `loadMoreError` + `retryLoadMore()`. A integração de cache é funcional e não altera a UI em condições normais.

3. **NotificationsScreen**: adicionou retry banner inline para `loadMoreError`. Mesmo caso do PaginatedListView — novo estado visual em cenário de erro.

4. **CommunitySearchScreen**: corrigiu bug de debounce duplo. Correção legítima de bug.

**Erro de compilação**: `ResponsiveUtil` em `paginated_list_view.dart:269` — tipo inventado, deveria ser `Responsive`.

**Veredicto: MANTER COM AJUSTES. 1 erro de compilação a corrigir. Novos estados visuais de erro (retry banners) — são defensivos e só aparecem em cenário de falha, mas devem ser sinalizados como mudança visual.**

### Sprint 3E — Realtime Hardening

A Sprint 3E criou o `RealtimeService` centralizado com reconexão automática e backoff exponencial, e migrou 4 consumidores (chat_room_screen, chat_provider, notification_provider, screening_room_screen). As mudanças introduziram:

1. **Banner visual "Reconectando..."** no `ChatRoomScreen` — **mudança visual não solicitada**. Aparece quando a conexão Realtime cai. Não existia antes.

2. **Campos `_channel` não utilizados** em 3 arquivos — os campos são atribuídos pelo retorno de `subscribeWithRetry()` mas nunca lidos, pois o `RealtimeService` gerencia os canais internamente. Exceção: `screening_room_screen.dart` usa `_channel` para `sendBroadcastMessage`, então ali o campo é necessário.

3. **Parâmetros `retryCount` e `retryTimer` no construtor de `_ManagedChannel`** — nunca passados como argumentos (usam defaults), mas são usados como campos mutáveis internamente. O warning é sobre os parâmetros do construtor, não sobre os campos em si.

**Veredicto: MANTER COM AJUSTES. 3 warnings de `_channel` unused a corrigir (remover em chat_provider e notification_provider, manter em screening_room). Remover parâmetros do construtor de `_ManagedChannel`. Banner "Reconectando..." é mudança visual não solicitada — deve ser sinalizado.**

## Fase D — Matriz de Decisão

| Item | Sprint | Benefício Real | Risco | Impacto Visual | Impacto Funcional | Status Atual | Recomendação |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Extração de 5 widgets do ChatRoomScreen | 3A | Alto — manutenção e testabilidade | Baixo | Nenhum | Nenhum | Limpo | **Manter** |
| Extração de 6 widgets do CommunityDetailScreen | 3B | Alto — manutenção | Baixo | Nenhum | Nenhum | Limpo | **Manter** |
| Extração de 5 widgets do ProfileScreen | 3B | Alto — manutenção | Baixo | Nenhum | Nenhum | Erro compilação | **Ajustar** (ResponsiveHelper → Responsive) |
| Correção anti-pattern `ref` como parâmetro | 3B | Médio — padrão Riverpod correto | Baixo | Nenhum | Nenhum | Limpo | **Manter** |
| Providers compartilhados extraídos | 3C | Alto — elimina acoplamento circular | Baixo | Nenhum | Nenhum | Limpo | **Manter** |
| Conversão `widget.ref.watch` → `ConsumerStatefulWidget` | 3C | Médio — padrão correto | Baixo | Nenhum | Nenhum | Limpo | **Manter** |
| `select()` em `currentUserProfileProvider.iconUrl` | 3C | Médio — reduz rebuilds reais | Baixo | Nenhum | Nenhum | Limpo | **Manter** |
| `RepaintBoundary` em 3 listas | 3C | Baixo-Médio — otimização de repaint | Nenhum | Nenhum | Nenhum | Limpo | **Manter** |
| Import não utilizado `community_shared_providers` | 3C | Nenhum | Nenhum | Nenhum | Nenhum | Warning | **Ajustar** (remover import) |
| Retry banner inline no PaginatedListView | 3D | Médio — UX defensiva | Baixo | **Sim** (novo estado de erro) | Nenhum | Erro compilação | **Ajustar** (ResponsiveUtil → Responsive) |
| Debounce de scroll no PaginatedListView | 3D | Médio — evita chamadas duplicadas | Nenhum | Nenhum | Nenhum | Limpo | **Manter** |
| Prefetch threshold configurável | 3D | Baixo — flexibilidade futura | Nenhum | Nenhum | Nenhum | Limpo | **Manter** |
| Cache offline-first no NotificationProvider | 3D | Médio — percepção de velocidade | Nenhum | Nenhum | Nenhum | Limpo | **Manter** |
| `loadMoreError` + retry no NotificationProvider | 3D | Médio — UX defensiva | Baixo | **Sim** (novo estado de erro) | Nenhum | Limpo | **Manter** |
| Retry banner inline no NotificationsScreen | 3D | Médio — UX defensiva | Baixo | **Sim** (novo estado de erro) | Nenhum | Limpo | **Manter** |
| Fix debounce duplo no CommunitySearchScreen | 3D | Alto — correção de bug real | Nenhum | Nenhum | **Sim** (autocomplete funciona) | Limpo | **Manter** |
| RealtimeService centralizado | 3E | Alto — resiliência a quedas de rede | Médio | Nenhum | Nenhum | Warnings | **Ajustar** (remover `_channel` unused) |
| Banner "Reconectando..." no ChatRoomScreen | 3E | Médio — feedback de conexão | Baixo | **Sim** (novo banner) | Nenhum | Limpo | **Sinalizar** (mudança visual) |
| `_channel` unused em 3 arquivos | 3E | Nenhum | Nenhum | Nenhum | Nenhum | Warnings | **Ajustar** (remover em 2, manter em 1) |
| Parâmetros unused no construtor `_ManagedChannel` | 3E | Nenhum | Nenhum | Nenhum | Nenhum | Warnings | **Ajustar** (remover do construtor) |

## Resumo de Ações Necessárias (Fase E)

A lista abaixo resume todas as correções cirúrgicas necessárias para restaurar a base a um estado verde:

1. **`profile_pinned_wikis.dart:170`** — Trocar `ResponsiveHelper r` por `Responsive r`
2. **`paginated_list_view.dart:269`** — Trocar `ResponsiveUtil r` por `Responsive r`
3. **`community_detail_screen.dart:14`** — Remover import não utilizado de `community_shared_providers.dart`
4. **`chat_provider.dart:101`** — Remover campo `_channel` não utilizado
5. **`notification_provider.dart:58`** — Remover campo `_channel` não utilizado
6. **`chat_room_screen.dart:62`** — Remover campo `_channel` não utilizado
7. **`realtime_service.dart:193-194`** — Remover parâmetros `retryCount` e `retryTimer` do construtor de `_ManagedChannel`

Nenhuma reversão de sprint é necessária. Todas as mudanças da Fase 3 são fundamentalmente corretas e benéficas, mas foram entregues com defeitos de compilação e linting que invalidam a afirmação de "sucesso total" do relatório original.

### Mudanças Visuais Identificadas

O banner "Reconectando..." no `ChatRoomScreen` (Sprint 3E) é uma **mudança visual não solicitada**. Ele só aparece quando a conexão Realtime cai, portanto não afeta o fluxo normal. A decisão de manter ou reverter fica a critério do usuário.

Os retry banners inline no `PaginatedListView` e `NotificationsScreen` (Sprint 3D) também são **novos estados visuais**, mas só aparecem em cenários de erro de rede em páginas intermediárias, substituindo um spinner infinito silencioso.
