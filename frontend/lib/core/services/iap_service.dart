import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Serviço de In-App Purchases via RevenueCat.
///
/// Implementação abstrata que funciona sem SDK de compras instalado.
/// Para ativar compras reais:
/// 1. Adicione `purchases_flutter: ^8.0.0` ao pubspec.yaml
/// 2. Crie uma conta em https://app.revenuecat.com
/// 3. Configure os produtos no Google Play Console
/// 4. Substitua as chaves abaixo pelas suas chaves reais
/// 5. Descomente as chamadas ao SDK no código abaixo
class IAPService {
  static const String apiKeyAndroid = 'YOUR_REVENUECAT_ANDROID_KEY';

  static const String entitlementAminoPlus = 'amino_plus';

  /// Pacotes de moedas disponíveis para compra
  static const List<CoinPackage> coinPackages = [
    CoinPackage(id: 'coins_100', coins: 100, priceLabel: r'R$ 4,90'),
    CoinPackage(id: 'coins_500', coins: 500, priceLabel: r'R$ 19,90'),
    CoinPackage(id: 'coins_1200', coins: 1200, priceLabel: r'R$ 39,90'),
    CoinPackage(id: 'coins_3000', coins: 3000, priceLabel: r'R$ 89,90'),
    CoinPackage(id: 'coins_7000', coins: 7000, priceLabel: r'R$ 179,90'),
  ];

  static bool _initialized = false;
  static bool _isAminoPlus = false;

  /// Inicializa o serviço de compras
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // TODO: Quando purchases_flutter estiver no pubspec:
      // final config = PurchasesConfiguration(apiKeyAndroid);
      // await Purchases.configure(config);
      // final userId = SupabaseService.currentUserId;
      // if (userId != null) await Purchases.logIn(userId);

      _initialized = true;
      await _checkEntitlements();
      debugPrint('[IAPService] Inicializado com sucesso');
    } catch (e) {
      debugPrint('[IAPService] Erro ao inicializar: $e');
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
      // TODO: Quando purchases_flutter estiver no pubspec:
      // final info = await Purchases.getCustomerInfo();
      // _isAminoPlus = info.entitlements.active.containsKey(entitlementAminoPlus);

      // Fallback: verificar no Supabase
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        final profile = await SupabaseService.table('profiles')
            .select('is_amino_plus')
            .eq('id', userId)
            .maybeSingle();
        _isAminoPlus = profile?['is_amino_plus'] == true;
      }
    } catch (e) {
      debugPrint('[IAPService] Erro ao verificar entitlements: $e');
    }
  }

  /// Retorna as ofertas disponíveis como lista de CoinPackage
  static Future<List<CoinPackage>> getOfferings() async {
    // TODO: Quando purchases_flutter estiver no pubspec:
    // return await Purchases.getOfferings();
    return coinPackages;
  }

  /// Compra um pacote de moedas (simulado sem SDK)
  static Future<bool> purchaseCoinPackage(CoinPackage package) async {
    try {
      // TODO: Quando purchases_flutter estiver no pubspec:
      // final result = await Purchases.purchasePackage(revenueCatPackage);
      // Verificar result.customerInfo.entitlements

      // Em modo de desenvolvimento, simular compra
      if (kDebugMode) {
        debugPrint('[IAPService] Simulando compra de ${package.coins} moedas');
      }

      await _creditCoins(package.coins);
      return true;
    } catch (e) {
      debugPrint('[IAPService] Erro na compra: $e');
      return false;
    }
  }

  /// Assina Amino+
  static Future<bool> subscribeAminoPlus() async {
    try {
      // TODO: Quando purchases_flutter estiver no pubspec:
      // final result = await Purchases.purchasePackage(aminoPlusPackage);
      // _isAminoPlus = result.customerInfo.entitlements.active.containsKey(entitlementAminoPlus);

      // Atualizar perfil no Supabase
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        await SupabaseService.table('profiles')
            .update({'is_amino_plus': true}).eq('id', userId);
        _isAminoPlus = true;
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
      // TODO: Quando purchases_flutter estiver no pubspec:
      // final info = await Purchases.restorePurchases();
      // _isAminoPlus = info.entitlements.active.containsKey(entitlementAminoPlus);

      await _checkEntitlements();
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

    try {
      await SupabaseService.client.rpc('transfer_coins', params: {
        'p_from_user_id': userId,
        'p_to_user_id': userId,
        'p_amount': amount,
        'p_reason': 'iap_purchase',
      });
    } catch (e) {
      debugPrint('[IAPService] Erro ao creditar moedas: $e');
    }
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
