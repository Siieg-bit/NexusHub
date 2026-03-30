# NexusHub — Notas de Desenvolvimento e Pendências

Este documento consolida as notas técnicas, análises de arquitetura e pendências identificadas durante o desenvolvimento do NexusHub.

## 1. Pendências de UI e Integração (TODOs)

Durante a auditoria do código, foram identificados os seguintes pontos que necessitam de implementação futura:

### Perfil Global (`profile_screen.dart`)
- O provider `userWallProvider` referencia uma tabela `wall_messages` que não existe no backend. A implementação correta deve utilizar a tabela `comments` com `profile_wall_id`.

### Perfil da Comunidade (`community_profile_screen.dart`)
- **Posts Salvos:** A aba atualmente é um placeholder vazio.
- **Botões de Ação:** Os botões "Friends", "Chat" e "Conquistas" estão com funções vazias (`/* TODO */`).

### Detalhes da Comunidade (`community_detail_screen.dart`)
- **Ações do AppBar:** Os botões "Presentes" (`claim gifts`) e "Galeria" estão pendentes.
- **Aba Online:** A página busca membros, mas falta a implementação da subscription realtime do Supabase para atualização em tempo real.

### Menu Lateral (`community_drawer.dart`)
- **Resource Links:** Seção pendente de implementação.
- **See More:** Funcionalidade para explorar mais comunidades.

### Interações com Posts (`post_detail_screen.dart`)
- As funções de "Salvar" (Bookmark) e "Compartilhar" (Share) estão com callbacks vazios.

### Criação de Conteúdo (`create_post_screen.dart`)
- Integração com Giphy para seleção de GIFs.
- Embed de músicas (ex: SoundCloud).
- Formatação de texto avançada (Negrito, Itálico, Tachado).

### Chat e Comunicação
- Criação de novos chats.
- Gravação e envio de mensagens de áudio.
- Sistema de gorjetas (tips) para usuários.
- Encaminhamento de mensagens.

### Feed Global e Lives
- Botões de ação no Global Feed estão vazios.
- Funcionalidades de "Iniciar Live" e "Criar Voice Chat" na tela de Lives.

## 2. Inconsistências de Banco de Dados (Frontend vs Backend)

Foi mapeada uma divergência entre as tabelas referenciadas no frontend e as existentes no backend Supabase. As correções necessárias são:

| Referência no Frontend | Tabela Real no Backend | Ação Necessária |
|------------------------|------------------------|-----------------|
| `achievements` | Não existe | Usar `store_items` ou criar tabela |
| `user_achievements` | Não existe | Criar tabela |
| `ad_rewards` | `ad_reward_logs` | Renomear referência no código |
| `chat_rooms` | `chat_threads` | Renomear referência no código |
| `message_reactions` | Não existe | Criar tabela |
| `messages` | `chat_messages` | Renomear referência no código |
| `privacy_settings` | `user_settings` | Renomear referência no código |
| `transactions` | `coin_transactions` | Renomear referência no código |
| `user_blocks` | `blocks` | Renomear referência no código |
| `user_inventory` | `user_purchases` | Renomear referência no código |
| `wallet_transactions` | `coin_transactions` | Renomear referência no código |
| `wallets` | `profiles.coins` | Utilizar o campo `coins` da tabela `profiles` |

## 3. Notas de Integração: Agora RTC

- O projeto utiliza o pacote `agora_rtc_engine` (SDK de baixo nível) para maior controle sobre a UI e funcionalidades (ex: níveis de áudio, controles customizados na `call_screen.dart`).
- A alternativa `agora_uikit` foi descartada para evitar conflitos e manter a interface personalizada.
- **Próximos passos para produção:** Implementar a geração de tokens via Edge Function no Supabase utilizando o App Certificate, substituindo o uso de tokens temporários ou App ID direto no client para maior segurança.

## 4. Notas de Integração: Gamificação e Reputação

- É necessário integrar a chamada RPC `add_reputation` em todas as ações relevantes do usuário (criar post, comentar, curtir, enviar mensagem no chat, seguir usuários, postar no mural) para alimentar o sistema de níveis e leaderboard.
- Apenas a funcionalidade de check-in diário está atualmente chamando a RPC `perform_checkin`.
