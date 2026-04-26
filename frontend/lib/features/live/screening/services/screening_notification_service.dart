// =============================================================================
// ScreeningNotificationService — Notificações de convite para a Sala de Projeção
//
// Quando o host cria uma sala, notifica todos os membros ativos da comunidade
// inserindo registros na tabela `notifications`. O webhook-handler do Supabase
// cuida de enviar o push notification via FCM/APNs automaticamente.
//
// Padrão de notificação:
//   type: 'screening_room_invite'
//   title: 'Sala de Projeção ao vivo!'
//   body: '{hostName} está assistindo "{videoTitle}" — entre agora!'
//   action_url: '/live/{communityId}?session={sessionId}'
// =============================================================================

import 'package:flutter/foundation.dart';
import '../../../../core/services/supabase_service.dart';

class ScreeningNotificationService {
  ScreeningNotificationService._();

  /// Notifica os membros ativos da comunidade sobre a nova sala de projeção.
  ///
  /// [communityId] — ID da comunidade.
  /// [sessionId] — ID da sessão criada.
  /// [hostUserId] — ID do usuário que criou a sala.
  /// [videoTitle] — Título do vídeo (pode ser vazio se ainda não definido).
  /// [roomTitle] — Título da sala.
  static Future<void> notifyRoomCreated({
    required String communityId,
    required String sessionId,
    required String hostUserId,
    String? videoTitle,
    String? roomTitle,
  }) async {
    try {
      // Buscar o nome do host
      final hostProfile = await SupabaseService.table('profiles')
          .select('nickname')
          .eq('id', hostUserId)
          .maybeSingle();

      final hostName =
          (hostProfile?['nickname'] as String?) ?? 'Alguém';

      // Montar o corpo da notificação
      final notifTitle = roomTitle ?? 'Sala de Projeção ao vivo!';
      final notifBody = videoTitle != null && videoTitle.isNotEmpty
          ? '$hostName está assistindo "$videoTitle" — entre agora!'
          : '$hostName abriu uma Sala de Projeção — entre agora!';

      final actionUrl = '/live/$communityId?session=$sessionId';

      // Buscar membros ativos da comunidade (excluindo o host)
      final members = await SupabaseService.table('community_members')
          .select('user_id')
          .eq('community_id', communityId)
          .eq('status', 'active')
          .neq('user_id', hostUserId)
          .limit(200); // Limite de 200 notificações por criação

      if (members == null || (members as List).isEmpty) return;

      // Inserir notificações em batch (até 200 por vez)
      final notifications = (members as List)
          .map((m) => {
                'user_id': m['user_id'] as String,
                'type': 'screening_room_invite',
                'title': notifTitle,
                'body': notifBody,
                'community_id': communityId,
                'action_url': actionUrl,
                'data': {
                  'session_id': sessionId,
                  'community_id': communityId,
                  'host_id': hostUserId,
                  'video_title': videoTitle ?? '',
                },
                'is_read': false,
              })
          .toList();

      // Inserir em lotes de 50 para evitar timeout
      const batchSize = 50;
      for (var i = 0; i < notifications.length; i += batchSize) {
        final batch = notifications.sublist(
          i,
          (i + batchSize).clamp(0, notifications.length),
        );
        await SupabaseService.table('notifications').insert(batch);
      }

      debugPrint(
        '[ScreeningNotification] Enviadas ${notifications.length} notificações para a sala $sessionId',
      );
    } catch (e) {
      // Não bloquear a criação da sala em caso de erro nas notificações
      debugPrint('[ScreeningNotification] Erro ao enviar notificações: $e');
    }
  }

  /// Notifica os membros quando o host troca o vídeo durante a sessão.
  static Future<void> notifyVideoChanged({
    required String communityId,
    required String sessionId,
    required String hostUserId,
    required String newVideoTitle,
  }) async {
    try {
      final hostProfile = await SupabaseService.table('profiles')
          .select('nickname')
          .eq('id', hostUserId)
          .maybeSingle();

      final hostName =
          (hostProfile?['nickname'] as String?) ?? 'O host';

      // Notificar apenas quem está na sala (participantes ativos)
      final participants = await SupabaseService.table('call_participants')
          .select('user_id')
          .eq('call_session_id', sessionId)
          .eq('status', 'connected')
          .neq('user_id', hostUserId);

      if (participants == null || (participants as List).isEmpty) return;

      final notifications = (participants as List)
          .map((p) => {
                'user_id': p['user_id'] as String,
                'type': 'screening_video_changed',
                'title': 'Novo vídeo na sala!',
                'body': '$hostName trocou para "$newVideoTitle"',
                'community_id': communityId,
                'action_url': '/live/$communityId?session=$sessionId',
                'data': {
                  'session_id': sessionId,
                  'community_id': communityId,
                  'video_title': newVideoTitle,
                },
                'is_read': false,
              })
          .toList();

      await SupabaseService.table('notifications').insert(notifications);
    } catch (e) {
      debugPrint('[ScreeningNotification] notifyVideoChanged error: $e');
    }
  }
}
