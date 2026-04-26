import '../l10n/locale_provider.dart';

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
  final String? coverImageUrl;
  final bool isPinned;
  final bool isAnnouncementOnly;
  final bool isReadOnly;
  final bool isVoiceEnabled;
  final bool isVideoEnabled;
  final bool isScreenRoomEnabled;
  final String? hostId;
  final List<dynamic> coHosts;
  final String? pinnedMessageId;

  /// Nota de texto livre fixada no topo do chat (Big Note).
  /// Editável apenas por host e co-hosts. NULL = sem nota.
  final String? bigNote;
  final DateTime? bigNoteUpdatedAt;

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

  /// Big Note do chat — texto fixado no topo pelo host/moderador.
  final String? bigNote;
  final String? bigNoteAuthorId;

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

  /// Presença persistida da contraparte em DMs.
  /// Esses campos vêm do perfil do outro usuário e substituem a dependência de
  /// presença em tempo real para a lista de chats.
  final int counterpartOnlineStatus;
  final bool counterpartIsGhostMode;
  final DateTime? counterpartLastSeenAt;

  ChatRoomModel({
    required this.id,
    this.communityId,
    required this.type,
    required this.title,
    this.iconUrl,
    this.description,
    this.backgroundUrl,
    this.coverImageUrl,
    this.isPinned = false,
    this.isAnnouncementOnly = false,
    this.isReadOnly = false,
    this.isVoiceEnabled = false,
    this.isVideoEnabled = false,
    this.isScreenRoomEnabled = false,
    this.hostId,
    this.coHosts = const [],
    this.pinnedMessageId,
    this.bigNote,
    this.bigNoteUpdatedAt,
    this.membersCount = 0,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageAuthor,
    this.status = 'ok',
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.isPinnedByUser = false,
    this.bigNote,
    this.bigNoteAuthorId,
    this.membershipStatus = 'none',
    this.counterpartOnlineStatus = 2,
    this.counterpartIsGhostMode = false,
    this.counterpartLastSeenAt,
  });

  static const Duration _presenceWindow = Duration(minutes: 15);

  bool get isCounterpartOnline {
    if (counterpartIsGhostMode) return false;
    final seenAt = counterpartLastSeenAt;
    if (seenAt == null) return counterpartOnlineStatus == 1;
    final elapsed = DateTime.now().toUtc().difference(seenAt.toUtc());
    return elapsed <= _presenceWindow;
  }

  int get counterpartLastActiveBucketMinutes {
    final seenAt = counterpartLastSeenAt;
    if (seenAt == null) return 0;
    final elapsedMinutes =
        DateTime.now().toUtc().difference(seenAt.toUtc()).inMinutes;
    if (elapsedMinutes <= 0) return 0;
    return ((elapsedMinutes + 14) ~/ 15) * 15;
  }

  String get counterpartPresenceLabel {
    if (isCounterpartOnline) return 'online';
    final seenAt = counterpartLastSeenAt;
    if (seenAt == null) return 'offline';
    final elapsed = DateTime.now().toUtc().difference(seenAt.toUtc());
    if (elapsed.inMinutes < 1) return 'agora mesmo';
    if (elapsed.inMinutes < 60) {
      final m = elapsed.inMinutes;
      return 'há $m ${m == 1 ? 'minuto' : 'minutos'}';
    }
    if (elapsed.inHours < 24) {
      final h = elapsed.inHours;
      return 'há $h ${h == 1 ? 'hora' : 'horas'}';
    }
    if (elapsed.inDays < 30) {
      final d = elapsed.inDays;
      return 'há $d ${d == 1 ? 'dia' : 'dias'}';
    }
    if (elapsed.inDays < 365) {
      final mo = (elapsed.inDays / 30).floor();
      return 'há $mo ${mo == 1 ? 'mês' : 'meses'}';
    }
    final y = (elapsed.inDays / 365).floor();
    return 'há $y ${y == 1 ? 'ano' : 'anos'}';
  }

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    final s = getStrings();
    return ChatRoomModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String?,
      type: json['type'] as String? ?? 'public',
      title: json['title'] as String? ?? s.chat2,
      iconUrl: json['icon_url'] as String?,
      description: json['description'] as String?,
      backgroundUrl: json['background_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      isAnnouncementOnly: json['is_announcement_only'] as bool? ?? false,
      isReadOnly: json['is_read_only'] as bool? ?? false,
      isVoiceEnabled: json['is_voice_enabled'] as bool? ?? false,
      isVideoEnabled: json['is_video_enabled'] as bool? ?? false,
      isScreenRoomEnabled: json['is_screen_room_enabled'] as bool? ?? false,
      hostId: json['host_id'] as String?,
      coHosts: json['co_hosts'] as List<dynamic>? ?? [],
      pinnedMessageId: json['pinned_message_id'] as String?,
      bigNote: json['big_note'] as String?,
      bigNoteUpdatedAt: json['big_note_updated_at'] != null
          ? DateTime.tryParse(json['big_note_updated_at'] as String)
          : null,
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
      bigNote: json['big_note'] as String?,
      bigNoteAuthorId: json['big_note_author_id'] as String?,
      membershipStatus: json['membership_status'] as String? ?? 'none',
      counterpartOnlineStatus: (json['counterpart_online_status'] as num?)?.toInt() ?? 2,
      counterpartIsGhostMode: json['counterpart_is_ghost_mode'] as bool? ?? false,
      counterpartLastSeenAt: json['counterpart_last_seen_at'] != null
          ? DateTime.tryParse(json['counterpart_last_seen_at'] as String)
          : null,
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
