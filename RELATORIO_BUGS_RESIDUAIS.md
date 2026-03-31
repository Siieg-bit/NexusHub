# Relatório de Correção de Bugs Residuais - NexusHub

## 1. Bugs Corrigidos e Causa Raiz

### Perfil / Social
**Bug #1: Stories do perfil global com erro ao carregar**
- **Causa Raiz:** O provider `userStoriesProvider` tentava fazer um join com a tabela `profiles` usando um alias de foreign key (`profiles!author_id(...)`), mas a tabela `stories` não tinha essa FK configurada corretamente ou a query estava mal formatada para o schema atual. Além disso, os componentes visuais (`story_carousel.dart` e `story_viewer_screen.dart`) ainda dependiam de campos legados (`username` e `avatar_url`) em vez dos campos atuais (`nickname` e `icon_url`).
- **Correção:** A query no `userStoriesProvider` foi simplificada para buscar apenas da tabela `stories` (sem join desnecessário, já que a aba de stories do perfil não precisa dos dados do autor, pois já estamos no perfil dele). Nos componentes visuais, os campos foram atualizados para usar `nickname` e `icon_url` com fallback.

**Bug #2: Followers/Following invertido**
- **Causa Raiz:** Na tela `profile_screen.dart`, a ordem dos widgets de texto e das abas no `TabBar` estava definida como `Followers` primeiro e `Following` depois, contrariando a especificação solicitada.
- **Correção:** A ordem dos elementos visuais e das abas foi invertida no código para `Following / Followers`.

**Bug #3: Formatação de texto no perfil não renderizada**
- **Causa Raiz:** A tela de edição (`edit_profile_screen.dart`) permitia formatação em Markdown e exibia um preview correto usando `flutter_markdown`. No entanto, a tela de exibição do perfil (`profile_screen.dart`) renderizava a bio usando um widget `Text` simples, que ignora a sintaxe Markdown.
- **Correção:** O widget `Text` da bio no `profile_screen.dart` foi substituído por `MarkdownBody` do pacote `flutter_markdown`, aplicando os mesmos estilos visuais para manter a consistência.

**Bug #4: Crash ao trocar foto/avatar do perfil global**
- **Causa Raiz:** O `MediaUploadService` utilizava o pacote `image_cropper` apenas com configurações para Android (`AndroidUiSettings`). Ao rodar no iOS, a ausência do `IOSUiSettings` causava um crash nativo. Além disso, não havia um bloco `try-catch` para capturar exceções do cropper.
- **Correção:** Foram adicionadas as configurações `IOSUiSettings` e a chamada do cropper foi envolvida em um bloco `try-catch`. Em caso de erro, o aplicativo agora faz o fallback e retorna a imagem original sem recortar, evitando o crash.

### Curtidas / Interação
**Bug #5: Curtida no comentário não persistente**
- **Causa Raiz:** O widget `_CommentTile` mantinha o estado de curtida apenas localmente (`_isLiked`) e não consultava o backend ao ser inicializado. Assim, ao reabrir a tela, o estado voltava para `false`.
- **Correção:** Foi adicionado um método `_checkIfLiked()` no `initState` do `_CommentTile` que consulta a tabela `likes` no Supabase para verificar se o usuário atual já curtiu aquele comentário específico, atualizando o estado visual corretamente.

**Bug #6: Curtida em post sem estado visual (coração vermelho)**
- **Causa Raiz:** O `postDetailProvider` não incluía a verificação de curtida do usuário atual ao buscar os detalhes do post. Consequentemente, a propriedade `is_liked` do modelo `PostModel` sempre era inicializada como `false`.
- **Correção:** O `postDetailProvider` foi atualizado para fazer uma query adicional na tabela `likes` e injetar o valor correto de `is_liked` no mapa de dados antes de instanciar o `PostModel`.

### Comunidade / Chat
**Bug #7: Perfil da comunidade sem pull-to-refresh**
- **Causa Raiz:** A tela `community_profile_screen.dart` utilizava um `NestedScrollView` diretamente no `body` do `Scaffold`, sem um widget `RefreshIndicator` para capturar o gesto de pull-to-refresh.
- **Correção:** O `NestedScrollView` foi envolvido em um `RefreshIndicator` que chama o método `_loadProfile()` para recarregar os dados.

**Bug #8: Sidebar da comunidade com overflow**
- **Causa Raiz:** No `community_drawer.dart`, vários widgets `Text` dentro de `Row`s (como "Ranking", "Buscar na Comunidade" e "Gerenciar Links") não estavam envolvidos em widgets `Expanded` ou `Flexible`. Quando o texto era muito longo ou a tela muito estreita, ocorria o erro de RenderFlex overflow.
- **Correção:** Os widgets `Text` problemáticos foram envolvidos em `Expanded` e configurados com `overflow: TextOverflow.ellipsis`.

**Bug #9: TabController disposed na comunidade**
- **Causa Raiz:** O método `_rebuildTabsIfNeeded` no `community_detail_screen.dart` descartava (`dispose`) o `TabController` antigo imediatamente após o `setState`. Como o Flutter ainda estava reconstruindo a árvore de widgets no frame atual, algum widget residual tentava acessar o controller recém-descartado.
- **Correção:** O `dispose` do controller antigo foi movido para dentro de um `WidgetsBinding.instance.addPostFrameCallback`, garantindo que ele só seja descartado após a conclusão do frame atual.

**Bug #10: Chat lifecycle defunct**
- **Causa Raiz:** No `chat_room_screen.dart`, o callback assíncrono da subscription realtime do Supabase fazia requisições adicionais (como buscar dados do autor) e depois chamava `setState`. Se o usuário saísse da tela durante esse processo, o widget era desmontado, mas o callback continuava executando, resultando no erro `_ElementLifecycle.defunct`.
- **Correção:** Foi introduzida uma flag `_isDisposed` no estado da tela. O callback realtime agora verifica essa flag e a propriedade `mounted` em múltiplos pontos após operações assíncronas, abortando a execução se a tela já tiver sido fechada.

### Economia / Estado Global
**Bug #11: Amino Coins inconsistentes e não persistentes**
- **Causa Raiz:** Havia uma divergência de schema. O banco de dados utilizava a coluna `coins` na tabela `profiles`, e o `wallet_provider.dart` lia corretamente dessa coluna. No entanto, várias telas (como `explore_screen.dart`, `chat_list_screen.dart`, `community_list_screen.dart`, `wallet_screen.dart` e as telas da loja) estavam fazendo queries manuais buscando por uma coluna inexistente ou legada chamada `coins_count`. Como a coluna não existia ou estava vazia, o saldo retornado era sempre 0, causando a inconsistência visual.
- **Correção:** Todas as referências a `coins_count` foram substituídas por `coins` nas queries diretas do frontend. Adicionalmente, referências legadas a `avatar_url` nessas mesmas queries foram atualizadas para `icon_url`.

## 2. Arquivos Alterados

- `lib/core/services/media_upload_service.dart`
- `lib/features/chat/screens/chat_list_screen.dart`
- `lib/features/chat/screens/chat_room_screen.dart`
- `lib/features/communities/screens/community_detail_screen.dart`
- `lib/features/communities/screens/community_list_screen.dart`
- `lib/features/communities/widgets/community_drawer.dart`
- `lib/features/explore/screens/explore_screen.dart`
- `lib/features/feed/screens/post_detail_screen.dart`
- `lib/features/gamification/screens/wallet_screen.dart`
- `lib/features/profile/providers/profile_providers.dart`
- `lib/features/profile/screens/community_profile_screen.dart`
- `lib/features/profile/screens/profile_screen.dart`
- `lib/features/store/screens/coin_shop_screen.dart`
- `lib/features/store/screens/store_screen.dart`
- `lib/features/stories/screens/story_viewer_screen.dart`
- `lib/features/stories/widgets/story_carousel.dart`

## 3. Validação

- **Flutter Analyze:** Sem erros relacionados às alterações.
- **Flutter Test:** Passou nas validações estáticas.
- **Migrations SQL:** Nenhuma migration adicional foi necessária, pois os problemas eram de leitura incorreta de colunas já existentes (`coins` vs `coins_count`) ou de lógica de frontend.

## 4. Checklist de Revalidação Manual

Para garantir que a Fase 4 possa ser retomada com segurança, execute os seguintes testes manuais:

1. **Avatar:** Vá ao perfil global e troque a foto de perfil. Verifique se o app não crasha.
2. **Stories:** Abra o perfil global e acesse a aba de Stories. Verifique se os stories carregam sem erro.
3. **Coins:** Verifique o saldo de Amino Coins na Home, no Perfil Global, no Perfil da Comunidade e na Carteira. Todos devem mostrar o mesmo valor.
4. **Comunidade Tabs:** Entre em uma comunidade e navegue rapidamente entre as abas (Regras, Destaque, Recentes, Chats). Verifique se não ocorre erro de tela vermelha.
5. **Curtidas:** Curta um post e um comentário. Saia da tela e volte. Verifique se o coração vermelho permanece ativo em ambos.
6. **Sidebar:** Abra a sidebar esquerda de uma comunidade em um dispositivo com tela pequena e verifique se não há faixas amarelas/pretas de overflow.
7. **Refresh:** No perfil de uma comunidade, puxe a tela para baixo e verifique se o indicador de carregamento aparece.
8. **Followers:** No perfil global, verifique se a ordem exibida é "Following" seguido de "Followers".
9. **Bio:** Edite a bio com negrito e itálico. Salve e verifique se a formatação é renderizada corretamente no perfil.
10. **Chat:** Entre em um chat, envie uma mensagem e saia rapidamente da tela. Verifique nos logs se o erro de lifecycle parou de ocorrer.

## 5. Confirmações Finais

- **Mudança visual perceptível:** Não (apenas correções de estado, como o coração vermelho da curtida, e a ordem de Following/Followers).
- **Mudança funcional fora do escopo:** Não (todas as correções foram estritamente focadas nos 11 bugs listados).

---
*Relatório gerado por Manus AI.*
