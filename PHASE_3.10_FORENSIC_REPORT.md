# Phase 3.10 — Forensic Bug Report

**Commit**: `dfa81ba`
**Data**: 2026-03-31
**Testes**: 35/35 passing
**Migration requerida**: `032_fix_add_reputation_param_order.sql`

---

## Sumario Executivo

Sete bugs foram diagnosticados e corrigidos cirurgicamente. O bug mais critico (#7) envolvia uma inversao de parametros na funcao SQL `add_reputation` que afetava **todas as 6 RPCs** que concedem reputacao (comentar, postar, curtir, seguir, enviar mensagem, entrar em chat). A correcao exigiu uma nova migration SQL (032) alem de ajustes no frontend.

---

## Bug #1: Stories do perfil — "Erro ao carregar stories"

| Aspecto | Detalhe |
|---|---|
| **Camada** | Frontend (Provider/Query) |
| **Arquivo** | `lib/features/profile/providers/profile_providers.dart` |
| **Causa raiz** | O join PostgREST usava `profiles!stories_author_id_fkey(...)` mas a tabela `stories` (migration 024) nao define um FK com esse nome explicito. PostgREST retornava erro 400. Adicionalmente, stories expirados (>24h) nao eram filtrados. |
| **Correcao** | Substituido por `profiles!author_id(...)` (join generico) e adicionado filtro `.gte('expires_at', DateTime.now().toUtc().toIso8601String())` |

**Antes:**
```dart
.select('*, profiles!stories_author_id_fkey(id, nickname, icon_url)')
.eq('is_active', true)
```

**Depois:**
```dart
.select('*, profiles!author_id(id, nickname, icon_url)')
.eq('is_active', true)
.gte('expires_at', DateTime.now().toUtc().toIso8601String())
```

---

## Bug #2: "Try amino+ for free today!" crasha

| Aspecto | Detalhe |
|---|---|
| **Camada** | Frontend (Navegacao/Rota) |
| **Arquivo** | `lib/features/profile/screens/profile_screen.dart` |
| **Causa raiz** | O botao usava `context.push('/store')`. A rota `/store` e filha do `StatefulShellRoute` (tab bar). `push()` de fora do shell tenta empilhar sem o shell pai, causando crash. |
| **Correcao** | Substituido por `context.go('/store')` que navega corretamente para a tab. |

---

## Bug #3: Followers/Following sem navegacao

| Aspecto | Detalhe |
|---|---|
| **Camada** | Frontend (Rotas incorretas) |
| **Arquivos** | `profile_screen.dart`, `community_profile_screen.dart` |
| **Causa raiz** | Os botoes usavam `context.push('/followers/${widget.userId}')` e `context.push('/following/${widget.userId}')`. Essas rotas NAO existem no router. A rota correta e `/user/:userId/followers` com query param `?tab=following`. |
| **Correcao** | Corrigido em ambos os arquivos para usar as rotas corretas. |

**Antes:**
```dart
context.push('/followers/${widget.userId}')
context.push('/following/${widget.userId}')
```

**Depois:**
```dart
context.push('/user/${widget.userId}/followers')
context.push('/user/${widget.userId}/followers?tab=following')
```

---

## Bug #4: Formatacao de texto no editar perfil nao funciona

| Aspecto | Detalhe |
|---|---|
| **Camada** | Frontend (Focus management) |
| **Arquivo** | `lib/features/profile/screens/edit_profile_screen.dart` |
| **Causa raiz** | Ao tocar nos botoes da toolbar (negrito, italico, etc.), o `TextField` da bio perdia o focus. O `_applyFormat()` alterava o texto mas o cursor sumia. Alem disso, os `InkWell` nao tinham `splashColor` visivel no tema escuro, dando impressao de que nao respondiam ao toque. |
| **Correcao** | (1) Adicionado `FocusNode _bioFocusNode` persistente atribuido ao TextField. (2) `_bioFocusNode.requestFocus()` chamado apos cada formatacao. (3) `Material` wrapper + `splashColor`/`highlightColor` explicitos na toolbar. |

---

## Bug #5: Adicionar foto de perfil nao funciona

| Aspecto | Detalhe |
|---|---|
| **Camada** | Frontend (Handler ausente) |
| **Arquivo** | `lib/features/profile/screens/edit_profile_screen.dart` |
| **Causa raiz** | O icone de camera (`Positioned(bottom: 0, right: 0, child: Container(...))`) era puramente decorativo — sem `GestureDetector` ou `onTap`. O `MediaUploadService.uploadAvatar()` existia e funcionava, mas nunca era chamado. |
| **Correcao** | (1) Todo o Stack do avatar envolvido em `GestureDetector(onTap: _pickAndUploadAvatar)`. (2) Metodo `_pickAndUploadAvatar()` chama `MediaUploadService.uploadAvatar()` e atualiza `_avatarUrl`. (3) Estado `_isUploadingAvatar` com loading indicator no icone. (4) `CachedNetworkImageProvider` exibe o avatar quando URL disponivel. (5) `_saveProfile()` inclui `icon_url` no update. |

---

## Bug #6: Conquistas — RenderFlex overflow 8.1px

| Aspecto | Detalhe |
|---|---|
| **Camada** | Frontend (Layout) |
| **Arquivo** | `lib/core/widgets/checkin_heatmap.dart` |
| **Causa raiz** | O `_StatCard` usava `Column` sem `mainAxisSize: MainAxisSize.min`, e o `Row` pai usava `Expanded` para os 3 cards. Quando `r.s()` escalava para telas maiores, o conteudo vertical (icon + spacing + value + spacing + label) excedia a altura implicita por ~8px. |
| **Correcao** | (1) `Column` com `mainAxisSize: MainAxisSize.min`. (2) `Expanded` substituido por `Flexible` no Row. (3) Textos com `maxLines: 1` e `overflow: TextOverflow.ellipsis`. |

---

## Bug #7: Comment / add_reputation — PostgrestException

> **Este bug exigiu correcao em 3 camadas distintas. Detalhamento completo abaixo.**

### 7A. Problema no RPC/SQL (CAUSA RAIZ PRINCIPAL)

| Aspecto | Detalhe |
|---|---|
| **Camada** | Backend (SQL/RPC) |
| **Arquivo origem** | `backend/supabase/migrations/021_integrate_reputation_and_fixes.sql` |
| **Arquivo correcao** | `backend/supabase/migrations/032_fix_add_reputation_param_order.sql` |

A migration 021 criou 6 funcoes RPC que chamam `add_reputation` com **parametros na ordem errada**.

**Assinatura correta** (definida na migration 019):
```sql
add_reputation(
  p_user_id UUID,        -- 1: quem ganha rep
  p_community_id UUID,   -- 2: em qual comunidade
  p_action_type TEXT,     -- 3: tipo da acao
  p_raw_amount INTEGER,   -- 4: quantidade
  p_reference_id UUID     -- 5: referencia (post, comment, etc.)
)
```

**Como a migration 021 chamava** (ERRADO):
```sql
PERFORM public.add_reputation(
  p_community_id,   -- ERRADO: deveria ser p_user_id
  p_author_id,      -- ERRADO: deveria ser p_community_id
  15,               -- ERRADO: deveria ser 'create_post' (TEXT)
  'create_post',    -- ERRADO: deveria ser 15 (INTEGER)
  v_post_id         -- OK
);
```

**Erros simultaneos:**
1. Parametros 1 e 2 invertidos (`user_id` <-> `community_id`)
2. Parametros 3 e 4 invertidos (`action_type TEXT` <-> `raw_amount INTEGER`)

### 7B. Problema de assinatura/tipos

O PostgreSQL nao encontra a funcao porque a assinatura `(uuid, uuid, integer, text, uuid)` nao existe — so existe `(uuid, uuid, text, integer, uuid)`. INTEGER e TEXT sao tipos incompativeis, entao nao ha cast implicito possivel. Resultado: `PostgrestException: function add_reputation(uuid, uuid, integer, unknown, uuid) does not exist`.

### 7C. Problema no frontend

O frontend em `post_detail_screen.dart` chama corretamente `create_comment_with_reputation` com os params corretos. O erro ocorre **dentro** da RPC quando ela tenta chamar `add_reputation` com args invertidos.

**Problema adicional** em `followers_screen.dart` — chamada direta a `add_reputation` com nomes de parametros errados:

| Parametro usado | Parametro correto |
|---|---|
| `p_action` | `p_action_type` |
| `p_source_id` | `p_reference_id` |
| (sem p_raw_amount) | `p_raw_amount: 1` |

### 7D. Migration necessaria

**Arquivo**: `032_fix_add_reputation_param_order.sql`

Esta migration usa `CREATE OR REPLACE FUNCTION` para recriar todas as 6 funcoes afetadas com a ordem correta. **DEVE ser aplicada ao banco de dados.**

| Funcao | Chamada corrigida |
|---|---|
| `create_post_with_reputation` | `add_reputation(p_author_id, p_community_id, 'create_post', 15, v_post_id)` |
| `create_comment_with_reputation` | `add_reputation(p_author_id, p_community_id, v_action_type, v_rep_amount, v_comment_id)` |
| `toggle_like_with_reputation` | `add_reputation(v_target_author, p_community_id, v_action_type, v_rep_amount, ...)` |
| `toggle_follow_with_reputation` | `add_reputation(p_follower_id, p_community_id, 'follow_user', 1, p_following_id)` |
| `send_chat_message_with_reputation` | `add_reputation(p_author_id, v_community_id, 'chat_message', 1, v_message_id)` |
| `join_public_chat_with_reputation` | `add_reputation(p_user_id, v_community_id, 'join_chat', 2, p_thread_id)` |

---

## Arquivos Modificados

| Arquivo | Bug(s) | Tipo de alteracao |
|---|---|---|
| `backend/supabase/migrations/032_fix_add_reputation_param_order.sql` | #7 | **NOVA MIGRATION** — corrige ordem dos params em 6 RPCs |
| `frontend/lib/features/profile/providers/profile_providers.dart` | #1 | FK join + filtro expires_at |
| `frontend/lib/features/profile/screens/profile_screen.dart` | #2, #3 | context.go + rotas followers |
| `frontend/lib/features/profile/screens/community_profile_screen.dart` | #3 | Rotas followers |
| `frontend/lib/features/profile/screens/edit_profile_screen.dart` | #4, #5 | FocusNode + avatar upload |
| `frontend/lib/features/profile/screens/followers_screen.dart` | #7C | Nomes de params RPC |
| `frontend/lib/core/widgets/checkin_heatmap.dart` | #6 | Layout overflow fix |

---

## Instrucoes de Deploy

1. **Aplicar migration 032** ao banco Supabase:
   ```bash
   supabase db push
   # ou executar manualmente o SQL de 032_fix_add_reputation_param_order.sql
   ```
2. **Build e deploy** do frontend Flutter normalmente.
3. **Verificar** que comentarios, likes, posts, follows, mensagens e join de chat agora concedem reputacao corretamente.

---

## Cobertura de Testes

35 assertions em 9 grupos cobrindo todos os 7 bugs + bonus (community_profile_screen).

```
Bug #1: Stories FK join .............. 3/3
Bug #2: Amino+ banner ............... 2/2
Bug #3: Followers/Following ......... 6/6
Bug #4: Formatacao FocusNode ........ 4/4
Bug #5: Avatar upload ............... 4/4
Bug #6: Achievements overflow ....... 4/4
Bug #7: Migration SQL ............... 7/7
Bug #7: Frontend params ............. 5/5
TOTAL: 35/35 passing
```
