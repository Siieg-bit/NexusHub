import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sticker_model.dart';
import '../repositories/sticker_repository.dart';

// ============================================================================
// PROVIDERS DE DADOS (FutureProvider)
// ============================================================================

/// Packs criados pelo usuário autenticado.
final myPacksProvider = FutureProvider<List<StickerPackModel>>((ref) async {
  return StickerRepository.instance.getMyPacks();
});

/// Packs salvos pelo usuário.
final savedPacksProvider = FutureProvider<List<StickerPackModel>>((ref) async {
  return StickerRepository.instance.getSavedPacks();
});

/// Packs da loja (não criados por usuários).
final storePacksProvider = FutureProvider<List<StickerPackModel>>((ref) async {
  return StickerRepository.instance.getStorePacks();
});

/// Packs da loja que o usuário já comprou.
/// Usado pelo picker do chat para exibir apenas packs desbloqueados.
final purchasedStorePacksProvider =
    FutureProvider<List<StickerPackModel>>((ref) async {
  return StickerRepository.instance.getPurchasedStorePacks();
});

/// Packs públicos para descoberta (com busca opcional).
final publicPacksProvider = FutureProvider.family<List<StickerPackModel>, String?>(
  (ref, search) async {
    return StickerRepository.instance.getPublicPacks(search: search);
  },
);

/// Stickers de um pack específico.
final packStickersProvider = FutureProvider.family<List<StickerModel>, String>(
  (ref, packId) async {
    return StickerRepository.instance.getPackStickers(packId);
  },
);

/// Detalhes de um pack específico.
final packDetailProvider = FutureProvider.family<StickerPackModel?, String>(
  (ref, packId) async {
    return StickerRepository.instance.getPackDetail(packId);
  },
);

/// Stickers favoritos do usuário.
final favoritesProvider = FutureProvider<List<StickerModel>>((ref) async {
  return StickerRepository.instance.getFavorites();
});

/// Stickers usados recentemente.
final recentsProvider = FutureProvider<List<StickerModel>>((ref) async {
  return StickerRepository.instance.getRecents();
});

// ============================================================================
// NOTIFIER — Estado do Picker de Stickers
// ============================================================================

/// Notifier que gerencia o estado completo do picker de stickers.
class StickerPickerNotifier extends StateNotifier<StickerPickerState> {
  StickerPickerNotifier() : super(const StickerPickerState(isLoading: true)) {
    _loadAll();
  }

  final _repo = StickerRepository.instance;

  Future<void> _loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getMyPacks(),
        _repo.getSavedPacks(),
        _repo.getFavorites(),
        _repo.getRecents(),
      ]);

      state = StickerPickerState(
        myPacks: results[0] as List<StickerPackModel>,
        savedPacks: results[1] as List<StickerPackModel>,
        storePacks: const [], // aba Loja removida do picker — packs da loja ficam em /store
        favorites: results[2] as List<StickerModel>,
        recents: results[3] as List<StickerModel>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Recarrega todos os dados.
  Future<void> reload() => _loadAll();

  /// Favorita/desfavorita um sticker e atualiza o estado local.
  Future<bool> toggleFavorite(StickerModel sticker) async {
    final added = await _repo.toggleFavorite(
      stickerId: sticker.id,
      stickerUrl: sticker.imageUrl,
      packId: sticker.packId.isNotEmpty ? sticker.packId : null,
      stickerName: sticker.name,
    );

    final currentFavs = List<StickerModel>.from(state.favorites);
    if (added) {
      if (!currentFavs.any((s) => s.id == sticker.id)) {
        currentFavs.insert(0, sticker);
      }
    } else {
      currentFavs.removeWhere((s) => s.id == sticker.id);
    }

    state = state.copyWith(favorites: currentFavs);
    return added;
  }

  /// Salva/remove um pack e atualiza o estado local.
  Future<bool> toggleSavePack(StickerPackModel pack) async {
    final wasSaved = state.isPackSaved(pack.id) || pack.isSaved;
    final saved = await _repo.savePack(pack.id);

    // Se o pack não estava salvo e a RPC retornou false, tratamos como falha
    // para não remover/localmente algo que nunca esteve salvo.
    if (!wasSaved && !saved) {
      state = state.copyWith(error: 'save_pack_failed');
      return false;
    }

    final currentSaved = List<StickerPackModel>.from(state.savedPacks);
    final currentStore = List<StickerPackModel>.from(state.storePacks);
    final currentMine = List<StickerPackModel>.from(state.myPacks);

    StickerPackModel syncPack(StickerPackModel item) {
      if (item.id != pack.id) return item;
      final nextCount = saved
          ? item.savesCount + (wasSaved ? 0 : 1)
          : (item.savesCount > 0 ? item.savesCount - 1 : 0);
      return item.copyWith(
        isSaved: saved,
        savesCount: nextCount,
      );
    }

    if (saved) {
      final updatedPack = syncPack(pack);
      final existingIndex = currentSaved.indexWhere((p) => p.id == pack.id);
      if (existingIndex == -1) {
        currentSaved.insert(0, updatedPack);
      } else {
        currentSaved[existingIndex] = syncPack(currentSaved[existingIndex]);
      }
    } else {
      currentSaved.removeWhere((p) => p.id == pack.id);
    }

    state = state.copyWith(
      savedPacks: currentSaved,
      storePacks: currentStore.map(syncPack).toList(growable: false),
      myPacks: currentMine.map(syncPack).toList(growable: false),
      error: null,
    );
    return saved;
  }

  /// Registra uso de um sticker e atualiza recentes.
  Future<void> trackUsed(StickerModel sticker) async {
    await _repo.trackUsed(
      stickerId: sticker.id,
      stickerUrl: sticker.imageUrl,
      packId: sticker.packId.isNotEmpty ? sticker.packId : null,
      stickerName: sticker.name,
    );

    // Atualizar lista de recentes localmente
    final currentRecents = List<StickerModel>.from(state.recents);
    currentRecents.removeWhere((s) => s.id == sticker.id);
    currentRecents.insert(0, sticker);
    if (currentRecents.length > 24) {
      currentRecents.removeLast();
    }

    state = state.copyWith(recents: currentRecents);
  }

  /// Verifica se um sticker está favoritado.
  bool isFavorite(String stickerId) {
    return state.favorites.any((s) => s.id == stickerId);
  }

  /// Verifica se um pack está salvo.
  bool isPackSaved(String packId) {
    return state.savedPacks.any((p) => p.id == packId);
  }

  /// Adiciona um pack recém-criado à lista local.
  void addMyPack(StickerPackModel pack) {
    final current = List<StickerPackModel>.from(state.myPacks);
    current.insert(0, pack);
    state = state.copyWith(myPacks: current);
  }

  /// Remove um pack da lista local.
  void removeMyPack(String packId) {
    final current = List<StickerPackModel>.from(state.myPacks);
    current.removeWhere((p) => p.id == packId);
    state = state.copyWith(myPacks: current);
  }

  /// Atualiza um pack na lista local.
  void updateMyPack(StickerPackModel updatedPack) {
    final current = List<StickerPackModel>.from(state.myPacks);
    final idx = current.indexWhere((p) => p.id == updatedPack.id);
    if (idx != -1) {
      current[idx] = updatedPack;
      state = state.copyWith(myPacks: current);
    }
  }
}

/// Provider do picker de stickers — estado global compartilhado.
final stickerPickerProvider =
    StateNotifierProvider<StickerPickerNotifier, StickerPickerState>(
  (ref) => StickerPickerNotifier(),
);

// ============================================================================
// NOTIFIER — Gerenciamento de Pack (criação/edição)
// ============================================================================

/// Estado de criação/edição de um pack.
class PackEditorState {
  final bool isLoading;
  final String? error;
  final String? successPackId;

  const PackEditorState({
    this.isLoading = false,
    this.error,
    this.successPackId,
  });

  PackEditorState copyWith({
    bool? isLoading,
    String? error,
    String? successPackId,
  }) {
    return PackEditorState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successPackId: successPackId ?? this.successPackId,
    );
  }
}

class PackEditorNotifier extends StateNotifier<PackEditorState> {
  PackEditorNotifier() : super(const PackEditorState());

  final _repo = StickerRepository.instance;

  Future<String?> createPack({
    required String name,
    String description = '',
    String? coverUrl,
    List<String> tags = const [],
    bool isPublic = true,
  }) async {
    state = const PackEditorState(isLoading: true);
    try {
      final packId = await _repo.createPack(
        name: name,
        description: description,
        coverUrl: coverUrl,
        tags: tags,
        isPublic: isPublic,
      );
      state = PackEditorState(successPackId: packId);
      return packId;
    } catch (e) {
      state = PackEditorState(error: e.toString());
      return null;
    }
  }

  Future<bool> updatePack({
    required String packId,
    String? name,
    String? description,
    String? coverUrl,
    List<String>? tags,
    bool? isPublic,
  }) async {
    state = const PackEditorState(isLoading: true);
    try {
      await _repo.updatePack(
        packId: packId,
        name: name,
        description: description,
        coverUrl: coverUrl,
        tags: tags,
        isPublic: isPublic,
      );
      state = const PackEditorState();
      return true;
    } catch (e) {
      state = PackEditorState(error: e.toString());
      return false;
    }
  }

  Future<bool> deletePack(String packId) async {
    state = const PackEditorState(isLoading: true);
    try {
      await _repo.deletePack(packId);
      state = const PackEditorState();
      return true;
    } catch (e) {
      state = PackEditorState(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final packEditorProvider =
    StateNotifierProvider.autoDispose<PackEditorNotifier, PackEditorState>(
  (ref) => PackEditorNotifier(),
);
