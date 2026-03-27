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
      final reward = await AdService.showRewardedAd();
      if (reward > 0) {
        // Creditar moedas
        final userId = SupabaseService.currentUserId;
        if (userId != null) {
          await SupabaseService.table('transactions').insert({
            'user_id': userId,
            'amount': reward,
            'type': 'ad_reward',
            'description': 'Recompensa por assistir anúncio',
          });

          await SupabaseService.table('wallets')
              .update({'balance': _balance + reward})
              .eq('user_id', userId);
        }

        setState(() {
          _balance += reward;
          _adsWatchedToday++;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+$reward moedas! 🎉'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar anúncio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganhar Moedas',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============================================================
          // SALDO ATUAL
          // ============================================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Seu Saldo',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: Colors.amber, size: 32),
                    const SizedBox(width: 8),
                    Text(
                      _balance.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ============================================================
          // ASSISTIR ANÚNCIOS
          // ============================================================
          _SectionTitle(title: 'Assistir Anúncios', isDark: isDark),
          const SizedBox(height: 8),
          _EarningCard(
            icon: Icons.play_circle_filled_rounded,
            iconColor: const Color(0xFFFF6B6B),
            title: 'Assistir Vídeo',
            subtitle: '$_adsWatchedToday/$_maxAdsPerDay assistidos hoje',
            reward: '+5 moedas',
            onTap: _adsWatchedToday < _maxAdsPerDay ? _watchAd : null,
            isLoading: _isLoadingAd,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // ============================================================
          // ATIVIDADES DIÁRIAS
          // ============================================================
          _SectionTitle(title: 'Atividades Diárias', isDark: isDark),
          const SizedBox(height: 8),
          _EarningCard(
            icon: Icons.calendar_today_rounded,
            iconColor: AppTheme.successColor,
            title: 'Check-in Diário',
            subtitle: 'Faça check-in todos os dias',
            reward: '+5-25 moedas',
            isDark: isDark,
          ),
          _EarningCard(
            icon: Icons.edit_rounded,
            iconColor: AppTheme.primaryColor,
            title: 'Criar um Post',
            subtitle: 'Publique conteúdo na comunidade',
            reward: '+3 moedas',
            isDark: isDark,
          ),
          _EarningCard(
            icon: Icons.comment_rounded,
            iconColor: AppTheme.accentColor,
            title: 'Comentar em Posts',
            subtitle: 'Participe das discussões',
            reward: '+1 moeda',
            isDark: isDark,
          ),
          _EarningCard(
            icon: Icons.quiz_rounded,
            iconColor: AppTheme.warningColor,
            title: 'Responder Quiz',
            subtitle: 'Acerte quizzes da comunidade',
            reward: '+2 moedas',
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // ============================================================
          // CONQUISTAS
          // ============================================================
          _SectionTitle(title: 'Conquistas', isDark: isDark),
          const SizedBox(height: 8),
          _EarningCard(
            icon: Icons.emoji_events_rounded,
            iconColor: Colors.amber,
            title: 'Completar Conquistas',
            subtitle: 'Desbloqueie badges e ganhe moedas',
            reward: '+10-100 moedas',
            isDark: isDark,
          ),
          _EarningCard(
            icon: Icons.person_add_rounded,
            iconColor: AppTheme.infoColor,
            title: 'Convidar Amigos',
            subtitle: 'Ganhe moedas quando amigos se cadastram',
            reward: '+50 moedas',
            isDark: isDark,
          ),
          _EarningCard(
            icon: Icons.trending_up_rounded,
            iconColor: AppTheme.primaryLight,
            title: 'Subir de Nível',
            subtitle: 'Ganhe moedas ao subir de nível',
            reward: '+20 moedas',
            isDark: isDark,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
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
  final bool isDark;

  const _EarningCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.reward,
    this.onTap,
    this.isLoading = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(
              color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
              fontSize: 12,
            )),
        trailing: onTap != null
            ? ElevatedButton(
                onPressed: isLoading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(reward,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
              )
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(reward,
                    style: const TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }
}
