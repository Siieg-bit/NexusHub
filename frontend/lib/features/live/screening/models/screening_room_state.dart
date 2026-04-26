// =============================================================================
// ScreeningRoomState — Estado global da Sala de Projeção
// =============================================================================

import 'screening_participant.dart';

enum ScreeningRoomStatus {
  loading,    // Inicializando (buscando sessão, conectando Realtime)
  active,     // Sala ativa e pronta
  closed,     // Sala encerrada pelo host
  error,      // Erro ao entrar na sala
}

class ScreeningRoomState {
  final ScreeningRoomStatus status;

  /// ID da sessão no Supabase (call_sessions.id).
  final String? sessionId;

  /// ID do thread da comunidade ao qual a sala pertence.
  final String threadId;

  /// URL do vídeo atual.
  final String? currentVideoUrl;

  /// Título do vídeo atual.
  final String? currentVideoTitle;

  /// TRUE se o usuário local é o host (tem controle de reprodução).
  final bool isHost;

  /// ID do usuário que é o host atual.
  final String? hostUserId;

  /// Lista de participantes conectados.
  final List<ScreeningParticipant> participants;

  /// Mensagem de erro (quando status == error).
  final String? errorMessage;

  const ScreeningRoomState({
    this.status = ScreeningRoomStatus.loading,
    this.sessionId,
    required this.threadId,
    this.currentVideoUrl,
    this.currentVideoTitle,
    this.isHost = false,
    this.hostUserId,
    this.participants = const [],
    this.errorMessage,
  });

  int get viewerCount => participants.length;

  ScreeningRoomState copyWith({
    ScreeningRoomStatus? status,
    String? sessionId,
    String? currentVideoUrl,
    String? currentVideoTitle,
    bool? isHost,
    String? hostUserId,
    List<ScreeningParticipant>? participants,
    String? errorMessage,
  }) {
    return ScreeningRoomState(
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      threadId: threadId,
      currentVideoUrl: currentVideoUrl ?? this.currentVideoUrl,
      currentVideoTitle: currentVideoTitle ?? this.currentVideoTitle,
      isHost: isHost ?? this.isHost,
      hostUserId: hostUserId ?? this.hostUserId,
      participants: participants ?? this.participants,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
