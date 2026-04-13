# Relatório de auditoria de segurança do Supabase

A auditoria de segurança foi concluída com foco em **políticas RLS**, **funções RPC**, **grants indiretos refletidos nas policies** e **configuração de storage** do projeto Amino Nexus. O trabalho comparou o estado remoto do projeto Supabase com as migrations versionadas no repositório e teve como objetivo separar divergências **reais e corrigíveis** de diferenças **legadas, equivalentes ou apenas nominais**.

## Resumo executivo

A divergência **real** identificada e corrigida nesta etapa estava no **Storage**. O bucket **`store-assets`** já existia no ambiente remoto e era utilizado por migrations e URLs do produto, mas ainda **não estava devidamente versionado** no histórico local. Além disso, o ambiente remoto já possuía políticas específicas para esse bucket, também ausentes no versionamento. Essa inconsistência foi reconciliada com uma nova migration idempotente e aplicada no Supabase remoto.

| Item | Situação antes | Ação tomada | Situação depois |
|---|---|---|---|
| Bucket `store-assets` | Existia remotamente, não versionado localmente | Migration 091 criada e aplicada | Alinhado |
| Policies do `store-assets` | Existiam remotamente, não versionadas localmente | Policies adicionadas de forma idempotente | Alinhado |
| Commit Git | Pendente | Commit e push executados | Concluído |

## Correção aplicada

A correção foi registrada na migration **`091_reconcile_store_assets_bucket_and_policies.sql`**. Essa migration garante, de forma segura e repetível, que o bucket **`store-assets`** exista como público e que as políticas remotas relevantes passem a fazer parte do histórico do projeto.

| Objeto reconciliado | Tipo | Observação |
|---|---|---|
| `store-assets` | Bucket de storage | Passou a ser explicitamente versionado |
| `store_assets_public_read` | Policy `SELECT` | Mantém leitura pública dos assets |
| `store_assets_team_insert` | Policy `INSERT` | Restringe escrita à equipe |
| `store_assets_team_update` | Policy `UPDATE` | Restringe alteração à equipe |
| `store_assets_team_delete` | Policy `DELETE` | Restringe exclusão à equipe |

Após a aplicação da migration, a comparação voltou a indicar **zero divergências de storage bucket** entre o repositório e o ambiente remoto para esse escopo específico.

## Divergências remanescentes analisadas

As demais diferenças encontradas foram analisadas e classificadas como **legadas**, **semanticamente equivalentes** ou **não prioritárias para reconciliação automática** nesta rodada, porque uma correção cega poderia sobrescrever comportamento já em produção sem ganho claro de segurança.

| Categoria | Objeto | Leitura técnica |
|---|---|---|
| Policy nominal | `public.chat_members` | Há diferença de nomenclatura e distribuição de policies, mas não foi evidenciado um gap funcional crítico nesta etapa |
| Policy remota extra | `public.chat_messages_delete` | Policy existente remotamente; requer revisão funcional antes de versionar ou remover |
| Policies legadas | `public.favorite_stickers` | Conjunto remoto aparece como legado e sem correspondência clara de uso atual no versionamento |
| Policy equivalente com outro desenho | `public.recently_used_stickers` | A diferença sugere mudança histórica de modelagem de policies, não necessariamente falha ativa |
| Policy remota extra | `public.user_purchases` | `purchases_select_equipped_public` deve ser validada funcionalmente antes de qualquer reconciliação |
| Funções remotas não versionadas | `public.get_service_role_key`, `public.rls_auto_enable`, `public.unpin_message` | Exigem revisão manual orientada a produto e segurança antes de entrar no histórico |
| Função local sem par remoto | `public.handle_like_change` | Diferença de inventário que deve ser revisada com cautela antes de alterar produção |

## Aplicação no ambiente remoto

A migration foi aplicada com sucesso no projeto Supabase remoto já vinculado ao repositório. Em seguida, a comparação do inventário de segurança indicou o seguinte resultado consolidado:

| Métrica | Resultado pós-correção |
|---|---|
| `local_storage_buckets` | 21 |
| `remote_storage_buckets` | 21 |
| `storage_bucket_gaps` | 0 |
| `policy_gap_tables` | 5 |
| `function_security_gaps` | 4 |

Isso confirma que a inconsistência de storage, que era a divergência operacional mais objetiva desta rodada, foi de fato eliminada.

## Registro no GitHub

A alteração foi registrada e enviada ao repositório remoto com o seguinte commit:

| Campo | Valor |
|---|---|
| Commit | `4eb8bdc` |
| Mensagem | `chore: version store assets storage policies` |
| Branch | `main` |

## Próximo passo recomendado

O próximo passo mais seguro é uma **auditoria funcional dirigida** das divergências remanescentes de RLS e funções, começando por **`chat_messages_delete`**, **`purchases_select_equipped_public`** e **`unpin_message`**. Diferentemente do caso do bucket `store-assets`, esses itens podem representar tanto comportamento legítimo em produção quanto resquícios legados, e por isso exigem validação orientada a uso real antes de qualquer migração adicional.

## Referências

[1]: https://github.com/Siieg-bit/NexusHub "Repositório NexusHub"
[2]: https://supabase.com/docs/guides/database/postgres/row-level-security "Supabase Docs: Row Level Security"
[3]: https://supabase.com/docs/guides/storage/security/access-control "Supabase Docs: Storage access control"
[4]: https://supabase.com/docs/reference/cli/supabase-db-push "Supabase CLI: db push"
