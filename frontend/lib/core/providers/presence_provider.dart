import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/presence_service.dart';

/// Provider que expõe o Set de userIds online em uma comunidade específica.
/// Atualiza em tempo real via Supabase Realtime Presence.
///
/// Uso:
/// ```dart
/// final onlineUsers = ref.watch(communityPresenceProvider(communityId));
/// final count = onlineUsers.length;
/// final isOnline = onlineUsers.contains(userId);
/// ```
final communityPresenceProvider = StreamNotifierProvider.family<
    CommunityPresenceNotifier, Set<String>, String>(
  CommunityPresenceNotifier.new,
);

class CommunityPresenceNotifier
    extends FamilyStreamNotifier<Set<String>, String> {
  @override
  Stream<Set<String>> build(String arg) {
    final communityId = arg;
    final presence = PresenceService.instance;

    // Entrar no canal de presença da comunidade
    presence.joinChannel(communityId);

    // Limpar ao sair
    ref.onDispose(() {
      presence.leaveChannel(communityId);
    });

    // Emitir estado inicial + stream de mudanças
    return _mergeInitialAndStream(communityId);
  }

  Stream<Set<String>> _mergeInitialAndStream(String communityId) async* {
    final presence = PresenceService.instance;

    // Emitir estado atual primeiro
    yield presence.getOnlineUsers(communityId);

    // Depois emitir mudanças em tempo real
    yield* presence.onlineUsersStream(communityId);
  }
}

/// Provider simples para contagem de membros online em uma comunidade.
/// Derivado do communityPresenceProvider.
final onlineCountProvider = Provider.family<int, String>((ref, communityId) {
  final presenceAsync = ref.watch(communityPresenceProvider(communityId));
  return presenceAsync.valueOrNull?.length ?? 0;
});

/// Provider que verifica se um usuário específico está online.
/// Parâmetro: "communityId:userId" (separado por ':').
final isUserOnlineProvider = Provider.family<bool, String>((ref, key) {
  final parts = key.split(':');
  if (parts.length != 2) return false;
  final communityId = parts[0];
  final userId = parts[1];

  final presenceAsync = ref.watch(communityPresenceProvider(communityId));
  return presenceAsync.valueOrNull?.contains(userId) ?? false;
});

/// Provider para presença global (não específica de comunidade).
final globalPresenceProvider =
    StreamNotifierProvider<GlobalPresenceNotifier, Set<String>>(
  GlobalPresenceNotifier.new,
);

class GlobalPresenceNotifier extends StreamNotifier<Set<String>> {
  @override
  Stream<Set<String>> build() {
    return _mergeInitialAndStream();
  }

  Stream<Set<String>> _mergeInitialAndStream() async* {
    final presence = PresenceService.instance;
    yield presence.getOnlineUsers('global');
    yield* presence.onlineUsersStream('global');
  }
}

/// Provider simples para verificar se um userId está online globalmente.
final isUserOnlineGlobalProvider = Provider.family<bool, String>((ref, userId) {
  final presenceAsync = ref.watch(globalPresenceProvider);
  return presenceAsync.valueOrNull?.contains(userId) ?? false;
});
