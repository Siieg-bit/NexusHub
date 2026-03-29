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
///
/// Uso:
/// ```dart
/// final cosmetics = ref.watch(userCosmeticsProvider(userId));
/// cosmetics.when(
///   data: (c) => AvatarWithFrame(
///     avatarUrl: user.iconUrl,
///     frameUrl: c.avatarFrameUrl,
///   ),
/// );
/// ```
final userCosmeticsProvider =
    FutureProvider.family<UserCosmetics, String>((ref, userId) async {
  try {
    // Buscar itens equipados do inventário do usuário
    final equipped = await SupabaseService.table('user_inventory')
        .select('*, store_items!user_inventory_item_id_fkey(*)')
        .eq('user_id', userId)
        .eq('is_equipped', true);

    String? avatarFrameUrl;
    String? chatBubbleId;
    String? chatBubbleStyle;
    String? chatBubbleColor;
    String? chatBubbleImageUrl;

    for (final item in (equipped as List)) {
      final storeItem = item['store_items'] as Map<String, dynamic>?;
      if (storeItem == null) continue;

      final type = storeItem['type'] as String? ?? '';
      final metadata = storeItem['metadata'] as Map<String, dynamic>? ?? {};

      if (type == 'avatar_frame') {
        avatarFrameUrl = (metadata['image_url'] as String?) ??
            (storeItem['image_url'] as String?);
      } else if (type == 'chat_bubble') {
        chatBubbleId = storeItem['id'] as String?;
        chatBubbleStyle = metadata['style'] as String?;
        chatBubbleColor = metadata['color'] as String?;
        chatBubbleImageUrl = (metadata['image_url'] as String?) ??
            (storeItem['image_url'] as String?);
      }
    }

    // Verificar se é Amino+
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
/// Útil para listas de membros, comentários, leaderboard.
final batchCosmeticsProvider =
    FutureProvider.family<Map<String, UserCosmetics>, List<String>>(
        (ref, userIds) async {
  final result = <String, UserCosmetics>{};

  if (userIds.isEmpty) return result;

  try {
    // Buscar todos os itens equipados de todos os usuários de uma vez
    final equipped = await SupabaseService.table('user_inventory')
        .select('*, store_items!user_inventory_item_id_fkey(*)')
        .inFilter('user_id', userIds)
        .eq('is_equipped', true);

    // Agrupar por user_id
    final byUser = <String, List<Map<String, dynamic>>>{};
    for (final item in (equipped as List)) {
      final uid = item['user_id'] as String;
      byUser.putIfAbsent(uid, () => []).add(Map<String, dynamic>.from(item));
    }

    for (final userId in userIds) {
      final items = byUser[userId] ?? [];
      String? avatarFrameUrl;
      String? chatBubbleId;
      String? chatBubbleStyle;
      String? chatBubbleColor;
      String? chatBubbleImageUrl;

      for (final item in items) {
        final storeItem = item['store_items'] as Map<String, dynamic>?;
        if (storeItem == null) continue;
        final type = storeItem['type'] as String? ?? '';
        final metadata = storeItem['metadata'] as Map<String, dynamic>? ?? {};

        if (type == 'avatar_frame') {
          avatarFrameUrl = (metadata['image_url'] as String?) ??
              (storeItem['image_url'] as String?);
        } else if (type == 'chat_bubble') {
          chatBubbleId = storeItem['id'] as String?;
          chatBubbleStyle = metadata['style'] as String?;
          chatBubbleColor = metadata['color'] as String?;
          chatBubbleImageUrl = (metadata['image_url'] as String?) ??
              (storeItem['image_url'] as String?);
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
