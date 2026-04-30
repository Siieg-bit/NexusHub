import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/realtime_service.dart';
import '../models/screening_chat_message.dart';

// =============================================================================
// ScreeningChatProvider — Chat em tempo real da Sala de Projeção
//
// Responsabilidades:
// - Carregar histórico de mensagens ao entrar na sala
// - Receber novas mensagens via Supabase Realtime Broadcast
// - Enviar mensagens (Broadcast + persistência no banco)
// - Expor a lista de mensagens para o ScreeningChatOverlay
// =============================================================================

final screeningChatProvider = StateNotifierProvider.family<
    ScreeningChatNotifier, List<ScreeningChatMessage>, String>(
  (ref, sessionId) => ScreeningChatNotifier(sessionId: sessionId),
);

class ScreeningChatNotifier extends StateNotifier<List<ScreeningChatMessage>> {
  final String sessionId;

  RealtimeChannel? _channel;
  String? _currentUserId;
  String? _myUsername;
  String? _myAvatarUrl;

  ScreeningChatNotifier({required this.sessionId}) : super([]) {
    // Aguardar sessionId válido antes de inicializar.
    // Durante o loading da sala, sessionId pode ser '' (string vazia),
    // o que causaria erro 'invalid input syntax for type uuid: ""' no banco.
    if (sessionId.isNotEmpty) _init();
  }

  Future<void> _init() async {
    _currentUserId = SupabaseService.currentUserId;
    if (_currentUserId == null) return;

    // Carregar perfil do usuário atual
    try {
      final profile = await SupabaseService.table('profiles')
          .select('nickname, icon_url')
          .eq('id', _currentUserId!)
          .maybeSingle();
      if (profile != null) {
        _myUsername = profile['nickname'] as String? ?? 'Usuário';
        _myAvatarUrl = profile['icon_url'] as String?;
      }
    } catch (e) {
      debugPrint('[ScreeningChat] load profile error: $e');
    }

    // Carregar histórico
    await _loadHistory();

    // Subscrever ao canal de chat
    _subscribeToChat();
  }

  Future<void> _loadHistory() async {
    try {
      final result = await SupabaseService.client.rpc(
        'get_screening_chat_history',
        params: {'p_session_id': sessionId, 'p_limit': 50},
      );

      if (result != null) {
        final messages = (result as List)
            .map((row) => ScreeningChatMessage.fromDb(
                  row as Map<String, dynamic>,
                  _currentUserId ?? '',
                ))
            .toList();
        state = messages;
      }
    } catch (e) {
      debugPrint('[ScreeningChat] loadHistory error: $e');
    }
  }

  void _subscribeToChat() {
    _channel = RealtimeService.instance.subscribeWithRetry(
      channelName: 'screening_chat_$sessionId',
      configure: (channel) {
        channel.onBroadcast(
          event: 'chat',
          callback: (payload) {
            try {
              final msg = ScreeningChatMessage.fromBroadcast(
                payload,
                _currentUserId ?? '',
              );
              // Evitar duplicatas (mensagens enviadas pelo próprio usuário
              // já são adicionadas localmente em sendMessage)
              if (!msg.isMe) {
                state = [...state, msg];
              }
            } catch (e) {
              debugPrint('[ScreeningChat] parse broadcast error: $e');
            }
          },
        );
      },
    );
  }

  // ── Enviar mensagem ─────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _sendRawMessage(trimmed);
  }

  Future<void> sendImage({required String imageUrl, String? name}) async {
    if (imageUrl.trim().isEmpty) return;
    final payload = ScreeningChatMessage.encodeMediaPayload(
      kind: ScreeningChatMessageKind.image,
      url: imageUrl.trim(),
      name: name,
    );
    await _sendRawMessage(payload);
  }

  Future<void> sendSticker({
    required String stickerUrl,
    String? stickerName,
  }) async {
    if (stickerUrl.trim().isEmpty) return;
    final payload = ScreeningChatMessage.encodeMediaPayload(
      kind: ScreeningChatMessageKind.sticker,
      url: stickerUrl.trim(),
      name: stickerName,
    );
    await _sendRawMessage(payload);
  }

  Future<void> _sendRawMessage(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty || _currentUserId == null) return;

    final now = DateTime.now();
    final msgId = '${_currentUserId}_${now.millisecondsSinceEpoch}';

    final msg = ScreeningChatMessage(
      id: msgId,
      userId: _currentUserId!,
      username: _myUsername ?? 'Usuário',
      avatarUrl: _myAvatarUrl,
      text: trimmed,
      createdAt: now,
      isMe: true,
    );

    // Adicionar localmente imediatamente (sem esperar o broadcast voltar)
    state = [...state, msg];

    // Broadcast para todos na sala
    _channel?.sendBroadcastMessage(
      event: 'chat',
      payload: msg.toBroadcast(),
    );

    // Persistir no banco (assíncrono, sem bloquear a UI)
    SupabaseService.table('screening_chat_messages').insert({
      'session_id': sessionId,
      'user_id': _currentUserId,
      'text': trimmed,
    }).catchError((e) => debugPrint('[ScreeningChat] persist error: $e'));
  }

  /// Adiciona uma mensagem de sistema localmente (ex: "Host transferido para Ana").
  /// Não é persistida nem transmitida — apenas visível para o usuário local.
  void addSystemMessage(String text) {
    if (!mounted) return;
    state = [...state, ScreeningChatMessage.system(text)];
  }

  @override
  void dispose() {
    if (_channel != null) {
      RealtimeService.instance.unsubscribe('screening_chat_$sessionId');
    }
    super.dispose();
  }
}
