import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/utils/responsive.dart';

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

      final wallet = await SupabaseService.table('profiles')
          .select('coins')
          .eq('id', userId)
          .maybeSingle();

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final adCount = await SupabaseService.table('coin_transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'ad_reward')
          .gte('created_at', today);

      if (mounted) {
        setState(() {
          _balance = wallet?['coins'] as int? ?? 0;
          _adsWatchedToday = (adCount as List?)?.length ?? 0;
        });
      }
    } catch (e) {
      debugPrint('[free_coins_screen] Erro: $e');
    }
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
      if (!mounted) return;
      if (success) {
        if (!mounted) return;
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
            content: Text('Erro ao carregar anúncio. Tente novamente.',
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
    final r = context.r;
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
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(4), vertical: r.s(4)),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white, size: r.s(20)),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            'Ganhar Moedas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(17),
                            ),
                          ),
                        ),
                        SizedBox(width: r.s(48)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: r.s(16)),
                    child: Column(
                      children: [
                        Container(
                          width: r.s(48),
                          height: r.s(48),
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
                          child: Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r.fs(20),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(8)),
                        Text(
                          _formatCoins(_balance),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(28),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Amino Coins',
                          style:
                              TextStyle(color: Colors.white70, fontSize: r.fs(13)),
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
              padding: EdgeInsets.all(r.s(16)),
              children: [
                // Assistir Anúncios
                _SectionTitle(title: 'Assistir Anúncios'),
                SizedBox(height: r.s(8)),
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
                SizedBox(height: r.s(20)),

                // Atividades Diárias
                _SectionTitle(title: 'Atividades Diárias'),
                SizedBox(height: r.s(8)),
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
                SizedBox(height: r.s(20)),

                // Conquistas
                _SectionTitle(title: 'Conquistas'),
                SizedBox(height: r.s(8)),
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
                SizedBox(height: r.s(24)),
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
    final r = context.r;
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: r.fs(16),
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
    final r = context.r;
    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.s(12)),
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
            width: r.s(44),
            height: r.s(44),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Icon(icon, color: iconColor, size: r.s(22)),
          ),
          SizedBox(width: r.s(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: r.fs(14),
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
                ),
              ],
            ),
          ),
          // Reward badge
          onTap != null
              ? GestureDetector(
                  onTap: isLoading ? null : onTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(12), vertical: r.s(6)),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(r.s(16)),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: r.s(14),
                            height: r.s(14),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monetization_on_rounded,
                                  color: Colors.white, size: r.s(14)),
                              SizedBox(width: r.s(4)),
                              Text(
                                reward,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                )
              : Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(4)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on_rounded,
                          color: Color(0xFFFF9800), size: r.s(14)),
                      SizedBox(width: r.s(4)),
                      Text(
                        reward,
                        style: TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: r.fs(12),
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
