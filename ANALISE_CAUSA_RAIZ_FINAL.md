# Análise de Causa Raiz Final — 6 Bugs Bloqueadores

## Bug #1 — Upload de foto / Avatar (crash + overflow)

### Caminho de reprodução
1. Usuário abre `EditProfileScreen`
2. Toca no avatar → `_pickAndUploadAvatar()` → `MediaUploadService.uploadAvatar()`
3. `pickImage()` abre `ImagePicker`
4. `cropImage()` abre `ImageCropper` com `AndroidUiSettings` + `IOSUiSettings`
5. `uploadFile()` faz upload para Supabase Storage

### Ponto de falha
O fluxo de pick → crop → upload está correto e protegido com try/catch.
O crash **não é no upload em si**, mas no **layout da tela** durante/após o retorno do picker/cropper nativo.

**Causa raiz real:** O `TabBar` dentro do `_buildRichBioEditor` (linhas 322-335) está dentro de um `Row` sem constraint de largura. Quando o teclado está aberto ou o picker retorna e a tela faz rebuild, o `TabBar(isScrollable: true)` + o `Row` com `Spacer` pode causar overflow. Além disso, a `Column` principal está dentro de `SingleChildScrollView` mas o `TabBarView` com `SizedBox(height: r.s(140))` pode conflitar com o `TextField(expands: true)` dentro dele.

**O overflow de 1197px** acontece quando o teclado está aberto e o `SingleChildScrollView` não consegue acomodar o layout. O `TextField` com `expands: true` dentro de um `SizedBox` fixo é seguro, mas o `TabBar` no `Row` pode estourar.

**Correção:** Envolver o `TabBar` em `Flexible` ou `Expanded` dentro do `Row`, e adicionar `resizeToAvoidBottomInset: true` explicitamente.

## Bug #2 — TabController disposed (comunidade)

### Caminho de reprodução
1. Usuário entra em `CommunityDetailScreen`
2. `communityHomeLayoutProvider` retorna um `Map<String, dynamic>` do Supabase
3. No `build()`, `_deepMapEquals` compara com `_lastLayout`
4. Se diferente, agenda `_rebuildTabsIfNeeded` via `addPostFrameCallback`
5. `_rebuildTabsIfNeeded` cria novo `TabController`, faz `setState`, e agenda dispose do antigo via outro `addPostFrameCallback`

### Ponto de falha
O problema é que **o `TabBar` e `TabBarView` no widget tree ainda referenciam o controller antigo durante o frame em que o `setState` ocorre**. O `addPostFrameCallback` para dispose do antigo executa no frame seguinte, mas se houver outro rebuild intermediário (ex: provider emitindo novo valor), o controller antigo pode já ter sido substituído mas o widget tree pode tentar acessá-lo.

**Causa raiz real:** O `_rebuildTabsIfNeeded` é chamado via `addPostFrameCallback` no `build()`, mas o `build()` pode ser chamado múltiplas vezes por frame (ex: múltiplos providers mudando). Cada chamada agenda um novo callback. Se dois callbacks executam em sequência, o segundo tenta dispor um controller que já foi substituído.

**Correção:** Usar um `_pendingRebuild` flag para garantir que apenas um rebuild é agendado por ciclo, e mover a comparação de layout para `didChangeDependencies` ou usar `ref.listen` em vez de comparar no `build`.

## Bug #3 — Chat lifecycle defunct

### Caminho de reprodução
1. Usuário abre `ChatRoomScreen`
2. `_initChat()` inicia: `_loadThreadInfo()`, `_ensureMembership()`, `_loadMessages()`, `_subscribeToRealtime()`
3. Usuário inicia gravação de voz → `VoiceRecorder` é montado
4. Usuário navega para trás (pop) enquanto gravação está ativa
5. `VoiceRecorder.dispose()` cancela timers e recorder
6. Mas `_stopAndSend()` ou `_cancelRecording()` podem chamar `widget.onCancel()` ou `widget.onRecordingComplete()` **após** o parent `ChatRoomScreen` já ter sido disposed

### Ponto de falha
Em `voice_recorder.dart`:
- `_startRecording()` linhas 137-143: se permissão falha, chama `widget.onCancel()` diretamente sem verificar `mounted`
- `_stopAndSend()` linhas 146-161: chama `widget.onRecordingComplete()` ou `widget.onCancel()` após `await _recorder.stop()` sem verificar `mounted`
- `_cancelRecording()` linhas 163-179: chama `widget.onCancel()` após `await _recorder.stop()` e `await file.delete()` sem verificar `mounted`

Em `chat_room_screen.dart`:
- `onCancel: () => setState(() => _isRecordingVoice = false)` (linha 1842) — se o parent já foi disposed, este `setState` causa `_ElementLifecycle.defunct`
- `onRecordingComplete` (linhas 1811-1840) — faz `setState` e depois operações async

**Causa raiz real:** O `VoiceRecorder` chama callbacks do parent após operações async sem verificar se o parent ainda está montado. O parent passa lambdas que fazem `setState` diretamente.

**Correção:** Adicionar guards `mounted` no `VoiceRecorder` antes de chamar callbacks do parent.

## Bug #4 — Curtidas (persistência + estado visual)

### Caminho de reprodução
1. Usuário vê feed na comunidade (via `communityFeedProvider` ou `communityFeaturedFeedProvider`)
2. Posts são carregados **sem** `is_liked` — campo fica `false` por padrão
3. `PostCard` cacheia `_post = widget.post` no `initState`
4. Usuário curte um post → optimistic UI funciona localmente
5. Usuário sai e volta → provider recarrega posts sem `is_liked` → coração volta a false
6. No `post_detail_screen.dart`, o `postDetailProvider` local **faz** a query de `is_liked`, mas ao voltar para o feed, o estado não é propagado

### Ponto de falha
**Causa raiz real (dupla):**
1. **Providers de feed não carregam `is_liked`:** `communityFeedProvider`, `communityFeaturedFeedProvider`, `CommunityFeedNotifier._fetchPage()`, `postDetailProvider` (em `post_provider.dart`), e `featuredPostsProvider` — nenhum deles consulta a tabela `likes` para determinar se o usuário atual curtiu cada post
2. **`PostCard.didUpdateWidget` ignora props atualizados para o mesmo post ID:** Se o mesmo post é reconstruído com dados atualizados (ex: após invalidação do provider), o `_post` local não é atualizado porque `oldWidget.post.id == widget.post.id`

**Correção:** 
1. Nos providers de feed, após carregar posts, fazer batch query na tabela `likes` para o usuário atual e injetar `is_liked` em cada post
2. Em `PostCard.didUpdateWidget`, sempre sincronizar `_post` com `widget.post` (não apenas quando o ID muda)

## Bug #5 — Sidebar da comunidade (reduzida/limitada)

### Caminho de reprodução
1. Usuário abre comunidade → `CommunityDetailScreen`
2. Toca no menu hamburger → `AminoDrawerController.toggle()`
3. Drawer abre com `maxSlide = 280` e `minScale = 0.82`

### Ponto de falha
**Causa raiz real:** O `AminoDrawerController` em `amino_drawer.dart` hardcoda `maxSlide = 280` e `minScale = 0.82`. Em telas maiores, 280px é suficiente, mas o usuário quer uma sidebar "normal" (mais larga). O drawer nunca se adapta à largura da tela.

**Correção:** Aumentar `maxSlide` para um valor proporcional à tela (ex: `MediaQuery.of(context).size.width * 0.78` com cap em 320) e ajustar `minScale` para `0.88` para que o conteúdo não pareça tão reduzido.

## Bug #6 — Seguidores / Seguindo invertidos

### Caminho de reprodução
1. Usuário abre perfil → `ProfileScreen`
2. Vê "Following" à esquerda e "Followers" à direita (correto após fix anterior)
3. Toca em "Following" → navega para `/user/:id/followers?tab=following`
4. `FollowersScreen` abre com `showFollowers = false` → `initialIndex = 1`
5. Mas as tabs são: `[Seguidores, Seguindo]` — tab 0 = Seguidores, tab 1 = Seguindo
6. O conteúdo está correto (tab 1 mostra seguindo), mas a **ordem visual** das tabs está invertida em relação ao que o usuário espera

### Ponto de falha
**Causa raiz real:** Na `FollowersScreen`, as tabs estão na ordem `[Seguidores, Seguindo]` (linhas 93-95). O prompt pede que "Seguindo" fique à esquerda e "Seguidores" à direita. A correção anterior no `ProfileScreen` inverteu os cards de navegação, mas a `FollowersScreen` mantém a ordem original das tabs.

**Correção:** Inverter a ordem das tabs e do `TabBarView` na `FollowersScreen`: `[Seguindo, Seguidores]` e ajustar `initialIndex` correspondentemente.
