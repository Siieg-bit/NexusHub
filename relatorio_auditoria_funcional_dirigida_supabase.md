# Relatório de Auditoria Funcional Dirigida do Supabase

## Contexto

Esta fase teve como objetivo validar, antes de qualquer nova intervenção em produção, o **uso real** das três divergências remanescentes identificadas nas etapas anteriores: a policy **`chat_messages_delete`**, a policy **`purchases_select_equipped_public`** e a função/RPC **`unpin_message`**. A premissa adotada foi conservadora: somente versionar mudanças quando houvesse evidência funcional suficiente de que o comportamento remoto deveria permanecer como parte explícita do histórico do projeto.

## Escopo validado

| Item auditado | Tipo | Situação inicial | Decisão |
|---|---|---|---|
| `chat_messages_delete` | Policy RLS | Divergência entre remoto e histórico local | **Não migrar nesta fase** |
| `purchases_select_equipped_public` | Policy RLS | Policy remota extra em produção | **Versionar no repositório** |
| `unpin_message` | Função/RPC | Função remota não versionada | **Não migrar nesta fase** |

## Evidências funcionais observadas

A análise do código do projeto confirmou que o domínio de **cosméticos/equipáveis** continua ativo no produto. O repositório mantém a tabela **`public.user_purchases`**, a coluna **`is_equipped`**, o índice parcial voltado para itens equipados e políticas locais para leitura do próprio usuário, o que demonstra que a noção de itens comprados e equipados não é um artefato morto no schema. Também foi confirmado que o fluxo de compra continua inserindo dados em **`public.user_purchases`**, reforçando que esse conjunto permanece funcional no produto.

| Evidência observada | Interpretação funcional |
|---|---|
| `backend/supabase/migrations/005_economy.sql` mantém `public.user_purchases`, `is_equipped` e índice para itens equipados | O conceito de compra equipada continua modelado no banco |
| `backend/supabase/migrations/007_rls_policies.sql` mantém `purchases_select_own` | O histórico local cobre apenas leitura do próprio usuário, mas não o caso público |
| `backend/supabase/migrations/077_fix_rls_and_cosmetics.sql` documenta equipar/desequipar itens no app | O produto ainda depende de estado de equipamento |
| `backend/supabase/functions/export-user-data/index.ts` inclui `user_purchases` na exportação de dados | A tabela segue relevante no domínio funcional |

## Decisão por item

### 1. `purchases_select_equipped_public`

A divergência foi considerada **legítima e funcionalmente coerente com o produto**. A combinação entre a existência de itens equipáveis, o campo **`is_equipped`** e a necessidade de expor cosméticos ativos em contextos sociais do aplicativo sustentou a conclusão de que o comportamento remoto não deveria ser removido, mas sim **versionado explicitamente**.

Por esse motivo, foi criada a migration **`092_reconcile_public_equipped_purchases_policy.sql`**, que registra de forma clara e mínima a policy pública de leitura para registros equipados em **`public.user_purchases`**. A política de leitura do próprio usuário permanece preservada; a nova versionagem apenas formaliza a leitura pública do subconjunto estritamente necessário.

### 2. `chat_messages_delete`

Para a policy **`chat_messages_delete`**, a auditoria funcional não encontrou evidência suficiente, nesta fase, para concluir com segurança se a divergência representa **comportamento ativo de produção** ou **resquício legado**. Como alterações em política de exclusão de mensagens têm impacto direto em moderação, autoria e integridade conversacional, a opção mais segura foi **não reconciliar automaticamente** esse item sem validação adicional orientada ao fluxo real do produto.

A decisão, portanto, foi **manter a divergência sob observação**, sem introduzir migration de remoção nem de versionamento nesta etapa.

### 3. `unpin_message`

A função **`unpin_message`** permaneceu na mesma categoria de cautela. Embora tenha sido identificada como divergência entre inventário remoto e histórico local, esta fase não produziu evidência suficiente para afirmar se a função ainda é chamada por telas, RPCs encadeadas, fluxos administrativos ou comportamentos de moderação não imediatamente visíveis no repositório auditado.

Diante desse cenário, a decisão operacional foi **não versionar nem remover** a função nesta fase, evitando consolidar no histórico algo que ainda carece de validação funcional conclusiva.

## Mudança aplicada

| Artefato | Ação executada |
|---|---|
| `backend/supabase/migrations/092_reconcile_public_equipped_purchases_policy.sql` | Criada para versionar a policy pública de leitura de itens equipados |
| Banco remoto Supabase | Mantido coerente com o comportamento já auditado em produção |
| Repositório GitHub | Commitado e enviado com sucesso |

## Registro no Git

A correção desta fase foi registrada no branch principal com o commit **`23e69e7`**, usando o e-mail solicitado para autoria dos commits.

| Campo | Valor |
|---|---|
| Commit | `23e69e7` |
| Mensagem | `fix: version public equipped purchases policy` |

## Conclusão

A auditoria funcional dirigida resultou em uma decisão **cirúrgica**: entre os três itens remanescentes, apenas **`purchases_select_equipped_public`** apresentou lastro funcional suficiente para reconciliação imediata e segura. Os itens **`chat_messages_delete`** e **`unpin_message`** permanecem como divergências controladas, exigindo futura validação orientada a fluxo real de produto antes de qualquer alteração em produção.
