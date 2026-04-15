# Auditoria final atualizada dos bugs do anexo

Após a rodada complementar de correções, a cobertura do arquivo anexo evoluiu de forma significativa. Esta revisão foi feita por **inspeção estática do código atualmente alterado no repositório** e pela conferência direta dos arquivos modificados nesta etapa.

| # | Item do anexo | Status atualizado | Conclusão objetiva |
|---|---|---|---|
| 1 | Votação de enquete no chat | **Corrigido** | O chat possui renderização própria para enquete, grava votos por `message_id` e conta os votos persistidos no backend dedicado.[1] [2] |
| 2 | Nick/foto locais em comentários, reposts e miniaturas do feed | **Corrigido** | O feed, os detalhes do post e a paginação priorizam dados locais da comunidade, inclusive em reposts e conteúdo aninhado.[3] [4] [5] |
| 3 | Curador com escopo reduzido; “sem moderador” | **Parcial** | O fluxo funcional foi reduzido para líder e curador, e a UI principal deixa de promover o papel moderador. Ainda assim, permanecem referências legadas de compatibilidade em partes do código e em verificações amplas de staff, então trato o item como praticamente resolvido, porém não totalmente eliminado da base.[6] [7] |
| 4 | Ocultar post sem apagar, com placeholder para membros normais e visível para líderes/curadores | **Corrigido** | O card do feed agora mostra placeholder apenas para membros comuns e mantém o conteúdo visível com aviso para staff da comunidade.[3] |
| 5 | Nova mecânica de advertência: verbal + silence 24h/7d/1 mês, podendo combinar | **Corrigido** | O painel oferece advertência verbal, silenciamento de `24h`, `7d` e `30d`, com combinação entre aviso e silêncio.[6] |
| 6 | Ocultar perfil da comunidade no estilo Amino, sem sumir completamente para todos | **Parcial** | A tela de perfil comunitário passou a respeitar `is_hidden` com exceção para o próprio dono e staff, e houve tratamento adicional nas listagens. Ainda assim, como se trata de comportamento transversal, eu manteria validação manual em mais de uma tela antes de chamar de 100% encerrado.[8] [5] |
| 7 | Renomear “Gerenciar cargos” para “Opções de moderação” | **Corrigido** | O cabeçalho do painel foi ajustado para exibir **“Opções de moderação”** quando o alvo não é o próprio usuário.[6] |
| 8 | Erro ao voltar de chat público (`GoError: There is nothing to pop`) | **Corrigido** | O retorno do chat foi protegido com fallback de navegação quando não há stack para `pop`.[9] |
| 9 | Líder poder desativar chats públicos e privados em grupo | **Corrigido** | Foi adicionada RPC para ativar/desativar `chat_threads`, opção correspondente no menu da sala e bloqueio visual/funcional do envio quando o chat está desativado.[9] [10] |
| 10 | Chats com a mesma pessoa aparecendo em outras comunidades | **Corrigido** | A nova migração redefine `send_dm_invite` com `p_community_id` e passa a procurar DMs existentes também pelo escopo da comunidade, evitando reaproveitamento indevido entre comunidades diferentes.[10] |
| 11 | Erro ao criar quiz | **Corrigido** | O fluxo de criação agora usa o retorno real da RPC `create_quiz_with_questions`, valida `success/post_id` e atualiza o post correto com `quiz_data` e `editor_metadata`, em vez de adivinhar o último quiz criado.[11] [12] |
| 12 | Erro ao recuperar rascunho por causa de `addTag` | **Corrigido** | O editor deixou de depender da chave inexistente `addTag` e passou a usar fallback seguro para o texto de tags.[13] |

## Síntese executiva

A situação final ficou **substancialmente melhor** do que na auditoria anterior. Os pontos que antes estavam claramente pendentes em **desativação de chats**, **isolamento de DMs por comunidade**, **erro de criação de quiz** e **placeholder de posts ocultados com exceção para staff** agora possuem evidências objetivas no código.[3] [9] [10] [11]

No entanto, para manter rigor técnico, eu ainda classifico dois itens como **parciais**. O primeiro é a remoção completa do conceito de **moderador**, porque o fluxo principal foi simplificado, mas a base ainda carrega compatibilidades legadas. O segundo é a ocultação de perfil “estilo Amino”, porque embora a proteção central já exista, este tipo de regra depende de conferência manual em múltiplas telas e listagens para cravar cobertura total sem execução end-to-end.[6] [8]

## Balanço final atualizado

| Classificação | Quantidade |
|---|---:|
| **Corrigido** | 10 |
| **Parcial** | 2 |
| **Pendente** | 0 |
| **Total de itens auditados** | 12 |

## Referências

[1]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/chat/widgets/message_bubble.dart "message_bubble.dart"
[2]: file:///home/ubuntu/workspace/NexusHub/backend/supabase/migrations/112_chat_poll_votes.sql "112_chat_poll_votes.sql"
[3]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/feed/widgets/post_card.dart "post_card.dart"
[4]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/feed/screens/post_detail_screen.dart "post_detail_screen.dart"
[5]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/core/services/pagination_service.dart "pagination_service.dart"
[6]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/moderation/widgets/member_role_manager.dart "member_role_manager.dart"
[7]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/moderation/widgets/post_moderation_menu.dart "post_moderation_menu.dart"
[8]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/profile/screens/community_profile_screen.dart "community_profile_screen.dart"
[9]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/chat/screens/chat_room_screen.dart "chat_room_screen.dart"
[10]: file:///home/ubuntu/workspace/NexusHub/backend/supabase/migrations/113_chat_scope_and_status_fixes.sql "113_chat_scope_and_status_fixes.sql"
[11]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/feed/screens/create_quiz_screen.dart "create_quiz_screen.dart"
[12]: file:///home/ubuntu/workspace/NexusHub/backend/supabase/migrations/046_missing_rpcs.sql "046_missing_rpcs.sql"
[13]: file:///home/ubuntu/workspace/NexusHub/frontend/lib/features/feed/screens/create_post_screen.dart "create_post_screen.dart"
