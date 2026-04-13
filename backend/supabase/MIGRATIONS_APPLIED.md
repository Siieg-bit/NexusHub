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

### Observações

- Migration 099: referência a `chat_thread_members` corrigida para `chat_members` (tabela real no banco).
- Migration 101: enum `wiki` adicionado a `post_type` e `community` adicionado a `post_visibility` como pré-requisito.
