# Amino UI Deep Analysis - Notas de Investigação

## Tela Principal (Discover)
- Header: Avatar do usuário (esquerda), Search bar (centro), Language dropdown (EN), Coins badge (verde/amarelo), botão + (verde), Bell icon com badge vermelho
- Tabs no topo: "My Communities" | "Post Feed" 
- Grid de comunidades: 3 colunas, cards com imagem de capa + nome embaixo + badge de notificação
- Botões: "Explore Communities" (verde/cyan) e "Create Your Own" (com ícone)
- Cor de fundo: Azul escuro/navy (#1B1B3A ou similar)
- Cor de destaque: Verde cyan (#2dbe60 / turquesa)

## Bottom Navigation (4 tabs)
- Discover (ícone de caneta/edição)
- Communities (ícone de grid 2x2)
- Chats (ícone de balão de chat com badge vermelho)
- Store (ícone de casa/loja)

## Tela Communities
- Título "My Communities"
- Cards de comunidades em GRID horizontal scrollável
- Cada card: imagem de capa + nome + botão "CHECK IN" (verde cyan)
- Texto: "Long press the card to change position"
- Botão "CREATE YOUR OWN" (outline verde cyan, grande)
- Seção "Recommended Communities" abaixo

## Tela Chats (MUITO IMPORTANTE - Layout com sidebar)
- Sidebar esquerda vertical com ícones:
  - Clock (Recent) no topo
  - Globe (Global) com badge vermelho
  - Separador
  - Ícones das comunidades (redondos) - cada uma que o usuário participa
  - Botão + no final
- Área principal à direita:
  - "Create a new Chat" no topo
  - Lista de chats: avatar + nome + última mensagem + tempo
  - Seção "Recommended" com cards de chat com imagem de capa

## Tela INTERNA de Comunidade (PRIORIDADE)
Baseado na engenharia reversa e screenshots:
- **Header**: Cover image da comunidade no topo com gradiente
- **Side Panel / Navigation Drawer** (abre da esquerda):
  - Ícone da comunidade
  - Menu items: Home, Featured, Latest, Chat, Members, Wiki, Guidelines, Leaderboard
  - Cada item com ícone à esquerda
- **Feed principal**: 
  - Tabs: Featured | Latest (e possivelmente mais como Quizzes, Polls)
  - Cards de posts com: avatar do autor, nome, level badge, título, preview do conteúdo, imagem, likes, comments
- **Floating Action Button** (+) no canto inferior direito para criar post
- **Tipos de posts**: Blog, Poll, Quiz, Wiki Entry, Image, Story
- **Check-in**: Botão de check-in diário dentro da comunidade
- **Barra de ações rápida**: Na parte inferior ou lateral

## Chat Room (dentro de uma comunidade)
- Header: Seta voltar, # (hashtag), nome do chat, seta >, ícone de busca
- Mensagens: Avatar (esquerda), nome com badges, conteúdo, timestamp
- Reações com emojis abaixo das mensagens (com contadores)
- Input bar: +, stickers, emojis, campo de texto, emoji, microfone
- Cor de fundo: Preto (#000000 ou muito escuro)

## Perfil do Usuário
- Background image customizável
- Avatar grande centralizado (com frame/borda customizável)
- Online status (verde "Online")
- Nome do usuário
- Level badge: "Lv18 Muse" (fundo escuro, texto branco)
- Badges/tags: "Leader" (verde), "She/Her" (cinza), "Stroke of Midnight" (roxo), etc.
- Botão "Edit" 
- Streak badge: "218 Day Streak" (laranja) com ícone de troféu
- Coins: "589" (azul) com ícone Amino
- Stats em 3 colunas: Reputation | Following | Followers (números grandes)
- Bio section: "Member since [date] ([days] days)"
- Tabs: Posts [count] | Wall [count] | Saved Posts
- "Create a new post:" no final

## Cores Exatas do Amino
- Background principal: #1B1B3A (navy escuro) ou #0B0B23
- Background de cards: #16162A ou #1E1E38
- Cor de destaque/CTA: #2dbe60 (verde) ou #00D68F (cyan/turquesa)
- Texto principal: #FFFFFF
- Texto secundário: #8E8EA0 (cinza)
- Badge Leader: #2dbe60 (verde)
- Badge Curator: #E040FB (roxo/magenta)
- Streak: #FF9800 (laranja)
- Coins: #2196F3 (azul)
- Destructive/Notificação: #FF0000 (vermelho)

## Tipografia
- Font: Roboto ou similar sans-serif
- Títulos: Bold, 16-20px
- Corpo: Regular, 13-14px
- Labels: Medium, 10-12px
- Level badges: Bold, 10px
