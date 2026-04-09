import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BlockProvider — Gerencia o estado de bloqueio de usuários.
//
// Responsabilidades:
//   - Carregar a lista de IDs bloqueados/bloqueadores do usuário atual
//   - Expor métodos block(userId) e unblock(userId)
//   - Invalidar providers dependentes após mudança de estado
//   - Fornecer helper isBlocked(userId) para verificação síncrona
// ─────────────────────────────────────────────────────────────────────────────

/// Provider que mantém o Set de IDs com relação de bloqueio (qualquer direção).
/// Usado para filtrar feeds, comentários, busca e perfis no cliente.
final blockedIdsProvider =
    AsyncNotifierProvider<BlockedIdsNotifier, Set<String>>(
  BlockedIdsNotifier.new,
);

class BlockedIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    return _fetchBlockedIds();
  }

  Future<Set<String>> _fetchBlockedIds() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return {};

    try {
      // Busca todos os registros onde o usuário é blocker ou blocked
      final res = await SupabaseService.client
          .rpc('get_blocked_ids') as List?;

      if (res == null) return {};
      return res.map((e) => e.toString()).toSet();
    } catch (e) {
      // Fallback: query direta na tabela blocks
      try {
        final res = await SupabaseService.table('blocks')
            .select('blocker_id, blocked_id')
            .or('blocker_id.eq.$userId,blocked_id.eq.$userId');

        final ids = <String>{};
        for (final row in (res as List? ?? [])) {
          final blockerId = row['blocker_id'] as String?;
          final blockedId = row['blocked_id'] as String?;
          if (blockerId == userId && blockedId != null) ids.add(blockedId);
          if (blockedId == userId && blockerId != null) ids.add(blockerId);
        }
        return ids;
      } catch (_) {
        return {};
      }
    }
  }

  /// Bloqueia um usuário. Retorna true em caso de sucesso.
  Future<bool> block(String targetUserId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .rpc('block_user', params: {'p_blocked_id': targetUserId});

      // Atualizar estado local imediatamente
      state = AsyncData({...?state.valueOrNull, targetUserId});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Desbloqueia um usuário pelo ID. Retorna true em caso de sucesso.
  Future<bool> unblock(String targetUserId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .rpc('unblock_user', params: {'p_blocked_id': targetUserId});

      // Atualizar estado local imediatamente
      final current = Set<String>.from(state.valueOrNull ?? {});
      current.remove(targetUserId);
      state = AsyncData(current);
      return true;
    } catch (e) {
      // Fallback: delete direto por blocker_id + blocked_id
      try {
        await SupabaseService.table('blocks')
            .delete()
            .eq('blocker_id', userId)
            .eq('blocked_id', targetUserId);

        final current = Set<String>.from(state.valueOrNull ?? {});
        current.remove(targetUserId);
        state = AsyncData(current);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Recarrega a lista de bloqueados do servidor.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchBlockedIds());
  }
}

/// Provider de conveniência: verifica se um userId específico está bloqueado
/// (em qualquer direção) pelo usuário atual.
final isBlockedProvider = Provider.family<bool, String>((ref, userId) {
  final blockedIds = ref.watch(blockedIdsProvider).valueOrNull ?? {};
  return blockedIds.contains(userId);
});

/// Provider que retorna apenas os IDs que o usuário atual bloqueou
/// (não inclui quem bloqueou o usuário atual).
/// Usado na blocked_users_screen para listar os bloqueados.
final myBlocksProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  try {
    final res = await SupabaseService.table('blocks')
        .select('id, created_at, blocked:profiles!blocked_id(id, nickname, icon_url, amino_id)')
        .eq('blocker_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  } catch (e) {
    return [];
  }
});
