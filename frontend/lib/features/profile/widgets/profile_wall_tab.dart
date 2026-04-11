import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import 'wall_comment_sheet.dart';

// =============================================================================
// WALL TAB — Mural de mensagens com stickers, imagens, likes e replies
// Refatorado para usar WallCommentSheet (corrige bugs de carregamento e envio)
// =============================================================================

class ProfileWallTab extends ConsumerWidget {
  final String userId;

  /// wallController mantido por compatibilidade com chamadas existentes.
  final TextEditingController? wallController;

  const ProfileWallTab({
    super.key,
    required this.userId,
    this.wallController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwnWall = userId == SupabaseService.currentUserId;
    return WallCommentSheet(
      wallUserId: userId,
      isOwnWall: isOwnWall,
      asBottomSheet: false,
    );
  }
}
