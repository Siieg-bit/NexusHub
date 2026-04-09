/// Modelo de thread de chat (sala/grupo/DM).
/// Baseado no schema v5 — tabela chat_threads (ChatThread.smali).
///
/// SEPARAÇÃO CONCEITUAL (Etapa 1):
/// - "Meus chats" = threads com membershipStatus == 'active' (chatListProvider)
/// - "Chats públicos disponíveis" = descoberta/exploração, tratada em tela separada
///   (não misturar com a lista pessoal do usuário)
class ChatRoomModel {
  final String id;
  final String? communityId;
  final String type; // enum: dm, group, public
  final String title;
  final String? iconUrl;
  final String? description;
  final String? backgroundUrl;
  final bool isPinned;
  final bool isAnnouncementOnly;
  final bool isVoiceEnabled;
  final bool isVideoEnabled;
  final bool isScreenRoomEnabled;
  final String? hostId;
  final List<dynamic> coHosts;
  final String? pinnedMessageId;
  final int membersCount;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageAuthor;
  final String status; // enum: ok, pending, closed, disabled, deleted
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos calculados (não na tabela chat_threads — injetados pelo chatListProvider)
  final int unreadCount;

  /// Pin pessoal do usuário (vem de chat_members.is_pinned_by_user).
  /// Injetado pelo chatListProvider — não existe em chat_threads.
  /// É SEMPRE uma preferência pessoal do usuário, nunca global.
  /// Chats fixados aparecem no topo da lista pessoal do usuário.
  final bool isPinnedByUser;

  /// Status de membership do usuário nesta thread (vem de chat_members.status).
  /// Valores possíveis:
  ///   'active'        — usuário é membro ativo
  ///   'left'          — usuário saiu intencionalmente (chat oculto da lista)
  ///   'invite_sent'   — convite enviado, aguardando aceite (Etapa 2+)
  ///   'join_requested'— solicitação enviada, aguardando aprovação (Etapa 2+)
  ///   'none'          — usuário nunca entrou (sem linha em chat_members)
  ///
  /// NOTA: Fluxos de convite/pendente (invite_sent, join_requested) serão
  /// implementados em Etapa posterior. Esta Etapa 1 não congela regras para
  /// esses fluxos — apenas registra o campo para uso futuro.
  final String membershipStatus;

  ChatRoomModel({
    required this.id,
    this.communityId,
    required this.type,
    required this.title,
    this.iconUrl,
    this.description,
    this.backgroundUrl,
    this.isPinned = false,
    this.isAnnouncementOnly = false,
    this.isVoiceEnabled = false,
    this.isVideoEnabled = false,
    this.isScreenRoomEnabled = false,
    this.hostId,
    this.coHosts = const [],
    this.pinnedMessageId,
    this.membersCount = 0,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageAuthor,
    this.status = 'ok',
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.isPinnedByUser = false,
    this.membershipStatus = 'none',
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String?,
      type: json['type'] as String? ?? 'public',
      title: json['title'] as String? ?? s.chat2,
      iconUrl: json['icon_url'] as String?,
      description: json['description'] as String?,
      backgroundUrl: json['background_url'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      isAnnouncementOnly: json['is_announcement_only'] as bool? ?? false,
      isVoiceEnabled: json['is_voice_enabled'] as bool? ?? false,
      isVideoEnabled: json['is_video_enabled'] as bool? ?? false,
      isScreenRoomEnabled: json['is_screen_room_enabled'] as bool? ?? false,
      hostId: json['host_id'] as String?,
      coHosts: json['co_hosts'] as List<dynamic>? ?? [],
      pinnedMessageId: json['pinned_message_id'] as String?,
      membersCount: json['members_count'] as int? ?? 0,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAuthor: json['last_message_author'] as String?,
      status: json['status'] as String? ?? 'ok',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      unreadCount: json['unread_count'] as int? ?? 0,
      isPinnedByUser: json['is_pinned_by_user'] as bool? ?? false,
      membershipStatus: json['membership_status'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() => {
        'community_id': communityId,
        'type': type,
        'title': title,
        'icon_url': iconUrl,
        'description': description,
        'is_pinned': isPinned,
      };
}
