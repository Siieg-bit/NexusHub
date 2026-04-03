# Correção — Lote 01 de endurecimento backend-autoritativo do NexusHub

**Data:** 02 de abril de 2026  
**Autor:** Manus AI

## Escopo do lote

Este lote concentrou-se em três frentes diretamente alinhadas ao relatório de auditoria já entregue: **broadcast administrativo/comunitário**, **remoção de mutações diretas sensíveis em notificações do frontend** e **correção de um contrato quebrado no fluxo de convites de DM**.

A prioridade desta sessão foi reduzir a dependência de `insert` direto no cliente em tabelas sensíveis, especialmente `notifications`, `chat_messages` e `chat_threads`, além de reparar um caminho real do backend que ainda escrevia colunas incompatíveis com o schema atual da tabela `notifications`.

## Alterações implementadas

| Área | Arquivo | Correção aplicada | Resultado esperado |
|---|---|---|---|
| Backend | `backend/supabase/migrations/044_fix_send_dm_invite_notification_contract.sql` | Criação de migração corretiva para sobrescrever `send_dm_invite` com uso do contrato real de `notifications` (`type`, `actor_id`, `chat_thread_id`, `action_url`) | Convites de DM deixam de falhar por uso de colunas inválidas como `notification_type` e `data` |
| Backend | `backend/supabase/migrations/045_send_system_notification_rpc.sql` | Nova RPC `send_system_notification` com `SECURITY DEFINER`, retornos estruturados e validação de permissões para team, system account e moderação comunitária | Fluxos sistêmicos passam a usar backend autoritativo para notificações |
| Frontend | `frontend/lib/core/services/system_account_service.dart` | Refatoração completa para substituir inserts diretos por chamadas às RPCs `send_broadcast` e `send_system_notification` | Elimina mutações diretas sensíveis do cliente em broadcasts, boas-vindas e avisos de moderação |
| Frontend | `frontend/lib/features/wiki/screens/wiki_curator_review_screen.dart` | Troca da gravação direta em `notifications` por chamada à RPC `send_system_notification` | A revisão de wiki passa a emitir notificação por backend em vez de cliente |

## Validação executada

Realizei validação estática dos arquivos Dart alterados nesta sessão usando o SDK Flutter local do ambiente. O formato foi normalizado e a análise retornou **zero issues** para os arquivos abaixo.

| Arquivo validado | Resultado |
|---|---|
| `frontend/lib/core/services/system_account_service.dart` | Formatado e analisado sem erros |
| `frontend/lib/features/wiki/screens/wiki_curator_review_screen.dart` | Formatado e analisado sem erros |

Também executei varreduras textuais para confirmar que **não restam `insert` diretos em `notifications` no frontend**, o que representa uma redução concreta de superfície sensível no cliente.

Além da validação estática do frontend, revalidei o acesso ao projeto Supabase com o **ref correto** e apliquei no banco as migrações do lote autoritativo. O diagnóstico inicial que indicava indisponibilidade de credenciais estava incorreto: o problema real foi uma checagem feita anteriormente com o identificador do projeto digitado de forma errada. Com a correção desse ponto, a execução SQL funcionou normalmente.

| Migração aplicada no Supabase | Status |
|---|---|
| `042_send_broadcast_rpc.sql` | Aplicada com sucesso |
| `043_secure_moderation_actions.sql` | Aplicada com sucesso |
| `044_secure_membership_rpcs.sql` | Aplicada com sucesso |
| `044_fix_send_dm_invite_notification_contract.sql` | Aplicada com sucesso |
| `045_send_system_notification_rpc.sql` | Aplicada com sucesso |

Depois da aplicação, confirmei no banco a presença das funções-chave do lote, incluindo `send_system_notification`, `send_dm_invite`, `log_moderation_action`, `change_member_role` e `remove_member_secure`. Na inspeção do catálogo também apareceu a coexistência de **três assinaturas diferentes de `send_broadcast`**, sendo que a nova variante utilizada pelo frontend desta sessão está presente e disponível.

## Limitações da validação desta sessão

A parte de backend deste lote foi efetivamente aplicada e validada em nível de catálogo de funções, mas **ainda falta o smoke test funcional ponta a ponta pela interface do app**, especialmente nos fluxos de broadcast, revisão de wiki e convite DM. Em outras palavras, o endurecimento estrutural e a publicação das RPCs já ocorreram, porém ainda resta a validação operacional completa do comportamento em runtime.

## Risco residual após este lote

Embora este lote avance de forma importante no endurecimento arquitetural, ainda permanecem itens relevantes para o próximo ciclo.

| Prioridade sugerida | Próximo item | Motivo |
|---|---|---|
| Alta | Executar smoke test ponta a ponta de broadcast, revisão de wiki e convite DM | Confirma o comportamento real dos contratos recém-publicados no banco e no app |
| Alta | Consolidar e validar o lote já iniciado de membership/moderação/broadcast no repositório | Há outros arquivos alterados no working tree que pertencem ao mesmo ciclo de correção e precisam ser fechados com testes integrados |
| Média/Alta | Revisar a coexistência de múltiplas assinaturas de `send_broadcast` | Reduz ambiguidade operacional e risco de chamadas para variantes legadas |
| Média/Alta | Continuar removendo lógica crítica residual do cliente em outras superfícies sensíveis | Aproxima o projeto de um backend realmente autoritativo |

## Conclusão

Este lote removeu os **inserts diretos remanescentes em `notifications` no frontend**, alinhou o serviço sistêmico do aplicativo às RPCs já existentes ou recém-criadas e corrigiu o fluxo de convites de DM no backend para respeitar o schema real da base. Com isso, o NexusHub avança mais um passo na direção recomendada pela auditoria: **menos regra crítica no cliente, mais efeitos sensíveis centralizados no backend**.
