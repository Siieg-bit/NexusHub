import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Tela de check-in diário com gamificação — Estilo Amino Apps.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _checkedIn = false;
  int _consecutiveDays = 0;
  int _xpEarned = 0;
  int _coinsEarned = 0;

  late AnimationController _pulseController;
  late AnimationController _celebrateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _celebrateScale;
  late Animation<double> _celebrateOpacity;

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

    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _celebrateScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _celebrateController, curve: Curves.elasticOut),
    );
    _celebrateOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _celebrateController,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );

    _loadCheckInStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckInStatus() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      setState(() {
        _consecutiveDays = user.consecutiveCheckinDays;
      });
    }
  }

  bool _luckyDrawUsed = false;
  int _luckyDrawPrize = 0;

  Future<void> _doLuckyDraw() async {
    try {
      final result = await SupabaseService.rpc('play_lucky_draw');
      if (result != null) {
        final data = result as Map<String, dynamic>;
        setState(() {
          _luckyDrawUsed = true;
          _luckyDrawPrize = data['coins_won'] as int? ?? 0;
        });
      } else {
        setState(() => _luckyDrawUsed = true);
      }
    } catch (_) {
      setState(() {
        _luckyDrawUsed = true;
        final rng = DateTime.now().millisecondsSinceEpoch % 10;
        _luckyDrawPrize = rng < 3 ? (rng + 1) * 10 : 0;
      });
    }
  }

  Future<void> _repairStreak() async {
    try {
      final result =
          await SupabaseService.rpc('repair_streak', params: {'p_cost': 50});
      if (result != null) {
        final data = result as Map<String, dynamic>;
        if (data['success'] == true) {
          setState(() {
            _consecutiveDays = data['restored_streak'] as int? ?? 1;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Streak restored! $_consecutiveDays consecutive days.'),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    data['message'] as String? ?? 'Not enough coins'),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _doCheckIn() async {
    setState(() => _isLoading = true);

    try {
      final result = await SupabaseService.rpc('daily_checkin');

      if (result != null) {
        final data = result as Map<String, dynamic>;
        if (data['success'] == true) {
          setState(() {
            _checkedIn = true;
            _consecutiveDays = data['consecutive_days'] as int? ?? 0;
            _xpEarned = data['xp_earned'] as int? ?? 0;
            _coinsEarned = data['coins_earned'] as int? ?? 0;
          });
          _pulseController.stop();
          _celebrateController.forward();
        } else {
          setState(() => _checkedIn = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    data['message'] as String? ?? 'Already checked in today!'),
                backgroundColor: AppTheme.warningColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Daily Check-in',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textPrimary)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ================================================================
            // ÍCONE PRINCIPAL — Amino style com glow
            // ================================================================
            _checkedIn
                ? ScaleTransition(
                    scale: _celebrateScale,
                    child: FadeTransition(
                      opacity: _celebrateOpacity,
                      child: _buildMainIcon(true),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: _buildMainIcon(false),
                      );
                    },
                  ),

            const SizedBox(height: 28),

            // ================================================================
            // STREAK COUNTER
            // ================================================================
            Text(
              _checkedIn ? 'Check-in Complete!' : 'Daily Check-in',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _checkedIn
                  ? 'Day $_consecutiveDays streak!'
                  : 'Check in to earn rewards',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),

            const SizedBox(height: 28),

            // ================================================================
            // DIAS DA SEMANA — Estilo Amino
            // ================================================================
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  final isCompleted = index < _consecutiveDays % 7;
                  final isToday = index == _consecutiveDays % 7;
                  return _DayCircle(
                    day: ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                    isCompleted: isCompleted,
                    isToday: isToday && !_checkedIn,
                    isTodayCompleted: isToday && _checkedIn,
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // ================================================================
            // RECOMPENSAS (após check-in)
            // ================================================================
            if (_checkedIn && _xpEarned > 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('Rewards',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RewardItem(
                          icon: Icons.star_rounded,
                          label: '+$_xpEarned XP',
                          color: AppTheme.primaryColor,
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        _RewardItem(
                          icon: Icons.monetization_on_rounded,
                          label: '+$_coinsEarned Coins',
                          color: AppTheme.warningColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ================================================================
            // BOTÃO DE CHECK-IN — Estilo Amino
            // ================================================================
            if (!_checkedIn)
              GestureDetector(
                onTap: _isLoading ? null : _doCheckIn,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF9800),
                        Color(0xFFFF5722),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_fire_department_rounded,
                                  color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text('Check In',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ================================================================
            // LUCKY DRAW — Estilo Amino
            // ================================================================
            if (_checkedIn) _buildLuckyDrawSection(),

            const SizedBox(height: 16),

            // ================================================================
            // STREAK REPAIR
            // ================================================================
            if (!_checkedIn && _consecutiveDays == 0)
              _buildStreakRepairSection(),

            const SizedBox(height: 20),

            // ================================================================
            // INFO — Estilo Amino
            // ================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How it works',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      text: 'Check in every day to maintain your streak'),
                  _InfoRow(
                      icon: Icons.trending_up_rounded,
                      text:
                          'Higher streak = more XP and coins'),
                  _InfoRow(
                      icon: Icons.star_rounded,
                      text: '7 consecutive days = special bonus!'),
                  _InfoRow(
                      icon: Icons.warning_amber_rounded,
                      text: 'Miss a day and streak resets to 1'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainIcon(bool completed) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: completed
              ? [AppTheme.primaryColor, AppTheme.accentColor]
              : [const Color(0xFFFF9800), const Color(0xFFFF5722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (completed
                    ? AppTheme.primaryColor
                    : const Color(0xFFFF9800))
                .withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        completed
            ? Icons.check_circle_rounded
            : Icons.local_fire_department_rounded,
        size: 64,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLuckyDrawSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningColor.withValues(alpha: 0.1),
            AppTheme.accentColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.warningColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.casino_rounded,
                  color: AppTheme.warningColor, size: 20),
              const SizedBox(width: 8),
              const Text('Lucky Draw',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          if (_luckyDrawUsed && _luckyDrawPrize > 0)
            Text('You won $_luckyDrawPrize extra coins!',
                style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700))
          else if (_luckyDrawUsed)
            Text('Better luck next time!',
                style: TextStyle(color: Colors.grey[500]))
          else ...[
            Text('Try your luck for extra coins!',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _doLuckyDraw,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFFFFD700).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.casino_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Spin',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreakRepairSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.errorColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.build_circle_rounded,
                  color: AppTheme.errorColor, size: 20),
              const SizedBox(width: 8),
              const Text('Streak Lost',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You lost your streak! Spend coins to recover it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _repairStreak,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Repair (50 coins)',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DAY CIRCLE — Estilo Amino
// =============================================================================

class _DayCircle extends StatelessWidget {
  final String day;
  final bool isCompleted;
  final bool isToday;
  final bool isTodayCompleted;

  const _DayCircle({
    required this.day,
    this.isCompleted = false,
    this.isToday = false,
    this.isTodayCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = isCompleted || isTodayCompleted;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: active
            ? null
            : isToday
                ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                : AppTheme.surfaceColor,
        border: isToday && !active
            ? Border.all(
                color: const Color(0xFFFF9800).withValues(alpha: 0.5),
                width: 2)
            : null,
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: Center(
        child: active
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : Text(day,
                style: TextStyle(
                    color: isToday
                        ? const Color(0xFFFF9800)
                        : Colors.grey[600],
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
      ),
    );
  }
}

// =============================================================================
// REWARD ITEM — Estilo Amino
// =============================================================================

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RewardItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ],
    );
  }
}

// =============================================================================
// INFO ROW — Estilo Amino
// =============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
