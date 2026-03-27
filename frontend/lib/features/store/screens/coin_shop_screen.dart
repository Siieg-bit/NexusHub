import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';

/// Tela de Compra de Moedas — IAP (RevenueCat) + Rewarded Ads.
///
/// Permite ao usuário comprar moedas com dinheiro real ou assistir anúncios.
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

  Future<void> _purchaseCoins(CoinPackage pkg) async {
    setState(() => _isPurchasing = true);
    try {
      final offerings = await IAPService.getOfferings();
      if (offerings == null || offerings.current == null) {
        _showError('Ofertas não disponíveis no momento');
        return;
      }

      // Encontrar o pacote correspondente
      final packages = offerings.current!.availablePackages;
      final target = packages.where(
        (p) => p.storeProduct.identifier.contains(pkg.id),
      );

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
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.successColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprar Moedas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _restorePurchases,
            child: const Text('Restaurar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Saldo atual
                  _buildBalanceCard(),
                  const SizedBox(height: 24),

                  // Assistir anúncio
                  _buildAdRewardSection(),
                  const SizedBox(height: 24),

                  // Pacotes de moedas
                  const Text(
                    'Pacotes de Moedas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...IAPService.coinPackages.map(_buildCoinPackageCard),
                  const SizedBox(height: 24),

                  // Amino+ Assinatura
                  _buildAminoPlusCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Seu Saldo',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Colors.white, size: 32),
              const SizedBox(width: 8),
              Text(
                formatCount(_userCoins),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'moedas',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAdRewardSection() {
    final remaining = AdService.remainingAdsToday;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.play_circle_filled_rounded,
                color: AppTheme.successColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assistir Anúncio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Ganhe 5 moedas grátis ($remaining restantes hoje)',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isWatchingAd || !AdService.canWatchAd
                ? null
                : _watchAdForCoins,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isWatchingAd
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Assistir',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinPackageCard(CoinPackage pkg) {
    final isPopular = pkg.coins == 1200;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular
              ? AppTheme.primaryColor.withOpacity(0.5)
              : AppTheme.dividerColor.withOpacity(0.3),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Ícone de moedas
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: AppTheme.warningColor, size: 28),
                if (isPopular)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star,
                          color: Colors.white, size: 8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${formatCount(pkg.coins)} Moedas',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (pkg.coins >= 1200)
                  Text(
                    'Melhor custo-benefício!',
                    style: TextStyle(
                      color: AppTheme.successColor.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Preço
          ElevatedButton(
            onPressed: _isPurchasing ? null : () => _purchaseCoins(pkg),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isPurchasing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    pkg.priceLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAminoPlusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Amino+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (IAPService.isAminoPlus)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ATIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Desbloqueie recursos exclusivos:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _aminoPlusBenefit('Sem anúncios'),
          _aminoPlusBenefit('Badge exclusiva no perfil'),
          _aminoPlusBenefit('Chat bubbles premium'),
          _aminoPlusBenefit('200 moedas/mês grátis'),
          _aminoPlusBenefit('Acesso antecipado a novidades'),
          const SizedBox(height: 16),
          if (!IAPService.isAminoPlus)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implementar fluxo de assinatura
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Assinatura será habilitada em breve!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6C5CE7),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Assinar por R\$ 14,90/mês',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _aminoPlusBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
