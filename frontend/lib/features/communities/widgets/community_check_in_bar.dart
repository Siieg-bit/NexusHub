import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/level_up_dialog.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/helpers.dart'; // ReputationRewards
import '../providers/community_shared_providers.dart'; // checkInStatusProvider
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// CHECK-IN BAR — Design moderno com gradiente, ícone animado e streak visual
// =============================================================================

class CommunityCheckInBar extends ConsumerStatefulWidget {
  final String communityId;
  final Color themeColor;

  const CommunityCheckInBar({
    super.key,
    required this.communityId,
    required this.themeColor,
  });

  @override
  ConsumerState<CommunityCheckInBar> createState() =>
      _CommunityCheckInBarState();
}

class _CommunityCheckInBarState extends ConsumerState<CommunityCheckInBar>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _doCheckIn() async {
    if (_loading) return;
    final s = ref.read(stringsProvider);
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final result = await SupabaseService.rpc('daily_checkin', params: {
        'p_community_id': widget.communityId,
      });
      if (!mounted) return;
      if (result != null && result['success'] == true) {
        final repEarned = result['reputation_earned'] as int? ?? 0;
        final newStreak = result['streak'] as int? ?? 0;
        final levelUp = result['level_up'] as bool? ?? false;
        final newLevel = result['new_level'] as int? ?? 0;
        HapticFeedback.mediumImpact();
        if (mounted) {
          ref.invalidate(checkInStatusProvider);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              s.checkInSuccessMsg(repEarned, newStreak),
            ),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ));
          if (levelUp && newLevel > 0) {
            LevelUpDialog.show(context, newLevel: newLevel);
          }
        }
      } else {
        final error = result?['error'] ?? s.unknownError;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$error'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.anErrorOccurredTryAgain),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final checkInStatus = ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.communityId];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;

    if (hasCheckedIn) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.themeColor.withValues(alpha: 0.15),
            context.nexusTheme.accentPrimary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(r.s(16)),
      child: Column(
        children: [
          // Título com ícone
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF6B35), size: r.s(20)),
              SizedBox(width: r.s(6)),
              Text(
                s.dailyCheckIn2,
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(4)),
          Text(
            s.plusReputationLabel(ReputationRewards.checkIn),
            style: TextStyle(
              color: context.nexusTheme.textSecondary,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: r.s(12)),

          // 7-day streak visual moderno
          _buildModernStreakBar(r, streak),
          SizedBox(height: r.s(14)),

          // Botão de check-in com animação de pulso
          ScaleTransition(
            scale: _loading ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
            child: SizedBox(
              width: double.infinity,
              height: r.s(44),
              child: ElevatedButton(
                onPressed: _loading ? null : _doCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  textStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(15),
                  ),
                ),
                child: _loading
                    ? SizedBox(
                        width: r.s(20),
                        height: r.s(20),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: r.s(18)),
                          SizedBox(width: r.s(6)),
                          Text(s.doCheckIn2),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStreakBar(Responsive r, int streak) {
    const totalDays = 7;
    final completedDays = (streak % 7 == 0 && streak > 0) ? 7 : streak % 7;

    return Row(
      children: List.generate(totalDays, (i) {
        final isDone = i < completedDays;
        final isNext = i == completedDays;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < totalDays - 1 ? r.s(4) : 0),
            child: Column(
              children: [
                // Dot/ícone do dia
                Container(
                  width: r.s(28),
                  height: r.s(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? context.nexusTheme.accentPrimary
                        : isNext
                            ? context.nexusTheme.accentPrimary.withValues(alpha: 0.20)
                            : Colors.grey.withValues(alpha: 0.15),
                    border: isNext
                        ? Border.all(
                            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.50),
                            width: 1.5,
                          )
                        : null,
                    boxShadow: isDone
                        ? [
                            BoxShadow(
                              color:
                                  context.nexusTheme.accentPrimary.withValues(alpha: 0.30),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: isDone
                      ? Icon(Icons.check_rounded,
                          color: Colors.white, size: r.s(14))
                      : isNext
                          ? Icon(Icons.arrow_forward_rounded,
                              color: context.nexusTheme.accentPrimary, size: r.s(12))
                          : null,
                ),
                SizedBox(height: r.s(3)),
                // Label do dia
                Text(
                  'D${i + 1}',
                  style: TextStyle(
                    color: isDone
                        ? context.nexusTheme.accentPrimary
                        : context.nexusTheme.textSecondary.withValues(alpha: 0.50),
                    fontSize: r.fs(8),
                    fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
