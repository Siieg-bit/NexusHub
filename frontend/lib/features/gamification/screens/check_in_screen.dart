import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/haptic_service.dart';

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
  int _bestStreak = 0;
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
    // Sempre busca o valor mais recente do banco para evitar exibir streak
    // desatualizado quando o usuário volta à tela após um check-in anterior.
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final row = await SupabaseService.table('profiles')
          .select('consecutive_checkin_days, last_checkin_at, best_streak_days')
          .eq('id', userId)
          .single();
      final streak = (row['consecutive_checkin_days'] as num?)?.toInt() ?? 0;
      final best = (row['best_streak_days'] as num?)?.toInt() ?? streak;
      final lastCheckin = row['last_checkin_at'] as String?;
      DateTime serverNow;
      try {
        final serverTimeResult = await SupabaseService.rpc('get_server_time');
        if (serverTimeResult is String) {
          serverNow = DateTime.parse(serverTimeResult).toUtc();
        } else if (serverTimeResult is Map && serverTimeResult['now'] is String) {
          serverNow = DateTime.parse(serverTimeResult['now'] as String).toUtc();
        } else {
          serverNow = DateTime.now().toUtc();
        }
      } catch (_) {
        serverNow = DateTime.now().toUtc();
      }
      final parsedLastCheckin =
          lastCheckin != null ? DateTime.tryParse(lastCheckin)?.toUtc() : null;
      final alreadyCheckedIn = parsedLastCheckin != null &&
          parsedLastCheckin.year == serverNow.year &&
          parsedLastCheckin.month == serverNow.month &&
          parsedLastCheckin.day == serverNow.day;
      if (!mounted) return;
      setState(() {
        _consecutiveDays = streak;
        _bestStreak = best;
        _checkedIn = alreadyCheckedIn;
      });
      if (alreadyCheckedIn) {
        _pulseController.stop();
      }
    } catch (_) {
      // Fallback para o cache em memória se o banco falhar
      final user = ref.read(currentUserProvider);
      if (user != null && mounted) {
        setState(() => _consecutiveDays = user.consecutiveCheckinDays);
      }
    }
  }

  bool _luckyDrawUsed = false;
  int _luckyDrawPrize = 0;

  Future<void> _doLuckyDraw() async {
    try {
      final result = await SupabaseService.rpc('play_lucky_draw');
      if (result != null) {
        final data = result as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _luckyDrawUsed = true;
          _luckyDrawPrize = data['coins_won'] as int? ?? 0;
        });
      } else {
        if (!mounted) return;
        setState(() => _luckyDrawUsed = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _luckyDrawUsed = true;
        final rng = DateTime.now().millisecondsSinceEpoch % 10;
        _luckyDrawPrize = rng < 3 ? (rng + 1) * 10 : 0;
      });
    }
  }

  Future<void> _repairStreak() async {
    final s = getStrings();
    final r = context.r;
    try {
      final result =
          await SupabaseService.rpc('repair_streak', params: {});
      if (result != null) {
        final data = result as Map<String, dynamic>;
        if (data['success'] == true) {
          final restoredDays = data['days_repaired'] as int? ?? 1;
          if (!mounted) return;
          setState(() {
            _consecutiveDays += restoredDays;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.read(stringsProvider).streakRestoredMsg(_consecutiveDays),
              ),
              backgroundColor: context.nexusTheme.accentPrimary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
              ),
            ),
          );
        } else {
          final errorCode = data['error'] as String?;
          final fallbackMessage = errorCode == 'insufficient_coins'
              ? ref.read(stringsProvider).insufficientCoins
              : errorCode == 'no_broken_streak'
                  ? ref.read(stringsProvider).alreadyCheckedInToday
                  : ref.read(stringsProvider).anErrorOccurredTryAgain;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(fallbackMessage),
                backgroundColor: context.nexusTheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(10))),
          ),
        );
      }
    }
  }

  Future<void> _doCheckIn() async {
    HapticService.success();
    final r = context.r;
    final s = ref.read(stringsProvider);
    setState(() => _isLoading = true);

    try {
      final result = await SupabaseService.rpc('daily_checkin');

      if (result != null) {
        final data = result as Map<String, dynamic>;
        if (data['success'] == true) {
          if (!mounted) return;
          final newStreak = data['streak'] as int? ?? 0;
          setState(() {
            _checkedIn = true;
            _consecutiveDays = newStreak;
            if (newStreak > _bestStreak) _bestStreak = newStreak;
            _xpEarned = (data['xp_earned'] as int?) ??
                (data['reputation_earned'] as int?) ??
                0;
            _coinsEarned = data['coins_earned'] as int? ?? 0;
          });
          _pulseController.stop();
          _celebrateController.forward();
          // Atualiza o cache global do usuário para que outros widgets
          // (ex: badges de streak) reflitam o novo valor imediatamente.
          ref.read(authProvider.notifier).refreshProfile();
        } else {
          final errorCode = data['error'] as String?;
          final alreadyCheckedIn = errorCode == 'already_checked_in';
          if (!mounted) return;
          setState(() => _checkedIn = alreadyCheckedIn);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                alreadyCheckedIn
                    ? s.alreadyCheckedInToday
                    : s.anErrorOccurredTryAgain,
              ),
              backgroundColor: alreadyCheckedIn
                  ? context.nexusTheme.warning
                  : context.nexusTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(10))),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: context.nexusTheme.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        title: Text(s.dailyCheckIn2,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: r.fs(18),
                color: context.nexusTheme.textPrimary)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(24)),
        child: Column(
          children: [
            SizedBox(height: r.s(12)),

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

            SizedBox(height: r.s(28)),

            // ================================================================
            // STREAK COUNTER
            // ================================================================
            Text(
              _checkedIn ? s.checkInComplete : s.dailyCheckIn2,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: r.fs(24),
                  color: context.nexusTheme.textPrimary),
            ),
            SizedBox(height: r.s(8)),
            Text(
              _checkedIn
                  ? s.dayOfStreak(_consecutiveDays)
                  : s.checkInForRewards,
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(14)),
            ),

            SizedBox(height: r.s(16)),

            // ================================================================
            // STREAK BANNER — Contador destacado estilo Kyodo
            // ================================================================
            Container(
              padding: EdgeInsets.symmetric(vertical: r.s(14), horizontal: r.s(20)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF9800).withValues(alpha: 0.15),
                    const Color(0xFFFF5722).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(r.s(16)),
                border: Border.all(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Streak atual
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded,
                              color: const Color(0xFFFF9800), size: r.s(28)),
                          SizedBox(width: r.s(4)),
                          Text(
                            '$_consecutiveDays',
                            style: TextStyle(
                              fontSize: r.fs(32),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Streak atual',
                        style: TextStyle(
                          fontSize: r.fs(11),
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Divisor
                  Container(
                    width: 1,
                    height: r.s(48),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  // Melhor streak
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded,
                              color: const Color(0xFFFFD700), size: r.s(22)),
                          SizedBox(width: r.s(4)),
                          Text(
                            '$_bestStreak',
                            style: TextStyle(
                              fontSize: r.fs(28),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFFD700),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Melhor streak',
                        style: TextStyle(
                          fontSize: r.fs(11),
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: r.s(20)),

            // ================================================================
            // DIAS DA SEMANA — Estilo Amino
            // ================================================================
            Container(
              padding:
                  EdgeInsets.symmetric(vertical: r.s(16), horizontal: r.s(12)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(16)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  // Quantos dias do ciclo atual (0-7) já foram completados.
                  // Ex: streak=7 → cicloAtual=7 (semana cheia completa)
                  //     streak=8 → cicloAtual=1 (começou novo ciclo)
                  final cicloAtual = _consecutiveDays % 7 == 0 && _consecutiveDays > 0
                      ? 7  // Semana exatamente completa: todos os 7 marcados
                      : _consecutiveDays % 7;
                  // index < cicloAtual: dias já concluídos neste ciclo
                  final isCompleted = _checkedIn
                      ? index < cicloAtual  // após check-in: inclui o dia de hoje
                      : index < cicloAtual; // antes do check-in: dias anteriores
                  // index == cicloAtual: o dia de hoje (ainda não concluído)
                  final isToday = !_checkedIn && index == cicloAtual && cicloAtual < 7;
                  final isTodayCompleted = _checkedIn && index == cicloAtual - 1 && cicloAtual > 0;
                  return _DayCircle(
                    day: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'][index],
                    isCompleted: isCompleted,
                    isToday: isToday,
                    isTodayCompleted: isTodayCompleted,
                  );
                }),
              ),
            ),

            SizedBox(height: r.s(24)),

            // ================================================================
            // RECOMPENSAS (após check-in)
            // ================================================================
            if (_checkedIn && _xpEarned > 0) ...[
              Container(
                padding: EdgeInsets.all(r.s(20)),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(r.s(16)),
                  border: Border.all(
                      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(s.rewards,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(16),
                            color: context.nexusTheme.textPrimary)),
                    SizedBox(height: r.s(16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RewardItem(
                          icon: Icons.star_rounded,
                          label: s.xpEarnedLabel(_xpEarned),
                          color: context.nexusTheme.accentPrimary,
                        ),
                        Container(
                          width: 1,
                          height: r.s(36),
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        _RewardItem(
                          icon: Icons.monetization_on_rounded,
                          label: s.coinsEarnedLabel(_coinsEarned),
                          color: context.nexusTheme.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.s(20)),
            ],

            // ================================================================
            // BOTÃO DE CHECK-IN — Estilo Amino
            // ================================================================
            if (!_checkedIn)
              GestureDetector(
                onTap: _isLoading ? null : _doCheckIn,
                child: Container(
                  width: double.infinity,
                  height: r.s(56),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF9800),
                        Color(0xFFFF5722),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(r.s(16)),
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
                        ? SizedBox(
                            width: r.s(24),
                            height: r.s(24),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_fire_department_rounded,
                                  color: Colors.white, size: r.s(22)),
                              SizedBox(width: r.s(8)),
                              Text(s.doCheckIn2,
                                  style: TextStyle(
                                      fontSize: r.fs(17),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                  ),
                ),
              ),

            SizedBox(height: r.s(16)),

            // ================================================================
            // LUCKY DRAW — Estilo Amino
            // ================================================================
            if (_checkedIn) _buildLuckyDrawSection(),

            SizedBox(height: r.s(16)),

            // ================================================================
            // STREAK REPAIR
            // ================================================================
            if (!_checkedIn && _consecutiveDays == 0)
              _buildStreakRepairSection(),

            SizedBox(height: r.s(20)),

            // ================================================================
            // INFO — Estilo Amino
            // ================================================================
            Container(
              padding: EdgeInsets.all(r.s(16)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(16)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.howItWorks,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.nexusTheme.textPrimary)),
                  SizedBox(height: r.s(10)),
                  _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      text:
                          s.checkInKeepStreak),
                  _InfoRow(
                      icon: Icons.trending_up_rounded,
                      text: s.higherStreakDesc),
                  _InfoRow(
                      icon: Icons.star_rounded,
                      text: s.consecutiveDaysBonus),
                  _InfoRow(
                      icon: Icons.warning_amber_rounded,
                      text: s.streakResetsDesc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainIcon(bool completed) {
    final r = context.r;
    return Container(
      width: r.s(140),
      height: r.s(140),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: completed
              ? [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary]
              : [const Color(0xFFFF9800), const Color(0xFFFF5722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (completed ? context.nexusTheme.accentPrimary : context.nexusTheme.streakGradient.colors.first)
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
        size: r.s(64),
        color: Colors.white,
      ),
    );
  }

  Widget _buildLuckyDrawSection() {
    final s = getStrings();
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.nexusTheme.warning.withValues(alpha: 0.1),
            context.nexusTheme.accentSecondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: context.nexusTheme.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.casino_rounded,
                  color: context.nexusTheme.warning, size: r.s(20)),
              SizedBox(width: r.s(8)),
              Text(s.luckyDraw,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(16),
                      color: context.nexusTheme.textPrimary)),
            ],
          ),
          SizedBox(height: r.s(10)),
          if (_luckyDrawUsed && _luckyDrawPrize > 0)
            Text(s.wonExtraCoins(_luckyDrawPrize),
                style: TextStyle(
                    color: context.nexusTheme.accentPrimary, fontWeight: FontWeight.w700))
          else if (_luckyDrawUsed)
            Text(s.betterLuckNextTime,
                style: TextStyle(color: Colors.grey[500]))
          else ...[
            Text(s.tryLuckExtraCoins,
                style: TextStyle(color: Colors.grey[500], fontSize: r.fs(13))),
            SizedBox(height: r.s(12)),
            GestureDetector(
              onTap: _doLuckyDraw,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(24), vertical: r.s(10)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(r.s(12)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.casino_rounded,
                        color: Colors.white, size: r.s(18)),
                    SizedBox(width: r.s(6)),
                    Text(s.rotate,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: r.fs(14))),
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
    final s = getStrings();
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.nexusTheme.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: context.nexusTheme.error.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.build_circle_rounded,
                  color: context.nexusTheme.error, size: r.s(20)),
              SizedBox(width: r.s(8)),
              Text(s.streakLost,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(16),
                      color: context.nexusTheme.textPrimary)),
            ],
          ),
          SizedBox(height: r.s(8)),
          Text(
            s.streakLostRecoverMsg,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: r.fs(13)),
          ),
          SizedBox(height: r.s(12)),
          GestureDetector(
            onTap: _repairStreak,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: context.nexusTheme.error,
                borderRadius: BorderRadius.circular(r.s(12)),
                boxShadow: [
                  BoxShadow(
                    color: context.nexusTheme.error.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on_rounded,
                      color: Colors.white, size: r.s(16)),
                  SizedBox(width: r.s(6)),
                  Text(s.repairCoins,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(13))),
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

class _DayCircle extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final bool active = isCompleted || isTodayCompleted;

    return Container(
      width: r.s(40),
      height: r.s(40),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? LinearGradient(
                colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: active
            ? null
            : isToday
                ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                : context.surfaceColor,
        border: isToday && !active
            ? Border.all(
                color: const Color(0xFFFF9800).withValues(alpha: 0.5), width: 2)
            : null,
        boxShadow: active
            ? [
                BoxShadow(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: Center(
        child: active
            ? Icon(Icons.check_rounded, color: Colors.white, size: r.s(18))
            : Text(day,
                style: TextStyle(
                    color: isToday ? const Color(0xFFFF9800) : Colors.grey[600],
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(12))),
      ),
    );
  }
}

// =============================================================================
// REWARD ITEM — Estilo Amino
// =================================================================
class _RewardItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RewardItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Column(
      children: [
        Container(
          width: r.s(48),
          height: r.s(48),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: r.s(24)),
        ),
        SizedBox(height: r.s(6)),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: r.fs(13))),
      ],
    );
  }
}

// =============================================================================
// INFO ROW — Estilo Amino
// ===================================================
class _InfoRow extends ConsumerWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.s(5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: r.s(14), color: Colors.grey[600]),
          SizedBox(width: r.s(8)),
          Expanded(
            child: Text(text,
                style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
          ),
        ],
      ),
    );
  }
}
