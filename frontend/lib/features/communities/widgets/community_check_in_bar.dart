import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/level_up_dialog.dart';
import '../../../core/utils/responsive.dart'; // checkInStatusProvider
import '../../communities/screens/community_list_screen.dart'; // ReputationRewards, checkInStatusProvider

// =============================================================================
// CHECK-IN BAR — Estilo Amino (streak progress + botão verde)
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

class _CommunityCheckInBarState extends ConsumerState<CommunityCheckInBar> {
  bool _loading = false;

  Future<void> _doCheckIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final result = await SupabaseService.rpc('perform_checkin', params: {
        'p_user_id': userId,
        'p_community_id': widget.communityId,
      });
      if (!mounted) return;
      if (result != null && result['success'] == true) {
        final repEarned = result['reputation_earned'] as int? ?? 0;
        final newStreak = result['streak'] as int? ?? 0;
        final levelUp = result['level_up'] as bool? ?? false;
        final newLevel = result['new_level'] as int? ?? 0;
        if (mounted) {
          ref.invalidate(checkInStatusProvider);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Check-in! +$repEarned rep | Streak: $newStreak dias',
            ),
            backgroundColor: AppTheme.primaryColor,
          ));
          if (levelUp && newLevel > 0) {
            LevelUpDialog.show(context, newLevel: newLevel);
          }
        }
      } else {
        final error = result?['error'] ?? 'Erro desconhecido';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$error'),
            backgroundColor: AppTheme.errorColor,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ocorreu um erro. Tente novamente.'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final checkInStatus = ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.communityId];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;

    if (hasCheckedIn) return const SizedBox.shrink();

    return Container(
      color: context.cardBg,
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
      child: Column(
        children: [
          Text(
            'Faça Check In para ganhar +${ReputationRewards.checkIn} rep',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(13),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(8)),
          // 7-day streak bar
          Row(
            children: List.generate(7, (i) {
              final filled = i < (streak % 7);
              return Expanded(
                child: Container(
                  height: r.s(6),
                  margin: EdgeInsets.only(right: i < 6 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: filled
                        ? AppTheme.primaryColor
                        : context.dividerClr,
                    borderRadius: BorderRadius.circular(r.s(3)),
                  ),
                  child: filled
                      ? null
                      : Center(
                          child: Container(
                            width: r.s(8),
                            height: r.s(8),
                            decoration: BoxDecoration(
                              color: context.dividerClr,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: (Colors.grey[700] ?? Colors.grey),
                                  width: 1),
                            ),
                          ),
                        ),
                ),
              );
            }),
          ),
          SizedBox(height: r.s(10)),
          SizedBox(
            width: double.infinity,
            height: r.s(40),
            child: ElevatedButton(
              onPressed: _loading ? null : _doCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10))),
                textStyle: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: r.fs(14)),
              ),
              child: _loading
                  ? SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Check In'),
            ),
          ),
        ],
      ),
    );
  }
}
