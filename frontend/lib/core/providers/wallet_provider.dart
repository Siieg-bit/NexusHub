import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

/// ============================================================================
/// WalletProvider — State Management para economia (coins, transações).
/// Usa profiles.coins como saldo e coin_transactions como histórico.
/// ============================================================================

class WalletState {
  final int coins;
  final List<Map<String, dynamic>> transactions;
  final bool isLoading;

  const WalletState({
    this.coins = 0,
    this.transactions = const [],
    this.isLoading = false,
  });

  WalletState copyWith({
    int? coins,
    List<Map<String, dynamic>>? transactions,
    bool? isLoading,
  }) {
    return WalletState(
      coins: coins ?? this.coins,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WalletNotifier extends AsyncNotifier<WalletState> {
  @override
  Future<WalletState> build() async {
    return _fetch();
  }

  Future<WalletState> _fetch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const WalletState();

    // Buscar saldo de coins do perfil
    final profileRes = await SupabaseService.table('profiles')
        .select('coins')
        .eq('id', userId)
        .maybeSingle();

    // Buscar histórico de transações
    final txRes = await SupabaseService.table('coin_transactions')
        .select()
        .or('user_id.eq.$userId,target_user_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(50);

    return WalletState(
      coins: (profileRes?['coins'] as int?) ?? 0,
      transactions: List<Map<String, dynamic>>.from(txRes as List? ?? []),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<bool> transferCoins({
    required String targetUserId,
    required int amount,
  }) async {
    try {
      await SupabaseService.client.rpc('transfer_coins', params: {
        'p_target_user_id': targetUserId,
        'p_amount': amount,
      });
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> purchaseItem(String itemId, int price) async {
    try {
      await SupabaseService.client.rpc('purchase_store_item', params: {
        'p_item_id': itemId,
      });
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final walletProvider =
    AsyncNotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);

// ── Coin Balance (lightweight) ──
final coinBalanceProvider = FutureProvider<int>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return 0;

  final res = await SupabaseService.table('profiles')
      .select('coins')
      .eq('id', userId)
      .maybeSingle();

  return (res?['coins'] as int?) ?? 0;
});
