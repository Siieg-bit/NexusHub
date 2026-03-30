# NexusHub - Backlog de Desenvolvimento

> Documento vivo que rastreia todas as funcionalidades pendentes, bugs conhecidos e melhorias planejadas.
> Atualizado em: 26/03/2026 (v5 - Animações, Join Community, Edição de Comunidade)

---

## Legenda de Status
- [ ] Pendente
- [x] Concluído
- [~] Em progresso
- [!] Bug conhecido

---

## 1. TELA DISCOVER (Tela Principal)

- [x] **Remover botão CHECK IN da Discover** - Check-in é por comunidade, não global
- [x] **Implementar sistema de categorias** - Categorias como: Anime & Manga, Gaming, Art, Music, K-Pop, Books, Movies & TV, Science, Sports, etc.
- [x] **Cada comunidade deve pertencer a uma ou mais categorias**
- [x] **Seção "Trending Communities"** com comunidades em alta
- [x] **Seção "New Communities"** com comunidades recém-criadas (scroll horizontal com badge NEW, banner, ícone, nome, membros)
- [x] **Seção "For You"** baseada em posts populares (thumbnail, comunidade, autor, likes/comments)
- [x] **Banner carousel** com comunidades em destaque (curadoria)
- [x] **Barra de busca funcional** com filtro por categoria, comunidade e usuário (tela de busca fiel ao Amino com tabs Comunidades/Usuários/Chats/Outros, resultado por ID Amino, tags coloridas)

## 2. TELA COMMUNITIES

- [x] Grid de comunidades do usuário
- [x] **Cards maiores verticalmente** - Fiel ao layout do Amino original
- [x] **Botão CHECK IN nos cards** - Cada comunidade com seu próprio check-in
- [x] **Indicador de notificações** por comunidade no card
- [x] **Reordenação por drag & drop** (long press)
- [x] **Botão "Create Your Own"** funcional com fluxo de criação
- [x] **Tela "Join Community"** - Aparece na primeira vez ao clicar numa comunidade (ícone, nome, membros, idioma, Amino ID, tags, botão JOIN COMMUNITY ciano, descrição)
- [x] **Long press no card** para ver detalhes de comunidade já joinada (sem botão Join)
- [x] **Estrutura para edição de comunidade** - Preparada para líder editar (nome, descrição, tags, avatar, capa)

## 3. SISTEMA DE PERFIS (Arquitetura Dual)

### 3.1 Perfil Global (Interface Principal)
- [x] **Perfil Global** - Visível antes de entrar em qualquer comunidade
- [x] **Avatar e nickname globais** - Compartilhados como identidade base
- [x] **Lista de comunidades** que o usuário participa (Linked Communities)
- [x] **Layout fiel ao Amino** - Avatar à esquerda, Edit Profile, Followers/Following em caixas divididas
- [x] **Banner Amino+** - "Try Amino+ for free today!"
- [x] **Tabs Stories/Wall** - Seções de conteúdo do perfil global
- [x] **Header com Coins + Share + Menu** - Fiel ao print do Amino
- [x] **Configurações da conta** (email, senha, notificações)
- [x] **Amino+ / Assinatura** funcional

### 3.2 Perfil por Comunidade (Dentro da Comunidade)
- [x] **Perfil individual por comunidade** - Completamente separado
- [x] **Nickname customizado** por comunidade
- [x] **Bio/descrição** específica da comunidade
- [x] **Background image** customizado por comunidade (full-width, customizável)
- [x] **Avatar com anel gradiente** decorativo (rosa/roxo/azul)
- [x] **Badges e títulos coloridos** específicos da comunidade (cápsulas coloridas)
- [x] **Role badge** (Leader/Curator) em destaque
- [x] **Level badge + título** (Lv + título descritivo)
- [x] **Reputação** independente por comunidade (números grandes)
- [x] **Streak bar dourada** com contagem de dias
- [x] **Botões Follow + Chat** centralizados
- [x] **Stats GRANDES** (Reputation, Following, Followers) - Fiel ao Amino
- [x] **Seção Biography** com data de membro
- [x] **Tabs Posts/Wall/Media** - Conteúdo do perfil na comunidade
- [x] **Followers/Following** dentro da comunidade

## 4. TELA INTERNA DA COMUNIDADE

### 4.1 Side Drawer
- [x] Sidebar com ícones das comunidades
- [x] Menu com ícones coloridos
- [x] Botão Check In
- [x] **Perfil do usuário NA COMUNIDADE** (não global)
- [x] **"See More..." expandir** para mostrar mais opções
- [x] **Seção "General"** com links customizáveis pelo admin

### 4.5 Animações e Transições
- [x] **Transições de tela** com framer-motion (fade + slide)
- [x] **Animação de cards** com stagger (entrada sequencial)
- [x] **Animação de tabs** com slide horizontal
- [x] **Animação de drawer** com slide lateral
- [x] **Animação de modais** com scale + fade
- [x] **Micro-interações** em botões (hover, tap scale)
- [x] **Animação de check-in** com pulse e confetti effect
- [x] **Animação de like** com scale bounce

### 4.2 Tela Principal
- [x] Cover image + info da comunidade
- [x] Check-in progress bar de 7 dias
- [x] Chatrooms ao vivo
- [x] Tabs (Guidelines, Featured, Latest Feed, Public Chatrooms)
- [x] **Tab Members** - Lista de membros com roles (Leader, Curator, Member)
- [x] **Tab Wiki/Catalog** - Entradas wiki da comunidade (placeholder com botão criar)
- [x] **Tab Leaderboard** - Ranking por reputação/check-in (com levels e títulos)

### 4.3 Bottom Nav da Comunidade
- [x] Menu, Online, +, Chats, Me
- [x] **Botão "Menu"** abrindo o drawer (funcional)
- [x] **Botão "Online"** mostrando lista de membros online (onlineCount integrado no bottom nav via provider)
- [x] **Botão "+"** com FAB funcional para criar posts (navega para /community/:id/create-post)
- [x] **Botão "Chats"** navegando para chats da comunidade
- [x] **Botão "Me"** abrindo perfil DA COMUNIDADE (não global)

## 5. SISTEMA DE POSTS

- [x] PostCard com autor, título, conteúdo, mídia
- [x] Tipos: Blog, Poll, Quiz
- [x] **Tela de criação de post funcional** com editor (create_post_screen com block editor, mídia, poll, quiz, crosspost)
- [x] **Upload de imagens** nos posts (integrado no create_post_screen com image picker)
- [x] **Sistema de tags** funcional (tags exibidas no PostDetailScreen com chips clicáveis #tag, busca por tag)
- [x] **Compartilhamento** de posts (botão share no AppBar copia deep link)
- [x] **Bookmark/Salvar** posts (toggle_bookmark RPC integrado no PostDetailScreen)
- [x] **Reportar** posts (ReportDialog integrado via PopupMenuButton no PostDetailScreen)
- [x] **Deletar** posts (autor pode deletar via menu more options, confirmação dialog)

## 6. SISTEMA DE CHAT

- [x] Lista de chats com sidebar de comunidades
- [x] Chat room com mensagens
- [x] **Criar novo chat** funcional (modal Novo Chat no ChatListScreen com opções Privado/Grupo)
- [x] **Chat em grupo** com convite de membros (CreateGroupChatScreen com 3 steps: comunidade, info, membros)
- [x] **Reações em mensagens** (tap para reagir - já implementado no chat_room_screen)
- [x] **Responder mensagem** (reply - já implementado com _replyingTo no chat_room_screen)
- [x] **Enviar imagens** no chat (image_picker integrado no chat_room_screen)
- [x] **Enviar stickers/GIFs** (StickerPicker e GiphyPicker integrados)
- [x] **Indicador de digitando** (typing indicator via Realtime presence)
- [x] **Mensagens de voz** (VoiceRecorder widget integrado no chat_room_screen)

## 7. SISTEMA DE NOTIFICAÇÕES

- [x] **Tela de notificações** completa (NotificationsScreen com tiles, avatares, ícones por tipo, indicador não-lida)
- [x] **Tipos**: curtida, comentário, seguidor, menção, convite de chat, level_up, achievement
- [x] **Badge de contagem** no ícone de notificação (unreadNotificationCountProvider integrado em todas as AminoTopBar)
- [x] **Marcar como lida** (individual ao tocar + botão 'Marcar todas' no AppBar)

## 8. GAMIFICAÇÃO

- [x] Check-in com streak
- [x] **Check-in POR COMUNIDADE** (não global)
- [x] **Sistema de XP** por ações (max 100 rep/dia)
- [x] **Sistema de Levels** com 20 níveis progressivos (Newcomer → Supreme) baseado em reputação total
- [x] **Sistema de Coins** com economia funcional
- [x] **Loja de itens** (chat bubbles, profile frames)
- [x] **Leaderboard** por comunidade

## 9. MODERAÇÃO

- [x] **Roles**: Agent (admin global), Leader, Curator, Member (implementado no community_members com role field)
- [x] **Painel de moderação** para Leaders/Curators (AdminPanelScreen + FlagCenterScreen + ModerationActionsScreen)
- [x] **Ban/Kick** membros (ban/unban/kick/mute/warn/strike no ModerationActionsScreen)
- [x] **Deletar posts/comentários** (delete_post/hide_post no ModerationActionsScreen)
- [x] **Feature/Pin** posts (feature_post/pin_post/unfeature/unpin no ModerationActionsScreen)
- [x] **Editar guidelines** da comunidade (EditGuidelinesScreen com editor + preview + templates)

## 10. AUTENTICAÇÃO

- [x] **Tela de Onboarding** com slides de boas-vindas
- [x] **Tela de Login** (email + senha)
- [x] **Tela de Signup** (email, nickname, avatar)
- [x] **Login social** (Google, Apple)
- [x] **Recuperação de senha**
- [x] **Verificação de email**

## 11. BUSCA

- [x] **Busca global** por comunidades (com tabs, ID match, keyword search, tags coloridas)
- [x] **Busca dentro da comunidade** por posts, membros, wiki
- [x] **Filtros** por tipo, data, popularidade
- [x] **Sugestões de busca** (autocomplete)

## 12. CONFIGURAÇÕES

- [x] **Configurações da conta** (perfil card com avatar/nome, exportar dados, excluir conta com dupla confirmação)
- [x] **Configurações de notificação** (push notifications toggle no SettingsScreen)
- [x] **Privacidade** (usuários bloqueados, dispositivos conectados no SettingsScreen)
- [x] **Idioma** (LocaleProvider integrado com seleção dinâmica pt-BR/en-US, persistência via Hive)
- [x] **Tema** (ThemeNotifier com toggle dark/light, persistência via SharedPreferences)
- [x] **Sobre o app** (showAboutDialog com versão e legalese)
- [x] **Logout** (confirmação dialog + signOut do Supabase)
- [x] **Limpar Cache** (CacheService integrado com tamanho do cache e confirmação)
- [x] **Gamificação** (Carteira, Conquistas, Inventário)
- [x] **Suporte** (Central de Ajuda, Reportar Bug)

---

## Bugs Conhecidos

| ID | Descrição | Severidade | Status |
|----|-----------|------------|--------|
| - | Nenhum bug registrado ainda | - | - |

---

## Prioridade de Desenvolvimento (Sprint Atual)

1. ~~**[ALTA]** Discover com categorias de comunidades~~ ✅
2. ~~**[ALTA]** Cards maiores em Communities~~ ✅
3. ~~**[ALTA]** Separação de perfis (global vs. comunidade)~~ ✅
4. ~~**[ALTA]** Botões funcionais em todas as telas~~ ✅ (toast "Coming soon" para features pendentes)
5. ~~**[ALTA]** Tela de busca fiel ao Amino~~ ✅
6. ~~**[ALTA]** Sistema de níveis com 20 levels~~ ✅
7. ~~**[ALTA]** Animações e transições~~ ✅
8. ~~**[ALTA]** Tela Join Community~~ ✅
9. ~~**[ALTA]** Estrutura de edição de comunidade~~ ✅
10. **[MÉDIA]** Tela de criação de post
11. **[MÉDIA]** Sistema de notificações
12. **[BAIXA]** Onboarding/Login
13. **[BAIXA]** Configurações
