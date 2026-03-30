# Sprint 3C — Mini-Relatório

## Objetivo
Otimizar providers e reduzir rebuilds desnecessários, corrigir anti-patterns de Riverpod, e eliminar acoplamento circular entre módulos.

---

## Antes

| Problema | Localização | Impacto |
|---|---|---|
| `widget.ref.watch()` — anti-pattern | `community_list_screen.dart` (2 ocorrências) | Widgets recebem `WidgetRef` como parâmetro, violando lifecycle do Riverpod |
| Providers inline em tela | `community_list_screen.dart` (3 providers, 71 LOC) | Acoplamento circular: drawer e check-in bar importam a tela inteira |
| Import incorreto | `community_check_in_bar.dart` | Importa `community_list_screen.dart` para acessar `ReputationRewards` (definido em `helpers.dart`) |
| `ref.watch(provider).valueOrNull?.iconUrl` | `community_detail_screen.dart` | Rebuild completo quando qualquer campo do UserModel muda |
| Sem `RepaintBoundary` em listas longas | chat, feed global, feed comunidade | Repaint de toda a lista ao scrollar |

### Grafo de dependência (antes)
```
community_drawer.dart ──import──> community_list_screen.dart (para checkInStatusProvider)
community_check_in_bar.dart ──import──> community_list_screen.dart (para ReputationRewards + checkInStatusProvider)
community_detail_screen.dart ──import──> community_list_screen.dart (para checkInStatusProvider)
```

---

## Depois

### 1. Extração de providers compartilhados

| Arquivo | Conteúdo |
|---|---|
| `community_shared_providers.dart` (87 LOC) | `userCommunitiesProvider`, `checkInStatusProvider`, `suggestedCommunitiesProvider` |

### Grafo de dependência (depois)
```
community_drawer.dart ──import──> community_shared_providers.dart
community_check_in_bar.dart ──import──> community_shared_providers.dart + helpers.dart
community_detail_screen.dart ──import──> community_shared_providers.dart
community_list_screen.dart ──import──> community_shared_providers.dart
```

### 2. Correção do anti-pattern `widget.ref.watch`

| Widget | Antes | Depois |
|---|---|---|
| `_AminoCommunityCard` | `StatefulWidget` + `final WidgetRef ref` | `ConsumerStatefulWidget` (ref próprio) |
| `_CommunityPreviewSheet` | `StatefulWidget` + `final WidgetRef ref` | `ConsumerStatefulWidget` (ref próprio) |

**Por que era caro:** Passar `WidgetRef` como parâmetro significa que o widget não participa do grafo de dependência do Riverpod. Quando o provider muda, o rebuild é disparado no widget pai (que detém o ref), e o filho é reconstruído por cascata — mesmo que o valor observado não tenha mudado para aquele filho específico. Com `ConsumerStatefulWidget`, cada widget assiste diretamente o provider e só reconstrói se o valor que ele observa mudar.

### 3. `select()` aplicado

| Localização | Antes | Depois | Justificativa |
|---|---|---|---|
| `community_detail_screen.dart` L238 | `ref.watch(currentUserProfileProvider).valueOrNull?.iconUrl` | `ref.watch(currentUserProfileProvider.select((a) => a.valueOrNull?.iconUrl))` | Bottom nav bar só precisa do `iconUrl`. Sem `select()`, qualquer mudança no UserModel (nickname, bio, coins, level) causa rebuild do bottom nav inteiro. |

**Decisão de não aplicar `select()` em outros pontos:**
- `communityDetailProvider` → usado em `.when()` (precisa do `AsyncValue` completo)
- `communityMembershipProvider` → dados pequenos (1 map), mudanças raras
- `communityHomeLayoutProvider` → fetched uma vez, nunca muda durante sessão
- `checkInStatusProvider` → já é um Map simples, `select()` por community ID adicionaria complexidade sem ganho mensurável
- `unreadNotificationCountProvider` → já retorna `int` (primitivo, sem campo para selecionar)

### 4. `RepaintBoundary` adicionado

| Arquivo | Widget envolvido |
|---|---|
| `chat_room_screen.dart` | `MessageBubble` no `ListView.builder` |
| `global_feed_screen.dart` | `PostCard` no `SliverChildBuilderDelegate` |
| `community_feed_tab.dart` | `PostCard` no `ListView.builder` |

### 5. Import corrigido

| Arquivo | Antes | Depois |
|---|---|---|
| `community_check_in_bar.dart` | `import community_list_screen.dart` | `import helpers.dart` + `import community_shared_providers.dart` |

---

## Ganhos

| Métrica | Antes | Depois | Delta |
|---|---|---|---|
| `community_list_screen.dart` LOC | 1226 | 1155 | -71 (providers extraídos) |
| Anti-patterns `widget.ref.watch` | 2 | 0 | -2 |
| Arquivos que importam `community_list_screen.dart` para providers | 3 | 0 | -3 |
| `select()` aplicados (com impacto real) | 0 | 1 | +1 |
| `RepaintBoundary` em listas | 0 | 3 | +3 |
| Imports incorretos corrigidos | 1 | 0 | -1 |

### Benefícios concretos
1. **Desacoplamento** — Nenhum widget/tela precisa importar `community_list_screen.dart` para acessar providers
2. **Lifecycle correto** — Cada widget com `ConsumerStatefulWidget` participa corretamente do grafo de dependência do Riverpod
3. **Menos rebuilds** — Bottom nav bar não reconstrói quando bio/nickname/coins mudam (apenas iconUrl)
4. **Menos repaint** — Listas longas de mensagens e posts não repintam itens fora da viewport

---

## Riscos

| Risco | Probabilidade | Mitigação |
|---|---|---|
| `_CommunityPreviewSheet` como `ConsumerStatefulWidget` dentro de `showModalBottomSheet` | Baixa | `ConsumerStatefulWidget` funciona normalmente em bottom sheets — o `ProviderScope` é herdado do widget tree |
| `select()` retornando `null` antes do fetch completar | Nenhum | `valueOrNull?.iconUrl` já retorna `null` quando loading — comportamento idêntico ao anterior |
| `RepaintBoundary` adicionando overhead de compositing | Desprezível | Cada `RepaintBoundary` adiciona ~1 layer. Em listas com 50+ itens, o ganho de evitar repaint em cascata supera largamente o custo |

---

## Arquivos Alterados

### Novos (1 arquivo)
- `frontend/lib/features/communities/providers/community_shared_providers.dart`

### Modificados (7 arquivos)
- `frontend/lib/features/communities/screens/community_list_screen.dart`
- `frontend/lib/features/communities/screens/community_detail_screen.dart`
- `frontend/lib/features/communities/widgets/community_drawer.dart`
- `frontend/lib/features/communities/widgets/community_check_in_bar.dart`
- `frontend/lib/features/communities/widgets/community_feed_tab.dart`
- `frontend/lib/features/chat/screens/chat_room_screen.dart`
- `frontend/lib/features/feed/screens/global_feed_screen.dart`

---

**Commit:** `1465d48`
**Branch:** `main`
