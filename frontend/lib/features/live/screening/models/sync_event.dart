// =============================================================================
// SyncEvent — Modelo do evento de sincronização de reprodução
//
// Trafega via Supabase Realtime Broadcast no canal 'screening_sync_{sessionId}'.
// Substitui o polling de call_sessions.metadata por eventos de baixa latência.
// =============================================================================

enum SyncEventType {
  play,        // Host pressionou play
  pause,       // Host pressionou pause
  seek,        // Host arrastou a barra de progresso
  changeVideo, // Host trocou o vídeo
  hostChange,  // Controle de host transferido
}

class SyncEvent {
  final SyncEventType type;

  /// Posição de reprodução em milissegundos no momento do evento.
  final int positionMs;

  /// Timestamp Unix em milissegundos do servidor quando o evento foi gerado.
  /// Usado para compensar a latência de rede no cálculo do drift.
  final int serverTimestampMs;

  /// URL do novo vídeo (apenas para [SyncEventType.changeVideo]).
  final String? videoUrl;

  /// Título do novo vídeo (apenas para [SyncEventType.changeVideo]).
  final String? videoTitle;

  /// ID do novo host (apenas para [SyncEventType.hostChange]).
  final String? newHostId;

  const SyncEvent({
    required this.type,
    required this.positionMs,
    required this.serverTimestampMs,
    this.videoUrl,
    this.videoTitle,
    this.newHostId,
  });

  factory SyncEvent.fromBroadcast(Map<String, dynamic> payload) {
    return SyncEvent(
      type: _parseType(payload['type'] as String? ?? 'pause'),
      positionMs: (payload['position'] as num?)?.toInt() ?? 0,
      serverTimestampMs: (payload['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      videoUrl: payload['video_url'] as String?,
      videoTitle: payload['video_title'] as String?,
      newHostId: payload['new_host_id'] as String?,
    );
  }

  Map<String, dynamic> toBroadcast() {
    return {
      'type': _typeToString(type),
      'position': positionMs,
      'timestamp': serverTimestampMs,
      if (videoUrl != null) 'video_url': videoUrl,
      if (videoTitle != null) 'video_title': videoTitle,
      if (newHostId != null) 'new_host_id': newHostId,
    };
  }

  static SyncEventType _parseType(String raw) {
    switch (raw) {
      case 'play':
        return SyncEventType.play;
      case 'pause':
        return SyncEventType.pause;
      case 'seek':
        return SyncEventType.seek;
      case 'change_video':
        return SyncEventType.changeVideo;
      case 'host_change':
        return SyncEventType.hostChange;
      default:
        return SyncEventType.pause;
    }
  }

  static String _typeToString(SyncEventType type) {
    switch (type) {
      case SyncEventType.play:
        return 'play';
      case SyncEventType.pause:
        return 'pause';
      case SyncEventType.seek:
        return 'seek';
      case SyncEventType.changeVideo:
        return 'change_video';
      case SyncEventType.hostChange:
        return 'host_change';
    }
  }
}
