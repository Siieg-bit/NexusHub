# Relatório de validação operacional — `chat_messages_delete` e `unpin_message`

## Contexto

Esta etapa teve como objetivo sair da zona cinzenta deixada pela auditoria anterior e validar, com **evidência remota e evidência de uso no código**, o que fazer com as duas divergências remanescentes do domínio de chat no projeto **NexusHub**: a policy RLS **`chat_messages_delete`** e a função/RPC **`unpin_message`**.

A abordagem adotada foi conservadora. Em vez de criar migrations adicionais por simetria de inventário, a validação buscou responder duas perguntas práticas: **o que existe hoje em produção** e **o que o aplicativo realmente usa**.

## Evidência remota confirmada

A inspeção remota do projeto Supabase, feita por consulta somente leitura à Management API, confirmou o seguinte estado atual em produção.

| Objeto remoto | Definição confirmada | Leitura operacional |
|---|---|---|
| `public.chat_messages_delete` | Policy `FOR DELETE USING (auth.uid() = author_id)` sobre `public.chat_messages` | O banco permite **DELETE direto apenas pelo autor** |
| `public.unpin_message(p_thread_id uuid)` | Função `SECURITY DEFINER` que limpa `chat_threads.pinned_message_id`, valida **host/co-host/time** e insere mensagem de sistema `system_unpin` | Existe um fluxo remoto explícito de **desfixação** |

> A função remota `unpin_message` não é um stub vazio: ela implementa regra de autorização, atualiza o thread e registra evento sistêmico de desfixação.

## Evidência do histórico versionado

O histórico local do repositório mostra um desenho diferente para os fluxos de chat.

| Artefato local | Evidência observada | Implicação |
|---|---|---|
| `027_chat_enhancements_and_drafts.sql` | Versiona `delete_chat_message_for_all` e `delete_chat_message_for_me` como RPCs `SECURITY DEFINER` | O produto foi modelado para **soft delete e deleção contextual**, não para `DELETE` direto como fluxo principal |
| `027_chat_enhancements_and_drafts.sql` | `delete_chat_message_for_all` permite **autor, host ou co-host** e converte a mensagem para `system_deleted` com `is_deleted = true` | O comportamento funcional esperado é mais amplo do que a policy remota `chat_messages_delete` |
| `046_missing_rpcs.sql` | Versiona `pin_message`, mas **não** versiona `unpin_message` | O histórico local contempla **fixação**, mas não a **desfixação** |

## Evidência de uso real no aplicativo

A auditoria do frontend confirmou que o aplicativo não usa `DELETE` direto em `chat_messages` e também não chamou `unpin_message` em nenhum ponto encontrado no repositório.

| Evidência no app | Arquivo | Leitura funcional |
|---|---|---|
| Exclusão para todos via RPC `delete_chat_message_for_all` | `frontend/lib/features/chat/screens/chat_room_screen.dart` | O app usa **RPC de soft delete**, não `DELETE` direto |
| Exclusão para mim via RPC `delete_chat_message_for_me` | `frontend/lib/features/chat/screens/chat_room_screen.dart` | A deleção pessoal também é feita por RPC dedicada |
| Fixação via RPC `pin_message` | `frontend/lib/features/chat/screens/chat_room_screen.dart` | Existe fluxo explícito de **fixar** mensagem |
| Ausência de chamadas `unpin_message` | busca global no repositório | Não houve evidência de uso direto da RPC remota no código auditado |
| Tipos `system_pin` e `system_unpin` reconhecidos pela UI | `frontend/lib/features/chat/screens/chat_room_screen.dart` | A UI **entende** eventos de desfixação, mesmo sem expor chamada direta à RPC |
| Strings de interface para mensagem desafixada | arquivos de localização | Há traço funcional de recurso existente ou planejado |

## Interpretação por item

### 1. `chat_messages_delete`

A policy remota existe e permite que o **autor** faça `DELETE` direto na tabela `chat_messages`. No entanto, o aplicativo auditado não usa esse caminho. O frontend chama RPCs específicas de deleção, e a principal delas, `delete_chat_message_for_all`, realiza **soft delete** com regras mais amplas do que a policy remota: além do autor, **host e co-host** também podem executar a ação.

Isso produz uma conclusão importante: **versionar agora a policy remota como se fosse parte essencial do comportamento do produto seria enganoso**, porque o desenho funcional realmente usado pelo app está concentrado nas RPCs de deleção e não em `DELETE` direto por RLS.

A policy remota pode ser apenas um resquício compatível, uma rota alternativa antiga ou um escape residual ainda não removido. Como a auditoria atual não identificou uso ativo desse `DELETE` direto no aplicativo, a decisão mais segura continua sendo **não migrar nesta fase**.

### 2. `unpin_message`

Diferentemente de um artefato morto óbvio, a função remota `unpin_message` tem lógica consistente e alinhada ao domínio de chat: valida autorização, limpa `pinned_message_id` e registra uma mensagem `system_unpin`. Além disso, o frontend reconhece `system_unpin` e possui textos de UI relacionados a mensagem desafixada.

Ainda assim, a busca no repositório não encontrou **nenhuma chamada real** à RPC `unpin_message`, nem uma ação de UI claramente ligada a desafixar mensagem dentro da tela auditada. O fluxo visível no app é apenas o de **fixar** mensagem por meio de `pin_message`.

Isso sugere duas hipóteses plausíveis: ou a função remota atende um fluxo ainda não exposto no cliente atual, ou ela é um remanescente funcional de uma implementação anterior/incompleta. Como não há prova suficiente para escolher entre essas hipóteses com segurança, a decisão prudente também é **não versionar nem remover nesta fase**.

## Decisão operacional recomendada

| Item | Decisão | Justificativa |
|---|---|---|
| `chat_messages_delete` | **Manter como divergência controlada** | O app usa RPCs de soft delete; não há evidência de `DELETE` direto em `chat_messages` |
| `unpin_message` | **Manter como divergência controlada** | A função é real e coerente, mas não apareceu como fluxo chamado pelo código auditado |

## Próximo passo mais seguro

A próxima etapa recomendada não é uma migration imediata, mas uma **validação dirigida em ambiente funcional** com dados reais ou staging. O ideal é confirmar, com execução assistida, se existe algum cliente antigo, painel administrativo, automação ou fluxo não auditado que ainda dependa de `DELETE` direto ou da RPC `unpin_message`.

| Cenário a testar | Objetivo |
|---|---|
| Excluir mensagem como autor | Verificar se algum fluxo fora do frontend atual usa `DELETE` direto em vez de RPC |
| Excluir mensagem como host/co-host | Confirmar que o comportamento esperado continua sendo o da RPC `delete_chat_message_for_all` |
| Fixar e depois desafixar uma mensagem no mesmo thread | Descobrir se a desfixação existe por fluxo oculto, cliente antigo ou chamada indireta |
| Inspecionar logs de RPC/queries do projeto | Identificar uso recente de `unpin_message` ou `DELETE FROM chat_messages` |

## Conclusão

Com a evidência agora disponível, a posição mais segura é **não criar migration adicional neste momento** para nenhum dos dois objetos.

A policy **`chat_messages_delete`** existe remotamente, mas não representa o fluxo principal usado pelo aplicativo auditado. A função **`unpin_message`** também existe remotamente e possui lógica legítima, porém sem uso direto comprovado no código atual. Portanto, ambas devem permanecer como **divergências controladas**, aguardando validação funcional final antes de qualquer reconciliação ou limpeza em produção.
