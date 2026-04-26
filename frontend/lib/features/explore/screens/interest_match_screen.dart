import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/widgets/user_status_badge.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';

// ============================================================================
// InterestMatchScreen — Encontrar usuários com interesses similares
//
// Usa a RPC find_interest_matches para retornar usuários com mais interesses
// em comum com o usuário atual. Exibe cards com interesses compartilhados,
// status e botão de seguir/enviar DM.
// ============================================================================

class MatchedUser {
  final String userId;
  final String nickname;
  final String? iconUrl;
  final String? bio;
  final String? statusEmoji;
  final String? statusText;
  final List<String> commonInterests;
  final int score;
  bool isFollowing;

  MatchedUser({
    required this.userId,
    required this.nickname,
    this.iconUrl,
    this.bio,
    this.statusEmoji,
    this.statusText,
    required this.commonInterests,
    required this.score,
    required this.isFollowing,
  });

  factory MatchedUser.fromJson(Map<String, dynamic> j) => MatchedUser(
        userId: j['user_id'] as String,
        nickname: j['nickname'] as String? ?? 'Usuário',
        iconUrl: j['icon_url'] as String?,
        bio: j['bio'] as String?,
        statusEmoji: j['status_emoji'] as String?,
        statusText: j['status_text'] as String?,
        commonInterests: List<String>.from(j['common_interests'] as List? ?? []),
        score: (j['score'] as num?)?.toInt() ?? 0,
        isFollowing: j['is_following'] as bool? ?? false,
      );
}

class InterestMatchScreen extends ConsumerStatefulWidget {
  const InterestMatchScreen({super.key});

  static void show(BuildContext context) {
    context.push('/interest-match');
  }

  @override
  ConsumerState<InterestMatchScreen> createState() =>
      _InterestMatchScreenState();
}

class _InterestMatchScreenState extends ConsumerState<InterestMatchScreen>
    with SingleTickerProviderStateMixin {
  List<MatchedUser> _matches = [];
  bool _isLoading = true;
  bool _hasInterests = true;
  String? _error;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadMatches();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.rpc(
        'find_interest_matches',
        params: {'p_limit': 20},
      );
      final rows = res as List? ?? [];
      if (!mounted) return;
      if (rows.isEmpty) {
        // Verificar se o usuário tem interesses cadastrados
        final profile = await SupabaseService.table('profiles')
            .select('selected_interests')
            .eq('id', SupabaseService.currentUserId ?? '')
            .maybeSingle();
        final interests =
            (profile?['selected_interests'] as List?)?.length ?? 0;
        setState(() {
          _hasInterests = interests > 0;
          _matches = [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _matches = rows
              .map((e) => MatchedUser.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[InterestMatch] loadMatches error: $e');
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar sugestões';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(MatchedUser user) async {
    HapticService.action();
    final wasFollowing = user.isFollowing;
    setState(() => user.isFollowing = !wasFollowing);
    try {
      if (wasFollowing) {
        await SupabaseService.table('follows').delete().match({
          'follower_id': SupabaseService.currentUserId ?? '',
          'following_id': user.userId,
        });
      } else {
        await SupabaseService.table('follows').insert({
          'follower_id': SupabaseService.currentUserId ?? '',
          'following_id': user.userId,
        });
      }
    } catch (e) {
      debugPrint('[InterestMatch] toggleFollow error: $e');
      if (mounted) setState(() => user.isFollowing = wasFollowing);
    }
  }

  Future<void> _openDm(MatchedUser user) async {
    HapticService.action();
    try {
      // Criar ou abrir DM existente
      final res = await SupabaseService.rpc(
        'get_or_create_dm_thread',
        params: {'p_other_user_id': user.userId},
      );
      final threadId = res as String?;
      if (threadId != null && mounted) {
        context.push('/chat/$threadId');
      }
    } catch (e) {
      debugPrint('[InterestMatch] openDm error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao abrir conversa'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.nexusTheme;
    final r = context.r;

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.people_alt_rounded,
                color: theme.accentPrimary, size: r.s(20)),
            SizedBox(width: r.s(8)),
            Text(
              'Pessoas com interesses similares',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
            onPressed: _loadMatches,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _buildBody(theme, r),
    );
  }

  Widget _buildBody(NexusThemeData theme, Responsive r) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Círculos de radar animados
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      final progress = (_pulseCtrl.value + index / 3) % 1.0;
                      return Container(
                        width: r.s(72 + (progress * 120)),
                        height: r.s(72 + (progress * 120)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.accentPrimary.withValues(alpha: 1 - progress),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  );
                }),
                // Avatar central pulsante
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: r.s(80),
                    height: r.s(80),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [theme.accentPrimary, theme.accentSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentPrimary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(Icons.people_alt_rounded,
                        color: Colors.white, size: r.s(40)),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(48)),
            Text(
              'Sintonizando interesses...',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.s(8)),
            Text(
              'Encontrando pessoas que curtem o mesmo que você',
              style: TextStyle(
                  color: theme.textSecondary, fontSize: r.fs(13)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: theme.error, size: r.s(48)),
            SizedBox(height: r.s(12)),
            Text(_error!,
                style: TextStyle(
                    color: theme.textSecondary, fontSize: r.fs(14))),
            SizedBox(height: r.s(16)),
            ElevatedButton(
              onPressed: _loadMatches,
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary),
              child: const Text('Tentar novamente',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (!_hasInterests) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.s(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(r.s(24)),
                decoration: BoxDecoration(
                  color: theme.accentPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.interests_rounded,
                    color: theme.accentPrimary, size: r.s(56)),
              ),
              SizedBox(height: r.s(24)),
              Text(
                'Personalize seu perfil',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: r.s(12)),
              Text(
                'Adicione seus interesses para que possamos encontrar pessoas que curtem o mesmo que você!',
                style: TextStyle(
                    color: theme.textSecondary, fontSize: r.fs(14), height: 1.4),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: r.s(32)),
              ElevatedButton.icon(
                onPressed: () => context.push('/edit-profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(32), vertical: r.s(14)),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(32))),
                ),
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: Text('ADICIONAR INTERESSES',
                    style: TextStyle(
                        fontSize: r.fs(13), fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              ),
            ],
          ),
        ),
      );
    }

    if (_matches.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.s(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  color: theme.textSecondary.withValues(alpha: 0.3), size: r.s(72)),
              SizedBox(height: r.s(20)),
              Text(
                'Nenhuma sugestão encontrada',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: r.fs(18),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: r.s(8)),
              Text(
                'Que tal adicionar interesses mais específicos para expandir sua rede?',
                style: TextStyle(
                    color: theme.textSecondary, fontSize: r.fs(14), height: 1.4),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: r.s(24)),
              TextButton(
                onPressed: _loadMatches,
                child: Text('TENTAR NOVAMENTE', 
                  style: TextStyle(
                    color: theme.accentPrimary, 
                    fontWeight: FontWeight.w800,
                    fontSize: r.fs(12),
                    letterSpacing: 1.0
                  )
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: theme.accentPrimary,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(12)),
        itemCount: _matches.length,
        separatorBuilder: (_, __) => SizedBox(height: r.s(8)),
        itemBuilder: (_, i) => _buildMatchCard(_matches[i], theme, r),
      ),
    );
  }

  Widget _buildMatchCard(MatchedUser user, NexusThemeData theme, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha superior: avatar + info + botões
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () => context.push('/profile/${user.userId}'),
                child: CosmeticAvatar(
                  userId: user.userId,
                  avatarUrl: user.iconUrl,
                  size: r.s(48),
                ),
              ),
              SizedBox(width: r.s(10)),
              // Nickname + bio + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nickname,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.statusEmoji != null || user.statusText != null)
                      Padding(
                        padding: EdgeInsets.only(top: r.s(2)),
                        child: UserStatusBadge(
                          emoji: user.statusEmoji,
                          text: user.statusText,
                          compact: false,
                        ),
                      )
                    else if (user.bio != null && user.bio!.isNotEmpty)
                      Text(
                        user.bio!,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(12),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: r.s(8)),
              // Botões: seguir + DM
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: user.isFollowing
                        ? Icons.person_remove_rounded
                        : Icons.person_add_rounded,
                    label: user.isFollowing ? 'Seguindo' : 'Seguir',
                    color: user.isFollowing
                        ? theme.textSecondary
                        : theme.accentPrimary,
                    onTap: () => _toggleFollow(user),
                    r: r,
                  ),
                  SizedBox(width: r.s(6)),
                  _ActionButton(
                    icon: Icons.chat_bubble_rounded,
                    label: 'DM',
                    color: theme.accentSecondary,
                    onTap: () => _openDm(user),
                    r: r,
                  ),
                ],
              ),
            ],
          ),
          // Interesses em comum
          if (user.commonInterests.isNotEmpty) ...[
            SizedBox(height: r.s(10)),
            Row(
              children: [
                Icon(Icons.interests_rounded,
                    color: theme.accentPrimary, size: r.s(12)),
                SizedBox(width: r.s(4)),
                Text(
                  '${user.score} interesse${user.score > 1 ? 's' : ''} em comum:',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(6)),
            Wrap(
              spacing: r.s(4),
              runSpacing: r.s(4),
              children: user.commonInterests
                  .take(5)
                  .map((interest) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(8), vertical: r.s(3)),
                        decoration: BoxDecoration(
                          color: theme.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(20)),
                        ),
                        child: Text(
                          interest,
                          style: TextStyle(
                            color: theme.accentPrimary,
                            fontSize: r.fs(11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Botão de ação compacto ────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Responsive r;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(10), vertical: r.s(6)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: r.s(13)),
            SizedBox(width: r.s(4)),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: r.fs(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
