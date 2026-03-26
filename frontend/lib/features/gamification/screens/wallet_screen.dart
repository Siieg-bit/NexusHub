import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';

/// Wallet / Economia — Saldo, histórico de transações, formas de ganhar moedas.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _coins = 0;
  int _totalXp = 0;
  int _level = 1;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final profile = await SupabaseService.table('profiles')
          .select('coins_count, xp_count, level')
          .eq('id', userId)
          .single();

      _coins = profile['coins_count'] as int? ?? 0;
      _totalXp = profile['xp_count'] as int? ?? 0;
      _level = profile['level'] as int? ?? 1;

      // Carregar transações
      try {
        final txRes = await SupabaseService.table('coin_transactions')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50);
        _transactions = List<Map<String, dynamic>>.from(txRes as List);
      } catch (_) {
        // Tabela pode não existir ainda
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteira',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ===========================================================
                  // SALDO PRINCIPAL
                  // ===========================================================
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.7),
                          AppTheme.accentColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text('Saldo',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on_rounded,
                                color: Colors.white, size: 32),
                            const SizedBox(width: 8),
                            Text(
                              formatCount(_coins),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _WalletStat(
                              icon: Icons.star_rounded,
                              label: 'XP Total',
                              value: formatCount(_totalXp),
                            ),
                            Container(
                                width: 1,
                                height: 30,
                                color: Colors.white30),
                            _WalletStat(
                              icon: Icons.arrow_upward_rounded,
                              label: 'Nível',
                              value: _level.toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ===========================================================
                  // AÇÕES RÁPIDAS
                  // ===========================================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.calendar_today_rounded,
                            label: 'Check-in',
                            color: AppTheme.warningColor,
                            onTap: () => context.push('/check-in'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.shopping_bag_rounded,
                            label: 'Loja',
                            color: AppTheme.primaryColor,
                            onTap: () {
                              // Navegar para a tab Store
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Transferir',
                            color: AppTheme.accentColor,
                            onTap: () => _showTransferDialog(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ===========================================================
                  // COMO GANHAR MOEDAS
                  // ===========================================================
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Como ganhar moedas',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        _EarnRow(
                          icon: Icons.calendar_today_rounded,
                          title: 'Check-in diário',
                          reward: '5-25',
                          color: AppTheme.warningColor,
                        ),
                        _EarnRow(
                          icon: Icons.article_rounded,
                          title: 'Criar posts',
                          reward: '10',
                          color: AppTheme.primaryColor,
                        ),
                        _EarnRow(
                          icon: Icons.comment_rounded,
                          title: 'Comentar',
                          reward: '2',
                          color: AppTheme.accentColor,
                        ),
                        _EarnRow(
                          icon: Icons.quiz_rounded,
                          title: 'Completar quizzes',
                          reward: '5-50',
                          color: const Color(0xFF9C27B0),
                        ),
                        _EarnRow(
                          icon: Icons.emoji_events_rounded,
                          title: 'Conquistas',
                          reward: '10-100',
                          color: const Color(0xFFFF5722),
                        ),
                        _EarnRow(
                          icon: Icons.people_rounded,
                          title: 'Convidar amigos',
                          reward: '50',
                          color: AppTheme.successColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ===========================================================
                  // HISTÓRICO DE TRANSAÇÕES
                  // ===========================================================
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Histórico',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        if (_transactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text('Nenhuma transação ainda',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)),
                            ),
                          )
                        else
                          ...(_transactions.take(20).map((tx) {
                            final amount = tx['amount'] as int? ?? 0;
                            final type = tx['type'] as String? ?? '';
                            final desc =
                                tx['description'] as String? ?? type;
                            final isPositive = amount >= 0;
                            final createdAt = tx['created_at'] != null
                                ? DateTime.parse(
                                    tx['created_at'] as String)
                                : DateTime.now();

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: (isPositive
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isPositive
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: isPositive
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                  size: 18,
                                ),
                              ),
                              title: Text(desc,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textHint),
                              ),
                              trailing: Text(
                                '${isPositive ? '+' : ''}$amount',
                                style: TextStyle(
                                  color: isPositive
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }).toList()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  void _showTransferDialog() {
    final userIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transferir Moedas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdCtrl,
              decoration: const InputDecoration(
                labelText: 'ID ou nome do usuário',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                prefixIcon: Icon(Icons.monetization_on_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Transferência em desenvolvimento')),
              );
            },
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WalletStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String reward;
  final Color color;

  const _EarnRow({
    required this.icon,
    required this.title,
    required this.reward,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 13)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: AppTheme.warningColor, size: 12),
                const SizedBox(width: 3),
                Text(reward,
                    style: const TextStyle(
                        color: AppTheme.warningColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
