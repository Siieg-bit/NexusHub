import 'package:flutter/material.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';

/// Tela de Compra de Moedas — Estilo Amino original.
/// Header azul celeste com moeda dourada, corpo claro com pacotes de moedas.
class CoinShopScreen extends StatefulWidget {
  const CoinShopScreen({super.key});

  @override
  State<CoinShopScreen> createState() => _CoinShopScreenState();
}

class _CoinShopScreenState extends State<CoinShopScreen> {
  int _userCoins = 0;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isWatchingAd = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        final profile = await SupabaseService.table('profiles')
            .select('coins_count')
            .eq('id', userId)
            .single();
        _userCoins = profile['coins_count'] as int? ?? 0;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
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

  Future<void> _purchaseCoins(CoinPackage pkg) async {
    setState(() => _isPurchasing = true);
    try {
      final packages = await IAPService.getOfferings();
      if (packages.isEmpty) {
        _showError('Ofertas não disponíveis no momento');
        return;
      }
      final target = packages.where((p) => p.id == pkg.id);
      if (target.isEmpty) {
        _showError('Pacote não encontrado');
        return;
      }
      final success = await IAPService.purchaseCoinPackage(target.first);
      if (success) {
        setState(() => _userCoins += pkg.coins);
        _showSuccess('${pkg.coins} moedas adicionadas!');
      }
    } catch (e) {
      _showError('Erro na compra: $e');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _watchAdForCoins() async {
    if (!AdService.canWatchAd) {
      _showError('Limite diário de anúncios atingido. Tente amanhã!');
      return;
    }
    setState(() => _isWatchingAd = true);
    try {
      final success = await AdService.showRewardedAd(rewardCoins: 5);
      if (success) {
        setState(() => _userCoins += 5);
        _showSuccess('+5 moedas ganhas!');
      } else {
        _showError('Anúncio não disponível no momento');
      }
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
  }

  Future<void> _restorePurchases() async {
    final success = await IAPService.restorePurchases();
    if (success) {
      _showSuccess('Compras restauradas com sucesso!');
    } else {
      _showError('Erro ao restaurar compras');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFE53935)),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF4CAF50)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00AAFF)))
          : Column(
              children: [
                // =============================================================
                // HEADER AZUL CELESTE — Estilo Amino
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
                        // Top bar
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(4), vertical: r.s(4)),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                    Icons.arrow_back_ios_rounded,
                                    color: Colors.white,
                                    size: r.s(20)),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  'Comprar Moedas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: r.fs(17),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _restorePurchases,
                                child: Text(
                                  'Restaurar',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Moeda dourada + saldo
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: r.s(16)),
                          child: Column(
                            children: [
                              Container(
                                width: r.s(56),
                                height: r.s(56),
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
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fs(24),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: r.s(8)),
                              Text(
                                _formatCoins(_userCoins),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(28),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Amino Coins',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: r.fs(13)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =============================================================
                // CORPO — Fundo claro com pacotes
                // =============================================================
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(r.s(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Assistir anúncio
                        _buildAdRewardCard(),
                        SizedBox(height: r.s(16)),

                        // Pacotes de moedas
                        Text(
                          'Pacotes de Moedas',
                          style: TextStyle(
                            fontSize: r.fs(16),
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF333333),
                          ),
                        ),
                        SizedBox(height: r.s(12)),
                        ...IAPService.fallbackCoinPackages
                            .map(_buildCoinPackageCard),
                        SizedBox(height: r.s(16)),

                        // Amino+ card
                        _buildAminoPlusCard(),
                        SizedBox(height: r.s(24)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAdRewardCard() {
      final r = context.r;
    final remaining = AdService.remainingAdsToday;
    return Container(
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
            padding: EdgeInsets.all(r.s(10)),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Icon(Icons.play_circle_filled_rounded,
                color: Color(0xFF4CAF50), size: r.s(28)),
          ),
          SizedBox(width: r.s(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistir Anúncio',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(14),
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ganhe 5 moedas grátis ($remaining restantes)',
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isWatchingAd || !AdService.canWatchAd
                ? null
                : _watchAdForCoins,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(14), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: _isWatchingAd || !AdService.canWatchAd
                    ? Colors.grey[300]
                    : const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: _isWatchingAd
                  ? SizedBox(
                      width: r.s(16),
                      height: r.s(16),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Assistir',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(12),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinPackageCard(CoinPackage pkg) {
      final r = context.r;
    final isPopular = pkg.coins == 1200;
    return Container(
      margin: EdgeInsets.only(bottom: r.s(10)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: isPopular
            ? Border.all(color: const Color(0xFFFF9800), width: 2)
            : null,
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
          // Moeda dourada
          Container(
            width: r.s(44),
            height: r.s(44),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
            ),
            child: Center(
              child: Text('A',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(18),
                      fontWeight: FontWeight.w900)),
            ),
          ),
          SizedBox(width: r.s(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${formatCount(pkg.coins)} Moedas',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(15),
                        color: Color(0xFF333333),
                      ),
                    ),
                    if (isPopular) ...[
                      SizedBox(width: r.s(8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(6), vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800),
                          borderRadius: BorderRadius.circular(r.s(8)),
                        ),
                        child: Text(
                          'POPULAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(9),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (pkg.coins >= 1200) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Melhor custo-benefício!',
                    style: TextStyle(
                      color: Color(0xFFFF9800),
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: _isPurchasing ? null : () => _purchaseCoins(pkg),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(14), vertical: r.s(8)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                ),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: _isPurchasing
                  ? SizedBox(
                      width: r.s(16),
                      height: r.s(16),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      pkg.priceLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: r.fs(13),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAminoPlusCard() {
      final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(20)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.s(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
                child: Text(
                  'A+',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: r.fs(14),
                  ),
                ),
              ),
              SizedBox(width: r.s(10)),
              Text(
                'Amino+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (IAPService.isAminoPlus)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(4)),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  child: Text(
                    'ATIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: r.fs(11),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: r.s(12)),
          _aminoPlusBenefit('Sem anúncios'),
          _aminoPlusBenefit('Badge exclusiva no perfil'),
          _aminoPlusBenefit('Chat bubbles premium'),
          _aminoPlusBenefit('200 moedas/mês grátis'),
          _aminoPlusBenefit('Acesso antecipado a novidades'),
          SizedBox(height: r.s(16)),
          if (!IAPService.isAminoPlus)
            GestureDetector(
              onTap: _isPurchasing ? null : () async {
                setState(() => _isPurchasing = true);
                try {
                  final success = await IAPService.subscribeAminoPlus();
                  if (mounted) {
                    if (success) {
                      _showSuccess('Amino+ ativado! Bem-vindo ao clube premium!');
                      setState(() {});
                    } else {
                      _showError('Não foi possível processar a assinatura.');
                    }
                  }
                } catch (e) {
                  if (mounted) _showError('Erro: $e');
                } finally {
                  if (mounted) setState(() => _isPurchasing = false);
                }
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.s(14)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(r.s(24)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Assinar por R\$ 14,90/mês',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.w800,
                    fontSize: r.fs(15),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _aminoPlusBenefit(String text) {

      final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(4)),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: Colors.white70, size: r.s(16)),
          SizedBox(width: r.s(8)),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: r.fs(13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
