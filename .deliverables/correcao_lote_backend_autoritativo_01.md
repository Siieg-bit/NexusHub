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

## Limitações da validação desta sessão

A aplicação das novas migrações no banco **não pôde ser executada automaticamente neste ambiente**, porque as variáveis `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` não estavam disponíveis na sessão atual. Assim, a validação de backend nesta rodada ficou restrita a revisão estrutural dos SQLs, inspeção de contratos e verificação estática dos pontos consumidores no frontend.

## Risco residual após este lote

Embora este lote avance de forma importante no endurecimento arquitetural, ainda permanecem itens relevantes para o próximo ciclo.

| Prioridade sugerida | Próximo item | Motivo |
|---|---|---|
| Alta | Aplicar e validar no Supabase as migrações 044 e 045 | Necessário para ativar as novas RPCs em ambiente real |
| Alta | Consolidar e validar o lote já iniciado de membership/moderação/broadcast no repositório | Há outros arquivos alterados no working tree que pertencem ao mesmo ciclo de correção e precisam ser fechados com testes integrados |
| Alta | Executar smoke test ponta a ponta de broadcast, revisão de wiki e convite DM | Confirma que os contratos corrigidos funcionam de fato no banco e na UI |
| Média/Alta | Continuar removendo lógica crítica residual do cliente em outras superfícies sensíveis | Aproxima o projeto de um backend realmente autoritativo |

## Conclusão

Este lote removeu os **inserts diretos remanescentes em `notifications` no frontend**, alinhou o serviço sistêmico do aplicativo às RPCs já existentes ou recém-criadas e corrigiu o fluxo de convites de DM no backend para respeitar o schema real da base. Com isso, o NexusHub avança mais um passo na direção recomendada pela auditoria: **menos regra crítica no cliente, mais efeitos sensíveis centralizados no backend**.
