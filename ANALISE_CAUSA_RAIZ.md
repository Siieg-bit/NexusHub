# Análise de Causa Raiz — 11 Bugs Residuais

## Bug #1 — Stories do perfil global: erro ao carregar
- **Arquivo:** `profile_providers.dart` (userStoriesProvider), `profile_stories_tab.dart`
- **Causa raiz:** O join `profiles!author_id(id, nickname, icon_url)` falha porque a FK na tabela `stories` é `author_id REFERENCES profiles(id)`, mas o PostgREST não consegue resolver o nome do relacionamento `author_id` como alias de FK — ele precisa do nome da constraint ou do nome da tabela. O `story_carousel.dart` usa `profiles!author_id(id, username, avatar_url)` com campos legados que também podem não existir.
- **Classificação:** provider/query errada

## Bug #2 — Followers/Following ordem invertida
- **Arquivo:** `profile_screen.dart` linhas 360-448
- **Causa raiz:** No layout, o primeiro box (esquerda) mostra `followersCount` com label "Followers", e o segundo (direita) mostra `followingCount` com label "Following". O esperado pelo usuário é `Following / Followers` (Following primeiro). A ordem visual está invertida em relação à expectativa.
- **Classificação:** renderização incorreta

## Bug #3 — Formatação de bio não renderizada no perfil final
- **Arquivo:** `profile_screen.dart` linhas 460-468
- **Causa raiz:** A bio é salva com markup Markdown (negrito, itálico, etc.) no `edit_profile_screen.dart`, mas no `profile_screen.dart` é renderizada com `Text(user.bio)` simples, sem `MarkdownBody`. O preview usa `MarkdownBody`, mas o perfil final não.
- **Classificação:** renderização incorreta

## Bug #4 — Crash ao trocar avatar
- **Arquivo:** `media_upload_service.dart` → `cropImage()`
- **Causa raiz:** O `image_cropper ^8.0.0` no Android requer `IOSUiSettings` ou pelo menos um `uiSettings` para cada plataforma. Se a lista `uiSettings` só contém `AndroidUiSettings`, no iOS o cropper pode crashar. Além disso, se o `image_cropper` não encontra a Activity (contexto Android), ele pode lançar exceção não capturada. O `_pickAndUploadAvatar` captura exceções genéricas mas o crash pode ocorrer dentro do plugin nativo antes do catch.
- **Classificação:** rota/callback + lifecycle

## Bug #5 — Curtida em comentário não persistente
- **Arquivo:** `post_detail_screen.dart` → `_CommentTileState`
- **Causa raiz:** `_isLiked` é inicializado como `false` hardcoded no `initState()`. Não há consulta ao backend para verificar se o usuário já curtiu o comentário. Ao reabrir a tela, o estado visual é sempre "não curtido" mesmo que a curtida exista no banco.
- **Classificação:** estado não persistido + provider/query errada

## Bug #6 — Curtida em post sem coração vermelho
- **Arquivo:** `post_detail_screen.dart` → `_toggleLike()` e `postDetailProvider`
- **Causa raiz:** O `postDetailProvider` faz `select('*, profiles!...')` na tabela `posts`, mas a tabela `posts` não tem coluna `is_liked`. O campo `is_liked` no `PostModel.fromJson` lê `json['is_liked']` que é sempre `null` → `false`. Após `_toggleLike()`, o provider é invalidado mas a nova query continua sem `is_liked`. O RPC retorna `{liked: true}` mas esse retorno não é usado para atualizar o estado local.
- **Classificação:** provider/query errada + optimistic UI quebrada

## Bug #7 — Perfil da comunidade sem pull-to-refresh
- **Arquivo:** `community_profile_screen.dart`
- **Causa raiz:** O `NestedScrollView` não está envolvido por `RefreshIndicator`. Não há mecanismo de pull-to-refresh.
- **Classificação:** renderização incorreta (feature ausente)

## Bug #8 — Sidebar da comunidade: RenderFlex overflow 17px
- **Arquivo:** `community_drawer.dart`
- **Causa raiz:** O drawer é renderizado dentro de um slot de 280px (`maxSlide`). O conteúdo interno tem `Row` com sidebar de 56px + painel `Expanded`. Dentro do painel, o header de 220px com `Positioned` pode ter textos longos que ultrapassam. Mais provável: o `Row` de check-in (linhas 429-519) com streak badge pode exceder a largura quando o texto "Check-in feito!" + badge streak + padding não cabem.
- **Classificação:** layout responsivo

## Bug #9 — TabController disposed na comunidade
- **Arquivo:** `community_detail_screen.dart`
- **Causa raiz:** O `_rebuildTabsIfNeeded` faz `oldController.dispose()` após `setState`, mas se o layout provider emite um novo valor durante a animação/rebuild, pode haver uma race condition onde o controller antigo é usado após dispose. O `_deepMapEquals` ajudou, mas se o provider emite valores idênticos em sequência rápida, o `addPostFrameCallback` pode executar após dispose.
- **Classificação:** lifecycle

## Bug #10 — Chat lifecycle defunct
- **Arquivo:** `chat_room_screen.dart`
- **Causa raiz:** O callback do realtime (`callback: (payload) async { ... }`) faz `await` para buscar sender data, e depois chama `setState`. Se o widget foi disposed durante o await, o `mounted` check pode passar mas o `setState` falha porque o Element já está defunct. O `mounted` check em linha 400 e 406 pode ter race condition entre o check e o setState.
- **Classificação:** lifecycle

## Bug #11/12 — Amino Coins inconsistentes / não persistentes
- **Arquivos:** `wallet_provider.dart`, `wallet_screen.dart`, `chat_list_screen.dart`, `community_list_screen.dart`, `explore_screen.dart`, `coin_shop_screen.dart`, `store_screen.dart`
- **Causa raiz:** Múltiplas fontes de verdade divergentes:
  - `walletProvider` e `coinBalanceProvider` leem `profiles.coins` (campo correto)
  - `wallet_screen.dart`, `chat_list_screen.dart`, `community_list_screen.dart`, `explore_screen.dart`, `coin_shop_screen.dart`, `store_screen.dart` leem `profiles.coins_count` (campo que NÃO EXISTE na tabela — retorna null → 0)
  - A coluna real no DB é `coins` (migration 001), não `coins_count`
  - Resultado: telas que usam `coins_count` sempre mostram 0, enquanto telas que usam `coins` mostram o valor real
- **Classificação:** sincronização entre telas + cache inconsistente + provider/query errada
