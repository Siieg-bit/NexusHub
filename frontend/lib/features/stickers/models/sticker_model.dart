/// Modelo de um sticker individual.
class StickerModel {
  final String id;
  final String packId;
  final String name;
  final String imageUrl;
  final String? thumbnailUrl;
  final List<String> tags;
  final bool isAnimated;
  final int usesCount;
  final int savesCount;
  final int sortOrder;
  final String? creatorId;

  const StickerModel({
    required this.id,
    required this.packId,
    this.name = '',
    required this.imageUrl,
    this.thumbnailUrl,
    this.tags = const [],
    this.isAnimated = false,
    this.usesCount = 0,
    this.savesCount = 0,
    this.sortOrder = 0,
    this.creatorId,
  });

  factory StickerModel.fromJson(Map<String, dynamic> json) {
    return StickerModel(
      id: json['id'] as String? ?? json['sticker_id'] as String? ?? '',
      packId: json['pack_id'] as String? ?? '',
      name: json['name'] as String? ?? json['sticker_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? json['sticker_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isAnimated: json['is_animated'] as bool? ?? false,
      usesCount: json['uses_count'] as int? ?? 0,
      savesCount: json['saves_count'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      creatorId: json['creator_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pack_id': packId,
    'name': name,
    'image_url': imageUrl,
    'thumbnail_url': thumbnailUrl,
    'tags': tags,
    'is_animated': isAnimated,
    'uses_count': usesCount,
    'saves_count': savesCount,
    'sort_order': sortOrder,
  };

  /// Retorna o mapa para envio como mensagem/comentário.
  Map<String, dynamic> toSendPayload() => {
    'sticker_id': id,
    'sticker_url': imageUrl,
    'sticker_name': name,
    'pack_id': packId,
  };

  StickerModel copyWith({
    String? name,
    String? imageUrl,
    int? sortOrder,
    bool? isAnimated,
    List<String>? tags,
  }) {
    return StickerModel(
      id: id,
      packId: packId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl,
      tags: tags ?? this.tags,
      isAnimated: isAnimated ?? this.isAnimated,
      usesCount: usesCount,
      savesCount: savesCount,
      sortOrder: sortOrder ?? this.sortOrder,
      creatorId: creatorId,
    );
  }
}

/// Modelo de um pack de stickers.
class StickerPackModel {
  final String id;
  final String name;
  final String description;
  final String? coverUrl;
  final List<String> tags;
  final int stickerCount;
  final int savesCount;
  final bool isPublic;
  final bool isUserCreated;
  final bool isFree;
  final String? creatorId;
  final String authorName;
  final String? creatorIcon;
  final bool isOwner;
  final bool isSaved;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<StickerModel> stickers;

  const StickerPackModel({
    required this.id,
    required this.name,
    this.description = '',
    this.coverUrl,
    this.tags = const [],
    this.stickerCount = 0,
    this.savesCount = 0,
    this.isPublic = true,
    this.isUserCreated = false,
    this.isFree = true,
    this.creatorId,
    this.authorName = '',
    this.creatorIcon,
    this.isOwner = false,
    this.isSaved = false,
    required this.createdAt,
    this.updatedAt,
    this.stickers = const [],
  });

  factory StickerPackModel.fromJson(Map<String, dynamic> json) {
    return StickerPackModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverUrl: json['cover_url'] as String? ?? json['icon_url'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      stickerCount: json['sticker_count'] as int? ?? 0,
      savesCount: json['saves_count'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      isUserCreated: json['is_user_created'] as bool? ?? false,
      isFree: json['is_free'] as bool? ?? true,
      creatorId: json['creator_id'] as String?,
      authorName: json['author_name'] as String? ?? '',
      creatorIcon: json['creator_icon'] as String?,
      isOwner: json['is_owner'] as bool? ?? false,
      isSaved: json['is_saved'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      stickers: (json['stickers'] as List<dynamic>?)
          ?.map((e) => StickerModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  StickerPackModel copyWith({
    String? name,
    String? description,
    String? coverUrl,
    List<String>? tags,
    bool? isPublic,
    int? stickerCount,
    List<StickerModel>? stickers,
    bool? isSaved,
    int? savesCount,
  }) {
    return StickerPackModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      tags: tags ?? this.tags,
      stickerCount: stickerCount ?? this.stickerCount,
      savesCount: savesCount ?? this.savesCount,
      isPublic: isPublic ?? this.isPublic,
      isUserCreated: isUserCreated,
      isFree: isFree,
      creatorId: creatorId,
      authorName: authorName,
      creatorIcon: creatorIcon,
      isOwner: isOwner,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt,
      updatedAt: updatedAt,
      stickers: stickers ?? this.stickers,
    );
  }
}

/// Estado do sistema de stickers para o picker.
class StickerPickerState {
  final List<StickerPackModel> myPacks;
  final List<StickerPackModel> savedPacks;
  final List<StickerPackModel> storePacks;
  final List<StickerModel> favorites;
  final List<StickerModel> recents;
  final bool isLoading;
  final String? error;

  const StickerPickerState({
    this.myPacks = const [],
    this.savedPacks = const [],
    this.storePacks = const [],
    this.favorites = const [],
    this.recents = const [],
    this.isLoading = false,
    this.error,
  });

  /// Verifica se um sticker está nos favoritos.
  bool isFavorite(String stickerId) =>
      favorites.any((s) => s.id == stickerId);

  /// Verifica se um pack está salvo.
  bool isPackSaved(String packId) =>
      savedPacks.any((p) => p.id == packId);

  StickerPickerState copyWith({
    List<StickerPackModel>? myPacks,
    List<StickerPackModel>? savedPacks,
    List<StickerPackModel>? storePacks,
    List<StickerModel>? favorites,
    List<StickerModel>? recents,
    bool? isLoading,
    String? error,
  }) {
    return StickerPickerState(
      myPacks: myPacks ?? this.myPacks,
      savedPacks: savedPacks ?? this.savedPacks,
      storePacks: storePacks ?? this.storePacks,
      favorites: favorites ?? this.favorites,
      recents: recents ?? this.recents,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
