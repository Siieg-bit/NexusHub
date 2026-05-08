-- =============================================================================
-- Migration 249 — Notification Channels Remote Config
--
-- Publica a configuração server-driven dos canais Android de notificação em
-- `app_remote_config`, mantendo os IDs atuais como fallback estável. Android não
-- permite renomear canais já criados de forma confiável; por isso, novos canais
-- devem ser introduzidos com IDs versionados futuros, sem remover os canais
-- históricos usados pelos APKs existentes.
-- =============================================================================

INSERT INTO public.app_remote_config (key, value, category, description)
VALUES
  (
    'features.remote_notification_channels_enabled',
    'true'::jsonb,
    'features',
    'Habilitar configuração remota versionada de canais Android de push/local notifications'
  ),
  (
    'notifications.channels',
    '{
      "schema_version": 1,
      "channels": [
        {
          "key": "default",
          "channel_id": "nexushub_default",
          "name": "Geral",
          "description": "Notificações gerais do NexusHub",
          "importance": "default",
          "enabled": true
        },
        {
          "key": "chat",
          "channel_id": "nexushub_chat",
          "name": "Mensagens",
          "description": "Novas mensagens e convites de chat",
          "importance": "high",
          "enabled": true
        },
        {
          "key": "social",
          "channel_id": "nexushub_social",
          "name": "Social",
          "description": "Curtidas, comentários e seguidores",
          "importance": "default",
          "enabled": true
        },
        {
          "key": "community",
          "channel_id": "nexushub_community",
          "name": "Comunidades",
          "description": "Atualizações de comunidades",
          "importance": "default",
          "enabled": true
        },
        {
          "key": "moderation",
          "channel_id": "nexushub_moderation",
          "name": "Moderação",
          "description": "Alertas importantes de moderação",
          "importance": "high",
          "enabled": true
        }
      ],
      "type_channel_map": {
        "chat": "chat",
        "chat_message": "chat",
        "chat_mention": "chat",
        "chat_invite": "chat",
        "dm_invite": "chat",
        "roleplay": "chat",
        "like": "social",
        "comment": "social",
        "follow": "social",
        "match": "social",
        "mention": "social",
        "wall_post": "social",
        "wall_comment": "social",
        "repost": "social",
        "wiki_approved": "social",
        "community_invite": "community",
        "community_update": "community",
        "join_request": "community",
        "role_change": "community",
        "moderation": "moderation",
        "strike": "moderation",
        "ban": "moderation"
      }
    }'::jsonb,
    'notifications',
    'Canais Android versionados e mapa tipo-canal usados por NotificationChannelConfigService com fallback local conservador'
  )
ON CONFLICT (key) DO UPDATE SET
  value       = EXCLUDED.value,
  category    = EXCLUDED.category,
  description = EXCLUDED.description;
