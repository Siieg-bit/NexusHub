# Relatório Forense — Fase 3.9: 7 Bugs Reportados

**Commit**: `324bfaf`
**Branch**: `main`
**Data**: 31 de março de 2026
**Arquivos modificados**: 7 (6 source + 1 test)
**Linhas adicionadas**: 1.207 | **Linhas removidas**: 303

---

## Resumo Executivo

Todos os 7 bugs reportados foram diagnosticados com análise de causa raiz e corrigidos cirurgicamente. As correções mantêm compatibilidade retroativa e não introduzem breaking changes. Um conjunto de 20 testes unitários foi adicionado para prevenir regressões.

---

## Diagnóstico e Correções

### Bug #1 e #2: Null check operator / TabController disposed

| Campo | Detalhe |
|---|---|
| **Arquivo** | `community_detail_screen.dart` |
| **Causa raiz** | `_lastLayout != layout` usava comparação por referência de objeto. Cada rebuild do `FutureProvider` criava um novo `Map<String, dynamic>`, fazendo `!=` retornar `true` sempre — mesmo quando os valores eram idênticos. Isso disparava `_rebuildTabsIfNeeded` a cada frame, que fazia `dispose()` do `TabController` antigo e criava um novo, causando o crash "TabController was used after being disposed" e null checks durante a transição. |
| **Correção** | Implementação de `_deepMapEquals()` que compara Maps recursivamente por valor (incluindo sub-Maps e Lists). A comparação `_lastLayout != layout` foi substituída por `!_deepMapEquals(_lastLayout, layout)`. |
| **Impacto** | Elimina crash na primeira entrada da comunidade e o loop infinito de dispose/recreate do TabController. |

### Bug #3: Páginas sem pull-to-refresh

| Campo | Detalhe |
|---|---|
| **Arquivos** | `community_chat_tab.dart`, `community_feed_tab.dart`, `community_guidelines_tab.dart` |
| **Causa raiz** | Nenhuma das 3 tabs tinha `RefreshIndicator`. Os ListViews não tinham `AlwaysScrollableScrollPhysics`, impedindo scroll quando o conteúdo era menor que a viewport. |
| **Correção** | Envolvemos cada ListView/SingleChildScrollView com `RefreshIndicator`. Para a tab de chat (StatefulWidget), o refresh chama `_loadChats()`. Para as tabs de feed (ConsumerWidget), o refresh usa `ref.invalidate()` nos providers Riverpod. Para guidelines, convertemos de `StatelessWidget` para `ConsumerWidget` para acessar `ref.invalidate()`. Estados vazios e de erro também suportam pull-to-refresh via `LayoutBuilder` + `SingleChildScrollView` com `AlwaysScrollableScrollPhysics`. |

### Bug #4: CTA de membership ausente no chat

| Campo | Detalhe |
|---|---|
| **Arquivo** | `chat_room_screen.dart` |
| **Causa raiz** | O `ChatInputBar` era renderizado incondicionalmente, mesmo quando `_membershipConfirmed` era `false`. A função `_ensureMembership()` tentava join silenciosamente, mas se falhasse, o usuário não tinha feedback visual nem opção de retry. |
| **Correção** | Adicionado banner CTA condicional: quando `!_membershipConfirmed && !_isLoading`, exibe uma barra com texto "Você não é membro deste chat" e botão "Entrar no Chat". O `ChatInputBar` agora só aparece quando `_membershipConfirmed || _isLoading`. O botão chama `_ensureMembership()` com feedback visual (loading spinner + SnackBar de sucesso). |

### Bug #5: "Sair do Chat" não funciona

| Campo | Detalhe |
|---|---|
| **Arquivo** | `chat_room_screen.dart`, case `'leave'` no `PopupMenuButton` |
| **Causa raiz** | O case `'leave':` continha apenas `break;` — nenhuma ação era executada. |
| **Correção** | Implementação completa: `_leaveChatConfirm()` exibe `AlertDialog` de confirmação. Ao confirmar, `_leaveChat()` deleta a row em `chat_members`, tenta decrementar `members_count` via RPC (com fallback silencioso), seta `_membershipConfirmed = false`, exibe SnackBar, e faz `context.pop()`. Tratamento de erro com SnackBar informativo. |

### Bug #6: "Membros" e "Configurações" não funcionam

| Campo | Detalhe |
|---|---|
| **Arquivo** | `chat_room_screen.dart`, cases `'members'` e `'settings'` |
| **Causa raiz** | Ambos os cases continham apenas `break;`. Não existem rotas dedicadas `/chat/:id/members` ou `/chat/:id/settings` no router. |
| **Correção** | **Membros**: `_showChatMembers()` abre `DraggableScrollableSheet` com widget `_ChatMembersSheet` (novo widget adicionado ao final do arquivo). Busca membros de `chat_members` com join em `profiles`, exibe lista com avatar, nickname e badge de role. **Configurações**: `_showChatSettings()` abre bottom sheet com opções: Fundo do Chat, Notificações, Ver Membros, e Config. Gerais (se vinculado a comunidade). Cada opção tem ação funcional ou placeholder informativo. |

### Bug #7: Sidebar/drawer overflow e swipe

| Campo | Detalhe |
|---|---|
| **Arquivo** | `community_drawer.dart` |
| **Causa raiz** | O `Drawer` definia `width: MediaQuery.of(context).size.width * 0.85`. O `AminoDrawerController` posiciona o drawer em um slot `Positioned` de `maxSlide = 280px`. Em qualquer tela > 329px de largura, 85% > 280px, causando overflow horizontal. Adicionalmente, o botão "Ver Mais..." chamava `HapticFeedback.selectionClick()` mas não chamava `setState(() => _showMore = !_showMore)`, então o `AnimatedCrossFade` nunca alternava. |
| **Correção** | Substituímos `Drawer(width: ...)` por `Container(color: ...)` sem width explícito — o widget agora preenche naturalmente o slot do `AminoDrawerController`. Adicionamos `setState(() => _showMore = !_showMore)` ao `onTap` do "Ver Mais...". |

---

## Arquivos Modificados

| Arquivo | Tipo | Bugs Corrigidos |
|---|---|---|
| `chat_room_screen.dart` | Modificado + Widget novo | #4, #5, #6 |
| `community_detail_screen.dart` | Modificado | #1, #2 |
| `community_drawer.dart` | Modificado | #7 |
| `community_chat_tab.dart` | Reescrito | #3 |
| `community_feed_tab.dart` | Reescrito | #3 |
| `community_guidelines_tab.dart` | Reescrito | #3 |
| `test/phase3_9_bugfix_test.dart` | Novo | Todos |

---

## Cobertura de Testes

| Grupo | Testes | Bugs |
|---|---|---|
| Deep map equality & TabController lifecycle | 5 | #1, #2 |
| Membership CTA gating | 4 | #4 |
| Leave chat action | 2 | #5 |
| Members & Settings actions | 3 | #6 |
| Drawer width overflow | 4 | #7 |
| Pull-to-refresh logic | 2 | #3 |
| **Total** | **20** | **7/7** |

---

## Bonus Fix Encontrado Durante Auditoria

O botão "Ver Mais..." no drawer (`community_drawer.dart`, linha 649) chamava `HapticFeedback.selectionClick()` mas **não** chamava `setState(() => _showMore = !_showMore)`. O `AnimatedCrossFade` dependia de `_showMore` para alternar, mas o valor nunca mudava. Corrigido adicionando o `setState` ao `onTap`.
