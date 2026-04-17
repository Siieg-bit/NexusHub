import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'supabase_service.dart';

/// Serviço de In-App Purchases via RevenueCat.
///
/// API Key Android (debug): test_vLhJHaVBiGHrRySKvvnWlaqWrfN
/// API Key Android (release): configurar em _apiKeyAndroidRelease
/// Entitlement: amino_plus
/// Produtos: coins_100, coins_500, coins_1200, coins_3000, coins_7000, amino_plus_monthly
class IAPService {
  /// Chave de teste — usada apenas em modo debug/desenvolvimento.
  /// NUNCA use esta chave em produção: apps serão rejeitados na App Review.
  static const String _apiKeyAndroidDebug = 'test_vLhJHaVBiGHrRySKvvnWlaqWrfN';

  /// Chave de produção — substitua pelo valor real do painel RevenueCat.
  /// Obtenha em: https://app.revenuecat.com → Project Settings → API Keys
  static const String _apiKeyAndroidRelease = 'REVENUECAT_ANDROID_PRODUCTION_KEY';

  /// Chave ativa baseada no modo de build.
  static String get _apiKeyAndroid =>
      kDebugMode ? _apiKeyAndroidDebug : _apiKeyAndroidRelease;
  static const String entitlementAminoPlus = 'amino_plus';

  /// Identificadores dos produtos configurados no Google Play Console
  static const String _offeringDefault = 'default';

  /// Pacotes de moedas com preços de referência (exibidos antes de carregar do RevenueCat)
  static const List<CoinPackage> fallbackCoinPackages = [
    CoinPackage(id: 'coins_100', coins: 100, priceLabel: r'R$ 4,90'),
    CoinPackage(id: 'coins_500', coins: 500, priceLabel: r'R$ 19,90'),
    CoinPackage(id: 'coins_1200', coins: 1200, priceLabel: r'R$ 39,90'),
    CoinPackage(id: 'coins_3000', coins: 3000, priceLabel: r'R$ 89,90'),
    CoinPackage(id: 'coins_7000', coins: 7000, priceLabel: r'R$ 179,90'),
  ];

  static bool _initialized = false;
  static bool _isAminoPlus = false;

  /// Inicializa o RevenueCat e faz login com o ID do usuário Supabase
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      final config = PurchasesConfiguration(_apiKeyAndroid);
      await Purchases.configure(config);

      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        await Purchases.logIn(userId);
      }

      _initialized = true;
      await _checkEntitlements();
      debugPrint('[IAPService] RevenueCat inicializado com sucesso');
    } catch (e) {
      debugPrint('[IAPService] Erro ao inicializar: $e');
    }
  }

  /// Faz login no RevenueCat quando o usuário fizer login no app
  static Future<void> loginUser(String userId) async {
    if (!_initialized) return;
    try {
      await Purchases.logIn(userId);
      await _checkEntitlements();
    } catch (e) {
      debugPrint('[IAPService] Erro ao fazer login: $e');
    }
  }

  /// Faz logout no RevenueCat quando o usuário sair do app
  static Future<void> logoutUser() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
      _isAminoPlus = false;
    } catch (e) {
      debugPrint('[IAPService] Erro ao fazer logout: $e');
    }
  }

  /// Verifica se o usuário tem Amino+ ativo
  static Future<bool> checkAminoPlus() async {
    await _checkEntitlements();
    return _isAminoPlus;
  }

  static bool get isAminoPlus => _isAminoPlus;

  /// Verifica entitlements atuais no RevenueCat
  static Future<void> _checkEntitlements() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _isAminoPlus = info.entitlements.active.containsKey(entitlementAminoPlus);
      // Sincronizar com Supabase
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        await SupabaseService.table('profiles')
            .update({'is_amino_plus': _isAminoPlus}).eq('id', userId);
      }
    } catch (e) {
      // Fallback: verificar no Supabase
      try {
        final userId = SupabaseService.currentUserId;
        if (userId != null) {
          final profile = await SupabaseService.table('profiles')
              .select('is_amino_plus')
              .eq('id', userId)
              .maybeSingle();
          _isAminoPlus = profile?['is_amino_plus'] == true;
        }
      } catch (e2) {
        debugPrint('[IAPService] Erro ao verificar entitlements: $e2');
      }
    }
  }

  /// Retorna os pacotes disponíveis do RevenueCat
  static Future<List<CoinPackage>> getOfferings() async {
    if (!_initialized) return fallbackCoinPackages;
    try {
      final offerings = await Purchases.getOfferings();
      final current =
          offerings.getOffering(_offeringDefault) ?? offerings.current;
      if (current == null) return fallbackCoinPackages;

      return current.availablePackages.map((pkg) {
        final coins = _coinsFromPackageId(pkg.storeProduct.identifier);
        return CoinPackage(
          id: pkg.storeProduct.identifier,
          coins: coins,
          priceLabel: pkg.storeProduct.priceString,
          revenueCatPackage: pkg,
        );
      }).toList();
    } catch (e) {
      debugPrint('[IAPService] Erro ao buscar ofertas: $e');
      return fallbackCoinPackages;
    }
  }

  /// Compra um pacote de moedas via RevenueCat
  static Future<bool> purchaseCoinPackage(CoinPackage package) async {
    if (!_initialized) {
      debugPrint('[IAPService] SDK não inicializado');
      return false;
    }
    try {
      if (package.revenueCatPackage != null) {
        await Purchases.purchasePackage(package.revenueCatPackage!);
      } else {
        // Compra direta pelo ID do produto
        final products = await Purchases.getProducts([package.id]);
        if (products.isNotEmpty) {
          await Purchases.purchaseStoreProduct(products.first);
        }
      }
      // Creditar moedas no Supabase após compra confirmada
      await _creditCoins(package.coins);
      debugPrint('[IAPService] ${package.coins} moedas creditadas');
      return true;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[IAPService] Compra cancelada pelo usuário');
      } else {
        debugPrint('[IAPService] Erro na compra: $e');
      }
      return false;
    } catch (e) {
      debugPrint('[IAPService] Erro inesperado na compra: $e');
      return false;
    }
  }

  /// Assina Amino+ via RevenueCat
  static Future<bool> subscribeAminoPlus() async {
    if (!_initialized) {
      debugPrint('[IAPService] SDK não inicializado');
      return false;
    }
    try {
      final offerings = await Purchases.getOfferings();
      final current =
          offerings.getOffering(_offeringDefault) ?? offerings.current;
      if (current == null) {
        debugPrint('[IAPService] Nenhuma oferta disponível');
        return false;
      }

      // Busca o pacote de assinatura Amino+
      final aminoPlusPkg = current.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier.contains('amino_plus'),
        orElse: () => current.availablePackages.first,
      );

      final customerInfo = await Purchases.purchasePackage(aminoPlusPkg);
      _isAminoPlus =
          customerInfo.entitlements.active.containsKey(entitlementAminoPlus);

      // Sincronizar com Supabase
      final userId = SupabaseService.currentUserId;
      if (userId != null && _isAminoPlus) {
        await SupabaseService.table('profiles')
            .update({'is_amino_plus': true}).eq('id', userId);
      }
      return _isAminoPlus;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[IAPService] Assinatura cancelada pelo usuário');
      } else {
        debugPrint('[IAPService] Erro na assinatura: $e');
      }
      return false;
    } catch (e) {
      debugPrint('[IAPService] Erro inesperado na assinatura: $e');
      return false;
    }
  }

  /// Restaura compras anteriores
  static Future<bool> restorePurchases() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.restorePurchases();
      _isAminoPlus = info.entitlements.active.containsKey(entitlementAminoPlus);
      // Sincronizar com Supabase
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        await SupabaseService.table('profiles')
            .update({'is_amino_plus': _isAminoPlus}).eq('id', userId);
      }
      debugPrint('[IAPService] Compras restauradas. Amino+: $_isAminoPlus');
      return true;
    } catch (e) {
      debugPrint('[IAPService] Erro ao restaurar compras: $e');
      return false;
    }
  }

  /// Credita moedas no banco de dados via RPC do Supabase
  static Future<void> _creditCoins(int amount) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.client.rpc('transfer_coins', params: {
        'p_receiver_id': userId,
        'p_amount': amount,
        'p_reason': 'iap_purchase',
      });
    } catch (e) {
      // Fallback: atualizar diretamente
      try {
        final current = await SupabaseService.table('profiles')
            .select('coins')
            .eq('id', userId)
            .maybeSingle();
        final balance = (current?['coins'] ?? 0) as num;
        await SupabaseService.table('profiles')
            .update({'coins': balance + amount}).eq('id', userId);
      } catch (e2) {
        debugPrint('[IAPService] Erro ao creditar moedas: $e2');
      }
    }
  }

  /// Retorna a quantidade de moedas com base no ID do produto
  static int _coinsFromPackageId(String productId) {
    if (productId.contains('100')) return 100;
    if (productId.contains('500')) return 500;
    if (productId.contains('1200')) return 1200;
    if (productId.contains('3000')) return 3000;
    if (productId.contains('7000')) return 7000;
    return 0;
  }
}

/// Modelo de pacote de moedas
class CoinPackage {
  final String id;
  final int coins;
  final String priceLabel;
  final Package? revenueCatPackage;

  const CoinPackage({
    required this.id,
    required this.coins,
    required this.priceLabel,
    this.revenueCatPackage,
  });
}
