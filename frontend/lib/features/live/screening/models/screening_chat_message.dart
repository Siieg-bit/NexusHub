// =============================================================================
// ScreeningChatMessage — Mensagem do chat interno da Sala de Projeção
// =============================================================================

class ScreeningChatMessage {
  final String id;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String text;
  final DateTime createdAt;

  /// TRUE se a mensagem foi enviada pelo usuário local.
  final bool isMe;

  const ScreeningChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.text,
    required this.createdAt,
    this.isMe = false,
  });

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
