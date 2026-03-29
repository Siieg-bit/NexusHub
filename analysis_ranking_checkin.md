# Análise: Ranking + Check-in

## Problema 1: Ranking - "column cm.level does not exist"

A função `get_community_leaderboard` na migration `011_missing_rpcs.sql` usa:
```sql
'level', cm.level,
```

Mas a tabela `community_members` tem a coluna como `local_level` (não `level`):
```sql
local_level INTEGER DEFAULT 1,
local_reputation INTEGER DEFAULT 0,
```

Também usa `cm.local_reputation` corretamente em outros lugares, mas `cm.level` está errado.

**Correção:** Alterar `cm.level` para `cm.local_level` na função RPC.

## Problema 2: Check-in continua aparecendo

A tabela `community_members` tem:
- `has_checkin_today BOOLEAN DEFAULT FALSE`
- `last_checkin_at TIMESTAMPTZ`
- `consecutive_checkin_days INTEGER DEFAULT 0`

Preciso verificar:
1. O provider `checkInStatusProvider` e como ele busca o estado
2. Se o `daily_checkin` RPC atualiza `has_checkin_today` corretamente
3. Se o provider é invalidado após o check-in
