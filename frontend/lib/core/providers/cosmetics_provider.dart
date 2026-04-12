import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

/// Modelo de cosméticos equipados de um usuário.
class UserCosmetics {
  final String userId;
  final String? avatarFrameUrl;
  final String? chatBubbleId;
  final String? chatBubbleStyle;
  final String? chatBubbleColor;
  final String? chatBubbleImageUrl;
  final bool isAminoPlus;

  const UserCosmetics({
    required this.userId,
    this.avatarFrameUrl,
    this.chatBubbleId,
    this.chatBubbleStyle,
    this.chatBubbleColor,
    this.chatBubbleImageUrl,
    this.isAminoPlus = false,
  });

  factory UserCosmetics.empty(String userId) => UserCosmetics(userId: userId);

  factory UserCosmetics.fromJson(Map<String, dynamic> json) {
    return UserCosmetics(
      userId: json['user_id'] as String? ?? '',
      avatarFrameUrl: json['avatar_frame_url'] as String?,
      chatBubbleId: json['chat_bubble_id'] as String?,
      chatBubbleStyle: json['chat_bubble_style'] as String?,
      chatBubbleColor: json['chat_bubble_color'] as String?,
      chatBubbleImageUrl: json['chat_bubble_image_url'] as String?,
      isAminoPlus: json['is_amino_plus'] as bool? ?? false,
    );
  }
}

/// Provider que busca e cacheia os cosméticos equipados de um usuário.
final userCosmeticsProvider =
    FutureProvider.family<UserCosmetics, String>((ref, userId) async {
  try {
    final equipped = await SupabaseService.table('user_purchases')
        .select('*, store_items!user_purchases_item_id_fkey(*)')
        .eq('user_id', userId)
        .eq('is_equipped', true);

    String? avatarFrameUrl;
    String? chatBubbleId;
    String? chatBubbleStyle;
    String? chatBubbleColor;
    String? chatBubbleImageUrl;

    for (final item in ((equipped as List? ?? []))) {
      final storeItem = _asMap(item['store_items']);
      if (storeItem.isEmpty) continue;

      final type = _asString(storeItem['type']);
      final assetConfig = _asMap(storeItem['asset_config']);
      final legacyMetadata = _asMap(storeItem['metadata']);

      if (type == 'avatar_frame') {
        avatarFrameUrl = _firstNonEmpty([
          _asString(assetConfig['frame_url']),
          _asString(assetConfig['image_url']),
          _asString(storeItem['asset_url']),
          _asString(storeItem['preview_url']),
          _asString(legacyMetadata['image_url']),
          _asString(storeItem['image_url']),
        ]);
      } else if (type == 'chat_bubble') {
        chatBubbleId = _asString(storeItem['id']);
        chatBubbleStyle = _firstNonEmpty([
          _asString(assetConfig['style']),
          _asString(assetConfig['bubble_style']),
          _asString(legacyMetadata['style']),
        ]);
        chatBubbleColor = _firstNonEmpty([
          _asString(assetConfig['color']),
          _asString(assetConfig['bubble_color']),
          _asString(legacyMetadata['color']),
        ]);
        chatBubbleImageUrl = _firstNonEmpty([
          _asString(assetConfig['image_url']),
          _asString(assetConfig['bubble_image_url']),
          _asString(storeItem['asset_url']),
          _asString(storeItem['preview_url']),
          _asString(legacyMetadata['image_url']),
          _asString(storeItem['image_url']),
        ]);
        // DEBUG — remover após diagnóstico
        debugPrint('[CosmeticsProvider] chat_bubble encontrado userId=$userId');
        debugPrint('[CosmeticsProvider] assetConfig=$assetConfig');
        debugPrint('[CosmeticsProvider] chatBubbleStyle=$chatBubbleStyle');
        debugPrint('[CosmeticsProvider] chatBubbleImageUrl=$chatBubbleImageUrl');
      }
    }

    final profile = await SupabaseService.table('profiles')
        .select('amino_plus')
        .eq('id', userId)
        .maybeSingle();
    final isAminoPlus = profile?['amino_plus'] as bool? ?? false;

    return UserCosmetics(
      userId: userId,
      avatarFrameUrl: avatarFrameUrl,
      chatBubbleId: chatBubbleId,
      chatBubbleStyle: chatBubbleStyle,
      chatBubbleColor: chatBubbleColor,
      chatBubbleImageUrl: chatBubbleImageUrl,
      isAminoPlus: isAminoPlus,
    );
  } catch (e) {
    return UserCosmetics.empty(userId);
  }
});

/// Provider para buscar cosméticos de múltiplos usuários de uma vez.
final batchCosmeticsProvider =
    FutureProvider.family<Map<String, UserCosmetics>, List<String>>(
        (ref, userIds) async {
  final result = <String, UserCosmetics>{};

  if (userIds.isEmpty) return result;

  try {
    final equipped = await SupabaseService.table('user_purchases')
        .select('*, store_items!user_purchases_item_id_fkey(*)')
        .inFilter('user_id', userIds)
        .eq('is_equipped', true);

    final byUser = <String, List<Map<String, dynamic>>>{};
    for (final item in ((equipped as List? ?? []))) {
      final map = _asMap(item);
      final uid = _asString(map['user_id']);
      if (uid.isEmpty) continue;
      byUser.putIfAbsent(uid, () => []).add(map);
    }

    for (final userId in userIds) {
      final items = byUser[userId] ?? [];
      String? avatarFrameUrl;
      String? chatBubbleId;
      String? chatBubbleStyle;
      String? chatBubbleColor;
      String? chatBubbleImageUrl;

      for (final item in items) {
        final storeItem = _asMap(item['store_items']);
        if (storeItem.isEmpty) continue;

        final type = _asString(storeItem['type']);
        final assetConfig = _asMap(storeItem['asset_config']);
        final legacyMetadata = _asMap(storeItem['metadata']);

        if (type == 'avatar_frame') {
          avatarFrameUrl = _firstNonEmpty([
            _asString(assetConfig['frame_url']),
            _asString(assetConfig['image_url']),
            _asString(storeItem['asset_url']),
            _asString(storeItem['preview_url']),
            _asString(legacyMetadata['image_url']),
            _asString(storeItem['image_url']),
          ]);
        } else if (type == 'chat_bubble') {
          chatBubbleId = _asString(storeItem['id']);
          chatBubbleStyle = _firstNonEmpty([
            _asString(assetConfig['style']),
            _asString(assetConfig['bubble_style']),
            _asString(legacyMetadata['style']),
          ]);
          chatBubbleColor = _firstNonEmpty([
            _asString(assetConfig['color']),
            _asString(assetConfig['bubble_color']),
            _asString(legacyMetadata['color']),
          ]);
          chatBubbleImageUrl = _firstNonEmpty([
            _asString(assetConfig['image_url']),
            _asString(assetConfig['bubble_image_url']),
            _asString(storeItem['asset_url']),
            _asString(storeItem['preview_url']),
            _asString(legacyMetadata['image_url']),
            _asString(storeItem['image_url']),
          ]);
        }
      }

      result[userId] = UserCosmetics(
        userId: userId,
        avatarFrameUrl: avatarFrameUrl,
        chatBubbleId: chatBubbleId,
        chatBubbleStyle: chatBubbleStyle,
        chatBubbleColor: chatBubbleColor,
        chatBubbleImageUrl: chatBubbleImageUrl,
      );
    }
  } catch (e) {
    for (final userId in userIds) {
      result[userId] = UserCosmetics.empty(userId);
    }
  }

  return result;
});

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String? _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
