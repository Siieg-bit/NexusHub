import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/ad_service.dart';

/// Tela "Ganhar Moedas Grátis" — lista todas as formas de ganhar coins.
///
/// Inclui: assistir anúncios, check-in diário, postar, comentar,
/// convidar amigos, completar conquistas, etc.
class FreeCoinsScreen extends StatefulWidget {
  const FreeCoinsScreen({super.key});

  @override
  State<FreeCoinsScreen> createState() => _FreeCoinsScreenState();
}

class _FreeCoinsScreenState extends State<FreeCoinsScreen> {
  int _balance = 0;
  int _adsWatchedToday = 0;
  static const int _maxAdsPerDay = 10;
  bool _isLoadingAd = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final wallet = await SupabaseService.table('wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final adCount = await SupabaseService.table('transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'ad_reward')
          .gte('created_at', today);

      if (mounted) {
        setState(() {
          _balance = wallet?['balance'] as int? ?? 0;
          _adsWatchedToday = (adCount as List).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _watchAd() async {
    if (_adsWatchedToday >= _maxAdsPerDay || _isLoadingAd) return;

    setState(() => _isLoadingAd = true);

    try {
      const int rewardCoins = 5;
      final success = await AdService.showRewardedAd(rewardCoins: rewardCoins);
      if (success) {
        setState(() {
          _balance += rewardCoins;
          _adsWatchedToday++;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+$rewardCoins moedas!', style: const TextStyle(color: AppTheme.textPrimary)),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar anúncio: $e', style: const TextStyle(color: AppTheme.textPrimary)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        title: const Text(
          'Ganhar Moedas',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============================================================
          // SALDO ATUAL
          // ============================================================
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Seu Saldo',
                  style: TextStyle(
                    color: AppTheme.textPrimary.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: AppTheme.warningColor,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _balance.toString(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ============================================================
          // ASSISTIR ANÚNCIOS
          // ============================================================
          const _SectionTitle(title: 'Assistir Anúncios'),
          const SizedBox(height: 12),
          _EarningCard(
            icon: Icons.play_circle_filled_rounded,
            iconColor: AppTheme.errorColor,
            title: 'Assistir Vídeo',
            subtitle: '$_adsWatchedToday/$_maxAdsPerDay assistidos hoje',
            reward: '+5 moedas',
            onTap: _adsWatchedToday < _maxAdsPerDay ? _watchAd : null,
            isLoading: _isLoadingAd,
          ),
          const SizedBox(height: 32),

          // ============================================================
          // ATIVIDADES DIÁRIAS
          // ============================================================
          const _SectionTitle(title: 'Atividades Diárias'),
          const SizedBox(height: 12),
          const _EarningCard(
            icon: Icons.calendar_today_rounded,
            iconColor: AppTheme.primaryColor,
            title: 'Check-in Diário',
            subtitle: 'Faça check-in todos os dias',
            reward: '+5-25 moedas',
          ),
          const _EarningCard(
            icon: Icons.edit_rounded,
            iconColor: AppTheme.accentColor,
            title: 'Criar um Post',
            subtitle: 'Publique conteúdo na comunidade',
            reward: '+3 moedas',
          ),
          const _EarningCard(
            icon: Icons.comment_rounded,
            iconColor: AppTheme.primaryColor,
            title: 'Comentar em Posts',
            subtitle: 'Participe das discussões',
            reward: '+1 moeda',
          ),
          const _EarningCard(
            icon: Icons.quiz_rounded,
            iconColor: AppTheme.warningColor,
            title: 'Responder Quiz',
            subtitle: 'Acerte quizzes da comunidade',
            reward: '+2 moedas',
          ),
          const SizedBox(height: 32),

          // ============================================================
          // CONQUISTAS
          // ============================================================
          const _SectionTitle(title: 'Conquistas'),
          const SizedBox(height: 12),
          const _EarningCard(
            icon: Icons.emoji_events_rounded,
            iconColor: AppTheme.warningColor,
            title: 'Completar Conquistas',
            subtitle: 'Desbloqueie badges e ganhe moedas',
            reward: '+10-100 moedas',
          ),
          const _EarningCard(
            icon: Icons.person_add_rounded,
            iconColor: AppTheme.accentColor,
            title: 'Convidar Amigos',
            subtitle: 'Ganhe moedas quando amigos se cadastram',
            reward: '+50 moedas',
          ),
          const _EarningCard(
            icon: Icons.trending_up_rounded,
            iconColor: AppTheme.primaryColor,
            title: 'Subir de Nível',
            subtitle: 'Ganhe moedas ao subir de nível',
            reward: '+20 moedas',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _EarningCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String reward;
  final VoidCallback? onTap;
  final bool isLoading;

  const _EarningCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.reward,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
        ),
        trailing: onTap != null
            ? GestureDetector(
                onTap: isLoading ? null : onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.textPrimary,
                          ),
                        )
                      : Text(
                          reward,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  reward,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}
