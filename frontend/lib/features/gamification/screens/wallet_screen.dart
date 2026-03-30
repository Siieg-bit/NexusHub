import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Carteira / Minha Carteira — Estilo Amino original.
/// Header azul celeste brilhante com moeda dourada, corpo claro/branco.
/// Sem misturar XP/Nível. Foco financeiro: saldo, assinaturas, histórico, loja.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _coins = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final profile = await SupabaseService.table('profiles')
          .select('coins_count')
          .eq('id', userId)
          .single();

      _coins = profile['coins_count'] as int? ?? 0;

      try {
        final txRes = await SupabaseService.table('coin_transactions')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50);
        _transactions = List<Map<String, dynamic>>.from(txRes as List?);
      } catch (e) {
        debugPrint('[wallet_screen] Erro: $e');
      }

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      // Corpo com fundo cinza claro (estilo Amino original)
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00AAFF)))
          : Column(
              children: [
                // =============================================================
                // HEADER AZUL CELESTE — Estilo Amino "Minha Carteira"
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
                        // Top bar: voltar + título + comprar
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(4), vertical: r.s(4)),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white, size: r.s(20)),
                                onPressed: () => context.pop(),
                              ),
                              Expanded(
                                child: Text(
                                  'Minha Carteira',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: r.fs(17),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push('/store/coins'),
                                child: Text(
                                  'Comprar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Moeda dourada grande + saldo
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: r.s(20)),
                          child: Column(
                            children: [
                              // Moeda dourada grande
                              Container(
                                width: r.s(72),
                                height: r.s(72),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFFA500),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fs(32),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: r.s(12)),
                              // Saldo
                              Text(
                                _formatCoins(_coins),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(36),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Amino Coins',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: r.fs(14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =============================================================
                // CORPO — Fundo claro, seções estilo Amino
                // =============================================================
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: r.s(16)),

                        // Seção: Assinaturas
                        _WalletMenuTile(
                          icon: Icons.card_membership_rounded,
                          iconColor: const Color(0xFF4CAF50),
                          title: 'Assinaturas',
                          subtitle: 'Gerencie seu Amino+',
                          onTap: () => context.push('/store'),
                        ),

                        // Seção: Histórico
                        _WalletMenuTile(
                          icon: Icons.history_rounded,
                          iconColor: const Color(0xFF2196F3),
                          title: 'Histórico',
                          subtitle: '${_transactions.length} transações',
                          onTap: () => _showHistory(),
                        ),

                        // Seção: Transferir
                        _WalletMenuTile(
                          icon: Icons.send_rounded,
                          iconColor: const Color(0xFF9C27B0),
                          title: 'Transferir Moedas',
                          subtitle: 'Envie moedas para um amigo',
                          onTap: () => _showTransferDialog(),
                        ),

                        // Seção: Props
                        _WalletMenuTile(
                          icon: Icons.volunteer_activism_rounded,
                          iconColor: const Color(0xFFE91E63),
                          title: 'Enviar Props',
                          subtitle: 'Reconheça um membro',
                          onTap: () => _showPropsDialog(),
                        ),

                        SizedBox(height: r.s(16)),

                        // Texto "Comprar Moedas"
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                          child: Text(
                            'Comprar Moedas',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: r.fs(13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(8)),

                        // Botão "Visite a loja"
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                          child: GestureDetector(
                            onTap: () => context.push('/store/coins'),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: r.s(14)),
                              decoration: BoxDecoration(
                                color: const Color(0xFF333333),
                                borderRadius: BorderRadius.circular(r.s(24)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: Color(0xFFFFD700), size: r.s(18)),
                                  SizedBox(width: r.s(8)),
                                  Text(
                                    'Visite a loja',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: r.fs(14),
                                    ),
                                  ),
                                  SizedBox(width: r.s(8)),
                                  Icon(Icons.star_rounded,
                                      color: Color(0xFFFFD700), size: r.s(18)),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: r.s(32)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // HISTÓRICO — Modal bottom sheet com transações
  // ===========================================================================
  void _showHistory() {
      final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            SizedBox(height: r.s(12)),
            Container(
              width: r.s(36),
              height: r.s(4),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.s(16)),
            Text(
              'Histórico de Transações',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: r.fs(16),
                color: Color(0xFF333333),
              ),
            ),
            SizedBox(height: r.s(8)),
            Expanded(
              child: _transactions.isEmpty
                  ? Center(
                      child: Text('Nenhuma transação ainda',
                          style: TextStyle(color: Colors.grey[500])),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                      itemCount: _transactions.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: Colors.grey[200], height: 1),
                      itemBuilder: (ctx, index) {
                        final tx = _transactions[index];
                        final amount = tx['amount'] as int? ?? 0;
                        final type = tx['type'] as String? ?? '';
                        final desc =
                            tx['description'] as String? ?? type;
                        final isPositive = amount >= 0;
                        final createdAt = tx['created_at'] != null
                            ? DateTime.parse(tx['created_at'] as String?)
                            : DateTime.now();

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: r.s(36),
                            height: r.s(36),
                            decoration: BoxDecoration(
                              color: (isPositive
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFE53935))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(r.s(10)),
                            ),
                            child: Icon(
                              isPositive
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: isPositive
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE53935),
                              size: r.s(18),
                            ),
                          ),
                          title: Text(desc,
                              style: TextStyle(
                                  fontSize: r.fs(13),
                                  color: Color(0xFF333333))),
                          subtitle: Text(
                            '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                            style: TextStyle(
                                fontSize: r.fs(11), color: Colors.grey[500]),
                          ),
                          trailing: Text(
                            '${isPositive ? '+' : ''}$amount',
                            style: TextStyle(
                              color: isPositive
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE53935),
                              fontWeight: FontWeight.w800,
                              fontSize: r.fs(14),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TRANSFERIR — Dialog
  // ===========================================================================
  void _showTransferDialog() {
      final r = context.r;
    final userIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
        title: const Text('Transferir Moedas',
            style: TextStyle(
                color: Color(0xFF333333), fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdCtrl,
              style: const TextStyle(color: Color(0xFF333333)),
              decoration: InputDecoration(
                labelText: 'Amino ID do destinatário',
                labelStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.person_rounded,
                    color: Color(0xFF00AAFF)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00AAFF)),
                ),
              ),
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF333333)),
              decoration: InputDecoration(
                labelText: 'Quantidade',
                labelStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.monetization_on_rounded,
                    color: Color(0xFFFF9800)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF9800)),
                ),
              ),
            ),
            SizedBox(height: r.s(8)),
            Text('Saldo atual: ${_formatCoins(_coins)} coins',
                style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
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
                    SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
                  );
                }
              }
            },
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: const Color(0xFF00AAFF),
                borderRadius: BorderRadius.circular(r.s(20)),
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

  // ===========================================================================
  // PROPS — Dialog
  // ===========================================================================
  void _showPropsDialog() {
      final r = context.r;
    final userIdCtrl = TextEditingController();
    int selectedAmount = 10;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16)),
          ),
          title: Row(
            children: [
              Icon(Icons.volunteer_activism_rounded,
                  color: Color(0xFFE91E63)),
              SizedBox(width: r.s(8)),
              Text('Enviar Props',
                  style: TextStyle(
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userIdCtrl,
                style: const TextStyle(color: Color(0xFF333333)),
                decoration: InputDecoration(
                  labelText: 'Amino ID do usuário',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.person_rounded,
                      color: Color(0xFF00AAFF)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00AAFF)),
                  ),
                ),
              ),
              SizedBox(height: r.s(16)),
              const Text('Quantidade de Props',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333))),
              SizedBox(height: r.s(8)),
              Wrap(
                spacing: 8,
                children: [5, 10, 25, 50, 100].map((amount) {
                  final isSelected = selectedAmount == amount;
                  return ChoiceChip(
                    label: Text('$amount',
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF333333))),
                    selected: isSelected,
                    selectedColor: const Color(0xFFE91E63),
                    backgroundColor: Colors.grey[100],
                    side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey[300]!),
                    onSelected: (_) {
                      setDialogState(() => selectedAmount = amount);
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: r.s(8)),
              Text('Custo: $selectedAmount coins',
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
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
                          content:
                              Text('$selectedAmount props enviados!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
                    );
                  }
                }
              },
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                  ),
                  borderRadius: BorderRadius.circular(r.s(20)),
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

// =============================================================================
// WALLET MENU TILE — Item de menu estilo Amino (fundo branco, ícone colorido)
// =============================================================================
class _WalletMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WalletMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
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
              width: r.s(40),
              height: r.s(40),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
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
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w600,
                      fontSize: r.fs(14),
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
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[400], size: r.s(22)),
          ],
        ),
      ),
    );
  }
}
