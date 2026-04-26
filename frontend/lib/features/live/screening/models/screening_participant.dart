// =============================================================================
// ScreeningParticipant — Participante da Sala de Projeção
// =============================================================================

class ScreeningParticipant {
  final String userId;
  final String username;
  final String? avatarUrl;
  final bool isHost;

  /// UID numérico do Agora RTC (para correlacionar com eventos de volume).
  final int? agoraUid;

  /// TRUE quando o Agora reporta volume > threshold para este usuário.
  final bool isSpeaking;

  const ScreeningParticipant({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.isHost = false,
    this.agoraUid,
    this.isSpeaking = false,
  });

  ScreeningParticipant copyWith({
    bool? isHost,
    int? agoraUid,
    bool? isSpeaking,
  }) {
    return ScreeningParticipant(
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      isHost: isHost ?? this.isHost,
      agoraUid: agoraUid ?? this.agoraUid,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  factory ScreeningParticipant.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return ScreeningParticipant(
      userId: map['user_id'] as String? ?? '',
      username: profile?['nickname'] as String? ??
          profile?['username'] as String? ??
          'Usuário',
      avatarUrl: profile?['icon_url'] as String? ??
          profile?['avatar_url'] as String?,
    );
  }
}
