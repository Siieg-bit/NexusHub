#!/usr/bin/env python3
"""Validação textual do módulo de canais push versionados.

Este script cobre a implementação server-driven da configuração de canais Android
sem executar Flutter/Dart, indisponíveis no ambiente atual. Ele valida presença do
serviço central, integrações principais, feature flag, payload remoto e migration
249.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CHECKS = [
    (
        "NotificationChannelConfigService criado",
        ROOT / "frontend/lib/core/services/notification_channel_config_service.dart",
        [
            "class NotificationChannelConfigService",
            "RemoteConfigService.isRemoteNotificationChannelsEnabled",
            "RemoteConfigService.notificationChannelsConfig",
            "channelIdForType",
            "channelNameForId",
            "getChannels",
            "_fallbackChannels",
            "_fallbackTypeChannelMap",
            "toAndroidChannel",
        ],
    ),
    (
        "PushNotificationService integrado aos canais versionados",
        ROOT / "frontend/lib/core/services/push_notification_service.dart",
        [
            "notification_channel_config_service.dart",
            "NotificationChannelConfigService.channelIdForType(type)",
            "NotificationChannelConfigService.channelNameForId(channelId)",
            "NotificationChannelConfigService.getChannels",
            "channel.toAndroidChannel()",
        ],
    ),
    (
        "MatchQueueService usa canal social centralizado",
        ROOT / "frontend/lib/core/services/match_queue_service.dart",
        [
            "notification_channel_config_service.dart",
            "NotificationChannelConfigService.channelIdForType('match')",
            "NotificationChannelConfigService.channelNameForId(channelId)",
        ],
    ),
    (
        "RemoteConfigService expõe flag e payload de canais push",
        ROOT / "frontend/lib/core/services/remote_config_service.dart",
        [
            "notificationChannelsConfig",
            "notifications.channels",
            "isRemoteNotificationChannelsEnabled",
            "features.remote_notification_channels_enabled",
        ],
    ),
    (
        "Migration 249 contém seed idempotente de canais push",
        ROOT / "backend/supabase/migrations/249_notification_channels_remote_config.sql",
        [
            "features.remote_notification_channels_enabled",
            "notifications.channels",
            "schema_version",
            "type_channel_map",
            "nexushub_default",
            "nexushub_chat",
            "nexushub_social",
            "nexushub_community",
            "nexushub_moderation",
            "ON CONFLICT (key) DO UPDATE",
        ],
    ),
]


def main() -> int:
    failures: list[str] = []
    for label, path, snippets in CHECKS:
        if not path.exists():
            failures.append(f"{label}: arquivo ausente: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet not in text:
                failures.append(f"{label}: trecho não encontrado: {snippet}")

    if failures:
        print("FAIL: validação Notification Channels encontrou problemas:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("OK: Notification Channels server-driven validado textualmente")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
