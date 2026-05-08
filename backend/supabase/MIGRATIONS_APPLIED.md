# Migrations Aplicadas no Supabase

## Projeto: Aminexus (ylvzqqvcanzzswjkqeya)

### Lote 098-103 — Aplicado em 13/04/2026

| Migration | Arquivo | Status |
|-----------|---------|--------|
| 098 | `098_fix_quiz_system.sql` | Aplicada |
| 099 | `099_chat_forms_support.sql` | Aplicada |
| 100 | `100_improve_drafts_system.sql` | Aplicada |
| 101 | `101_fix_wiki_system.sql` | Aplicada |
| 102 | `102_community_visual_enhancements.sql` | Aplicada |
| 103 | `103_smart_links_system.sql` | Aplicada |

### Lote 242-244 — Aplicado em 07/05/2026

| Migration | Arquivo | Status |
|-----------|---------|--------|
| 242 | `242_ota_translations_remote_config_flag.sql` | Aplicada e validada |
| 243 | `243_reward_tasks_free_coins.sql` | Aplicada e validada |
| 244 | `244_level_definitions.sql` | Aplicada e validada |

### Observações

- Migration 099: referência a `chat_thread_members` corrigida para `chat_members` (tabela real no banco).
- Migration 101: enum `wiki` adicionado a `post_type` e `community` adicionado a `post_visibility` como pré-requisito.
- Migration 242: flag `features.ota_translations_enabled` confirmada em `app_remote_config` no projeto remoto.
- Migration 243: tabela `reward_tasks`, RPC `get_reward_tasks`, grants, policies, seed PT/EN e flag `features.remote_reward_tasks_enabled` confirmados no projeto remoto.
- Migration 244: tabela `level_definitions`, RPC `get_level_definitions`, grants, policies, seed multilíngue de 200 registros ativos e flag `features.remote_level_definitions_enabled` confirmados no projeto remoto.
