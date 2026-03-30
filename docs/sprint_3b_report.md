# Sprint 3B — Mini-Relatório

## Objetivo
Decompor `community_detail_screen.dart` (1829 LOC) e `profile_screen.dart` (1534 LOC) em widgets e providers independentes, reduzindo acoplamento e melhorando manutenibilidade.

---

## Antes

| Arquivo | LOC |
|---|---|
| `community_detail_screen.dart` | 1829 |
| `profile_screen.dart` | 1534 |
| **Total** | **3363** |

### Problemas identificados

**community_detail_screen.dart:**
- 6 providers inline no topo do arquivo (não reutilizáveis)
- `_CheckInBar` (170 LOC) com lógica de negócio + UI misturadas
- `_LiveChatroomsSection` (165 LOC) autocontida mas privada
- `_FeedTab` recebia `WidgetRef ref` como parâmetro — anti-pattern do Riverpod
- `_ChatTab` e `_GuidelinesTab` privadas sem necessidade

**profile_screen.dart:**
- 5 providers inline (userProfileProvider, userPostsProvider, userLinkedCommunitiesProvider, userWallProvider, equippedItemsProvider)
- `_LinkedCommunitiesSection`, `_StoriesTab`, `_WallTab`, `_PinnedWikisSection` — todas privadas e impossíveis de reutilizar
- Imports não utilizados (CachedNetworkImage, PostModel, CommunityModel) após extração

---

## Depois

### community_detail_screen.dart

| Arquivo | LOC | Tipo |
|---|---|---|
| `community_detail_screen.dart` | 984 | Tela (orquestrador) |
| `community_detail_providers.dart` | 125 | Providers |
| `community_check_in_bar.dart` | 170 | Widget |
| `community_live_chats.dart` | 165 | Widget |
| `community_guidelines_tab.dart` | 61 | Widget |
| `community_feed_tab.dart` | 156 | Widget (ConsumerWidget) |
| `community_chat_tab.dart` | 180 | Widget |

### profile_screen.dart

| Arquivo | LOC | Tipo |
|---|---|---|
| `profile_screen.dart` | 760 | Tela (orquestrador) |
| `profile_providers.dart` | 177 | Providers |
| `profile_linked_communities.dart` | 141 | Widget |
| `profile_stories_tab.dart` | 68 | Widget |
| `profile_wall_tab.dart` | 264 | Widget |
| `profile_pinned_wikis.dart` | 181 | Widget |

---

## Ganhos

| Métrica | Antes | Depois | Delta |
|---|---|---|---|
| `community_detail_screen.dart` LOC | 1829 | 984 | **-46%** |
| `profile_screen.dart` LOC | 1534 | 760 | **-50%** |
| Providers reutilizáveis | 0 | 11 | +11 |
| Widgets públicos testáveis | 0 | 11 | +11 |
| Anti-patterns corrigidos | — | 1 | `ref` como parâmetro → `ConsumerWidget` |
| Imports desnecessários removidos | — | 3 | `CachedNetworkImage`, `PostModel`, `CommunityModel` |

### Benefícios concretos
1. **Providers agora importáveis** — qualquer tela futura pode usar `userProfileProvider`, `communityPostsProvider`, etc.
2. **Widgets testáveis isoladamente** — cada tab/seção pode receber testes de widget sem montar a tela inteira
3. **Menor superfície de rebuild** — cada widget assiste apenas os providers que precisa
4. **Anti-pattern corrigido** — `CommunityFeedTab` agora é `ConsumerWidget` ao invés de receber `ref` como argumento

---

## Riscos

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Import circular entre providers | Baixa | Providers extraídos não importam uns dos outros |
| Quebra de navegação interna | Baixa | Todos os `context.push()` preservados intactos |
| `equippedItemsProvider` vs `userCosmeticsProvider` (duplicação) | Média | Decisão consciente: mantido `equippedItemsProvider` que usa `user_purchases` (schema diferente de `user_inventory`). Unificação pode ser feita em sprint futura se schemas convergirem |
| `_TabBarDelegate` permanece privada em profile_screen | Nenhum | É um delegate de layout, não há necessidade de extrair |

---

## Arquivos Alterados

### Novos (11 arquivos)
- `frontend/lib/features/communities/providers/community_detail_providers.dart`
- `frontend/lib/features/communities/widgets/community_check_in_bar.dart`
- `frontend/lib/features/communities/widgets/community_live_chats.dart`
- `frontend/lib/features/communities/widgets/community_guidelines_tab.dart`
- `frontend/lib/features/communities/widgets/community_feed_tab.dart`
- `frontend/lib/features/communities/widgets/community_chat_tab.dart`
- `frontend/lib/features/profile/providers/profile_providers.dart`
- `frontend/lib/features/profile/widgets/profile_linked_communities.dart`
- `frontend/lib/features/profile/widgets/profile_stories_tab.dart`
- `frontend/lib/features/profile/widgets/profile_wall_tab.dart`
- `frontend/lib/features/profile/widgets/profile_pinned_wikis.dart`

### Modificados (2 arquivos)
- `frontend/lib/features/communities/screens/community_detail_screen.dart`
- `frontend/lib/features/profile/screens/profile_screen.dart`

---

**Commit:** `0387763`
**Branch:** `main`
