# Análise: get_user_profile vs profiles table

## Colunas que a RPC referencia mas NÃO existem na tabela profiles:
- `v_profile.xp` — NÃO EXISTE (profiles não tem coluna xp)
- `v_profile.global_role` — NÃO EXISTE (profiles tem is_team_admin, is_team_moderator, is_system_account)
- `v_profile.is_verified` — NÃO EXISTE (profiles tem is_nickname_verified)
- `v_profile.is_online` — NÃO EXISTE (profiles tem online_status INTEGER)
- `v_profile.last_online_at` — NÃO EXISTE (profiles tem last_seen_at)
- `v_profile.media_list` — NÃO EXISTE
- `v_profile.background_url` — NÃO EXISTE (profiles tem banner_url)

## Colunas que a RPC referencia e EXISTEM:
- id, nickname, icon_url, bio, amino_id, level, coins, created_at, consecutive_checkin_days

## Status do post count:
- RPC conta posts com `status = 'ok'` mas o app usa `status = 'published'`

## Conclusão:
A função get_user_profile referencia muitas colunas que não existem na tabela profiles.
Isso causa um erro PostgreSQL quando a função é executada, resultando em "Erro ao carregar perfil".
