import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'supabase_service.dart';

/// Serviço de In-App Purchases via RevenueCat.
///
/// Gerencia assinaturas (Amino+), pacotes de moedas e restauração de compras.
/// Para configurar:
/// 1. Crie uma conta em https://app.revenuecat.com
/// 2. Configure os produtos no App Store Connect / Google Play Console
/// 3. Substitua as chaves abaixo pelas suas chaves reais
class IAPService {
  static const String _apiKeyAndroid = 'YOUR_REVENUECAT_ANDROID_KEY';
  static const String _apiKeyIOS = 'YOUR_REVENUECAT_IOS_KEY';

  static const String entitlementAminoPlus = 'amino_plus';

  /// Pacotes de moedas disponíveis para compra
  static const List<CoinPackage> coinPackages = [
    CoinPackage(id: 'coins_100', coins: 100, priceLabel: 'R\$ 4,90'),
    CoinPackage(id: 'coins_500', coins: 500, priceLabel: 'R\$ 19,90'),
    CoinPackage(id: 'coins_1200', coins: 1200, priceLabel: 'R\$ 39,90'),
    CoinPackage(id: 'coins_3000', coins: 3000, priceLabel: 'R\$ 89,90'),
    CoinPackage(id: 'coins_7000', coins: 7000, priceLabel: 'R\$ 179,90'),
  ];

  static bool _initialized = false;
  static bool _isAminoPlus = false;

  /// Inicializa o RevenueCat SDK
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = PurchasesConfiguration(
        defaultTargetPlatform == TargetPlatform.iOS
            ? _apiKeyIOS
            : _apiKeyAndroid,
      );

      await Purchases.configure(config);

      // Identificar o usuário com o ID do Supabase
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        await Purchases.logIn(userId);
      }

      _initialized = true;
      await _checkEntitlements();
    } catch (e) {
      debugPrint('[IAPService] Erro ao inicializar RevenueCat: $e');
    }
  }

  /// Verifica se o usuário tem Amino+
  static Future<bool> checkAminoPlus() async {
    await _checkEntitlements();
    return _isAminoPlus;
  }

  static bool get isAminoPlus => _isAminoPlus;

  /// Verifica entitlements atuais
  static Future<void> _checkEntitlements() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _isAminoPlus =
          info.entitlements.active.containsKey(entitlementAminoPlus);
    } catch (e) {
      debugPrint('[IAPService] Erro ao verificar entitlements: $e');
    }
  }

  /// Retorna as ofertas disponíveis
  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('[IAPService] Erro ao buscar ofertas: $e');
      return null;
    }
  }

  /// Compra um pacote de moedas
  static Future<bool> purchaseCoinPackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      if (result.customerInfo.entitlements.active.isNotEmpty) {
        // Creditar moedas no Supabase
        final productId = package.storeProduct.identifier;
        final coins = _coinsForProduct(productId);
        if (coins > 0) {
          await _creditCoins(coins);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[IAPService] Erro na compra: $e');
      return false;
    }
  }

  /// Assina Amino+
  static Future<bool> subscribeAminoPlus(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      _isAminoPlus = result.customerInfo.entitlements.active
          .containsKey(entitlementAminoPlus);
      if (_isAminoPlus) {
        // Atualizar perfil no Supabase
        final userId = SupabaseService.currentUserId;
        if (userId != null) {
          await SupabaseService.table('profiles')
              .update({'is_amino_plus': true}).eq('id', userId);
        }
      }
      return _isAminoPlus;
    } catch (e) {
      debugPrint('[IAPService] Erro na assinatura: $e');
      return false;
    }
  }

  /// Restaura compras anteriores
  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _isAminoPlus =
          info.entitlements.active.containsKey(entitlementAminoPlus);
      return true;
    } catch (e) {
      debugPrint('[IAPService] Erro ao restaurar: $e');
      return false;
    }
  }

  /// Credita moedas no banco de dados
  static Future<void> _creditCoins(int amount) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await SupabaseService.client.rpc('transfer_coins', params: {
      'p_from_user_id': userId, // sistema → self (auto-credit)
      'p_to_user_id': userId,
      'p_amount': amount,
      'p_reason': 'iap_purchase',
    });
  }

  /// Mapeia product ID para quantidade de moedas
  static int _coinsForProduct(String productId) {
    for (final pkg in coinPackages) {
      if (productId.contains(pkg.id)) return pkg.coins;
    }
    return 0;
  }
}

/// Modelo de pacote de moedas
class CoinPackage {
  final String id;
  final int coins;
  final String priceLabel;

  const CoinPackage({
    required this.id,
    required this.coins,
    required this.priceLabel,
  });
}
