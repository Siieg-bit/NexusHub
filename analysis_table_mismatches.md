# Tabelas inconsistentes: Frontend referencia, Backend não tem

## Mapeamento de correções:

| Frontend usa | Backend tem | Correção |
|---|---|---|
| `achievements` | Não existe | Usar `store_items` ou criar tabela |
| `user_achievements` | Não existe | Criar tabela |
| `ad_rewards` | `ad_reward_logs` | Renomear referência |
| `chat_rooms` | `chat_threads` | Renomear referência |
| `message_reactions` | Não existe | Criar tabela |
| `messages` | `chat_messages` | Renomear referência |
| `privacy_settings` | `user_settings` | Renomear referência |
| `transactions` | `coin_transactions` | Renomear referência |
| `user_blocks` | `blocks` | Renomear referência |
| `user_inventory` | `user_purchases` | Renomear referência |
| `wallet_transactions` | `coin_transactions` | Renomear referência |
| `wallets` | `profiles.coins` | Usar profiles.coins |
