import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Tela de check-in diário com gamificação.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _checkedIn = false;
  int _consecutiveDays = 0;
  int _xpEarned = 0;
  int _coinsEarned = 0;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _loadCheckInStatus();
  }

  @override
  void dispose() {
    _animController.dispose();
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

  Widget _buildLuckyDrawSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.warningColor.withOpacity(0.15), AppTheme.accentColor.withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.casino_rounded, color: AppTheme.warningColor),
              SizedBox(width: 8),
              Text('Lucky Draw',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          if (_luckyDrawUsed && _luckyDrawPrize > 0)
            Text('Parabéns! Você ganhou $_luckyDrawPrize coins extras!',
                style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w600))
          else if (_luckyDrawUsed)
            const Text('Não foi dessa vez. Tente novamente amanhã!',
                style: TextStyle(color: AppTheme.textSecondary))
          else ...
            [
              const Text('Tente a sorte para ganhar coins extras!',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _doLuckyDraw,
                icon: const Icon(Icons.casino_rounded, color: Colors.white),
                label: const Text('Girar', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
        ],
      ),
    );
  }

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
      // Fallback: simulate locally if RPC doesn't exist yet
      setState(() {
        _luckyDrawUsed = true;
        // 30% chance of winning 5-50 coins
        final rng = DateTime.now().millisecondsSinceEpoch % 10;
        _luckyDrawPrize = rng < 3 ? (rng + 1) * 10 : 0;
      });
    }
  }

  Widget _buildStreakRepairSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.build_circle_rounded, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Streak Perdida',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Você perdeu sua streak! Gaste coins para recuperá-la.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _repairStreak,
            icon: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 18),
            label: const Text('Reparar (50 coins)', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _repairStreak() async {
    try {
      final result = await SupabaseService.rpc('repair_streak',
          params: {'p_cost': 50});
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
                      'Streak restaurada! $_consecutiveDays dias consecutivos.')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(data['message'] as String? ?? 'Coins insuficientes')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
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
          _animController.forward();
        } else {
          setState(() {
            _checkedIn = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] as String? ?? 'Já fez check-in hoje!')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in Diário')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ================================================================
            // ÍCONE PRINCIPAL
            // ================================================================
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _checkedIn
                        ? [AppTheme.successColor, AppTheme.accentColor]
                        : [AppTheme.warningColor, AppTheme.primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_checkedIn ? AppTheme.successColor : AppTheme.warningColor)
                          .withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _checkedIn ? Icons.check_circle_rounded : Icons.calendar_today_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ================================================================
            // STREAK
            // ================================================================
            Text(
              _checkedIn ? 'Check-in Realizado!' : 'Check-in Diário',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _checkedIn
                  ? 'Dia $_consecutiveDays consecutivo!'
                  : 'Faça check-in para ganhar recompensas',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),

            const SizedBox(height: 32),

            // ================================================================
            // DIAS DA SEMANA
            // ================================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final isCompleted = index < _consecutiveDays % 7;
                final isToday = index == _consecutiveDays % 7;
                return _DayCircle(
                  day: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'][index],
                  isCompleted: isCompleted,
                  isToday: isToday && !_checkedIn,
                  isTodayCompleted: isToday && _checkedIn,
                );
              }),
            ),

            const SizedBox(height: 32),

            // ================================================================
            // RECOMPENSAS (após check-in)
            // ================================================================
            if (_checkedIn && _xpEarned > 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text('Recompensas',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RewardItem(
                          icon: Icons.star_rounded,
                          label: '+$_xpEarned XP',
                          color: AppTheme.primaryColor,
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
              const SizedBox(height: 24),
            ],

            // ================================================================
            // BOTÃO DE CHECK-IN
            // ================================================================
            if (!_checkedIn)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _doCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Fazer Check-in',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

            const SizedBox(height: 16),

            // ================================================================
            // LUCKY DRAW (após check-in, chance de prêmio extra)
            // ================================================================
            if (_checkedIn)
              _buildLuckyDrawSection(),

            const SizedBox(height: 16),

            // ================================================================
            // STREAK REPAIR (se perdeu a streak)
            // ================================================================
            if (!_checkedIn && _consecutiveDays == 0)
              _buildStreakRepairSection(),

            const SizedBox(height: 24),

            // ================================================================
            // INFO DE STREAK
            // ================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Como funciona',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.calendar_today_rounded,
                      text: 'Faça check-in todos os dias para manter sua streak'),
                  _InfoRow(icon: Icons.trending_up_rounded,
                      text: 'Quanto maior a streak, mais XP e coins você ganha'),
                  _InfoRow(icon: Icons.star_rounded,
                      text: '7 dias seguidos = bônus especial!'),
                  _InfoRow(icon: Icons.warning_rounded,
                      text: 'Se perder um dia, a streak volta para 1'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    Color bgColor;
    Color textColor;
    if (isTodayCompleted) {
      bgColor = AppTheme.successColor;
      textColor = Colors.white;
    } else if (isCompleted) {
      bgColor = AppTheme.primaryColor;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = AppTheme.warningColor.withOpacity(0.3);
      textColor = AppTheme.warningColor;
    } else {
      bgColor = AppTheme.cardColorLight;
      textColor = AppTheme.textHint;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted || isTodayCompleted
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : Text(day, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RewardItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
