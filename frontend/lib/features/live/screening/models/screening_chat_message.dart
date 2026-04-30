import 'dart:convert';

// =============================================================================
// ScreeningChatMessage — Mensagem do chat interno da Sala de Projeção
// =============================================================================

enum ScreeningChatMessageKind { text, image, sticker }

class ScreeningChatMessage {
  static const _mediaPrefix = '__nexus_screening_chat_media__:';

  final String id;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String text;
  final DateTime createdAt;

  /// TRUE se a mensagem foi enviada pelo usuário local.
  final bool isMe;

  /// TRUE se é uma mensagem de sistema (ex: "Host mudou para Ana").
  final bool isSystem;

  const ScreeningChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.text,
    required this.createdAt,
    this.isMe = false,
    this.isSystem = false,
  });

  ScreeningChatMessageKind get kind {
    final payload = mediaPayload;
    if (payload == null) return ScreeningChatMessageKind.text;
    return switch (payload['type'] as String?) {
      'image' => ScreeningChatMessageKind.image,
      'sticker' => ScreeningChatMessageKind.sticker,
      _ => ScreeningChatMessageKind.text,
    };
  }

  Map<String, dynamic>? get mediaPayload {
    if (!text.startsWith(_mediaPrefix)) return null;
    try {
      final raw = text.substring(_mediaPrefix.length);
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String? get mediaUrl => mediaPayload?['url'] as String?;
  String? get mediaName => mediaPayload?['name'] as String?;
  bool get isMedia => kind != ScreeningChatMessageKind.text;

  String get displayText {
    final payload = mediaPayload;
    if (payload == null) return text;
    return (payload['name'] as String?) ??
        (kind == ScreeningChatMessageKind.sticker ? 'Sticker' : 'Imagem');
  }

  static String encodeMediaPayload({
    required ScreeningChatMessageKind kind,
    required String url,
    String? name,
  }) {
    final type = switch (kind) {
      ScreeningChatMessageKind.image => 'image',
      ScreeningChatMessageKind.sticker => 'sticker',
      ScreeningChatMessageKind.text => 'text',
    };
    return '$_mediaPrefix${jsonEncode({
      'type': type,
      'url': url,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    })}';
  }

  /// Cria uma mensagem de sistema.
  factory ScreeningChatMessage.system(String text) {
    return ScreeningChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'system',
      username: 'Sistema',
      text: text,
      createdAt: DateTime.now(),
      isMe: false,
      isSystem: true,
    );
  }

  /// Cria a partir de um payload de Broadcast Realtime (chat em tempo real).
  factory ScreeningChatMessage.fromBroadcast(
    Map<String, dynamic> payload,
    String currentUserId,
  ) {
    return ScreeningChatMessage(
      id: payload['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      userId: payload['user_id'] as String? ?? '',
      username: payload['username'] as String? ?? 'Usuário',
      avatarUrl: payload['avatar_url'] as String?,
      text: payload['text'] as String? ?? '',
      createdAt: payload['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch(payload['ts'] as int)
          : DateTime.now(),
      isMe: (payload['user_id'] as String?) == currentUserId,
    );
  }

  /// Cria a partir de um registro do banco (histórico via RPC).
  factory ScreeningChatMessage.fromDb(
    Map<String, dynamic> row,
    String currentUserId,
  ) {
    return ScreeningChatMessage(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      username: row['username'] as String? ?? 'Usuário',
      avatarUrl: row['avatar_url'] as String?,
      text: row['text'] as String? ?? '',
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      isMe: (row['user_id'] as String?) == currentUserId,
    );
  }

  Map<String, dynamic> toBroadcast() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'text': text,
      'ts': createdAt.millisecondsSinceEpoch,
    };
  }
}
