import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

/// Modelo de cosméticos equipados de um usuário.
///
/// Além das URLs e estilos, carrega os parâmetros de nine-slice
/// diretamente do [asset_config] do banco, evitando valores hardcoded
/// no widget e garantindo que cada bubble use suas próprias margens.
///
/// O campo [isAvatarFrameAnimated] indica se a moldura de perfil é um
/// arquivo animado (GIF ou WebP animado). Quando verdadeiro, o widget
/// [AvatarWithFrame] usa [Image.network] em vez de [CachedNetworkImage]
/// para garantir que a animação seja reproduzida corretamente, já que
/// o [CachedNetworkImage] pode armazenar apenas o primeiro frame em cache.
///
/// O campo [isChatBubbleAnimated] indica se o balão de chat equipado é
/// um arquivo animado (GIF ou WebP animado). Quando verdadeiro, o widget
/// [ChatBubble] usa um modo de renderização alternativo com [Image.network]
/// e [gaplessPlayback] em vez do [NineSliceBubble] (que usa
/// [Canvas.drawImageNine] e só suporta frames estáticos).
class UserCosmetics {
  final String userId;
  final String? avatarFrameUrl;

  /// Indica se a moldura de perfil é animada (GIF / WebP animado).
  /// Lido de [asset_config.is_animated] no banco de dados.
  final bool isAvatarFrameAnimated;

  final String? chatBubbleId;
  final String? chatBubbleStyle;
  final String? chatBubbleColor;
  final String? chatBubbleImageUrl;

  /// Indica se o balão de chat equipado é animado (GIF / WebP animado).
  /// Lido de [asset_config.is_animated] no banco de dados.
  /// Quando true, [ChatBubble] usa [Image.network] com [gaplessPlayback]
  /// em vez de [NineSliceBubble] + [Canvas.drawImageNine].
  final bool isChatBubbleAnimated;

  final bool isAminoPlus;

  // Parâmetros nine-slice vindos do asset_config
  final EdgeInsets chatBubbleSliceInsets;
  final Size chatBubbleImageSize;
  final EdgeInsets chatBubbleContentPadding;

  /// Cor customizada do texto do balão.
  ///
  /// Lida de [asset_config.text_color] no banco de dados.
  /// Quando nula, o [ChatBubble] usa a cor padrão baseada em role/isMine.
  /// Formato hex armazenado como string (ex: `#FFFFFF`), convertido aqui
  /// para [Color] via [_hexToColor].
  final Color? chatBubbleTextColor;

  const UserCosmetics({
    required this.userId,
    this.avatarFrameUrl,
    this.isAvatarFrameAnimated = false,
    this.chatBubbleId,
    this.chatBubbleStyle,
    this.chatBubbleColor,
    this.chatBubbleImageUrl,
    this.isChatBubbleAnimated = false,
    this.isAminoPlus = false,
    this.chatBubbleSliceInsets = const EdgeInsets.all(38),
    this.chatBubbleImageSize = const Size(128, 128),
    this.chatBubbleContentPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 14,
    ),
    this.chatBubbleTextColor,
  });

  factory UserCosmetics.empty(String userId) => UserCosmetics(userId: userId);

  factory UserCosmetics.fromJson(Map<String, dynamic> json) {
    return UserCosmetics(
      userId: json['user_id'] as String? ?? '',
      avatarFrameUrl: json['avatar_frame_url'] as String?,
      isAvatarFrameAnimated: json['is_avatar_frame_animated'] as bool? ?? false,
      chatBubbleId: json['chat_bubble_id'] as String?,
      chatBubbleStyle: json['chat_bubble_style'] as String?,
      chatBubbleColor: json['chat_bubble_color'] as String?,
      chatBubbleImageUrl: json['chat_bubble_image_url'] as String?,
      isChatBubbleAnimated: json['is_chat_bubble_animated'] as bool? ?? false,
      isAminoPlus: json['is_amino_plus'] as bool? ?? false,
      chatBubbleTextColor: _hexToColor(json['chat_bubble_text_color'] as String?),
    );
  }
}

/// Converte uma string hex (#RRGGBB ou RRGGBB) para [Color].
/// Retorna null se a string for nula, vazia ou inválida.
Color? _hexToColor(String? hex) {
  if (hex == null || hex.trim().isEmpty) return null;
  final clean = hex.trim().replaceFirst('#', '');
  if (clean.length == 6) {
    final value = int.tryParse('FF$clean', radix: 16);
    if (value != null) return Color(value);
  } else if (clean.length == 8) {
    final value = int.tryParse(clean, radix: 16);
    if (value != null) return Color(value);
  }
  return null;
}

/// Extrai os parâmetros de nine-slice do [assetConfig] de um store_item.
///
/// Retorna valores padrão seguros caso os campos não existam, garantindo
/// compatibilidade retroativa com itens antigos sem esses metadados.
({
  EdgeInsets sliceInsets,
  Size imageSize,
  EdgeInsets contentPadding,
}) _extractNineSliceParams(Map<String, dynamic> assetConfig) {
  double sliceTop = _asDouble(assetConfig['slice_top'], fallback: 38);
  double sliceLeft = _asDouble(assetConfig['slice_left'], fallback: 38);
  double sliceRight = _asDouble(assetConfig['slice_right'], fallback: 38);
  double sliceBottom = _asDouble(assetConfig['slice_bottom'], fallback: 38);

  double imageWidth = _asDouble(assetConfig['image_width'], fallback: 128);
  double imageHeight = _asDouble(assetConfig['image_height'], fallback: 128);

  double paddingH = _asDouble(assetConfig['content_padding_h'], fallback: 20);
  double paddingV = _asDouble(assetConfig['content_padding_v'], fallback: 14);

  return (
    sliceInsets: EdgeInsets.fromLTRB(sliceLeft, sliceTop, sliceRight, sliceBottom),
    imageSize: Size(imageWidth, imageHeight),
    contentPadding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
  );
}

/// Provider que busca e cacheia os cosméticos equipados de um usuário.
///
/// A query usa o join via FK nomeada [user_purchases_item_id_fkey] para
/// trazer os dados do store_item em uma única chamada ao banco.
/// A RLS policy [purchases_select_equipped_public] garante que cosméticos
/// equipados de qualquer usuário sejam visíveis (necessário para renderizar
/// os bubbles de outros participantes no chat).
final userCosmeticsProvider =
    FutureProvider.family<UserCosmetics, String>((ref, userId) async {
  // Mantém o resultado em memória enquanto o app estiver rodando.
  // Evita re-fetch toda vez que o widget é reconstruído ou a tela é reaberta.
  // Os cosméticos mudam raramente — o custo de manter em memória é mínimo.
  ref.keepAlive();
  try {
    final equipped = await SupabaseService.table('user_purchases')
        .select('*, store_items!user_purchases_item_id_fkey(*)')
        .eq('user_id', userId)
        .eq('is_equipped', true);

    String? avatarFrameUrl;
    bool isAvatarFrameAnimated = false;
    String? chatBubbleId;
    String? chatBubbleStyle;
    String? chatBubbleColor;
    String? chatBubbleImageUrl;
    bool isChatBubbleAnimated = false;
    var sliceParams = _extractNineSliceParams({});
    String chatBubbleTextColorHex = '';

    for (final item in ((equipped as List? ?? []))) {
      final storeItem = _asMap(item['store_items']);
      if (storeItem.isEmpty) continue;

      final type = _asString(storeItem['type']);
      final assetConfig = _asMap(storeItem['asset_config']);

      if (type == 'avatar_frame') {
        avatarFrameUrl = _firstNonEmpty([
          _asString(assetConfig['frame_url']),
          _asString(assetConfig['image_url']),
          _asString(storeItem['asset_url']),
          _asString(storeItem['preview_url']),
        ]);
        // Lê is_animated do asset_config para saber se deve usar Image.network
        // (que preserva a animação) em vez de CachedNetworkImage (que pode
        // armazenar apenas o primeiro frame do GIF em cache).
        isAvatarFrameAnimated = assetConfig['is_animated'] as bool? ?? false;
      } else if (type == 'chat_bubble') {
        chatBubbleId = _asString(storeItem['id']);
        chatBubbleStyle = _firstNonEmpty([
          _asString(assetConfig['style']),
          _asString(assetConfig['bubble_style']),
        ]);
        chatBubbleColor = _firstNonEmpty([
          _asString(assetConfig['color']),
          _asString(assetConfig['bubble_color']),
        ]);
        chatBubbleImageUrl = _firstNonEmpty([
          _asString(assetConfig['image_url']),
          _asString(assetConfig['bubble_url']),
          _asString(assetConfig['bubble_image_url']),
          _asString(storeItem['asset_url']),
          _asString(storeItem['preview_url']),
        ]);
        // Lê is_animated do asset_config para chat bubbles animados.
        // Quando true, ChatBubble usa Image.network com gaplessPlayback
        // em vez de NineSliceBubble (que só suporta frames estáticos).
        isChatBubbleAnimated = assetConfig['is_animated'] as bool? ?? false;
        // Extrai parâmetros nine-slice do asset_config
        sliceParams = _extractNineSliceParams(assetConfig);
        // Lê text_color do asset_config para cor customizada do texto
        chatBubbleTextColorHex = _asString(assetConfig['text_color']);
      }
    }

    final profile = await SupabaseService.table('profiles')
        .select('is_amino_plus')
        .eq('id', userId)
        .maybeSingle();
    final isAminoPlus = profile?['is_amino_plus'] as bool? ?? false;

    return UserCosmetics(
      userId: userId,
      avatarFrameUrl: avatarFrameUrl,
      isAvatarFrameAnimated: isAvatarFrameAnimated,
      chatBubbleId: chatBubbleId,
      chatBubbleStyle: chatBubbleStyle,
      chatBubbleColor: chatBubbleColor,
      chatBubbleImageUrl: chatBubbleImageUrl,
      isChatBubbleAnimated: isChatBubbleAnimated,
      isAminoPlus: isAminoPlus,
      chatBubbleSliceInsets: sliceParams.sliceInsets,
      chatBubbleImageSize: sliceParams.imageSize,
      chatBubbleContentPadding: sliceParams.contentPadding,
      chatBubbleTextColor: _hexToColor(chatBubbleTextColorHex),
    );
  } catch (e, st) {
    debugPrint('[CosmeticsProvider] ERRO userId=$userId: $e\n$st');
    return UserCosmetics.empty(userId);
  }
});

/// Provider para buscar cosméticos de múltiplos usuários de uma vez.
///
/// Útil para pré-carregar cosméticos de todos os participantes de um chat
/// antes de renderizar a lista de mensagens, evitando flickering.
final batchCosmeticsProvider =
    FutureProvider.family<Map<String, UserCosmetics>, List<String>>(
        (ref, userIds) async {
  // Mantém o batch em memória para evitar re-fetch ao reabrir o chat.
  ref.keepAlive();
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
      bool isAvatarFrameAnimated = false;
      String? chatBubbleId;
      String? chatBubbleStyle;
      String? chatBubbleColor;
      String? chatBubbleImageUrl;
      bool isChatBubbleAnimated = false;
      var sliceParams = _extractNineSliceParams({});
      String chatBubbleTextColorHex = '';

      for (final item in items) {
        final storeItem = _asMap(item['store_items']);
        if (storeItem.isEmpty) continue;

        final type = _asString(storeItem['type']);
        final assetConfig = _asMap(storeItem['asset_config']);

        if (type == 'avatar_frame') {
          avatarFrameUrl = _firstNonEmpty([
            _asString(assetConfig['frame_url']),
            _asString(assetConfig['image_url']),
            _asString(storeItem['asset_url']),
            _asString(storeItem['preview_url']),
          ]);
          isAvatarFrameAnimated = assetConfig['is_animated'] as bool? ?? false;
        } else if (type == 'chat_bubble') {
          chatBubbleId = _asString(storeItem['id']);
          chatBubbleStyle = _firstNonEmpty([
            _asString(assetConfig['style']),
            _asString(assetConfig['bubble_style']),
          ]);
          chatBubbleColor = _firstNonEmpty([
            _asString(assetConfig['color']),
            _asString(assetConfig['bubble_color']),
          ]);
          chatBubbleImageUrl = _firstNonEmpty([
            _asString(assetConfig['image_url']),
            _asString(assetConfig['bubble_url']),
            _asString(assetConfig['bubble_image_url']),
            _asString(storeItem['asset_url']),
            _asString(storeItem['preview_url']),
          ]);
          isChatBubbleAnimated = assetConfig['is_animated'] as bool? ?? false;
          sliceParams = _extractNineSliceParams(assetConfig);
          chatBubbleTextColorHex = _asString(assetConfig['text_color']);
        }
      }

      result[userId] = UserCosmetics(
        userId: userId,
        avatarFrameUrl: avatarFrameUrl,
        isAvatarFrameAnimated: isAvatarFrameAnimated,
        chatBubbleId: chatBubbleId,
        chatBubbleStyle: chatBubbleStyle,
        chatBubbleColor: chatBubbleColor,
        chatBubbleImageUrl: chatBubbleImageUrl,
        isChatBubbleAnimated: isChatBubbleAnimated,
        chatBubbleSliceInsets: sliceParams.sliceInsets,
        chatBubbleImageSize: sliceParams.imageSize,
        chatBubbleContentPadding: sliceParams.contentPadding,
        chatBubbleTextColor: _hexToColor(chatBubbleTextColorHex),
      );
    }
  } catch (e) {
    for (final userId in userIds) {
      result[userId] = UserCosmetics.empty(userId);
    }
  }

  return result;
});

// ─── Helpers ────────────────────────────────────────────────────────────────

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

String? _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
