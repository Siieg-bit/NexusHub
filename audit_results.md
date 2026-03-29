# Auditoria de Funcionalidades Faltantes

## 1. REPUTAÇÃO NÃO INTEGRADA NAS AÇÕES
- `add_reputation` RPC existe no backend (migration 019) mas NÃO é chamada em:
  - Criar post (create_post_screen.dart)
  - Comentar em post (post_detail_screen.dart)
  - Receber like (post_card.dart / post_detail_screen.dart)
  - Enviar mensagem em chat (chat_room_screen.dart)
  - Seguir alguém (profile_screen.dart / followers_screen.dart)
  - Escrever no mural (community_profile_screen.dart / user_wall_screen.dart)
- Apenas o check-in chama `perform_checkin` RPC

## 2. PERFIL GLOBAL (profile_screen.dart)
- Usa `wall_messages` tabela que NÃO EXISTE — deveria usar `comments` com `profile_wall_id`
- Provider `userWallProvider` referencia tabela inexistente

## 3. PERFIL DA COMUNIDADE (community_profile_screen.dart)
- Wall usa `comments` com `profile_wall_id` — CORRETO
- Posts Salvos tab é placeholder vazio (apenas ícone + texto "Nenhum post salvo")
- Botão "Friends" é `/* TODO: Add friend */`
- Botão "Chat" é `/* TODO: Open chat */`
- Botão "Conquistas" é `/* TODO: Achievements */`

## 4. COMMUNITY DETAIL SCREEN
- `/* TODO: claim gifts */` — botão Presentes
- `/* TODO: gallery */` — botão Galeria
- Online page busca membros mas não tem realtime subscription

## 5. COMMUNITY DRAWER
- `// TODO: Resource Links` — seção de links
- `// TODO: See more` — ver mais comunidades

## 6. POST DETAIL SCREEN
- `/* TODO: Bookmark */` — salvar post
- `/* TODO: Share */` — compartilhar post
- Botões de ação vazios: `onTap: () {}`

## 7. CREATE POST SCREEN
- GIF picker: `/* TODO: Giphy */`
- Music embed: `/* TODO: SoundCloud */`
- Bold/Italic/Strikethrough: todos TODO

## 8. CHAT
- `/* TODO: Novo chat */` — criar novo chat
- `// TODO: Record audio` — gravar áudio
- `// TODO: Select user to tip` — gorjeta
- `// TODO: Forward message` — encaminhar

## 9. GLOBAL FEED
- 3 botões com `onTap: () {}` vazios

## 10. LIVE SCREEN
- `/* TODO: Iniciar live */`
- `/* TODO: Criar Voice Chat */`

## PRIORIDADES (funcionalidades que afetam o que foi implementado):
1. Corrigir wall_messages → comments no profile_screen.dart
2. Integrar add_reputation nas ações (post, comment, like, chat, follow, wall)
3. Implementar Posts Salvos (bookmarks) no community_profile
4. Implementar botões Friends/Chat no community_profile
5. Implementar Bookmark no post_detail
