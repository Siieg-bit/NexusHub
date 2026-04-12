import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/sticker_model.dart';

/// Repositório central para todas as operações de stickers.
class StickerRepository {
  StickerRepository._();
  static final StickerRepository instance = StickerRepository._();

  // ============================================================================
  // PACKS DO USUÁRIO
  // ============================================================================

  /// Retorna os packs criados pelo usuário autenticado.
  Future<List<StickerPackModel>> getMyPacks() async {
    try {
      final res = await SupabaseService.rpc('get_my_sticker_packs');
      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      return list.map(StickerPackModel.fromJson).toList();
    } catch (e) {
      debugPrint('[StickerRepository] getMyPacks: $e');
      return [];
    }
  }

  /// Retorna os packs salvos pelo usuário.
  Future<List<StickerPackModel>> getSavedPacks() async {
    try {
      final res = await SupabaseService.rpc('get_saved_sticker_packs');
      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      return list.map(StickerPackModel.fromJson).toList();
    } catch (e) {
      debugPrint('[StickerRepository] getSavedPacks: $e');
      return [];
    }
  }

  /// Retorna packs públicos para descoberta.
  Future<List<StickerPackModel>> getPublicPacks({
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await SupabaseService.rpc('get_public_sticker_packs', params: {
        'p_search': search,
        'p_limit': limit,
        'p_offset': offset,
      });
      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      return list.map(StickerPackModel.fromJson).toList();
    } catch (e) {
      debugPrint('[StickerRepository] getPublicPacks: $e');
      return [];
    }
  }

  /// Retorna detalhes de um pack específico.
  Future<StickerPackModel?> getPackDetail(String packId) async {
    try {
      final res = await SupabaseService.rpc('get_sticker_pack_detail', params: {
        'p_pack_id': packId,
      });
      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      if (list.isEmpty) return null;
      return StickerPackModel.fromJson(list.first);
    } catch (e) {
      debugPrint('[StickerRepository] getPackDetail: $e');
      return null;
    }
  }

  /// Retorna os stickers de um pack.
  Future<List<StickerModel>> getPackStickers(String packId) async {
    try {
      final res = await SupabaseService.rpc('get_pack_stickers', params: {
        'p_pack_id': packId,
      });
      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      return list.map(StickerModel.fromJson).toList();
    } catch (e) {
      debugPrint('[StickerRepository] getPackStickers: $e');
      return [];
    }
  }

  // ============================================================================
  // CRIAÇÃO DE PACKS E STICKERS
  // ============================================================================

  /// Cria um novo pack de stickers.
  Future<String?> createPack({
    required String name,
    String description = '',
    String? coverUrl,
    List<String> tags = const [],
    bool isPublic = true,
  }) async {
    try {
      final res = await SupabaseService.rpc('create_sticker_pack', params: {
        'p_name': name,
        'p_description': description,
        'p_cover_url': coverUrl,
        'p_tags': tags,
        'p_is_public': isPublic,
      });
      return res as String?;
    } catch (e) {
      debugPrint('[StickerRepository] createPack: $e');
      rethrow;
    }
  }

  /// Atualiza um pack existente.
  Future<void> updatePack({
    required String packId,
    String? name,
    String? description,
    String? coverUrl,
    List<String>? tags,
    bool? isPublic,
  }) async {
    try {
      await SupabaseService.rpc('update_sticker_pack', params: {
        'p_pack_id': packId,
        'p_name': name,
        'p_description': description,
        'p_cover_url': coverUrl,
        'p_tags': tags,
        'p_is_public': isPublic,
      });
    } catch (e) {
      debugPrint('[StickerRepository] updatePack: $e');
      rethrow;
    }
  }

  /// Deleta um pack do usuário.
  Future<void> deletePack(String packId) async {
    try {
      await SupabaseService.rpc('delete_sticker_pack', params: {
        'p_pack_id': packId,
      });
    } catch (e) {
      debugPrint('[StickerRepository] deletePack: $e');
      rethrow;
    }
  }

  /// Faz upload de uma imagem de sticker para o Storage.
  Future<String?> uploadStickerImage({
    required String packId,
    required Uint8List imageBytes,
    required String fileName,
    String mimeType = 'image/png',
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return null;

      final path = 'stickers/$userId/$packId/$fileName';
      final url = await SupabaseService.uploadFile(
        bucket: 'user-stickers',
        path: path,
        file: imageBytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );
      return url;
    } catch (e) {
      debugPrint('[StickerRepository] uploadStickerImage: $e');
      rethrow;
    }
  }

  /// Adiciona um sticker a um pack.
  Future<String?> addStickerToPack({
    required String packId,
    required String imageUrl,
    String name = '',
    List<String> tags = const [],
    bool isAnimated = false,
  }) async {
    try {
      final res = await SupabaseService.rpc('add_sticker_to_pack', params: {
        'p_pack_id': packId,
        'p_image_url': imageUrl,
        'p_name': name,
        'p_tags': tags,
        'p_is_animated': isAnimated,
      });
      return res as String?;
    } catch (e) {
      debugPrint('[StickerRepository] addStickerToPack: $e');
      rethrow;
    }
  }

  /// Remove um sticker de um pack.
  Future<void> deleteStickerFromPack(String stickerId) async {
    try {
      await SupabaseService.rpc('delete_sticker_from_pack', params: {
        'p_sticker_id': stickerId,
      });
    } catch (e) {
      debugPrint('[StickerRepository] deleteStickerFromPack: $e');
      rethrow;
    }
  }

  // ============================================================================
  // FAVORITOS E SALVAMENTOS
  // ============================================================================

  /// Favorita ou desfavorita um sticker.
  Future<bool> toggleFavorite({
    required String stickerId,
    required String stickerUrl,
    String? packId,
    String stickerName = '',
  }) async {
    try {
      final res = await SupabaseService.rpc('toggle_sticker_favorite', params: {
        'p_sticker_id': stickerId,
        'p_sticker_url': stickerUrl,
        'p_pack_id': packId,
        'p_category': 'favorite',
        'p_sticker_name': stickerName,
      });
      return res as bool? ?? false;
    } catch (e) {
      debugPrint('[StickerRepository] toggleFavorite: $e');
      return false;
    }
  }

  /// Salva ou remove um pack de outro usuário.
  Future<bool> savePack(String packId) async {
    try {
      final res = await SupabaseService.rpc('save_sticker_pack', params: {
        'p_pack_id': packId,
      });
      return res as bool? ?? false;
    } catch (e) {
      debugPrint('[StickerRepository] savePack: $e');
      return false;
    }
  }

  /// Retorna os stickers favoritos do usuário.
  Future<List<StickerModel>> getFavorites() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return [];

      final res = await SupabaseService.table('user_sticker_favorites')
          .select('sticker_id, sticker_url, sticker_name, pack_id')
          .eq('user_id', userId)
          .eq('category', 'favorite')
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      return list.map((e) => StickerModel(
        id: e['sticker_id'] as String? ?? '',
        packId: e['pack_id'] as String? ?? '',
        name: e['sticker_name'] as String? ?? '',
        imageUrl: e['sticker_url'] as String? ?? '',
      )).toList();
    } catch (e) {
      debugPrint('[StickerRepository] getFavorites: $e');
      return [];
    }
  }

  /// Retorna os stickers usados recentemente.
  Future<List<StickerModel>> getRecents() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return [];

      final res = await SupabaseService.table('recently_used_stickers')
          .select('sticker_id, sticker_url, sticker_name')
          .eq('user_id', userId)
          .order('used_at', ascending: false)
          .limit(24);

      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      return list.map((e) => StickerModel(
        id: e['sticker_id'] as String? ?? '',
        packId: '',
        name: e['sticker_name'] as String? ?? '',
        imageUrl: e['sticker_url'] as String? ?? '',
      )).toList();
    } catch (e) {
      debugPrint('[StickerRepository] getRecents: $e');
      return [];
    }
  }

  /// Registra uso de um sticker (recentes + contador).
  Future<void> trackUsed({
    required String stickerId,
    required String stickerUrl,
    String? packId,
    String stickerName = '',
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('recently_used_stickers').upsert({
        'user_id': userId,
        'sticker_id': stickerId,
        'sticker_url': stickerUrl,
        'sticker_name': stickerName,
        'used_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,sticker_id');

      // Incrementar contador de usos
      await SupabaseService.rpc('increment_sticker_uses', params: {
        'p_sticker_id': stickerId,
      });
    } catch (e) {
      debugPrint('[StickerRepository] trackUsed: $e');
    }
  }

  // ============================================================================
  // PACKS DA LOJA (não criados por usuários)
  // ============================================================================

  /// Retorna os packs da loja disponíveis.
  Future<List<StickerPackModel>> getStorePacks() async {
    try {
      final res = await SupabaseService.table('sticker_packs')
          .select('*, stickers(*)')
          .eq('is_active', true)
          .eq('is_user_created', false)
          .order('sort_order');

      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      return list.map(StickerPackModel.fromJson).toList();
    } catch (e) {
      debugPrint('[StickerRepository] getStorePacks: $e');
      return [];
    }
  }

  /// Retorna apenas os sticker packs que o usuário comprou na loja.
  ///
  /// Busca as compras do tipo 'sticker_pack' e cruza com os packs reais
  /// para retornar os [StickerPackModel] completos com stickers.
  Future<List<StickerPackModel>> getPurchasedStorePacks() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return [];

      // 1. Busca todas as compras do usuário (sem filtro de join que não funciona no PostgREST)
      final purchases = await SupabaseService.table('user_purchases')
          .select('item_id, store_items!user_purchases_item_id_fkey(id, type, asset_config)')
          .eq('user_id', userId);

      final purchaseList = List<Map<String, dynamic>>.from(purchases as List? ?? []);

      // 2. Filtra apenas os de tipo sticker_pack e extrai os pack_ids
      final packIds = <String>{};
      for (final p in purchaseList) {
        final storeItem = p['store_items'] as Map<String, dynamic>?;
        if (storeItem == null) continue;
        if ((storeItem['type'] as String?) != 'sticker_pack') continue;
        final assetConfig = storeItem['asset_config'] as Map<String, dynamic>? ?? {};
        final packId = assetConfig['pack_id'] as String? ?? '';
        if (packId.isNotEmpty) packIds.add(packId);
      }

      if (packIds.isEmpty) return [];

      // 3. Busca os packs completos com stickers
      final res = await SupabaseService.table('sticker_packs')
          .select('*, stickers(*)')
          .inFilter('id', packIds.toList());

      final list = List<Map<String, dynamic>>.from(res as List? ?? []);
      return list.map(StickerPackModel.fromJson).toList();
    } catch (e) {
      debugPrint('[StickerRepository] getPurchasedStorePacks: $e');
      return [];
    }
  }
}
