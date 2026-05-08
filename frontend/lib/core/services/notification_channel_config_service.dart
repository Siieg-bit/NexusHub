import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'remote_config_service.dart';

/// Configuração tipada de um canal Android de notificação.
///
/// Android não permite renomear de forma confiável canais já criados no
/// dispositivo. Por isso, este modelo aceita canais versionados futuros via
/// Remote Config, mas mantém os IDs atuais como fallback estável.
@immutable
class NotificationChannelConfig {
  const NotificationChannelConfig({
    required this.key,
    required this.channelId,
    required this.name,
    required this.description,
    required this.importance,
    this.enabled = true,
  });

  final String key;
  final String channelId;
  final String name;
  final String description;
  final Importance importance;
  final bool enabled;

  AndroidNotificationChannel toAndroidChannel() {
    return AndroidNotificationChannel(
      channelId,
      name,
      description: description,
      importance: importance,
    );
  }

  factory NotificationChannelConfig.fromJson(Map<String, dynamic> json) {
    return NotificationChannelConfig(
      key: _asNonEmptyString(json['key'], fallback: 'default'),
      channelId: _asNonEmptyString(
        json['channel_id'] ?? json['channelId'],
        fallback: 'nexushub_default',
      ),
      name: _asNonEmptyString(json['name'], fallback: 'NexusHub'),
      description: _asNonEmptyString(
        json['description'],
        fallback: 'NexusHub notifications',
      ),
      importance: _parseImportance(json['importance']),
      enabled: _asBool(json['enabled'], fallback: true),
    );
  }
}

/// Serviço central para resolver canais Android de push/local notifications.
///
/// A fonte remota esperada é `notifications.channels` em `app_remote_config`,
/// com `schema_version`, `channels` e `type_channel_map`. A flag
/// `features.remote_notification_channels_enabled` permite rollback imediato
/// para os canais locais atuais.
class NotificationChannelConfigService {
  NotificationChannelConfigService._();

  static const int _supportedSchemaVersion = 1;

  static const Map<String, String> _fallbackTypeChannelMap = {
    // Chat
    'chat': 'chat',
    'chat_message': 'chat',
    'chat_mention': 'chat',
    'chat_invite': 'chat',
    'dm_invite': 'chat',
    'roleplay': 'chat',

    // Social
    'like': 'social',
    'comment': 'social',
    'follow': 'social',
    'match': 'social',
    'mention': 'social',
    'wall_post': 'social',
    'wall_comment': 'social',
    'repost': 'social',
    'wiki_approved': 'social',

    // Comunidade
    'community_invite': 'community',
    'community_update': 'community',
    'join_request': 'community',
    'role_change': 'community',

    // Moderação
    'moderation': 'moderation',
    'strike': 'moderation',
    'ban': 'moderation',
  };

  static List<NotificationChannelConfig> getChannels({
    String generalDescription = 'Notificações gerais do NexusHub',
    String chatDescription = 'Novas mensagens e convites de chat',
    String socialDescription = 'Curtidas, comentários e seguidores',
    String communityDescription = 'Atualizações de comunidades',
    String moderationName = 'Moderação',
    String moderationDescription = 'Alertas importantes de moderação',
  }) {
    final fallback = _fallbackChannels(
      generalDescription: generalDescription,
      chatDescription: chatDescription,
      socialDescription: socialDescription,
      communityDescription: communityDescription,
      moderationName: moderationName,
      moderationDescription: moderationDescription,
    );

    if (!RemoteConfigService.isRemoteNotificationChannelsEnabled) {
      return fallback;
    }

    final payload = RemoteConfigService.notificationChannelsConfig;
    final schemaVersion = _asInt(payload['schema_version'], fallback: 1);
    if (schemaVersion > _supportedSchemaVersion) {
      debugPrint(
        '[NotificationChannels] schema_version remoto não suportado: $schemaVersion',
      );
      return fallback;
    }

    final rawChannels = payload['channels'];
    if (rawChannels is! List) return fallback;

    final parsed = rawChannels
        .whereType<Map>()
        .map((item) => NotificationChannelConfig.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((channel) => channel.enabled)
        .where((channel) => channel.channelId.startsWith('nexushub_'))
        .toList(growable: false);

    if (parsed.isEmpty) return fallback;

    // Garante que os canais estáveis atuais continuem existindo mesmo quando o
    // payload remoto define apenas canais futuros/versionados.
    final byId = <String, NotificationChannelConfig>{
      for (final channel in fallback) channel.channelId: channel,
      for (final channel in parsed) channel.channelId: channel,
    };

    return byId.values.toList(growable: false);
  }

  static String channelIdForType(String type) {
    final fallbackKey = _fallbackTypeChannelMap[type] ?? 'default';
    final fallbackChannelId = _fallbackChannelIdForKey(fallbackKey);

    if (!RemoteConfigService.isRemoteNotificationChannelsEnabled) {
      return fallbackChannelId;
    }

    final payload = RemoteConfigService.notificationChannelsConfig;
    final schemaVersion = _asInt(payload['schema_version'], fallback: 1);
    if (schemaVersion > _supportedSchemaVersion) return fallbackChannelId;

    final channelsByKey = <String, NotificationChannelConfig>{
      for (final channel in getChannels()) channel.key: channel,
    };
    final rawMap = payload['type_channel_map'];
    if (rawMap is! Map) return fallbackChannelId;

    final channelKey = rawMap[type]?.toString();
    if (channelKey == null || channelKey.isEmpty) return fallbackChannelId;

    final channelId = channelsByKey[channelKey]?.channelId;
    if (channelId == null || !channelId.startsWith('nexushub_')) {
      return fallbackChannelId;
    }
    return channelId;
  }

  static String channelNameForId(String channelId) {
    for (final channel in getChannels()) {
      if (channel.channelId == channelId) return channel.name;
    }
    return channelId.replaceAll('nexushub_', '').toUpperCase();
  }

  static List<NotificationChannelConfig> _fallbackChannels({
    required String generalDescription,
    required String chatDescription,
    required String socialDescription,
    required String communityDescription,
    required String moderationName,
    required String moderationDescription,
  }) {
    return [
      NotificationChannelConfig(
        key: 'default',
        channelId: 'nexushub_default',
        name: 'Geral',
        description: generalDescription,
        importance: Importance.defaultImportance,
      ),
      NotificationChannelConfig(
        key: 'chat',
        channelId: 'nexushub_chat',
        name: 'Mensagens',
        description: chatDescription,
        importance: Importance.high,
      ),
      NotificationChannelConfig(
        key: 'social',
        channelId: 'nexushub_social',
        name: 'Social',
        description: socialDescription,
        importance: Importance.defaultImportance,
      ),
      NotificationChannelConfig(
        key: 'community',
        channelId: 'nexushub_community',
        name: 'Comunidades',
        description: communityDescription,
        importance: Importance.defaultImportance,
      ),
      NotificationChannelConfig(
        key: 'moderation',
        channelId: 'nexushub_moderation',
        name: moderationName,
        description: moderationDescription,
        importance: Importance.high,
      ),
    ];
  }

  static String _fallbackChannelIdForKey(String key) {
    switch (key) {
      case 'chat':
        return 'nexushub_chat';
      case 'social':
        return 'nexushub_social';
      case 'community':
        return 'nexushub_community';
      case 'moderation':
        return 'nexushub_moderation';
      default:
        return 'nexushub_default';
    }
  }
}

String _asNonEmptyString(Object? value, {required String fallback}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

bool _asBool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value == null) return fallback;
  final normalized = value.toString().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return fallback;
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Importance _parseImportance(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'max':
      return Importance.max;
    case 'high':
      return Importance.high;
    case 'low':
      return Importance.low;
    case 'min':
      return Importance.min;
    case 'none':
      return Importance.none;
    case 'default':
    default:
      return Importance.defaultImportance;
  }
}
