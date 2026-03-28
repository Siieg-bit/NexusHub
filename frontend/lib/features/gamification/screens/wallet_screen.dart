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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Carteira',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
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
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.accentColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text('Saldo',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
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
                                fontWeight: FontWeight.w800,
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
                                width: 1, height: 30, color: Colors.white30),
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
                            onTap: () => context.go('/store'),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.volunteer_activism_rounded,
                            label: 'Props',
                            color: const Color(0xFFE91E63),
                            onTap: () => _showPropsDialog(),
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
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Como ganhar moedas',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        const _EarnRow(
                          icon: Icons.calendar_today_rounded,
                          title: 'Check-in diário',
                          reward: '5-25',
                          color: AppTheme.warningColor,
                        ),
                        const _EarnRow(
                          icon: Icons.article_rounded,
                          title: 'Criar posts',
                          reward: '10',
                          color: AppTheme.primaryColor,
                        ),
                        const _EarnRow(
                          icon: Icons.comment_rounded,
                          title: 'Comentar',
                          reward: '2',
                          color: AppTheme.accentColor,
                        ),
                        const _EarnRow(
                          icon: Icons.quiz_rounded,
                          title: 'Completar quizzes',
                          reward: '5-50',
                          color: Color(0xFF9C27B0),
                        ),
                        const _EarnRow(
                          icon: Icons.emoji_events_rounded,
                          title: 'Conquistas',
                          reward: '10-100',
                          color: Color(0xFFFF5722),
                        ),
                        const _EarnRow(
                          icon: Icons.people_rounded,
                          title: 'Convidar amigos',
                          reward: '50',
                          color: AppTheme.primaryColor,
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
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Histórico',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        if (_transactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text('Nenhuma transação ainda',
                                  style: TextStyle(color: Colors.grey[500])),
                            ),
                          )
                        else
                          ...(_transactions.take(20).map((tx) {
                            final amount = tx['amount'] as int? ?? 0;
                            final type = tx['type'] as String? ?? '';
                            final desc = tx['description'] as String? ?? type;
                            final isPositive = amount >= 0;
                            final createdAt = tx['created_at'] != null
                                ? DateTime.parse(tx['created_at'] as String)
                                : DateTime.now();

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: (isPositive
                                          ? AppTheme.primaryColor
                                          : AppTheme.errorColor)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isPositive
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: isPositive
                                      ? AppTheme.primaryColor
                                      : AppTheme.errorColor,
                                  size: 18,
                                ),
                              ),
                              title: Text(desc,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textPrimary)),
                              subtitle: Text(
                                '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                              trailing: Text(
                                '${isPositive ? '+' : ''}$amount',
                                style: TextStyle(
                                  color: isPositive
                                      ? AppTheme.primaryColor
                                      : AppTheme.errorColor,
                                  fontWeight: FontWeight.w800,
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
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: const Text('Transferir Moedas',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Amino ID do destinatário',
                labelStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon:
                    const Icon(Icons.person_rounded, color: AppTheme.accentColor),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accentColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Quantidade',
                labelStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.monetization_on_rounded,
                    color: AppTheme.warningColor),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.warningColor),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Saldo atual: $_coins coins',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(color: Colors.grey[500]))),
          GestureDetector(
            onTap: () async {
              final amount = int.tryParse(amountCtrl.text) ?? 0;
              final targetAminoId = userIdCtrl.text.trim();
              Navigator.pop(ctx);
              if (amount <= 0 || targetAminoId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dados inválidos')),
                );
                return;
              }
              if (amount > _coins) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saldo insuficiente')),
                );
                return;
              }
              try {
                await SupabaseService.rpc('transfer_coins', params: {
                  'p_target_amino_id': targetAminoId,
                  'p_amount': amount,
                });
                setState(() => _coins -= amount);
                await _loadWallet();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$amount coins transferidos!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
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
              child: const Text('Transferir',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPropsDialog() {
    final userIdCtrl = TextEditingController();
    int selectedAmount = 10;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          title: const Row(
            children: [
              Icon(Icons.volunteer_activism_rounded, color: Color(0xFFE91E63)),
              SizedBox(width: 8),
              Text('Enviar Props',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userIdCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Amino ID do usuário',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon:
                      const Icon(Icons.person_rounded, color: AppTheme.accentColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accentColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Quantidade de Props',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [5, 10, 25, 50, 100].map((amount) {
                  final isSelected = selectedAmount == amount;
                  return ChoiceChip(
                    label: Text('$amount',
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFE91E63),
                    backgroundColor: AppTheme.surfaceColor,
                    side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.1)),
                    onSelected: (_) {
                      setDialogState(() => selectedAmount = amount);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text('Custo: $selectedAmount coins',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.grey[500]))),
            GestureDetector(
              onTap: () async {
                final targetAminoId = userIdCtrl.text.trim();
                Navigator.pop(ctx);
                if (targetAminoId.isEmpty) return;
                if (selectedAmount > _coins) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saldo insuficiente')),
                  );
                  return;
                }
                try {
                  await SupabaseService.rpc('send_tip', params: {
                    'p_target_user_id': targetAminoId,
                    'p_amount': selectedAmount,
                  });
                  setState(() => _coins -= selectedAmount);
                  await _loadWallet();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('$selectedAmount props enviados!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text('Enviar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
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
                fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
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
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
