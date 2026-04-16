import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider que expõe um conjunto de usuários online por comunidade.
///
/// A presença em tempo real por canal foi removida do projeto em favor de
/// janelas graduais de 15 minutos baseadas em `profiles.last_seen_at`.
/// Enquanto não houver uma fonte reativa específica por comunidade, este
/// provider mantém uma API compatível para o restante da UI sem depender das
/// chamadas deprecated do serviço legado.
final communityPresenceProvider = StreamNotifierProvider.family<
    CommunityPresenceNotifier, Set<String>, String>(
  CommunityPresenceNotifier.new,
);

class CommunityPresenceNotifier
    extends FamilyStreamNotifier<Set<String>, String> {
  @override
  Stream<Set<String>> build(String arg) {
    return const Stream<Set<String>>.value(<String>{});
  }
}

/// Provider simples para contagem de membros online em uma comunidade.
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

/// Provider para presença global.
final globalPresenceProvider =
    StreamNotifierProvider<GlobalPresenceNotifier, Set<String>>(
  GlobalPresenceNotifier.new,
);

class GlobalPresenceNotifier extends StreamNotifier<Set<String>> {
  @override
  Stream<Set<String>> build() {
    return const Stream<Set<String>>.value(<String>{});
  }
}

/// Provider simples para verificar se um userId está online globalmente.
final isUserOnlineGlobalProvider = Provider.family<bool, String>((ref, userId) {
  final presenceAsync = ref.watch(globalPresenceProvider);
  return presenceAsync.valueOrNull?.contains(userId) ?? false;
});
