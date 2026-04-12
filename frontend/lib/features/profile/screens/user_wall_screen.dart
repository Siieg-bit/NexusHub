import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../providers/profile_providers.dart';
import '../widgets/wall_comment_sheet.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Mural do Usuário (The Wall) — Mensagens públicas no perfil, estilo Amino.
/// Refatorado para usar WallCommentSheet (corrige bugs de carregamento e envio).
class UserWallScreen extends ConsumerWidget {
  final String userId;
  const UserWallScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final s = ref.watch(stringsProvider);
    final isOwnWall = userId == SupabaseService.currentUserId;
    final profileAsync = ref.watch(userProfileProvider(userId));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: profileAsync.when(
          data: (profile) => Row(
            children: [
              CosmeticAvatar(
                userId: userId,
                avatarUrl: profile.iconUrl,
                size: r.s(32),
              ),
              SizedBox(width: r.s(10)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.nickname,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Mural',
                    style: TextStyle(color: Colors.grey[500], fontSize: r.fs(11)),
                  ),
                ],
              ),
            ],
          ),
          loading: () => Text(
            isOwnWall ? 'Meu Mural' : s.wall,
            style: TextStyle(color: Colors.white, fontSize: r.fs(16)),
          ),
          error: (_, __) => Text(
            isOwnWall ? 'Meu Mural' : s.wall,
            style: TextStyle(color: Colors.white, fontSize: r.fs(16)),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.grey[400], size: r.s(20)),
            onPressed: () => ref.invalidate(wallCommentsProvider(userId)),
          ),
        ],
      ),
      body: WallCommentSheet(
        wallUserId: userId,
        isOwnWall: isOwnWall,
        asBottomSheet: false,
      ),
    );
  }
}
