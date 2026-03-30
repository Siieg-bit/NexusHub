# Mini-Relatório — Sprint 3A: Decomposição de `chat_room_screen.dart`

**Commit:** `60e155c`
**Branch:** `main`
**Data:** 2026-03-30

---

## Antes

| Métrica | Valor |
|---|---|
| `chat_room_screen.dart` | **2620 LOC** (arquivo monolítico) |
| Widgets extraídos | 0 — tudo inline |
| Responsabilidades misturadas | UI de bubble, input bar, reply preview, media sheet, message actions, link detection, tip dialog, poll creator, edit dialog, background picker, realtime, data loading, send logic |
| Classes privadas internas | `_MessageBubble`, `_MediaOptionItem`, `_actionTile` |

**Problemas concretos:**
- Qualquer mudança visual em bubble causava diff em arquivo de 2620 linhas
- Impossível reutilizar `_MessageBubble` em outra tela (e.g., forward preview)
- `_showMessageActions` tinha 150+ linhas inline com lógica de delete/edit/pin misturada com UI de bottom sheet
- `_showMediaOptions` era um bloco de 80+ linhas inline

---

## Depois

| Arquivo | LOC | Responsabilidade |
|---|---|---|
| `chat_room_screen.dart` | **1683** | Lifecycle, data, realtime, send, dialogs, orquestração |
| `message_bubble.dart` | **574** | Renderização de mensagem + reactions |
| `chat_reply_preview.dart` | **72** | Banner de reply |
| `chat_input_bar.dart` | **134** | Input de texto + botões |
| `chat_media_sheet.dart` | **205** | Bottom sheet de opções de mídia |
| `chat_message_actions.dart` | **161** | Bottom sheet de ações (long press) |
| **Total** | **2829** | — |

> O total subiu ~200 LOC por causa de imports, doc comments e boilerplate de classe pública. Isso é esperado e saudável — cada arquivo agora é independente e testável.

---

## Ganhos

1. **`chat_room_screen.dart` reduziu 36%** (2620 → 1683 LOC)
2. **Separação de concerns clara:** UI de apresentação (bubble, input, reply) isolada da lógica de negócio (send, delete, edit, pin)
3. **`ChatMessageActionsSheet` retorna `ChatMessageAction` enum** — a tela trata o resultado via switch, sem acoplamento com UI do sheet
4. **`ChatMediaSheet` recebe callbacks** — zero lógica de upload/send dentro do sheet
5. **`MessageBubble` e `MediaOptionItem` agora são públicos** — reutilizáveis em forward preview, notificações, etc.
6. **Diffs futuros isolados:** mudança visual em bubble não toca `chat_room_screen.dart`

---

## Riscos

| Risco | Mitigação |
|---|---|
| `MessageBubble` ainda tem `_buildContent` com type-dispatch longo (574 LOC) | Aceitável por agora — é UI pura. Pode ser decomposto em Sprint futura se necessário |
| `MessageBubble` acessa `SupabaseService.currentUserId` diretamente | Acoplamento leve. Poderia receber `currentUserId` como parâmetro, mas isso adicionaria prop-drilling sem ganho real neste momento |
| `ChatMessageActionsSheet` também acessa `SupabaseService.currentUserId` | Mesmo caso — aceitável para sheet que precisa saber se mensagem é do usuário |
| Sem Flutter SDK no sandbox para `dart analyze` | Validação feita via grep de referências, imports e contagem de LOC. Nenhum símbolo privado antigo referenciado |

---

## Arquivos Alterados

| Arquivo | Ação |
|---|---|
| `lib/features/chat/screens/chat_room_screen.dart` | **Modificado** — reescrito com delegação para widgets extraídos |
| `lib/features/chat/widgets/message_bubble.dart` | **Novo** — `MessageBubble` + `MediaOptionItem` |
| `lib/features/chat/widgets/chat_reply_preview.dart` | **Novo** — `ChatReplyPreview` |
| `lib/features/chat/widgets/chat_input_bar.dart` | **Novo** — `ChatInputBar` |
| `lib/features/chat/widgets/chat_media_sheet.dart` | **Novo** — `ChatMediaSheet` |
| `lib/features/chat/widgets/chat_message_actions.dart` | **Novo** — `ChatMessageActionsSheet` + `ChatMessageAction` enum |
