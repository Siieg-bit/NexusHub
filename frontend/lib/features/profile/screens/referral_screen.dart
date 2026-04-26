import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final referralCodeProvider = FutureProvider<String>((ref) async {
  final result =
      await SupabaseService.rpc('get_or_create_referral_code', params: {});
  return result as String? ?? '';
});

final referralStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final result = await SupabaseService.rpc('get_referral_stats', params: {});
  if (result == null) return {};
  return result as Map<String, dynamic>;
});

// ── Screen ────────────────────────────────────────────────────────────────────
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  static const _baseUrl = 'https://nexushub.app/join?ref=';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final codeAsync = ref.watch(referralCodeProvider);
    final statsAsync = ref.watch(referralStatsProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Programa de Convites',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero ──────────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(r.s(24)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.nexusTheme.accentPrimary.withValues(alpha: 0.9),
                    context.nexusTheme.accentSecondary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Column(
                children: [
                  Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: r.s(48)),
                  SizedBox(height: r.s(12)),
                  Text(
                    'Convide amigos e ganhe coins!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(20),
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: r.s(8)),
                  Text(
                    'Você ganha 50 coins por cada amigo que se cadastrar.\nSeu amigo também ganha 25 coins de boas-vindas!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: r.fs(13),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(24)),

            // ── Código de convite ─────────────────────────────────────────────
            Text(
              'Seu link de convite',
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.s(10)),
            codeAsync.when(
              loading: () => Container(
                height: r.s(56),
                decoration: BoxDecoration(
                  color: context.nexusTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(r.s(12)),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (code) {
                final link = '$_baseUrl$code';
                return Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(14)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.backgroundSecondary,
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border: Border.all(
                      color: context.nexusTheme.accentPrimary
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          link,
                          style: TextStyle(
                            color: context.nexusTheme.accentPrimary,
                            fontSize: r.fs(13),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: r.s(8)),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: link));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Link copiado!')),
                          );
                        },
                        child: Icon(Icons.copy_rounded,
                            color: context.nexusTheme.accentPrimary,
                            size: r.s(20)),
                      ),
                      SizedBox(width: r.s(12)),
                      GestureDetector(
                        onTap: () => Share.share(
                          'Vem pro NexusHub! Use meu link de convite e ganhe 25 coins: $link',
                          subject: 'Convite para o NexusHub',
                        ),
                        child: Icon(Icons.share_rounded,
                            color: context.nexusTheme.accentSecondary,
                            size: r.s(20)),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: r.s(24)),

            // ── Estatísticas ──────────────────────────────────────────────────
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) {
                final totalInvites = stats['total_invites'] as int? ?? 0;
                final completedInvites =
                    stats['completed_invites'] as int? ?? 0;
                final totalCoins = stats['total_coins_earned'] as int? ?? 0;
                final referredUsers =
                    (stats['referred_users'] as List?)?.cast<Map>() ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats cards
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.send_rounded,
                          label: 'Convites\nEnviados',
                          value: '$totalInvites',
                          color: context.nexusTheme.accentPrimary,
                        ),
                        SizedBox(width: r.s(12)),
                        _StatCard(
                          icon: Icons.check_circle_rounded,
                          label: 'Cadastros\nRealizados',
                          value: '$completedInvites',
                          color: const Color(0xFF22C55E),
                        ),
                        SizedBox(width: r.s(12)),
                        _StatCard(
                          icon: Icons.monetization_on_rounded,
                          label: 'Coins\nGanhos',
                          value: '$totalCoins',
                          color: const Color(0xFFFFD700),
                        ),
                      ],
                    ),

                    if (referredUsers.isNotEmpty) ...[
                      SizedBox(height: r.s(24)),
                      Text(
                        'Amigos convidados',
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(15),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: r.s(10)),
                      ...referredUsers.map((u) {
                        final nickname = u['nickname'] as String? ?? 'Usuário';
                        final iconUrl = u['icon_url'] as String?;
                        return Container(
                          margin: EdgeInsets.only(bottom: r.s(8)),
                          padding: EdgeInsets.all(r.s(12)),
                          decoration: BoxDecoration(
                            color: context.nexusTheme.backgroundSecondary,
                            borderRadius: BorderRadius.circular(r.s(12)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: r.s(20),
                                backgroundImage: iconUrl != null
                                    ? CachedNetworkImageProvider(iconUrl)
                                    : null,
                                backgroundColor: context
                                    .nexusTheme.accentPrimary
                                    .withValues(alpha: 0.2),
                                child: iconUrl == null
                                    ? Icon(Icons.person_rounded,
                                        color:
                                            context.nexusTheme.accentPrimary,
                                        size: r.s(20))
                                    : null,
                              ),
                              SizedBox(width: r.s(12)),
                              Expanded(
                                child: Text(
                                  nickname,
                                  style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
                                    fontSize: r.fs(14),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(8), vertical: r.s(4)),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E)
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(r.s(8)),
                                ),
                                child: Text(
                                  '+50 coins',
                                  style: TextStyle(
                                    color: const Color(0xFF22C55E),
                                    fontSize: r.fs(12),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(r.s(14)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: r.s(24)),
            SizedBox(height: r.s(6)),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: r.fs(22),
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: r.s(2)),
            Text(
              label,
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(10),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
