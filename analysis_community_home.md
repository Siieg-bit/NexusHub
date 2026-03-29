# Análise - Página Inicial da Comunidade

## Layout Amino (da screenshot):
1. **Top bar**: Seta voltar + "Claim gifts" (verde) + Gallery icon + Notificações (sino)
2. **Header com banner**: Banner de fundo + Avatar à esquerda + Nome da comunidade + "X Members" + Badge "Leaderboards"
3. **Check-in bar**: "Check In to earn a prize" + streak dots + botão verde "Check In"
4. **Live Chatrooms**: Scroll horizontal de cards de chat ao vivo (avatar do host + "Live" indicator + nome + membros)
5. **Tabs**: Guidelines | Featured | Latest Feed | Public Chatrooms
6. **Content**: Posts listados (Featured mostra títulos com bullet)
7. **Bottom bar**: Menu | Online (avatares + count) | + (criar) | Chats | Me

## Campos existentes no CommunityModel:
- configuration JSONB: post, chat, catalog, featured, ranking, sharedFolder, etc.
- themePack JSONB: pode armazenar configurações visuais customizáveis
- welcome_message: mensagem de boas-vindas

## O que precisa ser customizável pelo líder:
- Ordem das seções na home (check-in, live chats, tabs)
- Quais seções mostrar/esconder
- Welcome message
- Módulos habilitados (já existe no ACM)

## Plano de implementação:
1. Adicionar campo `home_layout` JSONB na tabela communities (ou usar themePack)
2. Reescrever community_detail_screen com bottom navigation bar estilo Amino
3. Adicionar tela de customização da home no ACM
