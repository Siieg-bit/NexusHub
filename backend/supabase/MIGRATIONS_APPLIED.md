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

### Lote 242-249 — Aplicado em 07/05/2026 a 08/05/2026

| Migration | Arquivo | Status |
|-----------|---------|--------|
| 242 | `242_ota_translations_remote_config_flag.sql` | Aplicada e validada |
| 243 | `243_reward_tasks_free_coins.sql` | Aplicada e validada |
| 244 | `244_level_definitions.sql` | Aplicada e validada |
| 245 | `245_system_announcements_server_driven.sql` | Aplicada e validada |
| 246 | `246_onboarding_slides_server_driven.sql` | Aplicada e validada |
| 247 | `247_streaming_rules_server_driven.sql` | Aplicada e validada |
| 248 | `248_cache_policies_remote_config.sql` | Aplicada e validada |
| 249 | `249_notification_channels_remote_config.sql` | Aplicada e validada |

### Observações

- Migration 099: referência a `chat_thread_members` corrigida para `chat_members` (tabela real no banco).
- Migration 101: enum `wiki` adicionado a `post_type` e `community` adicionado a `post_visibility` como pré-requisito.
- Migration 242: flag `features.ota_translations_enabled` confirmada em `app_remote_config` no projeto remoto.
- Migration 243: tabela `reward_tasks`, RPC `get_reward_tasks`, grants, policies, seed PT/EN e flag `features.remote_reward_tasks_enabled` confirmados no projeto remoto.
- Migration 244: tabela `level_definitions`, RPC `get_level_definitions`, grants, policies, seed multilíngue de 200 registros ativos e flag `features.remote_level_definitions_enabled` confirmados no projeto remoto.
- Migration 245: tabela `system_announcements` estendida com `locale`, `severity`, `placement`, `dismissible`, `sort_order`, `schema_version` e `metadata`; RPC `get_active_announcements_v2`, grant `authenticated`, policies, flag `features.remote_announcements_enabled` e preservação da RPC legada `get_active_system_announcements` confirmados no projeto remoto.
- Migration 246: tabela `onboarding_slides`, RPC `get_onboarding_slides`, grant `authenticated`, policies, flag `features.remote_onboarding_slides_enabled` e seed multilíngue de 30 registros ativos em 10 locales confirmados no projeto remoto.
- Migration 247: tabela `streaming_platform_rules`, RPC `get_streaming_platform_rules`, grant `authenticated`, policies, flag `features.remote_streaming_rules_enabled`, seed conservador de 17 plataformas, metadados DRM e blocklist de URLs diretas confirmados no projeto remoto.
- Migration 248: flag `features.remote_cache_policies_enabled` e payload `cache.ttl_seconds` confirmados em `app_remote_config`; baseline validado com chaves `default`, `posts`, `post`, `my_communities`, `community`, `messages`, `profiles`, `global_feed`, `for_you_feed`, `notifications` e `wiki`, todos com valores positivos.
- Migration 249: flag `features.remote_notification_channels_enabled` e payload `notifications.channels` confirmados em `app_remote_config`; validação remota confirmou canais habilitados `default`, `chat`, `social`, `community` e `moderation`, IDs estáveis `nexushub_default`, `nexushub_chat`, `nexushub_social`, `nexushub_community` e `nexushub_moderation`, além do `type_channel_map` para tipos como `chat`, `match`, `community_invite`, `strike` e `ban`.
