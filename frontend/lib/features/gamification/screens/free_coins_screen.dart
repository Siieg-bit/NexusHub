import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/ad_service.dart';

/// Tela "Ganhar Moedas Grátis" — Estilo Amino original.
/// Header azul celeste com saldo, corpo claro com cards de atividades.
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

  String _formatCoins(int coins) {
    if (coins >= 1000000) return '${(coins / 1000000).toStringAsFixed(1)}M';
    final str = coins.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
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
              content: Text('+$rewardCoins moedas!',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar anúncio: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFFE53935),
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // =============================================================
          // HEADER AZUL CELESTE
          // =============================================================
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00AAFF), Color(0xFF0088DD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Ganhar Moedas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFFFA500),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCoins(_balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Amino Coins',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =============================================================
          // CORPO — Cards de atividades
          // =============================================================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Assistir Anúncios
                _SectionTitle(title: 'Assistir Anúncios'),
                const SizedBox(height: 8),
                _EarningCard(
                  icon: Icons.play_circle_filled_rounded,
                  iconColor: const Color(0xFFE53935),
                  title: 'Assistir Vídeo',
                  subtitle:
                      '$_adsWatchedToday/$_maxAdsPerDay assistidos hoje',
                  reward: '+5',
                  onTap:
                      _adsWatchedToday < _maxAdsPerDay ? _watchAd : null,
                  isLoading: _isLoadingAd,
                ),
                const SizedBox(height: 20),

                // Atividades Diárias
                _SectionTitle(title: 'Atividades Diárias'),
                const SizedBox(height: 8),
                const _EarningCard(
                  icon: Icons.calendar_today_rounded,
                  iconColor: Color(0xFF2196F3),
                  title: 'Check-in Diário',
                  subtitle: 'Faça check-in todos os dias',
                  reward: '+5-25',
                ),
                const _EarningCard(
                  icon: Icons.edit_rounded,
                  iconColor: Color(0xFF4CAF50),
                  title: 'Criar um Post',
                  subtitle: 'Publique conteúdo na comunidade',
                  reward: '+3',
                ),
                const _EarningCard(
                  icon: Icons.comment_rounded,
                  iconColor: Color(0xFF00BCD4),
                  title: 'Comentar em Posts',
                  subtitle: 'Participe das discussões',
                  reward: '+1',
                ),
                const _EarningCard(
                  icon: Icons.quiz_rounded,
                  iconColor: Color(0xFFFF9800),
                  title: 'Responder Quiz',
                  subtitle: 'Acerte quizzes da comunidade',
                  reward: '+2',
                ),
                const SizedBox(height: 20),

                // Conquistas
                _SectionTitle(title: 'Conquistas'),
                const SizedBox(height: 8),
                const _EarningCard(
                  icon: Icons.emoji_events_rounded,
                  iconColor: Color(0xFFFF9800),
                  title: 'Completar Conquistas',
                  subtitle: 'Desbloqueie badges e ganhe moedas',
                  reward: '+10-100',
                ),
                const _EarningCard(
                  icon: Icons.person_add_rounded,
                  iconColor: Color(0xFF9C27B0),
                  title: 'Convidar Amigos',
                  subtitle: 'Ganhe moedas quando amigos se cadastram',
                  reward: '+50',
                ),
                const _EarningCard(
                  icon: Icons.trending_up_rounded,
                  iconColor: Color(0xFF2196F3),
                  title: 'Subir de Nível',
                  subtitle: 'Ganhe moedas ao subir de nível',
                  reward: '+20',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
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
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: Color(0xFF333333),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          // Reward badge
          onTap != null
              ? GestureDetector(
                  onTap: isLoading ? null : onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                reward,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: Color(0xFFFF9800), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        reward,
                        style: const TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
